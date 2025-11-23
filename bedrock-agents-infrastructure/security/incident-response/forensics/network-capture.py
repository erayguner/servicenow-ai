#!/usr/bin/env python3
"""
Network traffic capture for forensic analysis.

This script captures network traffic from EC2 instances and VPC endpoints
using packet capture tools (tcpdump) and AWS VPC Flow Logs.

Usage:
    python3 network-capture.py --incident-id INCIDENT123 --instance-ids i-1234567,i-7654321
"""

import argparse
import json
import boto3
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import subprocess

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class NetworkCaptureManager:
    """Manages network traffic capture for forensics."""

    def __init__(self, incident_id: str):
        """Initialize network capture manager."""
        self.incident_id = incident_id
        self.timestamp = datetime.utcnow().isoformat()

        # Initialize AWS clients
        self.ec2 = boto3.client("ec2")
        self.ssm = boto3.client("ssm")
        self.cloudwatch = boto3.client("logs")

        self.captures = {
            "packet_captures": [],
            "vpc_flow_logs": [],
            "dns_queries": [],
            "connections": [],
        }

    def capture_instance_traffic(
        self, instance_id: str, duration: int = 300, filter_expr: str = ""
    ) -> Dict:
        """
        Capture network traffic from EC2 instance using tcpdump.

        Args:
            instance_id: EC2 instance ID
            duration: Capture duration in seconds
            filter_expr: tcpdump filter expression

        Returns:
            Dictionary with capture results
        """
        logger.info(f"Capturing network traffic from {instance_id} for {duration}s")

        try:
            # Check if instance has SSM agent
            response = self.ec2.describe_instances(InstanceIds=[instance_id])
            instance = response["Reservations"][0]["Instances"][0]

            # Build tcpdump command
            filter_args = f'"{filter_expr}"' if filter_expr else ""
            tcpdump_cmd = f"sudo tcpdump -i any -s0 -w /tmp/pcap-{self.incident_id}.pcap -G {duration} -W 1 {filter_args}"

            # Execute via SSM Session Manager
            try:
                response = self.ssm.start_session(
                    Target=instance_id, Document="AWS-StartInteractiveCommand"
                )

                # Note: This would require interactive terminal in production
                # Here we use Systems Manager to run the command
                response = self.ssm.send_command(
                    InstanceIds=[instance_id],
                    DocumentName="AWS-RunShellScript",
                    Parameters={
                        "command": [
                            f"timeout {duration + 10} tcpdump -i any -s0 -w /tmp/traffic-{self.incident_id}.pcap {filter_expr}",
                            f"aws s3 cp /tmp/traffic-{self.incident_id}.pcap s3://incident-evidence/{self.incident_id}/",
                        ]
                    },
                )

                return {
                    "status": "success",
                    "instance_id": instance_id,
                    "command_id": response["Command"]["CommandId"],
                    "message": "Packet capture initiated",
                }

            except Exception as e:
                logger.error(f"Error running packet capture: {e}")
                return {"status": "error", "instance_id": instance_id, "error": str(e)}

        except Exception as e:
            logger.error(f"Error preparing packet capture: {e}")
            return {"status": "error", "instance_id": instance_id, "error": str(e)}

    def analyze_vpc_flow_logs(self, vpc_ids: List[str], hours: int = 24) -> Dict:
        """
        Analyze VPC Flow Logs for suspicious network activity.

        Args:
            vpc_ids: List of VPC IDs
            hours: Hours to look back

        Returns:
            Dictionary with analysis results
        """
        logger.info(f"Analyzing VPC Flow Logs for {len(vpc_ids)} VPCs")

        try:
            flow_logs = {}

            for vpc_id in vpc_ids:
                try:
                    logger.info(f"Analyzing flow logs for VPC {vpc_id}")

                    # Get flow log data
                    response = self.ec2.describe_flow_logs(
                        Filter=[{"Name": "resource-id", "Values": [vpc_id]}]
                    )

                    flow_log_info = []

                    for fl in response.get("FlowLogs", []):
                        log_group = fl.get("LogGroupName")

                        if log_group:
                            # Query for rejected/suspicious flows
                            start_time = int(
                                (datetime.utcnow() - timedelta(hours=hours)).timestamp()
                                * 1000
                            )
                            end_time = int(datetime.utcnow().timestamp() * 1000)

                            query = """
                            fields @timestamp, srcip, dstip, srcport, dstport, action, bytes
                            | filter action = "REJECT"
                            | stats count() as rejected_flows, sum(bytes) as total_bytes by srcip, dstip
                            | sort total_bytes desc
                            """

                            try:
                                response = self.cloudwatch.start_query(
                                    logGroupName=log_group,
                                    startTime=start_time,
                                    endTime=end_time,
                                    queryString=query,
                                )

                                flow_log_info.append(
                                    {
                                        "log_group": log_group,
                                        "query_id": response["queryId"],
                                        "status": "initiated",
                                    }
                                )
                            except Exception as e:
                                logger.warning(f"Error querying {log_group}: {e}")

                        self.captures["vpc_flow_logs"].extend(flow_log_info)

                    flow_logs[vpc_id] = flow_log_info

                except Exception as e:
                    logger.error(f"Error analyzing VPC {vpc_id}: {e}")
                    flow_logs[vpc_id] = {"error": str(e)}

            return {
                "status": "success",
                "vpcs_analyzed": len(flow_logs),
                "flow_logs": flow_logs,
            }

        except Exception as e:
            logger.error(f"Error analyzing VPC Flow Logs: {e}")
            return {"status": "error", "error": str(e)}

    def capture_dns_queries(self, instance_ids: List[str], duration: int = 300) -> Dict:
        """
        Capture DNS queries from instances.

        Args:
            instance_ids: List of instance IDs
            duration: Capture duration in seconds

        Returns:
            Dictionary with DNS capture results
        """
        logger.info(f"Capturing DNS queries from {len(instance_ids)} instances")

        captures = []

        for instance_id in instance_ids:
            try:
                logger.info(f"Capturing DNS from {instance_id}")

                # Use tcpdump to capture DNS queries
                cmd = [
                    f'timeout {duration} tcpdump -i any -nn "port 53" -w /tmp/dns-{self.incident_id}.pcap',
                    f'tcpdump -r /tmp/dns-{self.incident_id}.pcap -A | grep -i "A\\|CNAME\\|MX"',
                ]

                response = self.ssm.send_command(
                    InstanceIds=[instance_id],
                    DocumentName="AWS-RunShellScript",
                    Parameters={"command": cmd},
                )

                captures.append(
                    {
                        "instance_id": instance_id,
                        "command_id": response["Command"]["CommandId"],
                        "status": "initiated",
                    }
                )

                self.captures["dns_queries"].append(
                    {
                        "instance_id": instance_id,
                        "command_id": response["Command"]["CommandId"],
                    }
                )

            except Exception as e:
                logger.error(f"Error capturing DNS from {instance_id}: {e}")
                captures.append({"instance_id": instance_id, "error": str(e)})

        return {"status": "success", "instances": len(captures), "captures": captures}

    def analyze_connections(self, instance_ids: List[str]) -> Dict:
        """
        Analyze active network connections on instances.

        Args:
            instance_ids: List of instance IDs

        Returns:
            Dictionary with connection analysis
        """
        logger.info(f"Analyzing network connections on {len(instance_ids)} instances")

        connections = []

        for instance_id in instance_ids:
            try:
                logger.info(f"Analyzing connections on {instance_id}")

                # Get netstat/ss output
                cmd = [
                    "netstat -tnp 2>/dev/null || ss -tnp",
                    "netstat -unp 2>/dev/null || ss -unp",
                    "lsof -i -P -n | head -100",
                ]

                response = self.ssm.send_command(
                    InstanceIds=[instance_id],
                    DocumentName="AWS-RunShellScript",
                    Parameters={"command": cmd},
                )

                connections.append(
                    {
                        "instance_id": instance_id,
                        "command_id": response["Command"]["CommandId"],
                        "status": "initiated",
                    }
                )

                self.captures["connections"].append(
                    {
                        "instance_id": instance_id,
                        "command_id": response["Command"]["CommandId"],
                    }
                )

            except Exception as e:
                logger.error(f"Error analyzing connections on {instance_id}: {e}")
                connections.append({"instance_id": instance_id, "error": str(e)})

        return {
            "status": "success",
            "instances": len(connections),
            "connections": connections,
        }

    def create_capture_manifest(self) -> Dict:
        """Create manifest of all network captures."""
        manifest = {
            "incident_id": self.incident_id,
            "capture_time": datetime.utcnow().isoformat(),
            "captures": self.captures,
            "summary": {
                "packet_captures": len(self.captures["packet_captures"]),
                "vpc_flow_logs": len(self.captures["vpc_flow_logs"]),
                "dns_captures": len(self.captures["dns_queries"]),
                "connection_snapshots": len(self.captures["connections"]),
            },
        }

        return manifest

    def capture_all(
        self,
        instance_ids: Optional[List[str]] = None,
        vpc_ids: Optional[List[str]] = None,
        duration: int = 300,
    ) -> Dict:
        """
        Capture all network traffic.

        Args:
            instance_ids: EC2 instances to capture from
            vpc_ids: VPCs to analyze flow logs from
            duration: Capture duration in seconds

        Returns:
            Dictionary with all capture results
        """
        logger.info(f"Starting network capture for incident {self.incident_id}")

        results = {
            "incident_id": self.incident_id,
            "start_time": datetime.utcnow().isoformat(),
            "captures": {},
        }

        if instance_ids:
            results["captures"]["packet_captures"] = []
            for iid in instance_ids:
                results["captures"]["packet_captures"].append(
                    self.capture_instance_traffic(iid, duration)
                )
            results["captures"]["dns_queries"] = self.capture_dns_queries(
                instance_ids, duration
            )
            results["captures"]["connections"] = self.analyze_connections(instance_ids)

        if vpc_ids:
            results["captures"]["vpc_flow_logs"] = self.analyze_vpc_flow_logs(vpc_ids)

        # Create manifest
        results["manifest"] = self.create_capture_manifest()
        results["end_time"] = datetime.utcnow().isoformat()

        logger.info(f"Network capture initiated for incident {self.incident_id}")

        return results


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Capture network traffic for incident forensics"
    )
    parser.add_argument("--incident-id", required=True, help="Incident identifier")
    parser.add_argument("--instance-ids", help="Comma-separated EC2 instance IDs")
    parser.add_argument("--vpc-ids", help="Comma-separated VPC IDs")
    parser.add_argument(
        "--duration", type=int, default=300, help="Capture duration in seconds"
    )
    parser.add_argument("--filter", default="", help="tcpdump filter expression")

    args = parser.parse_args()

    # Parse comma-separated IDs
    instance_ids = args.instance_ids.split(",") if args.instance_ids else None
    vpc_ids = args.vpc_ids.split(",") if args.vpc_ids else None

    # Run capture
    manager = NetworkCaptureManager(args.incident_id)
    results = manager.capture_all(instance_ids, vpc_ids, args.duration)

    # Print results
    print(json.dumps(results, indent=2, default=str))


if __name__ == "__main__":
    main()
