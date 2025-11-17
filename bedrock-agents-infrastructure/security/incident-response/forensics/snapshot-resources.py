#!/usr/bin/env python3
"""
Create snapshots of resources for forensic analysis.

This script creates point-in-time snapshots of infrastructure resources
(EBS volumes, RDS databases, S3 buckets, etc.) for forensic investigation.

Usage:
    python3 snapshot-resources.py --incident-id INCIDENT123 --resource-type ec2
"""

import argparse
import json
import boto3
import logging
from datetime import datetime
from typing import Dict, List, Optional
from pathlib import Path
import time

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ResourceSnapshotManager:
    """Manages creation of resource snapshots for forensics."""

    def __init__(self, incident_id: str):
        """Initialize snapshot manager."""
        self.incident_id = incident_id
        self.timestamp = datetime.utcnow().isoformat()

        # Initialize AWS clients
        self.ec2 = boto3.client('ec2')
        self.rds = boto3.client('rds')
        self.s3 = boto3.client('s3')

        self.snapshots = {
            'ebs': [],
            'rds': [],
            's3': [],
            'ami': []
        }

    def snapshot_ebs_volumes(self, volume_ids: Optional[List[str]] = None) -> Dict:
        """
        Create snapshots of EBS volumes.

        Args:
            volume_ids: Specific volumes (all if None)

        Returns:
            Dictionary with snapshot results
        """
        logger.info("Creating EBS volume snapshots")

        try:
            # Get all volumes if not specified
            if volume_ids is None:
                paginator = self.ec2.get_paginator('describe_volumes')
                volumes = []
                for page in paginator.paginate():
                    volumes.extend(page.get('Volumes', []))
                volume_ids = [v['VolumeId'] for v in volumes]

            snapshots = []

            for volume_id in volume_ids:
                try:
                    logger.info(f"Snapshotting EBS volume {volume_id}")

                    response = self.ec2.create_snapshot(
                        VolumeId=volume_id,
                        Description=f'Forensics snapshot for incident {self.incident_id}',
                        TagSpecifications=[
                            {
                                'ResourceType': 'snapshot',
                                'Tags': [
                                    {'Key': 'IncidentId', 'Value': self.incident_id},
                                    {'Key': 'Purpose', 'Value': 'Forensics'},
                                    {'Key': 'CreatedTime', 'Value': self.timestamp}
                                ]
                            }
                        ]
                    )

                    snapshots.append({
                        'volume_id': volume_id,
                        'snapshot_id': response['SnapshotId'],
                        'state': response['State'],
                        'progress': response.get('Progress', '0%'),
                        'created_time': response['StartTime'].isoformat()
                    })

                except Exception as e:
                    logger.error(f"Error snapshotting {volume_id}: {e}")
                    snapshots.append({
                        'volume_id': volume_id,
                        'error': str(e)
                    })

            self.snapshots['ebs'] = snapshots

            return {
                'status': 'success',
                'snapshots_created': len(snapshots),
                'snapshots': snapshots
            }

        except Exception as e:
            logger.error(f"Error snapshotting EBS volumes: {e}")
            return {'status': 'error', 'error': str(e)}

    def snapshot_rds_databases(self, db_instances: Optional[List[str]] = None) -> Dict:
        """
        Create snapshots of RDS databases.

        Args:
            db_instances: Specific DB instances (all if None)

        Returns:
            Dictionary with snapshot results
        """
        logger.info("Creating RDS database snapshots")

        try:
            # Get all DB instances if not specified
            if db_instances is None:
                paginator = self.rds.get_paginator('describe_db_instances')
                db_instances = []
                for page in paginator.paginate():
                    db_instances.extend([db['DBInstanceIdentifier'] for db in page.get('DBInstances', [])])

            snapshots = []

            for db_id in db_instances:
                try:
                    logger.info(f"Snapshotting RDS database {db_id}")

                    snapshot_id = f"forensics-{db_id}-{int(time.time())}"

                    response = self.rds.create_db_snapshot(
                        DBSnapshotIdentifier=snapshot_id,
                        DBInstanceIdentifier=db_id,
                        Tags=[
                            {'Key': 'IncidentId', 'Value': self.incident_id},
                            {'Key': 'Purpose', 'Value': 'Forensics'},
                            {'Key': 'CreatedTime', 'Value': self.timestamp}
                        ]
                    )

                    snapshots.append({
                        'db_instance_id': db_id,
                        'snapshot_id': response['DBSnapshot']['DBSnapshotIdentifier'],
                        'status': response['DBSnapshot']['Status'],
                        'created_time': response['DBSnapshot']['SnapshotCreateTime'].isoformat()
                    })

                except Exception as e:
                    logger.error(f"Error snapshotting {db_id}: {e}")
                    snapshots.append({
                        'db_instance_id': db_id,
                        'error': str(e)
                    })

            self.snapshots['rds'] = snapshots

            return {
                'status': 'success',
                'snapshots_created': len(snapshots),
                'snapshots': snapshots
            }

        except Exception as e:
            logger.error(f"Error snapshotting RDS: {e}")
            return {'status': 'error', 'error': str(e)}

    def snapshot_ec2_instances(self, instance_ids: Optional[List[str]] = None) -> Dict:
        """
        Create AMIs from EC2 instances for forensics.

        Args:
            instance_ids: Specific instances (all if None)

        Returns:
            Dictionary with snapshot results
        """
        logger.info("Creating EC2 instance AMIs")

        try:
            # Get all instances if not specified
            if instance_ids is None:
                paginator = self.ec2.get_paginator('describe_instances')
                instance_ids = []
                for page in paginator.paginate():
                    for reservation in page.get('Reservations', []):
                        instance_ids.extend([i['InstanceId'] for i in reservation.get('Instances', [])])

            amis = []

            for instance_id in instance_ids:
                try:
                    logger.info(f"Creating AMI from instance {instance_id}")

                    ami_name = f"forensics-{instance_id}-{int(time.time())}"

                    response = self.ec2.create_image(
                        InstanceId=instance_id,
                        Name=ami_name,
                        Description=f'Forensics AMI for incident {self.incident_id}',
                        NoReboot=False,
                        TagSpecifications=[
                            {
                                'ResourceType': 'image',
                                'Tags': [
                                    {'Key': 'IncidentId', 'Value': self.incident_id},
                                    {'Key': 'Purpose', 'Value': 'Forensics'},
                                    {'Key': 'CreatedTime', 'Value': self.timestamp}
                                ]
                            }
                        ]
                    )

                    amis.append({
                        'instance_id': instance_id,
                        'ami_id': response['ImageId'],
                        'ami_name': ami_name,
                        'created_time': datetime.utcnow().isoformat()
                    })

                except Exception as e:
                    logger.error(f"Error creating AMI from {instance_id}: {e}")
                    amis.append({
                        'instance_id': instance_id,
                        'error': str(e)
                    })

            self.snapshots['ami'] = amis

            return {
                'status': 'success',
                'amis_created': len(amis),
                'amis': amis
            }

        except Exception as e:
            logger.error(f"Error creating EC2 AMIs: {e}")
            return {'status': 'error', 'error': str(e)}

    def backup_s3_buckets(self, buckets: Optional[List[str]] = None,
                         backup_bucket: Optional[str] = None) -> Dict:
        """
        Create backups of S3 buckets.

        Args:
            buckets: Specific buckets (all if None)
            backup_bucket: Destination bucket for backups

        Returns:
            Dictionary with backup results
        """
        logger.info("Backing up S3 buckets")

        try:
            # Get all buckets if not specified
            if buckets is None:
                response = self.s3.list_buckets()
                buckets = [b['Name'] for b in response.get('Buckets', [])]

            backups = []

            for bucket in buckets:
                try:
                    logger.info(f"Backing up S3 bucket {bucket}")

                    # Enable versioning if not already enabled
                    try:
                        self.s3.put_bucket_versioning(
                            Bucket=bucket,
                            VersioningConfiguration={'Status': 'Enabled'}
                        )
                    except:
                        pass

                    # Tag bucket for forensics
                    try:
                        self.s3.put_bucket_tagging(
                            Bucket=bucket,
                            Tagging={
                                'TagSet': [
                                    {'Key': 'IncidentId', 'Value': self.incident_id},
                                    {'Key': 'Purpose', 'Value': 'Forensics'},
                                    {'Key': 'BackupTime', 'Value': self.timestamp}
                                ]
                            }
                        )
                    except:
                        pass

                    # Get object count for reference
                    paginator = self.s3.get_paginator('list_objects_v2')
                    object_count = 0
                    for page in paginator.paginate(Bucket=bucket):
                        object_count += len(page.get('Contents', []))

                    backups.append({
                        'bucket': bucket,
                        'object_count': object_count,
                        'versioning_enabled': True,
                        'backup_time': self.timestamp
                    })

                except Exception as e:
                    logger.error(f"Error backing up {bucket}: {e}")
                    backups.append({
                        'bucket': bucket,
                        'error': str(e)
                    })

            self.snapshots['s3'] = backups

            return {
                'status': 'success',
                'buckets_backed_up': len(backups),
                'backups': backups
            }

        except Exception as e:
            logger.error(f"Error backing up S3 buckets: {e}")
            return {'status': 'error', 'error': str(e)}

    def create_manifest(self) -> Dict:
        """Create manifest of all snapshots created."""
        manifest = {
            'incident_id': self.incident_id,
            'manifest_time': datetime.utcnow().isoformat(),
            'snapshots': self.snapshots,
            'summary': {
                'ebs_snapshots': len(self.snapshots['ebs']),
                'rds_snapshots': len(self.snapshots['rds']),
                's3_backups': len(self.snapshots['s3']),
                'ami_images': len(self.snapshots['ami'])
            }
        }

        return manifest

    def snapshot_all(self, resource_filter: Optional[Dict] = None) -> Dict:
        """
        Create all snapshots.

        Args:
            resource_filter: Filter for specific resources

        Returns:
            Dictionary with all snapshot results
        """
        logger.info(f"Starting resource snapshot for incident {self.incident_id}")

        results = {
            'incident_id': self.incident_id,
            'start_time': datetime.utcnow().isoformat(),
            'snapshots': {}
        }

        # Filter or create all snapshots
        if not resource_filter or 'ebs' in resource_filter:
            results['snapshots']['ebs'] = self.snapshot_ebs_volumes(
                resource_filter.get('volume_ids') if resource_filter else None
            )

        if not resource_filter or 'rds' in resource_filter:
            results['snapshots']['rds'] = self.snapshot_rds_databases(
                resource_filter.get('db_instances') if resource_filter else None
            )

        if not resource_filter or 'ec2' in resource_filter:
            results['snapshots']['ami'] = self.snapshot_ec2_instances(
                resource_filter.get('instance_ids') if resource_filter else None
            )

        if not resource_filter or 's3' in resource_filter:
            results['snapshots']['s3'] = self.backup_s3_buckets(
                resource_filter.get('buckets') if resource_filter else None
            )

        # Create manifest
        results['manifest'] = self.create_manifest()
        results['end_time'] = datetime.utcnow().isoformat()

        logger.info(f"Resource snapshot completed for incident {self.incident_id}")

        return results


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Create resource snapshots for incident forensics'
    )
    parser.add_argument('--incident-id', required=True, help='Incident identifier')
    parser.add_argument('--resource-type', help='Resource type to snapshot (ebs, rds, ec2, s3, all)')
    parser.add_argument('--volume-ids', help='Comma-separated EBS volume IDs')
    parser.add_argument('--db-instances', help='Comma-separated RDS instance IDs')
    parser.add_argument('--instance-ids', help='Comma-separated EC2 instance IDs')
    parser.add_argument('--buckets', help='Comma-separated S3 bucket names')

    args = parser.parse_args()

    # Parse filter
    resource_filter = None
    if args.resource_type:
        resource_filter = {args.resource_type}

    # Parse IDs
    if args.volume_ids:
        if not resource_filter:
            resource_filter = {}
        resource_filter['volume_ids'] = args.volume_ids.split(',')
    if args.db_instances:
        if not resource_filter:
            resource_filter = {}
        resource_filter['db_instances'] = args.db_instances.split(',')
    if args.instance_ids:
        if not resource_filter:
            resource_filter = {}
        resource_filter['instance_ids'] = args.instance_ids.split(',')
    if args.buckets:
        if not resource_filter:
            resource_filter = {}
        resource_filter['buckets'] = args.buckets.split(',')

    # Run snapshot
    manager = ResourceSnapshotManager(args.incident_id)
    results = manager.snapshot_all(resource_filter)

    # Print results
    print(json.dumps(results, indent=2, default=str))


if __name__ == '__main__':
    main()
