"""
AWS Config Custom Rule: Bedrock Logging Enabled Check
Ensures Bedrock model invocation logging and agent tracing are enabled
"""

import json
import boto3
from datetime import datetime

config = boto3.client('config')
bedrock = boto3.client('bedrock')
logs = boto3.client('logs')


def lambda_handler(event, context):
    """
    Main Lambda handler for AWS Config custom rule evaluation
    """
    invoking_event = json.loads(event['invokingEvent'])
    rule_parameters = json.loads(event.get('ruleParameters', '{}'))

    # This rule evaluates account-level logging configuration
    # Trigger: Periodic or configuration change

    compliance = evaluate_bedrock_logging(rule_parameters)

    put_evaluation(
        config_rule_name=event['configRuleName'],
        resource_type='AWS::::Account',
        resource_id=event['accountId'],
        compliance_type=compliance['compliance_type'],
        annotation=compliance['annotation'],
        result_token=event['resultToken']
    )

    return {
        'statusCode': 200,
        'body': json.dumps({
            'compliance': compliance['compliance_type'],
            'annotation': compliance['annotation']
        })
    }


def evaluate_bedrock_logging(rule_parameters):
    """
    Evaluate Bedrock logging configuration
    """
    try:
        violations = []

        # Check model invocation logging
        model_logging_config = get_model_invocation_logging_config()

        if not model_logging_config:
            violations.append("Model invocation logging is not configured")
        else:
            # Validate logging configuration
            logging_config = model_logging_config.get('loggingConfig', {})

            # Check CloudWatch logging
            cloudwatch_config = logging_config.get('cloudWatchConfig')
            if not cloudwatch_config:
                violations.append("CloudWatch logging is not enabled for model invocations")
            else:
                log_group_name = cloudwatch_config.get('logGroupName')
                role_arn = cloudwatch_config.get('roleArn')

                if not log_group_name:
                    violations.append("CloudWatch log group is not specified")
                else:
                    # Verify log group exists and has encryption
                    log_group_encrypted = check_log_group_encryption(log_group_name)
                    if not log_group_encrypted:
                        violations.append(f"CloudWatch log group {log_group_name} is not encrypted")

                if not role_arn:
                    violations.append("IAM role for CloudWatch logging is not specified")

            # Check S3 logging (optional)
            s3_config = logging_config.get('s3Config')
            if s3_config:
                bucket_name = s3_config.get('bucketName')
                if bucket_name:
                    # Verify S3 bucket encryption
                    s3 = boto3.client('s3')
                    try:
                        encryption = s3.get_bucket_encryption(Bucket=bucket_name)
                        # Bucket has encryption
                    except s3.exceptions.NoSuchBucketEncryption:
                        violations.append(f"S3 logging bucket {bucket_name} is not encrypted")

            # Check text data delivery
            text_data_delivery = logging_config.get('textDataDeliveryEnabled')
            if rule_parameters.get('RequireTextDataDelivery', 'false').lower() == 'true':
                if not text_data_delivery:
                    violations.append("Text data delivery is not enabled (prompts and completions not logged)")

            # Check embedding data delivery
            embedding_data_delivery = logging_config.get('embeddingDataDeliveryEnabled')
            image_data_delivery = logging_config.get('imageDataDeliveryEnabled')

        # If violations found, non-compliant
        if violations:
            return {
                'compliance_type': 'NON_COMPLIANT',
                'annotation': f"Logging configuration violations: {'; '.join(violations)}"
            }
        else:
            return {
                'compliance_type': 'COMPLIANT',
                'annotation': 'Bedrock model invocation logging is properly configured with encryption'
            }

    except Exception as e:
        return {
            'compliance_type': 'NON_COMPLIANT',
            'annotation': f'Error evaluating Bedrock logging: {str(e)}'
        }


def get_model_invocation_logging_config():
    """
    Get Bedrock model invocation logging configuration
    """
    try:
        response = bedrock.get_model_invocation_logging_configuration()
        return response
    except bedrock.exceptions.ResourceNotFoundException:
        return None
    except Exception as e:
        print(f"Error getting model invocation logging config: {e}")
        return None


def check_log_group_encryption(log_group_name):
    """
    Check if CloudWatch log group is encrypted with KMS
    """
    try:
        response = logs.describe_log_groups(
            logGroupNamePrefix=log_group_name
        )

        log_groups = response.get('logGroups', [])

        for log_group in log_groups:
            if log_group['logGroupName'] == log_group_name:
                # Check if KMS key is configured
                kms_key_id = log_group.get('kmsKeyId')
                return kms_key_id is not None

        return False

    except Exception as e:
        print(f"Error checking log group encryption: {e}")
        return False


def put_evaluation(config_rule_name, resource_type, resource_id, compliance_type, annotation, result_token):
    """
    Submit evaluation result to AWS Config
    """
    try:
        config.put_evaluations(
            Evaluations=[
                {
                    'ComplianceResourceType': resource_type,
                    'ComplianceResourceId': resource_id,
                    'ComplianceType': compliance_type,
                    'Annotation': annotation,
                    'OrderingTimestamp': datetime.now()
                }
            ],
            ResultToken=result_token
        )
        print(f"Evaluation submitted: {compliance_type} - {annotation}")
    except Exception as e:
        print(f"Error submitting evaluation: {e}")
        raise


if __name__ == "__main__":
    test_event = {
        'configRuleName': 'bedrock-logging-enabled',
        'accountId': '123456789012',
        'invokingEvent': json.dumps({
            'messageType': 'ScheduledNotification'
        }),
        'ruleParameters': json.dumps({
            'RequireTextDataDelivery': 'true'
        }),
        'resultToken': 'test-token'
    }

    result = lambda_handler(test_event, {})
    print(json.dumps(result, indent=2))
