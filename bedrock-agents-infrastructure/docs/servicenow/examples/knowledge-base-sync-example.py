#!/usr/bin/env python3
"""
ServiceNow Bedrock Knowledge Base Synchronization Example

This example demonstrates automatic KB article generation from incident resolutions
and knowledge base optimization using Bedrock.

Prerequisites:
- AWS credentials configured
- ServiceNow instance with REST API enabled
- Python 3.9+ with boto3 and requests libraries
"""

import json
import boto3
import requests
import base64
from typing import List, Dict, Optional, Tuple
from datetime import datetime, timedelta
from dataclasses import dataclass


@dataclass
class IncidentResolution:
    """Represents a resolved incident"""

    sys_id: str
    number: str
    short_description: str
    description: str
    resolution_notes: str
    category: str
    state: str
    created_on: str
    resolved_on: str
    resolved_by: str


class KnowledgeBaseSynchronizer:
    """Synchronizes and optimizes the ServiceNow Knowledge Base"""

    def __init__(
        self,
        servicenow_url: str,
        username: str,
        api_token: str,
        aws_region: str = "us-east-1",
    ):
        """
        Initialize KB synchronizer

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

    def get_recently_resolved_incidents(
        self, days: int = 7, limit: int = 50
    ) -> List[IncidentResolution]:
        """
        Get recently resolved incidents

        Args:
            days: Number of days to look back
            limit: Maximum number of incidents

        Returns:
            List of IncidentResolution objects
        """
        url = f"{self.servicenow_url}/api/now/table/incident"

        # Query for resolved incidents from last N days
        query = f"state=7^resolved_onONLAST{days}@days^ORDERBYDESCresolved_on"
        params = {
            "sysparm_query": query,
            "sysparm_limit": limit,
            "sysparm_fields": "sys_id,number,short_description,description,resolution_notes,category,state,created_on,resolved_on,resolved_by",
        }

        try:
            response = requests.get(
                url, headers=self.headers, params=params, timeout=15
            )
            response.raise_for_status()

            incidents = []
            for data in response.json()["result"]:
                incidents.append(
                    IncidentResolution(
                        sys_id=data["sys_id"],
                        number=data["number"],
                        short_description=data["short_description"],
                        description=data["description"],
                        resolution_notes=data.get("resolution_notes", ""),
                        category=data.get("category", "Other"),
                        state=data["state"],
                        created_on=data["created_on"],
                        resolved_on=data["resolved_on"],
                        resolved_by=data["resolved_by"],
                    )
                )

            return incidents

        except requests.RequestException as e:
            print(f"Error retrieving resolved incidents: {e}")
            return []

    def search_kb_for_duplicates(
        self, article_title: str, keywords: List[str]
    ) -> List[Dict]:
        """
        Search for existing KB articles that might be duplicates

        Args:
            article_title: Potential article title
            keywords: Keywords to search for

        Returns:
            List of potentially duplicate articles
        """
        url = f"{self.servicenow_url}/api/now/table/kb_knowledge"

        # Search for articles with similar keywords
        query_terms = " OR ".join(
            f"CONTAINS(short_description,'{kw}')" for kw in keywords[:3]
        )
        query = f"({query_terms})^workflow_state=published"
        params = {
            "sysparm_query": query,
            "sysparm_limit": 10,
            "sysparm_fields": "sys_id,number,short_description,text",
        }

        try:
            response = requests.get(
                url, headers=self.headers, params=params, timeout=10
            )
            response.raise_for_status()
            return response.json()["result"]

        except requests.RequestException as e:
            print(f"Error searching for duplicate KB articles: {e}")
            return []

    def generate_kb_article(
        self, incident: IncidentResolution, existing_articles: List[Dict]
    ) -> Dict:
        """
        Generate a KB article from incident resolution using Bedrock

        Args:
            incident: IncidentResolution object
            existing_articles: List of existing articles for duplicate detection

        Returns:
            Dictionary with generated article content
        """
        # Build context about existing articles
        existing_context = "Existing KB articles on similar topics:\n"
        for article in existing_articles:
            existing_context += (
                f"- {article['number']}: {article['short_description']}\n"
            )

        if not existing_articles:
            existing_context += "- No existing articles found on this topic\n"

        prompt = f"""
Generate a high-quality ServiceNow Knowledge Base article based on this incident resolution.

INCIDENT INFORMATION:
- Number: {incident.number}
- Title: {incident.short_description}
- Original Issue: {incident.description}
- Root Cause: [Implied from resolution]
- Resolution: {incident.resolution_notes}
- Category: {incident.category}
- Resolution Time: {incident.resolved_on}

