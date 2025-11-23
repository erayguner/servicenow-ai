"""
AWS Config Custom Rule: Bedrock Network Isolation Check
Ensures Bedrock agents and knowledge bases use VPC endpoints for network isolation (RESTRICTED data)
"""

import json
import boto3
from datetime import datetime

config = boto3.client("config")
ec2 = boto3.client("ec2")


def lambda_handler(event, context):
    """
    Main Lambda handler for AWS Config custom rule evaluation
    """
    invoking_event = json.loads(event["invokingEvent"])
    rule_parameters = json.loads(event.get("ruleParameters", "{}"))

    # This rule evaluates account-level VPC endpoint configuration
    compliance = evaluate_bedrock_vpc_endpoints(rule_parameters)

    put_evaluation(
        config_rule_name=event["configRuleName"],
        resource_type="AWS::::Account",
        resource_id=event["accountId"],
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


def evaluate_bedrock_vpc_endpoints(rule_parameters):
    """
    Evaluate Bedrock VPC endpoint configuration for network isolation
    """
    try:
        required_vpc_id = rule_parameters.get("RequiredVPCId")
        enforce_private_dns = (
            rule_parameters.get("EnforcePrivateDNS", "true").lower() == "true"
        )

        violations = []

        # Check for Bedrock VPC endpoints
        bedrock_endpoints = find_bedrock_vpc_endpoints()

        if not bedrock_endpoints:
            violations.append(
                "No Bedrock VPC endpoints found - RESTRICTED data access must use VPC endpoints"
            )
        else:
            for endpoint in bedrock_endpoints:
                endpoint_id = endpoint["VpcEndpointId"]
                vpc_id = endpoint["VpcId"]
                state = endpoint["State"]
                private_dns_enabled = endpoint.get("PrivateDnsEnabled", False)

                # Check endpoint state
                if state != "available":
                    violations.append(
                        f"VPC endpoint {endpoint_id} is not in 'available' state (current: {state})"
                    )

                # Check if in required VPC
                if required_vpc_id and vpc_id != required_vpc_id:
                    violations.append(
                        f"VPC endpoint {endpoint_id} is not in required VPC {required_vpc_id} (found in {vpc_id})"
                    )

                # Check private DNS
                if enforce_private_dns and not private_dns_enabled:
                    violations.append(
                        f"VPC endpoint {endpoint_id} does not have private DNS enabled"
                    )

                # Check security groups
                security_groups = endpoint.get("Groups", [])
                if not security_groups:
                    violations.append(
                        f"VPC endpoint {endpoint_id} has no security groups attached"
                    )
                else:
                    # Verify security groups are restrictive
                    for sg in security_groups:
                        sg_id = sg["GroupId"]
                        sg_violations = check_security_group_rules(sg_id)
                        if sg_violations:
                            violations.extend(
                                [
                                    f"VPC endpoint {endpoint_id} SG {sg_id}: {v}"
                                    for v in sg_violations
                                ]
                            )

                # Check subnets (should be private subnets)
                subnet_ids = endpoint.get("SubnetIds", [])
                if not subnet_ids:
                    violations.append(
                        f"VPC endpoint {endpoint_id} has no subnets configured"
                    )
                else:
                    for subnet_id in subnet_ids:
                        if not is_private_subnet(subnet_id):
                            violations.append(
                                f"VPC endpoint {endpoint_id} subnet {subnet_id} is not a private subnet (has route to IGW)"
                            )

        # Evaluate compliance
        if violations:
            return {
                "compliance_type": "NON_COMPLIANT",
                "annotation": f"Network isolation violations: {'; '.join(violations)}",
            }
        else:
            return {
                "compliance_type": "COMPLIANT",
                "annotation": f"Bedrock VPC endpoints properly configured for network isolation ({len(bedrock_endpoints)} endpoints)",
            }

    except Exception as e:
        return {
            "compliance_type": "NON_COMPLIANT",
            "annotation": f"Error evaluating Bedrock network isolation: {str(e)}",
        }


def find_bedrock_vpc_endpoints():
    """
    Find all Bedrock VPC endpoints
    """
    try:
        # Bedrock service endpoints
        bedrock_services = [
            "com.amazonaws.*.bedrock",
            "com.amazonaws.*.bedrock-runtime",
            "com.amazonaws.*.bedrock-agent",
            "com.amazonaws.*.bedrock-agent-runtime",
        ]

        endpoints = []

        for service_pattern in bedrock_services:
            response = ec2.describe_vpc_endpoints(
                Filters=[
                    {
                        "Name": "service-name",
                        "Values": [service_pattern.replace("*", ec2.meta.region_name)],
                    }
                ]
            )

            endpoints.extend(response.get("VpcEndpoints", []))

        return endpoints

    except Exception as e:
        print(f"Error finding Bedrock VPC endpoints: {e}")
        return []


def check_security_group_rules(security_group_id):
    """
    Check if security group rules are restrictive
    """
    violations = []

    try:
        response = ec2.describe_security_groups(GroupIds=[security_group_id])

        security_groups = response.get("SecurityGroups", [])
        if not security_groups:
            return violations

        sg = security_groups[0]

        # Check ingress rules
        ingress_rules = sg.get("IpPermissions", [])

        for rule in ingress_rules:
            # Check for overly permissive CIDR blocks
            ip_ranges = rule.get("IpRanges", [])
            for ip_range in ip_ranges:
                cidr = ip_range.get("CidrIp", "")
                if cidr == "0.0.0.0/0":
                    violations.append(
                        "Ingress rule allows access from 0.0.0.0/0 (internet)"
                    )

            ipv6_ranges = rule.get("Ipv6Ranges", [])
            for ipv6_range in ipv6_ranges:
                cidr = ipv6_range.get("CidrIpv6", "")
                if cidr == "::/0":
                    violations.append(
                        "Ingress rule allows access from ::/0 (internet IPv6)"
                    )

        # Egress rules should typically allow outbound to AWS services
        # Not checking egress as strictly since VPC endpoints need to communicate with AWS services

    except Exception as e:
        print(f"Error checking security group rules: {e}")

    return violations


def is_private_subnet(subnet_id):
    """
    Check if subnet is private (no route to Internet Gateway)
    """
    try:
        # Get subnet details
        subnet_response = ec2.describe_subnets(SubnetIds=[subnet_id])

        subnets = subnet_response.get("Subnets", [])
        if not subnets:
            return False

        subnet = subnets[0]
        vpc_id = subnet["VpcId"]

        # Get route tables for this subnet
        route_table_response = ec2.describe_route_tables(
            Filters=[{"Name": "association.subnet-id", "Values": [subnet_id]}]
        )

        route_tables = route_table_response.get("RouteTables", [])

        # If no explicit association, check main route table
        if not route_tables:
            route_table_response = ec2.describe_route_tables(
                Filters=[
                    {"Name": "vpc-id", "Values": [vpc_id]},
                    {"Name": "association.main", "Values": ["true"]},
                ]
            )
            route_tables = route_table_response.get("RouteTables", [])

        # Check routes for Internet Gateway
        for route_table in route_tables:
            routes = route_table.get("Routes", [])
            for route in routes:
                gateway_id = route.get("GatewayId", "")
                if gateway_id.startswith("igw-"):
                    # Route to Internet Gateway found - public subnet
                    return False

        # No route to IGW found - private subnet
        return True

    except Exception as e:
        print(f"Error checking if subnet is private: {e}")
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
        "configRuleName": "bedrock-network-isolation",
        "accountId": "123456789012",
        "invokingEvent": json.dumps({"messageType": "ScheduledNotification"}),
        "ruleParameters": json.dumps(
            {"RequiredVPCId": "vpc-12345678", "EnforcePrivateDNS": "true"}
        ),
        "resultToken": "test-token",
    }

    result = lambda_handler(test_event, {})
    print(json.dumps(result, indent=2))
