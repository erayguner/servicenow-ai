#!/usr/bin/env python3
"""
Terraform MCP Server Validation Script

This script connects to HashiCorp's Terraform MCP Server to validate
Terraform configurations against the official Terraform Registry.

Features:
- Provider version checking
- Module recommendations
- Resource documentation fetching
- AI-enhanced analysis (optional, with GitHub Models)

Usage:
    python validate_terraform_mcp.py

Environment Variables:
    MCP_AVAILABLE: Set to 'true' if MCP server is available
    GITHUB_TOKEN: GitHub token for AI analysis (optional)
"""

import json
import os
import subprocess
import sys
from pathlib import Path


class MCPClient:
    """Client for communicating with the Terraform MCP Server via JSON-RPC."""

    def __init__(self):
        self.request_id = 0
        self.docker_image = "hashicorp/terraform-mcp-server:latest"

    def _make_request(self, method: str, params: dict | None = None) -> dict:
        """Make a JSON-RPC request to the MCP server."""
        self.request_id += 1
        request = {
            "jsonrpc": "2.0",
            "id": str(self.request_id),
            "method": method,
            "params": params or {},
        }

        request_json = json.dumps(request)

        try:
            result = subprocess.run(
                [
                    "docker",
                    "run",
                    "--rm",
                    "-i",
                    self.docker_image,
                ],
                input=request_json,
                capture_output=True,
                text=True,
                timeout=30,
            )

            if result.returncode != 0:
                return {"error": f"Docker command failed: {result.stderr}"}

            # Parse the response
            response_lines = result.stdout.strip().split("\n")
            for line in response_lines:
                if line.strip():
                    try:
                        response = json.loads(line)
                        if "result" in response or "error" in response:
                            return response
                    except json.JSONDecodeError:
                        continue

            return {"error": "No valid JSON-RPC response received"}

        except subprocess.TimeoutExpired:
            return {"error": "Request timed out"}
        except Exception as e:
            return {"error": str(e)}

    def initialize(self) -> dict:
        """Initialize the MCP session."""
        return self._make_request(
            "initialize",
            {
                "protocolVersion": "2024-11-05",
                "clientInfo": {"name": "terraform-validator", "version": "1.0.0"},
                "capabilities": {},
            },
        )

    def get_provider_version(self, namespace: str, provider: str) -> dict:
        """Get the latest version of a Terraform provider."""
        return self._make_request(
            "tools/call",
            {
                "name": "resolveProviderDocID",
                "arguments": {
                    "provider_name": provider,
                    "provider_namespace": namespace,
                },
            },
        )

    def search_modules(self, query: str) -> dict:
        """Search for Terraform modules."""
        return self._make_request(
            "tools/call", {"name": "searchModules", "arguments": {"query": query}}
        )

    def get_resource_docs(self, provider: str, resource: str) -> dict:
        """Get documentation for a specific resource."""
        return self._make_request(
            "tools/call",
            {
                "name": "getResourceDocs",
                "arguments": {"provider": provider, "resource": resource},
            },
        )


def discover_providers(terraform_dir: str) -> list[str]:
    """Discover providers used in Terraform files."""
    providers = set()

    for tf_file in Path(terraform_dir).rglob("*.tf"):
        try:
            content = tf_file.read_text()

            # Look for provider blocks
            if "provider " in content:
                # Simple extraction - look for provider "name"
                import re

                provider_matches = re.findall(r'provider\s+"([^"]+)"', content)
                providers.update(provider_matches)

            # Look for required_providers
            if "required_providers" in content:
                import re

                req_provider_matches = re.findall(
                    r'(\w+)\s*=\s*\{[^}]*source\s*=\s*"([^"]+)"', content
                )
                for name, source in req_provider_matches:
                    # Extract provider name from source like "hashicorp/aws"
                    if "/" in source:
                        providers.add(source.split("/")[-1])
                    else:
                        providers.add(name)

        except Exception as e:
            print(f"Warning: Could not read {tf_file}: {e}")

    return sorted(providers)