{existing_context}

CREATE A KB ARTICLE WITH:

1. TITLE: Clear, descriptive, searchable title (not the incident number)
   Example: "Resolve Database Connection Timeout Errors"

2. SUMMARY: 1-2 sentence overview of the issue and solution

3. SYMPTOMS: Bulleted list of symptoms users experience

4. ROOT CAUSE: Clear explanation of why this problem occurs

5. SOLUTION: Step-by-step resolution procedure
   Include prerequisites, exact steps, and verification

6. PREVENTION: How to prevent this issue in the future

7. RELATED ARTICLES: References to related KB articles

8. KEYWORDS: 5-10 search keywords

9. CATEGORY: Appropriate KB category

10. AFFECTED SYSTEMS: List of systems/components

FORMATTING:
- Use markdown formatting
- Use headers (##, ###) for structure
- Use bullet points for lists
- Include code blocks for commands if applicable

RESPOND AS JSON:
{{
    "title": "...",
    "summary": "...",
    "symptoms": ["symptom1", "symptom2"],
    "root_cause": "...",
    "solution": "Step 1: ...\nStep 2: ...",
    "prevention": ["measure1", "measure2"],
    "keywords": ["keyword1", "keyword2"],
    "category": "...",
    "affected_systems": ["system1", "system2"],
    "duplicate_of": null,
    "merge_with": [],
    "quality_score": 0.85,
    "is_publishable": true,
    "notes": "..."
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
                        "max_tokens": 2000,
                    }
                ),
            )

            result = json.loads(response["body"].read())
            content = result["content"][0]["text"]

            # Extract JSON from response
            import re

            json_match = re.search(r"\{.*\}", content, re.DOTALL)
            if json_match:
                article = json.loads(json_match.group())
            else:
                article = {"error": "Could not parse response"}

            article["source_incident"] = incident.number
            article["source_incident_id"] = incident.sys_id
            article["generated_at"] = datetime.now().isoformat()

            return article

        except Exception as e:
            return {"source_incident": incident.number, "error": str(e)}

    def publish_kb_article(self, article_content: Dict) -> Tuple[bool, str]:
        """
        Publish a generated KB article to ServiceNow

        Args:
            article_content: Dictionary with article content

        Returns:
            Tuple of (success, article_id_or_error_message)
        """
        url = f"{self.servicenow_url}/api/now/table/kb_knowledge"

        kb_data = {
            "short_description": article_content["title"],
            "text": article_content["solution"],
            "category": article_content.get("category", "General"),
            "kb_category": "How-To",
            "workflow_state": "draft",  # Draft first for review
            "meta": ", ".join(article_content.get("keywords", [])),
            "author": "Bedrock-Integration",
        }

        # Add full content as text
        full_text = f"""## {article_content.get('title', '')}

### Summary
{article_content.get('summary', '')}

### Symptoms
{chr(10).join(f"- {s}" for s in article_content.get('symptoms', []))}

### Root Cause
{article_content.get('root_cause', '')}

### Solution
{article_content.get('solution', '')}

### Prevention
{chr(10).join(f"- {p}" for p in article_content.get('prevention', []))}

### Related Articles
- Linked during publication

### Affected Systems
{chr(10).join(f"- {s}" for s in article_content.get('affected_systems', []))}
"""

        kb_data["text"] = full_text

        try:
            response = requests.post(
                url, headers=self.headers, json=kb_data, timeout=10
            )
            response.raise_for_status()

            result = response.json()["result"]
            return True, result["sys_id"]

        except requests.RequestException as e:
            return False, str(e)

    def analyze_kb_coverage(self, max_days: int = 90) -> Dict:
        """
        Analyze KB coverage and identify gaps

        Args:
            max_days: Number of days to analyze

        Returns:
            Dictionary with coverage metrics
        """
        # Get recent incidents
        url = f"{self.servicenow_url}/api/now/table/incident"
        query = f"created_onONLAST{max_days}@days^state=7"
        params = {
            "sysparm_query": query,
            "sysparm_limit": 500,
            "sysparm_fields": "category,short_description",
        }

        incidents_by_category = {}
        try:
            response = requests.get(
                url, headers=self.headers, params=params, timeout=15
            )
            response.raise_for_status()

            for incident in response.json()["result"]:
                category = incident.get("category", "Other")
                if category not in incidents_by_category:
                    incidents_by_category[category] = []
                incidents_by_category[category].append(incident)

        except requests.RequestException as e:
            print(f"Error analyzing coverage: {e}")

        # Get KB article count by category
        kb_by_category = {}
        url = f"{self.servicenow_url}/api/now/table/kb_knowledge"
        params = {"sysparm_limit": 500, "sysparm_fields": "category"}

        try:
            response = requests.get(
                url, headers=self.headers, params=params, timeout=15
            )
            response.raise_for_status()

            for article in response.json()["result"]:
                category = article.get("category", "Other")
                kb_by_category[category] = kb_by_category.get(category, 0) + 1

        except requests.RequestException as e:
            print(f"Error getting KB statistics: {e}")

        # Calculate coverage
        coverage = {}
        for category, incidents in incidents_by_category.items():
            kb_count = kb_by_category.get(category, 0)
            incident_count = len(incidents)
            coverage[category] = {
                "incidents": incident_count,
                "kb_articles": kb_count,
                "coverage_ratio": (
                    kb_count / incident_count if incident_count > 0 else 0
                ),
                "gaps": incident_count - kb_count,
            }

        return {
            "analysis_date": datetime.now().isoformat(),
            "days_analyzed": max_days,
            "coverage_by_category": coverage,
            "total_incidents": sum(c["incidents"] for c in coverage.values()),
            "total_kb_articles": sum(c["kb_articles"] for c in coverage.values()),
        }


