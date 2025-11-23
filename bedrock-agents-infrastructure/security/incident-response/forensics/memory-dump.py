#!/usr/bin/env python3
"""
Memory dump and analysis for EC2 and Lambda functions.

This script captures memory dumps from EC2 instances and analyzes
Lambda function memory for forensic investigation.

Usage:
    python3 memory-dump.py --incident-id INCIDENT123 --instance-ids i-1234567
"""

import argparse
import json
import boto3
import logging
from datetime import datetime
from typing import Any, Dict, List, Optional

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class MemoryDumpManager:
    """Manages memory dump collection for forensics."""

    def __init__(self, incident_id: str):
        """Initialize memory dump manager."""
        self.incident_id = incident_id
        self.timestamp = datetime.utcnow().isoformat()

        # Initialize AWS clients
        self.ec2 = boto3.client("ec2")
        self.ssm = boto3.client("ssm")
        self.lambda_client = boto3.client("lambda")
        self.cloudwatch = boto3.client("logs")

        self.dumps: Dict[str, List] = {
            "ec2_memory": [],
            "lambda_memory": [],
            "process_dumps": [],
        }

    def dump_ec2_memory(self, instance_id: str) -> Dict:
        """
        Dump memory from EC2 instance using /dev/mem or crash dump.

        Args:
            instance_id: EC2 instance ID

        Returns:
            Dictionary with dump results
        """
        logger.info(f"Dumping memory from EC2 instance {instance_id}")

        try:
            # Verify instance exists and is running
            response = self.ec2.describe_instances(InstanceIds=[instance_id])
            instance = response["Reservations"][0]["Instances"][0]
            state = instance["State"]["Name"]

            if state != "running":
                logger.warning(
                    f"Instance {instance_id} is not running (state: {state})"
                )
                return {
                    "status": "skipped",
                    "instance_id": instance_id,
                    "reason": f"Instance state is {state}",
                }

            # Use core dump if available, otherwise use crash dump
            commands = [
                "mkdir -p /tmp/forensics",
                "cd /tmp/forensics",
                # Try to trigger core dump
                "ulimit -c unlimited",
                # Get process list for targeting
                "ps auxww > processes.txt",
                # Dump specific high-privilege processes
                "for pid in $(pgrep -u root | head -20); do gcore -o core-$pid $pid 2>/dev/null; done",
                # If crash dump available
                "if [ -f /var/crash/dmesg* ]; then cat /var/crash/dmesg* > system-crash.log; fi",
                # Get kernel logs
                "dmesg > kernel-messages.log",
                # Get memory info
                "cat /proc/meminfo > meminfo.txt",
                "cat /proc/slabinfo > slabinfo.txt",
                # Package everything
                f"tar czf /tmp/memory-dump-{self.incident_id}.tar.gz .",
                f"aws s3 cp /tmp/memory-dump-{self.incident_id}.tar.gz s3://incident-evidence/{self.incident_id}/",
            ]

            response = self.ssm.send_command(
                InstanceIds=[instance_id],
                DocumentName="AWS-RunShellScript",
                Parameters={"command": commands},
            )

            dump_info = {
                "status": "initiated",
                "instance_id": instance_id,
                "command_id": response["Command"]["CommandId"],
                "instance_type": instance.get("InstanceType"),
                "private_ip": instance["PrivateIpAddress"],
                "initiated_time": datetime.utcnow().isoformat(),
            }

            self.dumps["ec2_memory"].append(dump_info)

            return dump_info

        except Exception as e:
            logger.error(f"Error dumping EC2 memory: {e}")
            return {"status": "error", "instance_id": instance_id, "error": str(e)}

    def dump_lambda_memory(self, function_names: List[str]) -> Dict:
        """
        Capture Lambda function execution context and memory usage.

        Args:
            function_names: List of Lambda function names

        Returns:
            Dictionary with Lambda memory dump results
        """
        logger.info(
            f"Capturing memory dumps from {len(function_names)} Lambda functions"
        )

        dumps = []

        for func_name in function_names:
            try:
                logger.info(f"Capturing memory from {func_name}")

                # Get function configuration
                func_config = self.lambda_client.get_function(FunctionName=func_name)
                func_info = func_config["Configuration"]

                # Get recent invocations from CloudWatch
                log_group = f"/aws/lambda/{func_name}"

                try:
                    # Query for recent executions
                    query = """
                    fields @timestamp, @duration, @maxMemoryUsed, @memorySize, @initDuration
                    | stats max(@maxMemoryUsed) as peak_memory,
                             avg(@duration) as avg_duration,
                             max(@duration) as max_duration,
                             count() as invocations
                    """

                    response = self.cloudwatch.start_query(
                        logGroupName=log_group,
                        startTime=int((datetime.utcnow().timestamp() - 3600)),
                        endTime=int(datetime.utcnow().timestamp()),
                        queryString=query,
                    )

                    dump_info = {
                        "status": "captured",
                        "function_name": func_name,
                        "configured_memory": func_info.get("MemorySize"),
                        "handler": func_info.get("Handler"),
                        "runtime": func_info.get("Runtime"),
                        "timeout": func_info.get("Timeout"),
                        "query_id": response["queryId"],
                    }

                except Exception as e:
                    logger.warning(f"Error querying CloudWatch for {func_name}: {e}")
                    dump_info = {
                        "status": "partial",
                        "function_name": func_name,
                        "configured_memory": func_info.get("MemorySize"),
                        "warning": "CloudWatch query failed",
                    }

                self.dumps["lambda_memory"].append(dump_info)
                dumps.append(dump_info)

            except Exception as e:
                logger.error(f"Error capturing Lambda memory: {e}")
                dumps.append(
                    {"function_name": func_name, "status": "error", "error": str(e)}
                )

        return {"status": "success", "functions_captured": len(dumps), "dumps": dumps}

    def dump_process_memory(self, instance_id: str, process_names: List[str]) -> Dict:
        """
        Dump memory of specific processes on an instance.

        Args:
            instance_id: EC2 instance ID
            process_names: List of process names to dump

        Returns:
            Dictionary with process dump results
        """
        logger.info(
            f"Dumping memory for {len(process_names)} processes on {instance_id}"
        )

        try:
            commands = [
                "mkdir -p /tmp/forensics/process-dumps",
                "cd /tmp/forensics/process-dumps",
            ]

            for proc_name in process_names:
                commands.extend(
                    [
                        f"# Dumping {proc_name}",
                        f"pids=$(pgrep {proc_name})",
                        "for pid in $pids; do",
                        '  echo "Dumping PID: $pid"',
                        "  # Get process memory map",
                        "  cat /proc/$pid/maps > maps-$pid.txt",
                        "  # Get process environ",
                        "  cat /proc/$pid/environ | tr \\0 \\n > environ-$pid.txt",
                        "  # Get open files",
                        "  ls -la /proc/$pid/fd > files-$pid.txt 2>&1",
                        "  # Get memory stats",
                        "  cat /proc/$pid/status > status-$pid.txt",
                        "  # Core dump if gcore available",
                        "  gcore -o core-$pid $pid 2>/dev/null",
                        "done",
                    ]
                )

            commands.extend(
                [
                    f"tar czf /tmp/process-dumps-{self.incident_id}.tar.gz .",
                    f"aws s3 cp /tmp/process-dumps-{self.incident_id}.tar.gz s3://incident-evidence/{self.incident_id}/",
                ]
            )

            response = self.ssm.send_command(
                InstanceIds=[instance_id],
                DocumentName="AWS-RunShellScript",
                Parameters={"command": commands},
            )

            dump_info = {
                "status": "initiated",
                "instance_id": instance_id,
                "processes": process_names,
                "command_id": response["Command"]["CommandId"],
                "initiated_time": datetime.utcnow().isoformat(),
            }

            self.dumps["process_dumps"].append(dump_info)

            return dump_info

        except Exception as e:
            logger.error(f"Error dumping process memory: {e}")
            return {"status": "error", "instance_id": instance_id, "error": str(e)}

    def create_dump_manifest(self) -> Dict:
        """Create manifest of all memory dumps."""
        manifest = {
            "incident_id": self.incident_id,
            "manifest_time": datetime.utcnow().isoformat(),
            "dumps": self.dumps,
            "summary": {
                "ec2_instances_dumped": len(self.dumps["ec2_memory"]),
                "lambda_functions_dumped": len(self.dumps["lambda_memory"]),
                "processes_dumped": len(self.dumps["process_dumps"]),
            },
        }

        return manifest

    def dump_all(
        self,
        instance_ids: Optional[List[str]] = None,
        function_names: Optional[List[str]] = None,
        process_names: Optional[List[str]] = None,
    ) -> Dict:
        """
        Collect all memory dumps.

        Args:
            instance_ids: EC2 instances to dump
            function_names: Lambda functions to dump
            process_names: Specific processes to dump (on all instances)

        Returns:
            Dictionary with all dump results
        """
        logger.info(f"Starting memory dump collection for incident {self.incident_id}")

        results: Dict[str, Any] = {
            "incident_id": self.incident_id,
            "start_time": datetime.utcnow().isoformat(),
            "dumps": {},
        }

        if instance_ids:
            results["dumps"]["ec2_memory"] = []
            for iid in instance_ids:
                results["dumps"]["ec2_memory"].append(self.dump_ec2_memory(iid))

            # Dump specific processes if provided
            if process_names:
                results["dumps"]["process_memory"] = []
                for iid in instance_ids:
                    results["dumps"]["process_memory"].append(
                        self.dump_process_memory(iid, process_names)
                    )

        if function_names:
            results["dumps"]["lambda_memory"] = self.dump_lambda_memory(function_names)

        # Create manifest
        results["manifest"] = self.create_dump_manifest()
        results["end_time"] = datetime.utcnow().isoformat()

        logger.info(f"Memory dump collection initiated for incident {self.incident_id}")

        return results


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description="Dump memory for incident forensics")
    parser.add_argument("--incident-id", required=True, help="Incident identifier")
    parser.add_argument("--instance-ids", help="Comma-separated EC2 instance IDs")
    parser.add_argument(
        "--function-names", help="Comma-separated Lambda function names"
    )
    parser.add_argument("--process-names", help="Comma-separated process names to dump")

    args = parser.parse_args()

    # Parse comma-separated arguments
    instance_ids = args.instance_ids.split(",") if args.instance_ids else None
    function_names = args.function_names.split(",") if args.function_names else None
    process_names = args.process_names.split(",") if args.process_names else None

    # Run dump
    manager = MemoryDumpManager(args.incident_id)
    results = manager.dump_all(instance_ids, function_names, process_names)

    # Print results
    print(json.dumps(results, indent=2, default=str))


if __name__ == "__main__":
    main()