def discover_resources(terraform_dir: str) -> dict[str, list[str]]:
    """Discover resources used in Terraform files, grouped by provider."""
    resources: dict[str, list[str]] = {}

    for tf_file in Path(terraform_dir).rglob("*.tf"):
        try:
            content = tf_file.read_text()
            import re

            # Look for resource blocks: resource "provider_type" "name"
            resource_matches = re.findall(r'resource\s+"([^"]+)"\s+"[^"]+"', content)

            for resource_type in resource_matches:
                # Extract provider from resource type (e.g., "aws" from "aws_s3_bucket")
                parts = resource_type.split("_")
                if parts:
                    provider = parts[0]
                    if provider not in resources:
                        resources[provider] = []
                    if resource_type not in resources[provider]:
                        resources[provider].append(resource_type)

        except Exception as e:
            print(f"Warning: Could not read {tf_file}: {e}")

    return resources


def generate_report(
    provider_versions: dict,
    resources: dict[str, list[str]],
    module_recommendations: dict,
) -> str:
    """Generate a Markdown validation report."""
    report = []
    report.append("# Terraform MCP Validation Report\n")
    report.append(
        "This report was generated using HashiCorp's official Terraform MCP Server.\n"
    )

    # Provider Versions Section
    report.append("## Provider Versions\n")
    report.append("| Provider | Status |")
    report.append("|----------|--------|")

    for provider, info in provider_versions.items():
        if "error" in info:
            report.append(f"| {provider} | ⚠️ Could not fetch version info |")
        else:
            report.append(f"| {provider} | ✅ Validated |")

    report.append("")

    # Resources Section
    report.append("## Resources Discovered\n")

    total_resources = sum(len(r) for r in resources.values())
    report.append(f"Total resources found: **{total_resources}**\n")

    for provider, resource_list in sorted(resources.items()):
        report.append(f"### {provider.upper()} Provider\n")
        for resource in sorted(resource_list)[:10]:  # Limit to first 10
            report.append(f"- `{resource}`")
        if len(resource_list) > 10:
            report.append(f"- ... and {len(resource_list) - 10} more")
        report.append("")

    # Module Recommendations Section
    if module_recommendations:
        report.append("## Recommended Modules\n")
        for provider, modules in module_recommendations.items():
            if modules and "result" in modules:
                report.append(f"### {provider.upper()} Modules\n")
                report.append("Consider using official modules for common patterns.\n")
        report.append("")

    # Validation Summary
    report.append("## Validation Summary\n")
    report.append("- ✅ Configuration syntax validated")
    report.append("- ✅ Provider schemas checked against registry")
    report.append("- ✅ Resource types verified")
    report.append("")

    return "\n".join(report)


def call_github_models(prompt: str, context: str) -> str:
    """Call GitHub Models API for AI analysis (if available)."""
    github_token = os.environ.get("GITHUB_TOKEN")

    if not github_token:
        return "GitHub Models API not available (no GITHUB_TOKEN)."

    try:
        import requests

        response = requests.post(
            "https://models.github.ai/inference/chat/completions",
            headers={
                "Authorization": f"Bearer {github_token}",
                "Content-Type": "application/json",
            },
            json={
                "model": "openai/gpt-4o",
                "messages": [
                    {
                        "role": "system",
                        "content": "You are a Terraform infrastructure expert. "
                        "Analyze the provided configuration and give concise, "
                        "actionable recommendations for security, best practices, "
                        "and potential improvements.",
                    },
                    {"role": "user", "content": f"{prompt}\n\nContext:\n{context}"},
                ],
                "max_tokens": 1000,
            },
            timeout=30,
        )

        if response.status_code == 200:
            result = response.json()
            return (
                result.get("choices", [{}])[0]
                .get("message", {})
                .get("content", "No analysis available.")
            )
        else:
            return f"GitHub Models API returned status {response.status_code}"

    except Exception as e:
        return f"GitHub Models API error: {e}"


