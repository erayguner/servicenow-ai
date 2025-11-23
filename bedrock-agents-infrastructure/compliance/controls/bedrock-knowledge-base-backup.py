"""
AWS Config Custom Rule: Bedrock Knowledge Base Backup Check
Ensures Bedrock knowledge bases have proper backup configuration
"""

import json
import boto3
from datetime import datetime

config = boto3.client("config")
bedrock_agent = boto3.client("bedrock-agent")
backup = boto3.client("backup")
s3 = boto3.client("s3")


def lambda_handler(event, context):
    """
    Main Lambda handler for AWS Config custom rule evaluation
    """
    invoking_event = json.loads(event["invokingEvent"])
    configuration_item = invoking_event.get("configurationItem")

    rule_parameters = json.loads(event.get("ruleParameters", "{}"))
    min_retention_days = int(
        rule_parameters.get("MinRetentionDays", "2557")
    )  # 7 years default

    resource_type = configuration_item.get("resourceType")

    if resource_type == "AWS::Bedrock::KnowledgeBase":
        compliance = evaluate_knowledge_base_backup(
            configuration_item, min_retention_days
        )
    else:
        compliance = {
            "compliance_type": "NOT_APPLICABLE",
            "annotation": f"Resource type {resource_type} not evaluated by this rule",
        }

    put_evaluation(
        config_rule_name=event["configRuleName"],
        resource_type=resource_type,
        resource_id=configuration_item.get("resourceId"),
        compliance_type=compliance["compliance_type"],
        annotation=compliance["annotation"],
        result_token=event["resultToken"],
    )

    return {
        "statusCode": 200,
        "body": json.dumps(
            {
                "compliance": compliance["compliance_type"],
                "annotation": compliance["annotation"],
            }
        ),
    }


def evaluate_knowledge_base_backup(configuration_item, min_retention_days):
    """
    Evaluate backup configuration for Bedrock Knowledge Base
    """
    resource_id = configuration_item.get("resourceId")
    resource_arn = configuration_item.get("ARN")

    try:
        # Get knowledge base details
        kb_details = bedrock_agent.get_knowledge_base(knowledgeBaseId=resource_id)

        storage_config = kb_details.get("knowledgeBase", {}).get(
            "storageConfiguration", {}
        )

        violations = []

        # Check S3 data source backup
        data_sources_response = bedrock_agent.list_data_sources(
            knowledgeBaseId=resource_id
        )

        for ds_summary in data_sources_response.get("dataSourceSummaries", []):
            ds_id = ds_summary.get("dataSourceId")

            ds_details = bedrock_agent.get_data_source(
                knowledgeBaseId=resource_id, dataSourceId=ds_id
            )

            data_source_config = ds_details.get("dataSource", {}).get(
                "dataSourceConfiguration", {}
            )

            # S3 data source
            if "s3Configuration" in data_source_config:
                bucket_arn = data_source_config["s3Configuration"].get("bucketArn")
                bucket_name = bucket_arn.split(":::")[-1] if bucket_arn else None

                if bucket_name:
                    # Check S3 bucket versioning
                    versioning_enabled = check_s3_versioning(bucket_name)
                    if not versioning_enabled:
                        violations.append(
                            f"S3 data source bucket {bucket_name} does not have versioning enabled"
                        )

                    # Check AWS Backup configuration for S3 bucket
                    backup_configured = check_aws_backup_configuration(
                        bucket_arn, min_retention_days
                    )
                    if not backup_configured:
                        violations.append(
                            f"S3 data source bucket {bucket_name} does not have AWS Backup configured with required retention ({min_retention_days} days)"
                        )

        # Check vector database backup (if RDS/Aurora)
        if "rdsConfiguration" in storage_config:
            resource_arn_value = storage_config["rdsConfiguration"].get("resourceArn")

            if resource_arn_value:
                # Check RDS automated backups
                rds_backup_configured = check_rds_backup_configuration(
                    resource_arn_value, min_retention_days
                )
                if not rds_backup_configured:
                    violations.append(
                        f"RDS vector database does not have automated backups with required retention"
                    )

        # Check OpenSearch Serverless (automatic backups are managed by AWS)
        if "opensearchServerlessConfiguration" in storage_config:
            # OpenSearch Serverless provides automatic backups, no action needed
            pass

        # Evaluate compliance
        if violations:
            return {
                "compliance_type": "NON_COMPLIANT",
                "annotation": f"Backup configuration violations: {'; '.join(violations)}",
            }
        else:
            return {
                "compliance_type": "COMPLIANT",
                "annotation": f"Knowledge base has proper backup configuration with {min_retention_days} days retention",
            }

    except Exception as e:
        return {
            "compliance_type": "NON_COMPLIANT",
            "annotation": f"Error evaluating knowledge base backup: {str(e)}",
        }


