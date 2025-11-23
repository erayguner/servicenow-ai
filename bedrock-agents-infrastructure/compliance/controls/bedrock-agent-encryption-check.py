"""
AWS Config Custom Rule: Bedrock Agent Encryption Check
Ensures all Amazon Bedrock agents and knowledge bases are encrypted with customer-managed KMS keys (CMK)
"""

import json
import boto3
from datetime import datetime

# AWS clients
config = boto3.client('config')
bedrock_agent = boto3.client('bedrock-agent')
kms = boto3.client('kms')


def lambda_handler(event, context):
    """
    Main Lambda handler for AWS Config custom rule evaluation
    """
    # Get the configuration item from the event
    invoking_event = json.loads(event['invokingEvent'])
    configuration_item = invoking_event.get('configurationItem')

    # Get rule parameters
    rule_parameters = json.loads(event.get('ruleParameters', '{}'))
    require_cmk = rule_parameters.get('RequireCustomerManagedKey', 'true').lower() == 'true'

    # Determine resource type and evaluate
    resource_type = configuration_item.get('resourceType')

    if resource_type == 'AWS::Bedrock::KnowledgeBase':
        compliance = evaluate_knowledge_base_encryption(configuration_item, require_cmk)
    elif resource_type == 'AWS::Bedrock::Agent':
        compliance = evaluate_agent_encryption(configuration_item, require_cmk)
    else:
        # Not applicable for other resource types
        compliance = {
            'compliance_type': 'NOT_APPLICABLE',
            'annotation': f'Resource type {resource_type} not evaluated by this rule'
        }

    # Submit evaluation to AWS Config
    put_evaluation(
        config_rule_name=event['configRuleName'],
        resource_type=resource_type,
        resource_id=configuration_item.get('resourceId'),
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


def evaluate_knowledge_base_encryption(configuration_item, require_cmk):
    """
    Evaluate encryption configuration for Bedrock Knowledge Base
    """
    resource_id = configuration_item.get('resourceId')
    resource_arn = configuration_item.get('ARN')

    try:
        # Get knowledge base details
        kb_details = bedrock_agent.get_knowledge_base(
            knowledgeBaseId=resource_id
        )

        storage_config = kb_details.get('knowledgeBase', {}).get('storageConfiguration', {})

        # Check for encryption configuration
        encryption_config = None

        # OpenSearch Serverless
        if 'opensearchServerlessConfiguration' in storage_config:
            # OpenSearch Serverless encryption is managed via collection security policy
            collection_arn = storage_config['opensearchServerlessConfiguration'].get('collectionArn')
            if collection_arn:
                # Verify collection has encryption enabled
                encryption_config = check_opensearch_serverless_encryption(collection_arn)

        # Pinecone (third-party)
        elif 'pineconeConfiguration' in storage_config:
            # Pinecone encryption is managed by Pinecone
            return {
                'compliance_type': 'NOT_APPLICABLE',
                'annotation': 'Pinecone knowledge base encryption managed by third-party service'
            }

        # RDS (Aurora)
        elif 'rdsConfiguration' in storage_config:
            resource_arn_value = storage_config['rdsConfiguration'].get('resourceArn')
            if resource_arn_value:
                encryption_config = check_rds_encryption(resource_arn_value)

        # Redis Enterprise Cloud
        elif 'redisEnterpriseCloudConfiguration' in storage_config:
            return {
                'compliance_type': 'NOT_APPLICABLE',
                'annotation': 'Redis Enterprise Cloud encryption managed by third-party service'
            }

        # If no encryption configuration found
        if not encryption_config:
            return {
                'compliance_type': 'NON_COMPLIANT',
                'annotation': 'Knowledge base does not have encryption enabled or encryption configuration not found'
            }

        # Check if using customer-managed key (CMK)
        if require_cmk:
            kms_key_id = encryption_config.get('kms_key_id')
            if not kms_key_id:
                return {
                    'compliance_type': 'NON_COMPLIANT',
                    'annotation': 'Knowledge base is not encrypted with customer-managed KMS key (CMK)'
                }

            # Verify the key is a customer-managed key (not AWS-managed)
            if is_customer_managed_key(kms_key_id):
                # Check if key rotation is enabled
                rotation_enabled = is_key_rotation_enabled(kms_key_id)
                if rotation_enabled:
                    return {
                        'compliance_type': 'COMPLIANT',
                        'annotation': f'Knowledge base is encrypted with CMK {kms_key_id} with automatic rotation enabled'
                    }
                else:
                    return {
                        'compliance_type': 'NON_COMPLIANT',
                        'annotation': f'Knowledge base encrypted with CMK {kms_key_id} but automatic key rotation is NOT enabled'
                    }
            else:
                return {
                    'compliance_type': 'NON_COMPLIANT',
                    'annotation': f'Knowledge base is encrypted with AWS-managed key, not customer-managed key (CMK)'
                }
        else:
            # Just check if encrypted (any key type acceptable)
            return {
                'compliance_type': 'COMPLIANT',
                'annotation': 'Knowledge base is encrypted'
            }

    except Exception as e:
        return {
            'compliance_type': 'NON_COMPLIANT',
            'annotation': f'Error evaluating knowledge base encryption: {str(e)}'
        }


def evaluate_agent_encryption(configuration_item, require_cmk):
    """
    Evaluate encryption configuration for Bedrock Agent
    Agents don't persist data, but action group Lambda functions should use encrypted environment variables
    """
    resource_id = configuration_item.get('resourceId')

    try:
        # Get agent details
        agent_details = bedrock_agent.get_agent(
            agentId=resource_id
        )

        # Get action groups
        action_groups_response = bedrock_agent.list_agent_action_groups(
            agentId=resource_id,
            agentVersion='DRAFT'  # or specific version
        )

        action_groups = action_groups_response.get('actionGroupSummaries', [])

        non_compliant_lambdas = []

        for ag in action_groups:
            action_group_id = ag.get('actionGroupId')
            ag_details = bedrock_agent.get_agent_action_group(
                agentId=resource_id,
                agentVersion='DRAFT',
                actionGroupId=action_group_id
            )

            executor = ag_details.get('actionGroup', {}).get('actionGroupExecutor', {})
            lambda_arn = executor.get('lambda')

            if lambda_arn:
                # Check Lambda encryption configuration
                lambda_client = boto3.client('lambda')
                lambda_config = lambda_client.get_function_configuration(
                    FunctionName=lambda_arn
                )

                env_vars = lambda_config.get('Environment', {})
                kms_key_arn = env_vars.get('KMSKeyArn')

                if require_cmk and not kms_key_arn:
                    non_compliant_lambdas.append(lambda_arn)
                elif require_cmk and kms_key_arn:
                    # Verify it's a customer-managed key
                    if not is_customer_managed_key(kms_key_arn):
                        non_compliant_lambdas.append(f"{lambda_arn} (AWS-managed key)")

        if non_compliant_lambdas:
            return {
                'compliance_type': 'NON_COMPLIANT',
                'annotation': f'Agent action group Lambda functions do not use CMK for environment variable encryption: {", ".join(non_compliant_lambdas)}'
            }
        else:
            return {
                'compliance_type': 'COMPLIANT',
                'annotation': 'Agent action group Lambda functions use CMK for environment variable encryption'
            }

    except Exception as e:
        return {
            'compliance_type': 'NON_COMPLIANT',
            'annotation': f'Error evaluating agent encryption: {str(e)}'
        }


def check_opensearch_serverless_encryption(collection_arn):
    """
    Check if OpenSearch Serverless collection has encryption enabled
    """
    try:
        opensearch_serverless = boto3.client('opensearchserverless')

        collection_id = collection_arn.split('/')[-1]
        collection_name = collection_arn.split('/')[-1]  # Simplified, may need parsing

        # Get collection details
        response = opensearch_serverless.batch_get_collection(
            names=[collection_name]
        )

        collections = response.get('collectionDetails', [])
        if not collections:
            return None

        collection = collections[0]

        # OpenSearch Serverless uses encryption by default
        # Check security policy for encryption configuration
        encryption_policies = opensearch_serverless.list_security_policies(
            type='encryption',
            resource=[collection_arn]
        )

        for policy in encryption_policies.get('securityPolicySummaries', []):
            policy_detail = opensearch_serverless.get_security_policy(
                name=policy['name'],
                type='encryption'
            )

            policy_doc = json.loads(policy_detail['securityPolicyDetail']['policy'])

            # Check if KMS key is specified
            kms_key_arn = policy_doc.get('KmsARN') or policy_doc.get('AWSOwnedKey')
            if kms_key_arn and kms_key_arn != 'true':  # AWSOwnedKey: true means AWS-managed
                return {'kms_key_id': kms_key_arn}

        # Default: AWS-owned key
        return {'kms_key_id': None}

    except Exception as e:
        print(f"Error checking OpenSearch Serverless encryption: {e}")
        return None


def check_rds_encryption(resource_arn):
    """
    Check if RDS instance has encryption enabled
    """
    try:
        rds = boto3.client('rds')

        db_instance_id = resource_arn.split(':')[-1]

        response = rds.describe_db_instances(
            DBInstanceIdentifier=db_instance_id
        )

        instances = response.get('DBInstances', [])
        if not instances:
            return None

        instance = instances[0]

        if instance.get('StorageEncrypted'):
            kms_key_id = instance.get('KmsKeyId')
            return {'kms_key_id': kms_key_id}
        else:
            return None

    except Exception as e:
        print(f"Error checking RDS encryption: {e}")
        return None


def is_customer_managed_key(kms_key_id):
    """
    Determine if a KMS key is customer-managed (not AWS-managed or AWS-owned)
    """
    try:
        # Describe the key
        response = kms.describe_key(
            KeyId=kms_key_id
        )

        key_metadata = response.get('KeyMetadata', {})
        key_manager = key_metadata.get('KeyManager')

        # 'CUSTOMER' = customer-managed, 'AWS' = AWS-managed
        return key_manager == 'CUSTOMER'

    except Exception as e:
        print(f"Error checking if key is customer-managed: {e}")
        return False


def is_key_rotation_enabled(kms_key_id):
    """
    Check if automatic key rotation is enabled for a KMS key
    """
    try:
        response = kms.get_key_rotation_status(
            KeyId=kms_key_id
        )

        return response.get('KeyRotationEnabled', False)

    except Exception as e:
        print(f"Error checking key rotation status: {e}")
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


# For local testing
if __name__ == "__main__":
    # Mock event for testing
    test_event = {
        'configRuleName': 'bedrock-encryption-check',
        'executionRoleArn': 'arn:aws:iam::123456789012:role/config-role',
        'eventLeftScope': False,
        'invokingEvent': json.dumps({
            'configurationItem': {
                'resourceType': 'AWS::Bedrock::KnowledgeBase',
                'resourceId': 'test-kb-id',
                'ARN': 'arn:aws:bedrock:us-east-1:123456789012:knowledge-base/test-kb-id'
            }
        }),
        'ruleParameters': json.dumps({
            'RequireCustomerManagedKey': 'true'
        }),
        'resultToken': 'test-token'
    }

    result = lambda_handler(test_event, {})
    print(json.dumps(result, indent=2))
