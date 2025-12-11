#!/usr/bin/env python3
"""
ServiceNow Bedrock Ticket Triage Example

This example demonstrates batch ticket triage using Bedrock agents.
It processes multiple incidents concurrently and applies intelligent categorization.

Prerequisites:
- AWS credentials configured
- ServiceNow instance with REST API enabled
- Python 3.9+ with boto3 and requests libraries
"""

import json
import boto3
from typing import List, Dict, Tuple
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
import requests
import base64


class TicketTriageSystem:
    """System for batch triaging tickets using Bedrock"""

    def __init__(self, servicenow_config: Dict, aws_region: str = "eu-west-2"):
        """
        Initialize the triage system

        Args:
            servicenow_config: Dictionary with 'instance_url', 'username', 'api_token'
            aws_region: AWS region for Bedrock
        """
        self.servicenow_config = servicenow_config
        self.bedrock = boto3.client("bedrock-runtime", region_name=aws_region)
        self.model_id = "anthropic.claude-3-5-sonnet-20241022-v2:0"

        # Setup ServiceNow authentication
        credentials = (
            f"{servicenow_config['username']}:{servicenow_config['api_token']}"
        )
        encoded = base64.b64encode(credentials.encode()).decode()
        self.snow_headers = {
            "Authorization": f"Basic {encoded}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

    def get_untriaged_incidents(self, limit: int = 50) -> List[Dict]:
        """
        Retrieve untriaged incidents from ServiceNow

        Args:
            limit: Maximum number of incidents to retrieve

        Returns:
            List of incident dictionaries
        """
        url = f"{self.servicenow_config['instance_url']}/api/now/table/incident"

        # Query for incidents in "New" state without assignment
        query = "state=1^categoryEMPTY^ORDERBYDESCcreated_on"
        params = {
            "sysparm_query": query,
            "sysparm_limit": limit,
            "sysparm_fields": "sys_id,number,short_description,description,caller_id,created_on,impact,urgency",
        }

        try:
            response = requests.get(
                url, headers=self.snow_headers, params=params, timeout=15
            )
            response.raise_for_status()
            return response.json()["result"]
        except requests.RequestException as e:
            print(f"Error retrieving incidents: {e}")
            return []

    def triage_ticket(self, ticket: Dict) -> Dict:
        """
        Triage a single ticket using Bedrock

        Args:
            ticket: Incident dictionary from ServiceNow

        Returns:
            Dictionary with triage results
        """
        prompt = f"""
You are an expert IT support ticket triage specialist. Analyze this support ticket and provide triage recommendations.

TICKET INFORMATION:
- Ticket Number: {ticket['number']}
- Title: {ticket['short_description']}
- Description: {ticket['description'][:500]}
- Urgency: {ticket.get('urgency', '3')}
- Impact: {ticket.get('impact', '3')}
- Created: {ticket.get('created_on', 'Unknown')}

PROVIDE TRIAGE RECOMMENDATIONS:

1. CATEGORY: Assign to one of these categories:
   - Hardware (printers, displays, keyboards, etc.)
   - Software (applications, operating system, utilities)
   - Network (connectivity, VPN, WiFi)
   - Email (email client, mailbox access)
   - Database (database connectivity, performance)
   - Other (specify)

2. SUBCATEGORY: More specific classification

3. ASSIGNMENT: Which support team should handle this?
   - Hardware Support
   - Software Support
   - Network Operations
   - Email Support
   - Database Team
   - Management (if escalation needed)

4. PRIORITY: Set priority based on impact and urgency
   - 1 (Critical): System down, multiple users affected
   - 2 (High): Significant impact, workaround available
   - 3 (Medium): Minor impact, user productivity affected
   - 4 (Low): Cosmetic or informational

5. IMMEDIATE ACTION: What should be the first troubleshooting step?

6. ESCALATION: Does this need immediate escalation? (Yes/No)
   If yes, explain why.

RESPOND AS JSON:
{{
    "category": "...",
    "subcategory": "...",
    "assignment_group": "...",
    "priority": 2,
    "first_step": "...",
    "escalate": false,
    "escalation_reason": "",
    "confidence": 0.95,
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
                        "max_tokens": 800,
                    }
                ),
            )

            result = json.loads(response["body"].read())
            content = result["content"][0]["text"]

            # Parse JSON from response
            import re

            json_match = re.search(r"\{.*\}", content, re.DOTALL)
            if json_match:
                triage_result = json.loads(json_match.group())
            else:
                triage_result = {"error": "Could not parse response"}

            # Add original ticket info
            triage_result["ticket_id"] = ticket["sys_id"]
            triage_result["ticket_number"] = ticket["number"]

            return triage_result

        except Exception as e:
            return {
                "ticket_id": ticket["sys_id"],
                "ticket_number": ticket["number"],
                "error": str(e),
            }

    def update_ticket_in_servicenow(self, ticket_id: str, triage_result: Dict) -> bool:
        """
        Update ticket in ServiceNow with triage results

        Args:
            ticket_id: Incident sys_id
            triage_result: Dictionary with triage results

        Returns:
            True if successful
        """
        url = f"{self.servicenow_config['instance_url']}/api/now/table/incident/{ticket_id}"

        update_data = {
            "category": triage_result.get("category", ""),
            "assignment_group": triage_result.get("assignment_group", ""),
            "priority": triage_result.get("priority", 3),
            "work_notes": "Automated Triage:\n"
            + f"Category: {triage_result.get('category')}\n"
            + f"First Step: {triage_result.get('first_step')}\n"
            + f"Confidence: {triage_result.get('confidence', 0):.0%}\n"
            + f"Notes: {triage_result.get('notes', '')}",
        }

        if triage_result.get("escalate"):
            update_data[
                "work_notes"
            ] += f"\n\nEscalation: {triage_result.get('escalation_reason')}"

        try:
            response = requests.patch(
                url, headers=self.snow_headers, json=update_data, timeout=10
            )
            response.raise_for_status()
            return True
        except requests.RequestException as e:
            print(f"Error updating ticket {ticket_id}: {e}")
            return False

    def triage_batch(
        self, tickets: List[Dict], max_workers: int = 5
    ) -> Tuple[List[Dict], List[str]]:
        """
        Triage multiple tickets concurrently

        Args:
            tickets: List of incident dictionaries
            max_workers: Number of concurrent workers

        Returns:
            Tuple of (successful_triages, error_messages)
        """
        successful = []
        errors = []

        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            # Submit all triage tasks
            future_to_ticket = {
                executor.submit(self.triage_ticket, ticket): ticket
                for ticket in tickets
            }

            # Process completed tasks
            for i, future in enumerate(future_to_ticket, 1):
                try:
                    triage_result = future.result(timeout=30)
                    ticket = future_to_ticket[future]

                    print(
                        f"[{i}/{len(tickets)}] Triaged {ticket['number']}: "
                        + f"{triage_result.get('category', 'Error')}"
                    )

                    # Update in ServiceNow
                    if "error" not in triage_result:
                        if self.update_ticket_in_servicenow(
                            ticket["sys_id"], triage_result
                        ):
                            triage_result["status"] = "updated"
                        else:
                            triage_result["status"] = "triaged_not_updated"
                    else:
                        triage_result["status"] = "error"

                    successful.append(triage_result)

                except Exception as e:
                    ticket = future_to_ticket[future]
                    error_msg = f"Failed to triage {ticket['number']}: {str(e)}"
                    print(f"[{i}/{len(tickets)}] {error_msg}")
                    errors.append(error_msg)

        return successful, errors

    def generate_triage_report(self, results: List[Dict]) -> str:
        """
        Generate a summary report of triage results

        Args:
            results: List of triage results

        Returns:
            Formatted report string
        """
        total = len(results)
        successful = len([r for r in results if "error" not in r])
        escalations = len([r for r in results if r.get("escalate")])

        # Count by category
        categories: Dict[str, int] = {}
        for r in results:
            cat = r.get("category", "Unknown")
            categories[cat] = categories.get(cat, 0) + 1

        # Count by priority
        priorities = {1: 0, 2: 0, 3: 0, 4: 0}
        for r in results:
            pri = r.get("priority", 3)
            if pri in priorities:
                priorities[pri] += 1

        report = f"""
TICKET TRIAGE REPORT
{'=' * 50}
Generated: {datetime.now().isoformat()}

SUMMARY:
- Total Tickets: {total}
- Successfully Triaged: {successful}
- Escalations Recommended: {escalations}
- Success Rate: {successful/total*100:.1f}%

DISTRIBUTION BY CATEGORY:
"""
        for cat, count in sorted(categories.items(), key=lambda x: x[1], reverse=True):
            report += f"  {cat}: {count} ({count/total*100:.1f}%)\n"

        report += "\nDISTRIBUTION BY PRIORITY:\n"
        for priority in [1, 2, 3, 4]:
            count = priorities[priority]
            priority_names = {1: "Critical", 2: "High", 3: "Medium", 4: "Low"}
            report += f"  Priority {priority} ({priority_names[priority]}): {count} ({count/total*100:.1f}%)\n"

        return report


def main():
    """Main example: batch ticket triage"""

    # Configuration
    servicenow_config = {
        "instance_url": "https://your-instance.service-now.com",
        "username": "servicenow_bedrock_api",
        "api_token": "your-api-token",
    }

    # Initialize triage system
    print("Initializing ticket triage system...")
    triage_system = TicketTriageSystem(servicenow_config)

    # Get untriaged incidents
    print("\nRetrieving untriaged incidents...")
    incidents = triage_system.get_untriaged_incidents(limit=20)
    print(f"Found {len(incidents)} untriaged incidents")

    if not incidents:
        print("No incidents to triage")
        return

    # Triage batch with 5 concurrent workers
    print(f"\nTriaging {len(incidents)} incidents with 5 concurrent workers...\n")
    results, errors = triage_system.triage_batch(incidents, max_workers=5)

    # Generate and display report
    report = triage_system.generate_triage_report(results)
    print(report)

    # Print summary
    print("\nTriaging complete:")
    print(f"  Successful: {len([r for r in results if 'error' not in r])}")
    print(f"  Errors: {len(errors)}")

    if errors:
        print("\nErrors encountered:")
        for error in errors[:5]:  # Show first 5 errors
            print(f"  - {error}")

    # Save results to file
    output_file = "triage_results.json"
    with open(output_file, "w") as f:
        json.dump(
            {
                "timestamp": datetime.now().isoformat(),
                "results": results,
                "errors": errors,
                "summary": {
                    "total": len(results),
                    "successful": len([r for r in results if "error" not in r]),
                    "errors": len(errors),
                },
            },
            f,
            indent=2,
        )
    print(f"\nResults saved to {output_file}")


if __name__ == "__main__":
    main()