def main():
    """Main example: KB synchronization"""

    # Configuration
    SERVICENOW_INSTANCE = "https://your-instance.service-now.com"
    SERVICENOW_USERNAME = "servicenow_bedrock_api"
    SERVICENOW_API_TOKEN = "your-api-token"

    print("Initializing Knowledge Base synchronizer...")
    synchronizer = KnowledgeBaseSynchronizer(
        SERVICENOW_INSTANCE, SERVICENOW_USERNAME, SERVICENOW_API_TOKEN
    )

    # Step 1: Analyze KB coverage
    print("\n1. Analyzing KB coverage...")
    coverage = synchronizer.analyze_kb_coverage(max_days=90)
    print(f"   Total incidents (90 days): {coverage['total_incidents']}")
    print(f"   Total KB articles: {coverage['total_kb_articles']}")
    print("   Coverage by category:")
    for category, stats in coverage["coverage_by_category"].items():
        print(
            f"     {category}: {stats['kb_articles']}/{stats['incidents']} ({stats['coverage_ratio']:.0%})"
        )

    # Step 2: Get recently resolved incidents
    print("\n2. Retrieving recently resolved incidents...")
    incidents = synchronizer.get_recently_resolved_incidents(days=7, limit=5)
    print(f"   Found {len(incidents)} recently resolved incidents")

    # Step 3: Generate KB articles from incidents
    print("\n3. Generating KB articles from incident resolutions...\n")
    generated_articles = []

    for i, incident in enumerate(incidents, 1):
        print(
            f"   [{i}/{len(incidents)}] Processing {incident.number}: {incident.short_description}"
        )

        # Check for duplicates
        keywords = incident.short_description.split()[:3]
        existing = synchronizer.search_kb_for_duplicates(
            incident.short_description, keywords
        )

        # Generate article
        article = synchronizer.generate_kb_article(incident, existing)
        generated_articles.append(article)

        if "error" not in article:
            # Publish article
            success, article_id = synchronizer.publish_kb_article(article)
            if success:
                print(f"       ✓ Article generated and published: {article_id}")
            else:
                print(f"       ✓ Article generated but not published: {article_id}")
        else:
            print(f"       ✗ Failed to generate article: {article['error']}")

    # Step 4: Generate report
    print("\n4. Generating report...")
    successful = len([a for a in generated_articles if "error" not in a])
    report = f"""
KNOWLEDGE BASE SYNCHRONIZATION REPORT
{'=' * 50}
Generated: {datetime.now().isoformat()}

SUMMARY:
- Analyzed: {len(incidents)} recent incidents
- Articles Generated: {successful}/{len(incidents)}
- Success Rate: {successful/len(incidents)*100:.1f}%

GENERATED ARTICLES:
"""
    for article in generated_articles:
        if "error" not in article:
            report += f"\n- {article['title']}\n"
            report += f"  Quality Score: {article.get('quality_score', 0):.0%}\n"
            report += f"  Keywords: {', '.join(article.get('keywords', [])[:5])}\n"

    print(report)

    # Save report
    output_file = "kb_sync_report.json"
    with open(output_file, "w") as f:
        json.dump(
            {
                "coverage_analysis": coverage,
                "generated_articles": generated_articles,
                "report": report,
                "timestamp": datetime.now().isoformat(),
            },
            f,
            indent=2,
        )
    print(f"\nReport saved to {output_file}")


if __name__ == "__main__":
    main()