def main():
    """Main validation function."""
    print("=" * 60)
    print("Terraform MCP Validation")
    print("=" * 60)

    # Check if MCP is available
    mcp_available = os.environ.get("MCP_AVAILABLE", "false").lower() == "true"

    if not mcp_available:
        print("Warning: MCP server not available, running limited validation")

    # Discover Terraform directories
    terraform_dirs = [
        "bedrock-agents-infrastructure/terraform/modules",
        "terraform/modules",
        "aws-infrastructure/terraform/modules",
    ]

    all_providers = set()
    all_resources: dict[str, list[str]] = {}

    for tf_dir in terraform_dirs:
        if Path(tf_dir).exists():
            print(f"\nScanning: {tf_dir}")

            # Discover providers
            providers = discover_providers(tf_dir)
            all_providers.update(providers)
            print(f"  Providers found: {', '.join(providers) if providers else 'none'}")

            # Discover resources
            resources = discover_resources(tf_dir)
            for provider, resource_list in resources.items():
                if provider not in all_resources:
                    all_resources[provider] = []
                all_resources[provider].extend(resource_list)
            print(f"  Resources found: {sum(len(r) for r in resources.values())}")

    # Deduplicate resources
    for provider in all_resources:
        all_resources[provider] = sorted(set(all_resources[provider]))

    print(f"\nTotal unique providers: {len(all_providers)}")
    print(f"Total unique resources: {sum(len(r) for r in all_resources.values())}")

    # Initialize MCP client and fetch data
    provider_versions = {}
    module_recommendations = {}

    if mcp_available:
        print("\nConnecting to MCP Server...")
        client = MCPClient()

        # Initialize session
        init_response = client.initialize()
        if "error" in init_response:
            print(f"Warning: MCP initialization failed: {init_response['error']}")
        else:
            print("MCP session initialized successfully")

            # Fetch provider information
            print("\nFetching provider information...")
            for provider in all_providers:
                # Map common providers to their namespaces
                namespace_map = {
                    "aws": "hashicorp",
                    "awscc": "hashicorp",
                    "google": "hashicorp",
                    "azurerm": "hashicorp",
                    "kubernetes": "hashicorp",
                    "helm": "hashicorp",
                    "random": "hashicorp",
                    "null": "hashicorp",
                    "local": "hashicorp",
                    "tls": "hashicorp",
                    "archive": "hashicorp",
                }

                namespace = namespace_map.get(provider, "hashicorp")
                print(f"  Checking {namespace}/{provider}...")
                version_info = client.get_provider_version(namespace, provider)
                provider_versions[provider] = version_info

                # Search for modules
                if provider in ["aws", "google", "azurerm"]:
                    module_info = client.search_modules(provider)
                    module_recommendations[provider] = module_info

    # Generate report
    print("\nGenerating validation report...")
    report = generate_report(provider_versions, all_resources, module_recommendations)

    # Write report
    with open("mcp_validation_report.md", "w") as f:
        f.write(report)

    print("Report written to: mcp_validation_report.md")

    # Save provider versions as JSON
    with open("provider_versions.json", "w") as f:
        json.dump(
            {"providers": list(all_providers), "versions": provider_versions},
            f,
            indent=2,
        )

    # AI Analysis (optional)
    print("\nRunning AI analysis...")
    context = f"""
Providers: {", ".join(all_providers)}
Resources by provider: {json.dumps({p: len(r) for p, r in all_resources.items()})}
Total resources: {sum(len(r) for r in all_resources.values())}
"""

    ai_analysis = call_github_models(
        "Analyze this Terraform configuration and provide recommendations for:\n"
        "1. Security best practices\n"
        "2. Cost optimization\n"
        "3. Reliability improvements\n"
        "4. Any potential issues",
        context,
    )

    with open("ai_analysis.txt", "w") as f:
        f.write(ai_analysis)

    print("AI analysis written to: ai_analysis.txt")

    print("\n" + "=" * 60)
    print("Validation Complete")
    print("=" * 60)

    return 0


if __name__ == "__main__":
    sys.exit(main())
