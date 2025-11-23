"""
AWS Config Custom Rule: Bedrock IAM Least Privilege Check
Ensures Bedrock agent IAM roles follow least privilege principle
"""

import json
import boto3
from datetime import datetime

config = boto3.client("config")
iam = boto3.client("iam")
bedrock_agent = boto3.client("bedrock-agent")


def lambda_handler(event, context):
    """
    Main Lambda handler for AWS Config custom rule evaluation
    """
    invoking_event = json.loads(event["invokingEvent"])
    configuration_item = invoking_event.get("configurationItem")

    rule_parameters = json.loads(event.get("ruleParameters", "{}"))

    resource_type = configuration_item.get("resourceType")

    if resource_type == "AWS::IAM::Role":
        # Check if this is a Bedrock agent role
        role_name = configuration_item.get("resourceName")
        compliance = evaluate_bedrock_role(role_name, rule_parameters)
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


def evaluate_bedrock_role(role_name, rule_parameters):
    """
    Evaluate if IAM role follows least privilege for Bedrock
    """
    try:
        # Get role details
        role_response = iam.get_role(RoleName=role_name)
        role = role_response["Role"]

        # Check if this is a Bedrock-related role
        assume_role_policy = json.loads(role["AssumeRolePolicyDocument"])

        is_bedrock_role = False
        for statement in assume_role_policy.get("Statement", []):
            principal = statement.get("Principal", {})
            if isinstance(principal, dict):
                service = principal.get("Service", "")
                if "bedrock" in service.lower():
                    is_bedrock_role = True
                    break

        if not is_bedrock_role:
            return {
                "compliance_type": "NOT_APPLICABLE",
                "annotation": "Role is not a Bedrock agent role",
            }

        # Evaluate attached policies
        attached_policies = iam.list_attached_role_policies(RoleName=role_name)
        inline_policies = iam.list_role_policies(RoleName=role_name)

        violations = []

        # Check for overly permissive managed policies
        dangerous_managed_policies = [
            "arn:aws:iam::aws:policy/AdministratorAccess",
            "arn:aws:iam::aws:policy/PowerUserAccess",
            "arn:aws:iam::aws:policy/IAMFullAccess",
        ]

        for policy in attached_policies.get("AttachedPolicies", []):
            policy_arn = policy["PolicyArn"]
            if policy_arn in dangerous_managed_policies:
                violations.append(
                    f"Overly permissive managed policy attached: {policy_arn}"
                )

        # Check inline policies for wildcards and excessive permissions
        for policy_name in inline_policies.get("PolicyNames", []):
            policy_doc_response = iam.get_role_policy(
                RoleName=role_name, PolicyName=policy_name
            )

            policy_doc = policy_doc_response["PolicyDocument"]

            # Check for wildcard permissions
            for statement in policy_doc.get("Statement", []):
                if statement.get("Effect") == "Allow":
                    actions = statement.get("Action", [])
                    resources = statement.get("Resource", [])

                    # Convert to list if single string
                    if isinstance(actions, str):
                        actions = [actions]
                    if isinstance(resources, str):
                        resources = [resources]

                    # Check for dangerous action wildcards
                    for action in actions:
                        if action == "*":
                            violations.append(
                                f"Inline policy '{policy_name}' grants all actions (*)"
                            )
                        elif action.endswith(":*"):
                            # Service-level wildcard (e.g., s3:*) - warn if broad
                            service = action.split(":")[0]
                            if service in ["iam", "sts", "kms", "organizations"]:
                                violations.append(
                                    f"Inline policy '{policy_name}' grants broad permissions: {action}"
                                )

                    # Check for resource wildcards
                    for resource in resources:
                        if resource == "*":
                            # Wildcard resource may be acceptable for certain actions (e.g., List, Describe)
                            # Check if actions are all read-only
                            read_only = all(
                                any(
                                    action.startswith(prefix)
                                    for prefix in [
                                        "Get",
                                        "List",
                                        "Describe",
                                        "bedrock:Invoke",
                                        "bedrock:Retrieve",
                                    ]
                                )
                                for action in actions
                            )

                            if not read_only:
                                violations.append(
                                    f"Inline policy '{policy_name}' allows write actions on all resources (*)"
                                )

        # Check for conditions that restrict scope (good practice)
        has_conditions = False
        for policy_name in inline_policies.get("PolicyNames", []):
            policy_doc_response = iam.get_role_policy(
                RoleName=role_name, PolicyName=policy_name
            )

            policy_doc = policy_doc_response["PolicyDocument"]

            for statement in policy_doc.get("Statement", []):
                if statement.get("Condition"):
                    has_conditions = True
                    break

        # Evaluate compliance
        if violations:
            return {
                "compliance_type": "NON_COMPLIANT",
                "annotation": f"Least privilege violations: {'; '.join(violations)}",
            }
        else:
            annotation = "Role follows least privilege principle"
            if has_conditions:
                annotation += " with conditional access"
            return {"compliance_type": "COMPLIANT", "annotation": annotation}

    except iam.exceptions.NoSuchEntityException:
        return {
            "compliance_type": "NOT_APPLICABLE",
            "annotation": f"Role {role_name} does not exist",
        }
    except Exception as e:
        return {
            "compliance_type": "NON_COMPLIANT",
            "annotation": f"Error evaluating role: {str(e)}",
        }


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
        "configRuleName": "bedrock-iam-least-privilege",
        "invokingEvent": json.dumps(
            {
                "configurationItem": {
                    "resourceType": "AWS::IAM::Role",
                    "resourceId": "bedrock-agent-role",
                    "resourceName": "bedrock-agent-role",
                }
            }
        ),
        "ruleParameters": "{}",
        "resultToken": "test-token",
    }

    result = lambda_handler(test_event, {})
    print(json.dumps(result, indent=2))
