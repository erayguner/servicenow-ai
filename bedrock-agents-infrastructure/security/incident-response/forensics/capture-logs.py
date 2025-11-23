#!/usr/bin/env python3
"""
Comprehensive log capture for incident forensics.

This script captures all relevant logs from AWS services for incident investigation.
Supports CloudTrail, CloudWatch, VPC Flow Logs, application logs, and database logs.

Usage:
    python3 capture-logs.py --incident-id INCIDENT123 --resources resource1,resource2
"""

import argparse
import json
import boto3
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import os
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class LogCaptureManager:
    """Manages comprehensive log capture for incident forensics."""

    def __init__(self, incident_id: str, output_dir: str = "./incident-logs"):
        """
        Initialize log capture manager.

        Args:
            incident_id: Unique incident identifier
            output_dir: Directory for captured logs
        """
        self.incident_id = incident_id
        self.output_dir = Path(output_dir) / incident_id
        self.output_dir.mkdir(parents=True, exist_ok=True)

        # Initialize AWS clients
        self.cloudtrail = boto3.client('cloudtrail')
        self.cloudwatch = boto3.client('logs')
        self.ec2 = boto3.client('ec2')
        self.rds = boto3.client('rds')
        self.s3 = boto3.client('s3')

        self.logs_captured = {
            'cloudtrail': [],
            'cloudwatch': [],
            'vpc_flow': [],
            'application': [],
            'database': [],
            's3_access': []
        }

    def capture_cloudtrail_logs(self, hours: int = 24) -> Dict:
        """
        Capture CloudTrail events for the specified time range.

        Args:
            hours: Number of hours to look back

        Returns:
            Dictionary with capture results
        """
        logger.info(f"Capturing CloudTrail logs for {hours} hours")

        try:
            start_time = datetime.utcnow() - timedelta(hours=hours)
            end_time = datetime.utcnow()

            events = []
            paginator = self.cloudtrail.get_paginator('lookup_events')

            page_iterator = paginator.paginate(
                StartTime=start_time,
                EndTime=end_time
            )

            for page in page_iterator:
                for event in page.get('Events', []):
                    # Parse CloudTrail JSON
                    if isinstance(event.get('CloudTrailEvent'), str):
                        try:
                            event['CloudTrailEvent'] = json.loads(event['CloudTrailEvent'])
                        except json.JSONDecodeError:
                            pass
                    events.append(event)

            # Save to file
            output_file = self.output_dir / 'cloudtrail-events.json'
            with open(output_file, 'w') as f:
                json.dump(events, f, default=str, indent=2)

            logger.info(f"Captured {len(events)} CloudTrail events")
            self.logs_captured['cloudtrail'] = events

            return {
                'status': 'success',
                'events_captured': len(events),
                'output_file': str(output_file)
            }

        except Exception as e:
            logger.error(f"Error capturing CloudTrail logs: {e}")
            return {'status': 'error', 'error': str(e)}

    def capture_cloudwatch_logs(self, log_groups: Optional[List[str]] = None,
                               hours: int = 24) -> Dict:
        """
        Capture CloudWatch logs for specified log groups.

        Args:
            log_groups: List of log group names (all if None)
            hours: Number of hours to look back

        Returns:
            Dictionary with capture results
        """
        logger.info("Capturing CloudWatch logs")

        try:
            start_time = int((datetime.utcnow() - timedelta(hours=hours)).timestamp() * 1000)
            end_time = int(datetime.utcnow().timestamp() * 1000)

            # Get all log groups if not specified
            if log_groups is None:
                paginator = self.cloudwatch.get_paginator('describe_log_groups')
                log_groups = []
                for page in paginator.paginate():
                    log_groups.extend([lg['logGroupName'] for lg in page.get('logGroups', [])])

            all_logs = {}
            total_events = 0

            for log_group in log_groups:
                try:
                    logger.info(f"Capturing logs from {log_group}")
                    events = []

                    paginator = self.cloudwatch.get_paginator('filter_log_events')
                    page_iterator = paginator.paginate(
                        logGroupName=log_group,
                        startTime=start_time,
                        endTime=end_time
                    )

                    for page in page_iterator:
                        events.extend(page.get('events', []))

                    all_logs[log_group] = events
                    total_events += len(events)

                except Exception as e:
                    logger.warning(f"Error capturing {log_group}: {e}")
                    all_logs[log_group] = {'error': str(e)}

            # Save to file
            output_file = self.output_dir / 'cloudwatch-logs.json'
            with open(output_file, 'w') as f:
                json.dump(all_logs, f, default=str, indent=2)

            logger.info(f"Captured {total_events} CloudWatch events from {len(all_logs)} groups")
            self.logs_captured['cloudwatch'] = all_logs

            return {
                'status': 'success',
                'log_groups': len(all_logs),
                'total_events': total_events,
                'output_file': str(output_file)
            }

        except Exception as e:
            logger.error(f"Error capturing CloudWatch logs: {e}")
            return {'status': 'error', 'error': str(e)}

    def capture_vpc_flow_logs(self, vpc_ids: Optional[List[str]] = None,
                             hours: int = 24) -> Dict:
        """
        Capture VPC Flow Logs for forensic analysis.

        Args:
            vpc_ids: List of VPC IDs (all if None)
            hours: Number of hours to look back

        Returns:
            Dictionary with capture results
        """
        logger.info("Capturing VPC Flow Logs")

        try:
            # Get all VPCs if not specified
            if vpc_ids is None:
                vpcs = self.ec2.describe_vpcs()
                vpc_ids = [vpc['VpcId'] for vpc in vpcs.get('Vpcs', [])]

            start_time = int((datetime.utcnow() - timedelta(hours=hours)).timestamp())
            end_time = int(datetime.utcnow().timestamp())

            flow_logs = {}

            for vpc_id in vpc_ids:
                try:
                    logger.info(f"Capturing flow logs for VPC {vpc_id}")

                    # Get flow log destination
                    flow_logs_response = self.ec2.describe_flow_logs(
                        Filter=[{'Name': 'resource-id', 'Values': [vpc_id]}]
                    )

                    # Extract logs from CloudWatch (if stored there)
                    if flow_logs_response.get('FlowLogs'):
                        for fl in flow_logs_response['FlowLogs']:
                            log_group = fl.get('LogGroupName')
                            if log_group:
                                logs = []
                                paginator = self.cloudwatch.get_paginator('filter_log_events')
                                page_iterator = paginator.paginate(
                                    logGroupName=log_group,
                                    startTime=int(start_time * 1000),
                                    endTime=int(end_time * 1000)
                                )

                                for page in page_iterator:
                                    logs.extend(page.get('events', []))

                                flow_logs[vpc_id] = {
                                    'log_group': log_group,
                                    'event_count': len(logs),
                                    'logs': logs[:100]  # First 100 for review
                                }

                except Exception as e:
                    logger.warning(f"Error capturing flow logs for {vpc_id}: {e}")
                    flow_logs[vpc_id] = {'error': str(e)}

            # Save to file
            output_file = self.output_dir / 'vpc-flow-logs.json'
            with open(output_file, 'w') as f:
                json.dump(flow_logs, f, default=str, indent=2)

            logger.info(f"Captured VPC Flow Logs for {len(flow_logs)} VPCs")
            self.logs_captured['vpc_flow'] = flow_logs

            return {
                'status': 'success',
                'vpcs': len(flow_logs),
                'output_file': str(output_file)
            }

        except Exception as e:
            logger.error(f"Error capturing VPC Flow Logs: {e}")
            return {'status': 'error', 'error': str(e)}

    def capture_rds_logs(self, db_instances: Optional[List[str]] = None) -> Dict:
        """
        Capture RDS database logs.

        Args:
            db_instances: List of DB instance identifiers (all if None)

        Returns:
            Dictionary with capture results
        """
        logger.info("Capturing RDS logs")

        try:
            rds_logs = {}

            # Get all DB instances if not specified
            if db_instances is None:
                paginator = self.rds.get_paginator('describe_db_instances')
                db_instances = []
                for page in paginator.paginate():
                    db_instances.extend([db['DBInstanceIdentifier'] for db in page.get('DBInstances', [])])

            for db_id in db_instances:
                try:
                    logger.info(f"Capturing logs from RDS {db_id}")

                    # Get available log files
                    log_files = self.rds.describe_db_log_files(
                        DBInstanceIdentifier=db_id
                    )

                    db_logs = {}
                    for log_file in log_files.get('DescribeDBLogFiles', [])[:10]:  # Last 10 files
                        try:
                            log_content = self.rds.download_db_log_file_portion(
                                DBInstanceIdentifier=db_id,
                                LogFileName=log_file['LogFileName'],
                                FromTail=True,
                                NumLines=1000
                            )
                            db_logs[log_file['LogFileName']] = log_content['LogFileData']
                        except Exception as e:
                            logger.warning(f"Error downloading {log_file['LogFileName']}: {e}")

                    rds_logs[db_id] = db_logs

                except Exception as e:
                    logger.warning(f"Error capturing logs for {db_id}: {e}")
                    rds_logs[db_id] = {'error': str(e)}

            # Save to file
            output_file = self.output_dir / 'rds-logs.json'
            with open(output_file, 'w') as f:
                json.dump(rds_logs, f, default=str, indent=2)

            logger.info(f"Captured RDS logs for {len(rds_logs)} instances")
            self.logs_captured['database'] = rds_logs

            return {
                'status': 'success',
                'instances': len(rds_logs),
                'output_file': str(output_file)
            }

        except Exception as e:
            logger.error(f"Error capturing RDS logs: {e}")
            return {'status': 'error', 'error': str(e)}

    def capture_s3_access_logs(self, buckets: Optional[List[str]] = None) -> Dict:
        """
        Capture S3 access logs.

        Args:
            buckets: List of bucket names (all if None)

        Returns:
            Dictionary with capture results
        """
        logger.info("Capturing S3 access logs")

        try:
            s3_logs = {}

            # Get all buckets if not specified
            if buckets is None:
                response = self.s3.list_buckets()
                buckets = [b['Name'] for b in response.get('Buckets', [])]

            for bucket in buckets:
                try:
                    logger.info(f"Capturing access logs for bucket {bucket}")

                    # Get bucket logging configuration
                    try:
                        logging_config = self.s3.get_bucket_logging(Bucket=bucket)
                        log_bucket = logging_config.get('LoggingEnabled', {}).get('TargetBucket')

                        if log_bucket:
                            # List log files
                            paginator = self.s3.get_paginator('list_objects_v2')
                            page_iterator = paginator.paginate(Bucket=log_bucket)

                            log_files = []
                            for page in page_iterator:
                                log_files.extend([obj['Key'] for obj in page.get('Contents', [])])

                            s3_logs[bucket] = {
                                'log_bucket': log_bucket,
                                'log_count': len(log_files),
                                'sample_logs': log_files[-10:]  # Last 10 files
                            }
                        else:
                            s3_logs[bucket] = {'logging_enabled': False}

                    except Exception as e:
                        logger.warning(f"Error getting logging config for {bucket}: {e}")
                        s3_logs[bucket] = {'error': str(e)}

                except Exception as e:
                    logger.warning(f"Error processing bucket {bucket}: {e}")
                    s3_logs[bucket] = {'error': str(e)}

            # Save to file
            output_file = self.output_dir / 's3-access-logs.json'
            with open(output_file, 'w') as f:
                json.dump(s3_logs, f, default=str, indent=2)

            logger.info(f"Captured S3 logging info for {len(s3_logs)} buckets")
            self.logs_captured['s3_access'] = s3_logs

            return {
                'status': 'success',
                'buckets': len(s3_logs),
                'output_file': str(output_file)
            }

        except Exception as e:
            logger.error(f"Error capturing S3 access logs: {e}")
            return {'status': 'error', 'error': str(e)}

    def create_capture_summary(self) -> Dict:
        """Create summary of all captured logs."""
        summary = {
            'incident_id': self.incident_id,
            'capture_time': datetime.utcnow().isoformat(),
            'output_directory': str(self.output_dir),
            'captures': {}
        }

        for log_type, logs in self.logs_captured.items():
            if isinstance(logs, list):
                summary['captures'][log_type] = {'count': len(logs)}
            elif isinstance(logs, dict):
                summary['captures'][log_type] = {'count': len(logs)}
            else:
                summary['captures'][log_type] = {'status': 'captured'}

        # Save summary
        summary_file = self.output_dir / 'capture-summary.json'
        with open(summary_file, 'w') as f:
            json.dump(summary, f, indent=2)

        return summary

    def capture_all(self, resources: Optional[Dict] = None) -> Dict:
        """
        Capture all logs.

        Args:
            resources: Dictionary with specific resources to capture

        Returns:
            Dictionary with all capture results
        """
        logger.info(f"Starting comprehensive log capture for incident {self.incident_id}")

        results = {
            'incident_id': self.incident_id,
            'start_time': datetime.utcnow().isoformat(),
            'captures': {}
        }

        # Capture all log types
        results['captures']['cloudtrail'] = self.capture_cloudtrail_logs()
        results['captures']['cloudwatch'] = self.capture_cloudwatch_logs(
            log_groups=resources.get('log_groups') if resources else None
        )
        results['captures']['vpc_flow'] = self.capture_vpc_flow_logs(
            vpc_ids=resources.get('vpc_ids') if resources else None
        )
        results['captures']['rds'] = self.capture_rds_logs(
            db_instances=resources.get('db_instances') if resources else None
        )
        results['captures']['s3'] = self.capture_s3_access_logs(
            buckets=resources.get('buckets') if resources else None
        )

        # Create summary
        results['summary'] = self.create_capture_summary()
        results['end_time'] = datetime.utcnow().isoformat()

        logger.info(f"Log capture completed for incident {self.incident_id}")

        return results


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Capture logs for incident forensics'
    )
    parser.add_argument('--incident-id', required=True, help='Incident identifier')
    parser.add_argument('--output-dir', default='./incident-logs', help='Output directory')
    parser.add_argument('--log-groups', help='Comma-separated log group names')
    parser.add_argument('--vpc-ids', help='Comma-separated VPC IDs')
    parser.add_argument('--db-instances', help='Comma-separated DB instance IDs')
    parser.add_argument('--buckets', help='Comma-separated S3 bucket names')

    args = parser.parse_args()

    # Parse comma-separated arguments
    resources = {}
    if args.log_groups:
        resources['log_groups'] = args.log_groups.split(',')
    if args.vpc_ids:
        resources['vpc_ids'] = args.vpc_ids.split(',')
    if args.db_instances:
        resources['db_instances'] = args.db_instances.split(',')
    if args.buckets:
        resources['buckets'] = args.buckets.split(',')

    # Run capture
    manager = LogCaptureManager(args.incident_id, args.output_dir)
    results = manager.capture_all(resources or None)

    # Print results
    print(json.dumps(results, indent=2, default=str))


if __name__ == '__main__':
    main()