def check_s3_versioning(bucket_name):
    """
    Check if S3 bucket has versioning enabled
    """
    try:
        response = s3.get_bucket_versioning(Bucket=bucket_name)
        status = response.get("Status")
        return status == "Enabled"
    except Exception as e:
        print(f"Error checking S3 versioning: {e}")
        return False


def check_aws_backup_configuration(resource_arn, min_retention_days):
    """
    Check if resource is included in AWS Backup plan with required retention
    """
    try:
        # List backup selections that include this resource
        backup_plans = backup.list_backup_plans()

        for plan in backup_plans.get("BackupPlansList", []):
            plan_id = plan["BackupPlanId"]

            # Get backup plan details
            plan_details = backup.get_backup_plan(BackupPlanId=plan_id)
            rules = plan_details.get("BackupPlan", {}).get("Rules", [])

            # Check if any rule meets retention requirement
            for rule in rules:
                lifecycle = rule.get("Lifecycle", {})
                delete_after_days = lifecycle.get("DeleteAfterDays")

                if delete_after_days and delete_after_days >= min_retention_days:
                    # Check if this resource is selected
                    selections = backup.list_backup_selections(BackupPlanId=plan_id)

                    for selection_summary in selections.get("BackupSelectionsList", []):
                        selection_id = selection_summary["SelectionId"]
                        selection_details = backup.get_backup_selection(
                            BackupPlanId=plan_id, SelectionId=selection_id
                        )

                        selection_resources = selection_details.get(
                            "BackupSelection", {}
                        ).get("Resources", [])

                        # Check if resource is included (exact match or wildcard)
                        for selected_resource in selection_resources:
                            if (
                                selected_resource == resource_arn
                                or selected_resource.endswith("*")
                            ):
                                return True

        return False

    except Exception as e:
        print(f"Error checking AWS Backup configuration: {e}")
        return False


def check_rds_backup_configuration(resource_arn, min_retention_days):
    """
    Check RDS automated backup configuration
    """
    try:
        rds = boto3.client("rds")

        db_instance_id = resource_arn.split(":")[-1]

        response = rds.describe_db_instances(DBInstanceIdentifier=db_instance_id)

        instances = response.get("DBInstances", [])
        if not instances:
            return False

        instance = instances[0]

        backup_retention_period = instance.get("BackupRetentionPeriod", 0)

        # RDS retention is in days (max 35 days), so check if >= min or if AWS Backup is used
        if backup_retention_period >= min(min_retention_days, 35):
            return True

        # Check if AWS Backup is configured for long-term retention
        return check_aws_backup_configuration(resource_arn, min_retention_days)

    except Exception as e:
        print(f"Error checking RDS backup: {e}")
        return False


def put_evaluation(
    config_rule_name,
    resource_type,
    resource_id,
    compliance_type,
    annotation,
    result_token,
):
    """
    Submit evaluation result to AWS Config
    """
    try:
        config.put_evaluations(
            Evaluations=[
                {
                    "ComplianceResourceType": resource_type,
                    "ComplianceResourceId": resource_id,
                    "ComplianceType": compliance_type,
                    "Annotation": annotation,
                    "OrderingTimestamp": datetime.now(),
                }
            ],
            ResultToken=result_token,
        )
        print(f"Evaluation submitted: {compliance_type} - {annotation}")
    except Exception as e:
        print(f"Error submitting evaluation: {e}")
        raise


if __name__ == "__main__":
    test_event = {
        "configRuleName": "bedrock-knowledge-base-backup",
        "invokingEvent": json.dumps(
            {
                "configurationItem": {
                    "resourceType": "AWS::Bedrock::KnowledgeBase",
                    "resourceId": "test-kb-id",
                    "ARN": "arn:aws:bedrock:us-east-1:123456789012:knowledge-base/test-kb-id",
                }
            }
        ),
        "ruleParameters": json.dumps({"MinRetentionDays": "2557"}),  # 7 years
        "resultToken": "test-token",
    }

    result = lambda_handler(test_event, {})
    print(json.dumps(result, indent=2))
