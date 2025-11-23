#!/usr/bin/env python3
"""
ServiceNow Bedrock Incident Automation Example

This example demonstrates how to automatically analyze and resolve incidents
using the ServiceNow and Amazon Bedrock integration.

Prerequisites:
- AWS credentials configured (access key and secret key)
- ServiceNow instance URL and API credentials
- Python 3.9+
"""

import json
import boto3
import requests
import base64
from typing import Dict, List, Optional
from dataclasses import dataclass


@dataclass
class IncidentData:
    """Represents a ServiceNow incident"""

    sys_id: str
    number: str
    short_description: str
    description: str
    caller_id: str
    state: str
    priority: int
    impact: int
    urgency: int
    category: Optional[str] = None
    assignment_group: Optional[str] = None


class ServiceNowClient:
    """Client for interacting with ServiceNow REST API"""

    def __init__(self, instance_url: str, username: str, api_token: str):
        """
        Initialize ServiceNow client

        Args:
            instance_url: ServiceNow instance URL (e.g., https://instance.service-now.com)
            username: API username
            api_token: API token
        """
        self.instance_url = instance_url.rstrip("/")
        self.username = username
        self.api_token = api_token

        # Create authorization header
        credentials = f"{username}:{api_token}"
        encoded_credentials = base64.b64encode(credentials.encode()).decode()
        self.headers = {
            "Authorization": f"Basic {encoded_credentials}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

    def get_incident(self, incident_id: str) -> Optional[IncidentData]:
        """
        Retrieve an incident from ServiceNow

        Args:
            incident_id: Incident sys_id

        Returns:
            IncidentData object or None if not found
        """
        url = f"{self.instance_url}/api/now/table/incident/{incident_id}"
        params = {
            "sysparm_fields": "sys_id,number,short_description,description,caller_id,state,priority,impact,urgency,category,assignment_group"
        }

        try:
            response = requests.get(
                url, headers=self.headers, params=params, timeout=10
            )
            response.raise_for_status()

            data = response.json()["result"]
            return IncidentData(
                sys_id=data["sys_id"],
                number=data["number"],
                short_description=data["short_description"],
                description=data["description"],
                caller_id=data["caller_id"],
                state=data["state"],
                priority=int(data.get("priority", 3)),
                impact=int(data.get("impact", 3)),
                urgency=int(data.get("urgency", 3)),
                category=data.get("category"),
                assignment_group=data.get("assignment_group"),
            )
        except requests.exceptions.RequestException as e:
            print(f"Error retrieving incident: {e}")
            return None

    def search_kb(self, query: str, limit: int = 5) -> List[Dict]:
        """
        Search the ServiceNow Knowledge Base

        Args:
            query: Search query
            limit: Maximum number of results

        Returns:
            List of KB articles
        """
        url = f"{self.instance_url}/api/now/table/kb_knowledge"
        # Encode query for CONTAINS search
        encoded_query = f"CONTAINS(text,'{query}')"
        params = {
            "sysparm_query": encoded_query,
            "sysparm_limit": limit,
            "sysparm_fields": "number,short_description,text",
        }

        try:
            response = requests.get(
                url, headers=self.headers, params=params, timeout=10
            )
            response.raise_for_status()
            return response.json()["result"]
        except requests.exceptions.RequestException as e:
            print(f"Error searching KB: {e}")
            return []

    def update_incident(self, incident_id: str, update_data: Dict) -> bool:
        """
        Update an incident in ServiceNow

        Args:
            incident_id: Incident sys_id
            update_data: Dictionary of fields to update

        Returns:
            True if successful, False otherwise
        """
        url = f"{self.instance_url}/api/now/table/incident/{incident_id}"

        try:
            response = requests.patch(
                url, headers=self.headers, json=update_data, timeout=10
            )
            response.raise_for_status()
            return True
        except requests.exceptions.RequestException as e:
            print(f"Error updating incident: {e}")
            return False

    def get_similar_incidents(self, category: str, limit: int = 10) -> List[Dict]:
        """
        Get similar incidents by category

        Args:
            category: Incident category
            limit: Maximum number of results

        Returns:
            List of incident records
        """
        url = f"{self.instance_url}/api/now/table/incident"
        query = f"category={category}^state!=1^ORDERBYDESCcreated_on"
        params = {
            "sysparm_query": query,
            "sysparm_limit": limit,
            "sysparm_fields": "number,short_description,state,resolution_notes",
        }

        try:
            response = requests.get(
                url, headers=self.headers, params=params, timeout=10
            )
            response.raise_for_status()
            return response.json()["result"]
        except requests.exceptions.RequestException as e:
            print(f"Error retrieving similar incidents: {e}")
            return []


class BedrockIncidentAnalyzer:
    """Analyzer for incidents using Amazon Bedrock"""

    def __init__(self, region: str = "us-east-1"):
        """
        Initialize Bedrock client

        Args:
            region: AWS region for Bedrock
        """
        self.bedrock = boto3.client("bedrock-runtime", region_name=region)
        self.model_id = "anthropic.claude-3-5-sonnet-20241022-v2:0"

    def analyze_incident(
        self,
        incident: IncidentData,
        kb_articles: List[Dict],
        similar_incidents: List[Dict],
    ) -> Dict:
        """
        Analyze incident using Claude

        Args:
            incident: The incident to analyze
            kb_articles: Relevant KB articles
            similar_incidents: Similar incidents for reference

        Returns:
            Analysis results including recommendations
        """
        # Build context for the model
        context = f"""
Analyze this ServiceNow incident and provide recommendations:

INCIDENT DETAILS:
- Number: {incident.number}
- Title: {incident.short_description}
- Description: {incident.description}
- Impact Level: {incident.impact}
- Urgency Level: {incident.urgency}
- Current Category: {incident.category}
- Current State: {incident.state}

RELEVANT KB ARTICLES:
"""
        for i, article in enumerate(kb_articles, 1):
            context += f"\n{i}. {article['short_description']}\n"
            context += f"   Content: {article['text'][:200]}...\n"

        context += "\nSIMILAR RESOLVED INCIDENTS:\n"
        for i, incident_record in enumerate(similar_incidents, 1):
            context += f"\n{i}. {incident_record['number']}: {incident_record['short_description']}\n"
            if incident_record.get("resolution_notes"):
                context += (
                    f"   Resolution: {incident_record['resolution_notes'][:150]}...\n"
                )

        context += """
PROVIDE:
1. Probable root cause (with confidence %)
2. Recommended category and subcategory
3. Recommended assignment group
4. Suggested solution steps
5. Estimated resolution time
6. Recommended priority (1-3)

Format response as JSON with these exact keys:
{
    "root_cause": "...",
    "confidence": 95,
    "category": "...",
    "subcategory": "...",
    "assignment_group": "...",
    "solution_steps": ["step1", "step2", ...],
    "estimated_time_minutes": 30,
    "recommended_priority": 2,
    "rationale": "..."
}
"""

        try:
            # Call Bedrock
            response = self.bedrock.invoke_model(
                modelId=self.model_id,
                contentType="application/json",
                accept="application/json",
                body=json.dumps(
                    {
                        "messages": [{"role": "user", "content": context}],
                        "max_tokens": 1000,
                    }
                ),
            )

            # Parse response
            result = json.loads(response["body"].read())
            content = result["content"][0]["text"]

            # Extract JSON from response
            try:
                # Try to parse the entire response as JSON
                analysis = json.loads(content)
            except json.JSONDecodeError:
                # If that fails, try to extract JSON from the text
                import re

                json_match = re.search(r"\{.*\}", content, re.DOTALL)
                if json_match:
                    analysis = json.loads(json_match.group())
                else:
                    analysis = {"raw_response": content}

            return analysis

        except Exception as e:
            print(f"Error analyzing with Bedrock: {e}")
            return {"error": str(e)}


def main():
    """Main example demonstrating incident automation"""

    # Configuration
    SERVICENOW_INSTANCE = "https://your-instance.service-now.com"
    SERVICENOW_USERNAME = "servicenow_bedrock_api"
    SERVICENOW_API_TOKEN = "your-api-token-here"

    # Initialize clients
    print("Initializing clients...")
    snow_client = ServiceNowClient(
        SERVICENOW_INSTANCE, SERVICENOW_USERNAME, SERVICENOW_API_TOKEN
    )
    bedrock_analyzer = BedrockIncidentAnalyzer()

    # Example: Process an incident
    incident_id = "a59c6c43db..."  # Replace with actual incident sys_id

    print(f"\n1. Retrieving incident {incident_id}...")
    incident = snow_client.get_incident(incident_id)

    if not incident:
        print("Failed to retrieve incident")
        return

    print(f"   Retrieved: {incident.number} - {incident.short_description}")

    # Search for related KB articles
    print("\n2. Searching for related KB articles...")
    search_terms = incident.short_description.split()[:3]
    search_query = " ".join(search_terms)
    kb_articles = snow_client.search_kb(search_query, limit=5)
    print(f"   Found {len(kb_articles)} KB articles")

    # Get similar incidents
    print("\n3. Retrieving similar incidents...")
    category = incident.category or "Software"
    similar_incidents = snow_client.get_similar_incidents(category, limit=5)
    print(f"   Found {len(similar_incidents)} similar incidents")

    # Analyze with Bedrock
    print("\n4. Analyzing incident with Bedrock...")
    analysis = bedrock_analyzer.analyze_incident(
        incident, kb_articles, similar_incidents
    )

    print("\n5. Analysis Results:")
    print(json.dumps(analysis, indent=2))

    # Update incident with recommendations
    if "error" not in analysis:
        print("\n6. Updating incident with recommendations...")
        update_data = {
            "category": analysis.get("category", incident.category),
            "assignment_group": analysis.get("assignment_group"),
            "priority": analysis.get("recommended_priority", 3),
            "work_notes": f"AI Analysis:\nRoot Cause: {analysis.get('root_cause')}\nConfidence: {analysis.get('confidence')}%\n\nSuggested Solution:\n"
            + "\n".join(
                f"  {i+1}. {step}"
                for i, step in enumerate(analysis.get("solution_steps", []))
            )
            + f"\n\nEstimated Resolution Time: {analysis.get('estimated_time_minutes')} minutes",
        }

        if snow_client.update_incident(incident.sys_id, update_data):
            print("   Incident updated successfully")
        else:
            print("   Failed to update incident")

    print("\n7. Incident automation complete!")


if __name__ == "__main__":
    main()
