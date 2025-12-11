#!/usr/bin/env python3
"""
ServiceNow Bedrock Change Request Risk Assessment Example

This example demonstrates intelligent change request analysis and risk assessment
using Amazon Bedrock's Claude model.

Prerequisites:
- AWS credentials configured
- ServiceNow instance with REST API enabled
- Python 3.9+ with boto3 and requests libraries
"""

import json
import boto3
import requests
import base64
from typing import Dict, Optional, List, Any
from datetime import datetime
from dataclasses import dataclass
from collections import defaultdict


@dataclass
class ChangeRequest:
    """Represents a ServiceNow change request"""

    sys_id: str
    number: str
    short_description: str
    description: str
    type: str  # standard, normal, emergency
    implementation_plan: str
    backout_plan: str
    planned_start_date: str
    planned_end_date: str
    assignment_group: str
    priority: int


class ChangeRiskAssessment:
    """Provides risk assessment for change requests"""

    def __init__(
        self,
        servicenow_url: str,
        username: str,
        api_token: str,
        aws_region: str = "eu-west-2",
    ):
        """
        Initialize the change risk assessment system

        Args:
            servicenow_url: ServiceNow instance URL
            username: API username
            api_token: API token
            aws_region: AWS region for Bedrock
        """
        self.servicenow_url = servicenow_url.rstrip("/")
        self.bedrock = boto3.client("bedrock-runtime", region_name=aws_region)
        self.model_id = "anthropic.claude-3-5-sonnet-20241022-v2:0"

        # Setup authentication
        credentials = f"{username}:{api_token}"
        encoded = base64.b64encode(credentials.encode()).decode()
        self.headers = {
            "Authorization": f"Basic {encoded}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

    def get_change_request(self, change_id: str) -> Optional[ChangeRequest]:
        """
        Retrieve a change request from ServiceNow

        Args:
            change_id: Change request sys_id

        Returns:
            ChangeRequest object or None if not found
        """
        url = f"{self.servicenow_url}/api/now/table/change_request/{change_id}"

        try:
            response = requests.get(url, headers=self.headers, timeout=10)
            response.raise_for_status()

            data = response.json()["result"]
            return ChangeRequest(
                sys_id=data["sys_id"],
                number=data["number"],
                short_description=data["short_description"],
                description=data["description"],
                type=data.get("type", "normal"),
                implementation_plan=data.get("implementation_plan", ""),
                backout_plan=data.get("backout_plan", ""),
                planned_start_date=data.get("planned_start_date", ""),
                planned_end_date=data.get("planned_end_date", ""),
                assignment_group=data.get("assignment_group", ""),
                priority=int(data.get("priority", 3)),
            )
        except requests.RequestException as e:
            print(f"Error retrieving change request: {e}")
            return None

    def get_recent_changes(self, limit: int = 10) -> Dict:
        """
        Get recent changes for reference

        Args:
            limit: Number of recent changes to retrieve

        Returns:
            Dictionary mapping change type to list of changes
        """
        url = f"{self.servicenow_url}/api/now/table/change_request"
        query = "ORDERBYDESCcreated_on"
        params = {
            "sysparm_query": query,
            "sysparm_limit": limit,
            "sysparm_fields": "number,short_description,type,state",
            "sysparm_exclude_reference_link": "true",
        }

        try:
            response = requests.get(
                url, headers=self.headers, params=params, timeout=10
            )
            response.raise_for_status()

            changes = response.json()["result"]
            grouped: Dict[str, List[Any]] = defaultdict(list)
            for change in changes:
                change_type = change.get("type", "unknown")
                grouped[change_type].append(change)

            return grouped
        except requests.RequestException as e:
            print(f"Error retrieving recent changes: {e}")
            return {}

    def assess_change_risk(self, change: ChangeRequest, recent_changes: Dict) -> Dict:
        """
        Assess risk of a change request using Bedrock

        Args:
            change: ChangeRequest object
            recent_changes: Dictionary of recent changes for reference

        Returns:
            Dictionary with risk assessment results
        """
        # Build context for the model
        recent_context = "Recent similar changes:\n"
        change_type = change.type
        if change_type in recent_changes:
            for similar in recent_changes[change_type][:3]:
                recent_context += (
                    f"- {similar['number']}: {similar['short_description']} "
                    f"(Status: {similar['state']})\n"
                )
        else:
            recent_context += "- No recent similar changes\n"

        # Calculate change window duration
        try:
            start = datetime.fromisoformat(change.planned_start_date)
            end = datetime.fromisoformat(change.planned_end_date)
            duration_minutes = int((end - start).total_seconds() / 60)
        except (ValueError, TypeError, AttributeError):
            duration_minutes = 0

        prompt = f"""
You are an experienced change management consultant. Perform a comprehensive risk assessment
for this change request.

CHANGE REQUEST DETAILS:
- Number: {change.number}
- Type: {change.type.upper()}
- Title: {change.short_description}
- Description: {change.description[:300]}
- Planned Duration: {duration_minutes} minutes
- Assigned to: {change.assignment_group}
- Priority: {change.priority}

IMPLEMENTATION PLAN:
{change.implementation_plan}

BACKOUT PLAN:
{change.backout_plan}

{recent_context}

PERFORM RISK ASSESSMENT:

1. TECHNICAL RISK (scale 1-10):
   - Complexity of change
   - Testing coverage
   - Rollback feasibility
   - Dependency complexity

2. BUSINESS RISK (scale 1-10):
   - Number of users affected
   - Revenue/SLA impact
   - Business criticality
   - Time sensitivity

3. OPERATIONAL RISK (scale 1-10):
   - Team skill level
   - Resource availability
   - Schedule pressure
   - Documentation completeness

4. OVERALL ASSESSMENT:
   Calculate: (Technical × 0.4) + (Business × 0.4) + (Operational × 0.2)

   Risk Levels:
   - 1-30: LOW (can proceed with standard approval)
   - 31-60: MEDIUM (CAB review recommended)
   - 61-90: HIGH (CAB review required)
   - 91-100: CRITICAL (executive approval required)

5. RECOMMENDATIONS:
   - Does CAB approval need to be scheduled?
   - What testing is required?
   - Is rollback plan adequate?
   - Any additional mitigations needed?
   - Suggested success criteria?

RESPOND AS JSON:
{{
    "technical_risk": 6,
    "business_risk": 7,
    "operational_risk": 5,
    "overall_risk_score": 63,
    "risk_level": "HIGH",
    "cab_required": true,
    "testing_required": true,
    "rollback_feasible": true,
    "mitigations": ["mitigation1", "mitigation2"],
    "success_criteria": ["criterion1", "criterion2"],
    "estimated_cab_meeting_hours": 24,
    "confidence": 0.90,
    "summary": "Clear summary of assessment"
}}
"""

        try:
            response = self.bedrock.invoke_model(
                modelId=self.model_id,
                contentType="application/json",
                accept="application/json",
                body=json.dumps(
                    {
                        "messages": [{"role": "user", "content": prompt}],
                        "max_tokens": 1200,
                    }
                ),
            )

            result = json.loads(response["body"].read())
            content = result["content"][0]["text"]

            # Extract JSON from response
            import re

            json_match = re.search(r"\{.*\}", content, re.DOTALL)
            if json_match:
                assessment = json.loads(json_match.group())
            else:
                assessment = {"error": "Could not parse response", "raw": content}

            assessment["change_id"] = change.sys_id
            assessment["change_number"] = change.number
            assessment["assessed_at"] = datetime.now().isoformat()

            return assessment

        except Exception as e:
            return {
                "change_id": change.sys_id,
                "change_number": change.number,
                "error": str(e),
            }

    def generate_cab_summary(self, change: ChangeRequest, assessment: Dict) -> str:
        """
        Generate a CAB (Change Advisory Board) summary

        Args:
            change: ChangeRequest object
            assessment: Risk assessment results

        Returns:
            Formatted CAB summary
        """
        summary = f"""
CHANGE ADVISORY BOARD (CAB) REVIEW SUMMARY
{'=' * 60}

CHANGE REQUEST: {change.number}
TITLE: {change.short_description}
REQUESTED BY: {change.assignment_group}
DATE PREPARED: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

EXECUTIVE SUMMARY:
{assessment.get('summary', 'Risk assessment completed')}

CHANGE DETAILS:
- Type: {change.type.upper()}
- Priority: {change.priority}
- Planned Start: {change.planned_start_date}
- Planned End: {change.planned_end_date}

RISK ASSESSMENT:
- Technical Risk: {assessment.get('technical_risk', 'N/A')}/10
- Business Risk: {assessment.get('business_risk', 'N/A')}/10
- Operational Risk: {assessment.get('operational_risk', 'N/A')}/10
- OVERALL RISK SCORE: {assessment.get('overall_risk_score', 'N/A')}/100
- RISK LEVEL: {assessment.get('risk_level', 'N/A')}

APPROVAL DECISION:
- CAB Approval Required: {'YES' if assessment.get('cab_required') else 'NO'}
- Recommended Testing: {'YES' if assessment.get('testing_required') else 'NO'}
- Rollback Feasible: {'YES' if assessment.get('rollback_feasible') else 'NO'}

IMPLEMENTATION PLAN:
{change.implementation_plan}

BACKOUT/ROLLBACK PLAN:
{change.backout_plan}

RECOMMENDED MITIGATIONS:
"""
        for mitigation in assessment.get("mitigations", []):
            summary += f"- {mitigation}\n"

        summary += "\nSUCCESS CRITERIA:\n"
        for criteria in assessment.get("success_criteria", []):
            summary += f"- {criteria}\n"

        summary += f"\nCONFIDENCE LEVEL: {assessment.get('confidence', 0):.0%}\n"

        if assessment.get("cab_required"):
            summary += f"\nRECOMMENDED CAB MEETING TIME: {assessment.get('estimated_cab_meeting_hours', 24)} hours from now\n"

        return summary

    def update_change_in_servicenow(
        self, change_id: str, assessment: Dict, cab_summary: str
    ) -> bool:
        """
        Update change request in ServiceNow with assessment

        Args:
            change_id: Change request sys_id
            assessment: Risk assessment results
            cab_summary: CAB summary text

        Returns:
            True if successful
        """
        url = f"{self.servicenow_url}/api/now/table/change_request/{change_id}"

        update_data = {
            "work_notes": "Risk Assessment Completed:\n"
            + f"Risk Score: {assessment.get('overall_risk_score', 'N/A')}/100\n"
            + f"Risk Level: {assessment.get('risk_level', 'N/A')}\n"
            + f"CAB Required: {'Yes' if assessment.get('cab_required') else 'No'}\n\n"
            + cab_summary
        }

        try:
            response = requests.patch(
                url, headers=self.headers, json=update_data, timeout=10
            )
            response.raise_for_status()
            return True
        except requests.RequestException as e:
            print(f"Error updating change request: {e}")
            return False


def main():
    """Main example: change request risk assessment"""

    # Configuration
    SERVICENOW_INSTANCE = "https://your-instance.service-now.com"
    SERVICENOW_USERNAME = "servicenow_bedrock_api"
    SERVICENOW_API_TOKEN = "your-api-token"

    # Initialize assessment system
    print("Initializing change risk assessment system...")
    assessor = ChangeRiskAssessment(
        SERVICENOW_INSTANCE, SERVICENOW_USERNAME, SERVICENOW_API_TOKEN
    )

    # Get example change request
    change_id = "c73e8e65fc..."  # Replace with actual change sys_id

    print(f"\n1. Retrieving change request {change_id}...")
    change = assessor.get_change_request(change_id)

    if not change:
        print("Failed to retrieve change request")
        return

    print(f"   Retrieved: {change.number} - {change.short_description}")

    # Get recent changes for context
    print("\n2. Retrieving recent changes for reference...")
    recent_changes = assessor.get_recent_changes(limit=20)
    print(f"   Found {sum(len(v) for v in recent_changes.values())} recent changes")

    # Assess risk
    print("\n3. Assessing change risk with Bedrock...")
    assessment = assessor.assess_change_risk(change, recent_changes)

    print("\n4. Risk Assessment Results:")
    print(f"   Risk Score: {assessment.get('overall_risk_score', 'N/A')}/100")
    print(f"   Risk Level: {assessment.get('risk_level', 'N/A')}")
    print(f"   CAB Required: {'Yes' if assessment.get('cab_required') else 'No'}")

    # Generate CAB summary
    print("\n5. Generating CAB summary...")
    cab_summary = assessor.generate_cab_summary(change, assessment)
    print(cab_summary)

    # Update change in ServiceNow
    print("\n6. Updating change request in ServiceNow...")
    if assessor.update_change_in_servicenow(change.sys_id, assessment, cab_summary):
        print("   Change request updated successfully")
    else:
        print("   Failed to update change request")

    # Save detailed assessment
    print("\n7. Saving assessment to file...")
    output_file = f"change_assessment_{change.number}.json"
    with open(output_file, "w") as f:
        json.dump(
            {
                "change": {
                    "sys_id": change.sys_id,
                    "number": change.number,
                    "short_description": change.short_description,
                },
                "assessment": assessment,
                "cab_summary": cab_summary,
                "timestamp": datetime.now().isoformat(),
            },
            f,
            indent=2,
        )
    print(f"   Saved to {output_file}")

    print("\n8. Change risk assessment complete!")


if __name__ == "__main__":
    main()
