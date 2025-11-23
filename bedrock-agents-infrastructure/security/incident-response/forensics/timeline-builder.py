#!/usr/bin/env python3
"""
Build incident timeline from forensic data.

This script aggregates logs and events from multiple sources to create
a comprehensive timeline of incident activities.

Usage:
    python3 timeline-builder.py --incident-id INCIDENT123 --start-time 2024-01-01T00:00:00
"""

import argparse
import json
import boto3
import logging
from datetime import datetime
from typing import Dict, List, Optional
from collections import defaultdict

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class TimelineBuilder:
    """Builds incident timeline from forensic data."""

    def __init__(
        self,
        incident_id: str,
        start_time: datetime,
        end_time: Optional[datetime] = None,
    ):
        """
        Initialize timeline builder.

        Args:
            incident_id: Unique incident identifier
            start_time: Timeline start time
            end_time: Timeline end time (now if None)
        """
        self.incident_id = incident_id
        self.start_time = start_time
        self.end_time = end_time or datetime.utcnow()

        # Initialize AWS clients
        self.cloudtrail = boto3.client("cloudtrail")
        self.cloudwatch = boto3.client("logs")
        self.ec2 = boto3.client("ec2")
        self.rds = boto3.client("rds")

        # Timeline events storage
        self.events = []

    def parse_cloudtrail_events(self) -> List[Dict]:
        """Parse CloudTrail events into timeline format."""
        logger.info("Parsing CloudTrail events")

        events = []

        try:
            paginator = self.cloudtrail.get_paginator("lookup_events")
            page_iterator = paginator.paginate(
                StartTime=self.start_time, EndTime=self.end_time
            )

            for page in page_iterator:
                for event in page.get("Events", []):
                    try:
                        # Parse event JSON
                        event_data = json.loads(event.get("CloudTrailEvent", "{}"))

                        timeline_event = {
                            "timestamp": (
                                event["EventTime"].isoformat()
                                if hasattr(event["EventTime"], "isoformat")
                                else str(event["EventTime"])
                            ),
                            "source": "CloudTrail",
                            "event_type": event.get("EventName"),
                            "principal": event.get("Username"),
                            "source_ip": event_data.get("sourceIPAddress"),
                            "resource_type": event_data.get(
                                "requestParameters", {}
                            ).get("resource"),
                            "action": event.get("EventName"),
                            "status": (
                                "Success" if event.get("CloudTrailEvent") else "Unknown"
                            ),
                            "raw_event": event_data,
                        }

                        events.append(timeline_event)

                    except Exception as e:
                        logger.warning(f"Error parsing CloudTrail event: {e}")

            logger.info(f"Parsed {len(events)} CloudTrail events")

        except Exception as e:
            logger.error(f"Error retrieving CloudTrail events: {e}")

        return events

    def parse_vpc_flow_logs(self, vpc_ids: Optional[List[str]] = None) -> List[Dict]:
        """Parse VPC Flow Logs into timeline format."""
        logger.info("Parsing VPC Flow Logs")

        events = []

        try:
            if vpc_ids is None:
                vpcs = self.ec2.describe_vpcs()
                vpc_ids = [vpc["VpcId"] for vpc in vpcs.get("Vpcs", [])]

            for vpc_id in vpc_ids:
                try:
                    # Get flow logs
                    flow_logs_response = self.ec2.describe_flow_logs(
                        Filter=[{"Name": "resource-id", "Values": [vpc_id]}]
                    )

                    for fl in flow_logs_response.get("FlowLogs", []):
                        log_group = fl.get("LogGroupName")
                        if log_group:
                            start_time = int(self.start_time.timestamp() * 1000)
                            end_time = int(self.end_time.timestamp() * 1000)

                            # Query for rejected flows (suspicious activity)
                            query = """
                            fields @timestamp, srcip, dstip, srcport, dstport, action, bytes, packets
                            | filter action = "REJECT"
                            """

                            response = self.cloudwatch.start_query(
                                logGroupName=log_group,
                                startTime=start_time,
                                endTime=end_time,
                                queryString=query,
                            )

                            # Note: In production, would poll for results
                            events.append(
                                {
                                    "timestamp": datetime.utcnow().isoformat(),
                                    "source": "VPC Flow Logs",
                                    "vpc_id": vpc_id,
                                    "query_id": response["queryId"],
                                    "log_group": log_group,
                                }
                            )

                except Exception as e:
                    logger.warning(f"Error parsing flow logs for {vpc_id}: {e}")

        except Exception as e:
            logger.error(f"Error parsing VPC Flow Logs: {e}")

        return events

    def parse_cloudwatch_logs(
        self, log_groups: Optional[List[str]] = None
    ) -> List[Dict]:
        """Parse CloudWatch logs into timeline format."""
        logger.info("Parsing CloudWatch logs")

        events = []

        try:
            if log_groups is None:
                paginator = self.cloudwatch.get_paginator("describe_log_groups")
                log_groups = []
                for page in paginator.paginate():
                    log_groups.extend(
                        [lg["logGroupName"] for lg in page.get("logGroups", [])]
                    )

            for log_group in log_groups:
                try:
                    logger.info(f"Querying {log_group}")

                    start_time = int(self.start_time.timestamp() * 1000)
                    end_time = int(self.end_time.timestamp() * 1000)

                    # Query for error/warning events
                    query = """
                    fields @timestamp, @message, @logStream
                    | filter @message like /ERROR|WARNING|CRITICAL|FATAL|exception/
                    | sort @timestamp desc
                    """

                    response = self.cloudwatch.start_query(
                        logGroupName=log_group,
                        startTime=start_time,
                        endTime=end_time,
                        queryString=query,
                    )

                    events.append(
                        {
                            "timestamp": datetime.utcnow().isoformat(),
                            "source": "CloudWatch",
                            "log_group": log_group,
                            "query_id": response["queryId"],
                        }
                    )

                except Exception as e:
                    logger.warning(f"Error querying {log_group}: {e}")

        except Exception as e:
            logger.error(f"Error parsing CloudWatch logs: {e}")

        return events

    def correlate_events(self, events: List[Dict]) -> List[Dict]:
        """
        Correlate events from multiple sources.

        Args:
            events: List of timeline events

        Returns:
            List of correlated events with relationships
        """
        logger.info(f"Correlating {len(events)} events")

        # Sort by timestamp
        sorted_events = sorted(events, key=lambda x: x.get("timestamp", ""))

        # Group by source IP and time window (5 min)
        correlations = defaultdict(list)

        for event in sorted_events:
            source_ip = event.get("source_ip")
            timestamp = event.get("timestamp")

            if source_ip and timestamp:
                correlations[source_ip].append(event)

        # Add correlation info
        correlated = []
        for event in sorted_events:
            source_ip = event.get("source_ip")

            if source_ip in correlations:
                event["related_events"] = len(correlations[source_ip]) - 1
                event["source_ip_activity"] = len(correlations[source_ip])

            correlated.append(event)

        return correlated

    def build_timeline(self) -> Dict:
        """
        Build complete incident timeline.

        Returns:
            Dictionary with timeline and analysis
        """
        logger.info(f"Building timeline for incident {self.incident_id}")

        # Collect events from all sources
        logger.info("Collecting events from all sources...")
        all_events = []

        # CloudTrail events
        cloudtrail_events = self.parse_cloudtrail_events()
        all_events.extend(cloudtrail_events)
        logger.info(f"Collected {len(cloudtrail_events)} CloudTrail events")

        # VPC Flow Logs
        vpc_events = self.parse_vpc_flow_logs()
        all_events.extend(vpc_events)
        logger.info(f"Collected {len(vpc_events)} VPC events")

        # CloudWatch logs
        cw_events = self.parse_cloudwatch_logs()
        all_events.extend(cw_events)
        logger.info(f"Collected {len(cw_events)} CloudWatch events")

        # Sort and correlate events
        logger.info("Sorting and correlating events...")
        correlated_events = self.correlate_events(all_events)

        # Analyze event patterns
        logger.info("Analyzing event patterns...")
        analysis = self.analyze_patterns(correlated_events)

        # Build timeline output
        timeline = {
            "incident_id": self.incident_id,
            "timeline_period": {
                "start": self.start_time.isoformat(),
                "end": self.end_time.isoformat(),
                "duration_seconds": (self.end_time - self.start_time).total_seconds(),
            },
            "total_events": len(correlated_events),
            "events_by_source": self._count_by_source(correlated_events),
            "timeline": correlated_events,
            "analysis": analysis,
            "generated_time": datetime.utcnow().isoformat(),
        }

        return timeline

    def _count_by_source(self, events: List[Dict]) -> Dict[str, int]:
        """Count events by source."""
        counts = defaultdict(int)
        for event in events:
            source = event.get("source", "Unknown")
            counts[source] += 1
        return dict(counts)

    def analyze_patterns(self, events: List[Dict]) -> Dict:
        """Analyze event patterns for insights."""
        analysis = {
            "top_principals": defaultdict(int),
            "top_source_ips": defaultdict(int),
            "top_event_types": defaultdict(int),
            "suspicious_patterns": [],
        }

        for event in events:
            # Count by principal
            principal = event.get("principal", "Unknown")
            analysis["top_principals"][principal] += 1

            # Count by source IP
            source_ip = event.get("source_ip", "Unknown")
            if source_ip:
                analysis["top_source_ips"][source_ip] += 1

            # Count by event type
            event_type = event.get("event_type", "Unknown")
            analysis["top_event_types"][event_type] += 1

        # Find top items
        analysis["top_principals"] = dict(
            sorted(
                analysis["top_principals"].items(), key=lambda x: x[1], reverse=True
            )[:5]
        )
        analysis["top_source_ips"] = dict(
            sorted(
                analysis["top_source_ips"].items(), key=lambda x: x[1], reverse=True
            )[:5]
        )
        analysis["top_event_types"] = dict(
            sorted(
                analysis["top_event_types"].items(), key=lambda x: x[1], reverse=True
            )[:10]
        )

        return dict(analysis)

    def export_timeline(self, output_file: str) -> str:
        """Export timeline to file."""
        timeline = self.build_timeline()

        with open(output_file, "w") as f:
            json.dump(timeline, f, indent=2, default=str)

        logger.info(f"Timeline exported to {output_file}")
        return output_file


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Build incident timeline from forensic data"
    )
    parser.add_argument("--incident-id", required=True, help="Incident identifier")
    parser.add_argument(
        "--start-time", required=True, help="Timeline start time (ISO format)"
    )
    parser.add_argument(
        "--end-time", help="Timeline end time (ISO format, now if not specified)"
    )
    parser.add_argument("--output-file", default="timeline.json", help="Output file")

    args = parser.parse_args()

    # Parse times
    start_time = datetime.fromisoformat(args.start_time.replace("Z", "+00:00"))
    end_time = None
    if args.end_time:
        end_time = datetime.fromisoformat(args.end_time.replace("Z", "+00:00"))

    # Build timeline
    builder = TimelineBuilder(args.incident_id, start_time, end_time)
    output_file = builder.export_timeline(args.output_file)

    print(f"Timeline created: {output_file}")


if __name__ == "__main__":
    main()
