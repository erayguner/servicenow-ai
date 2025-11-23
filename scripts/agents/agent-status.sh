#!/bin/bash
# Agent Status Script - Check deployment status and health
# Usage: ./scripts/agents/agent-status.sh

set -euo pipefail

SESSION_ID="servicenow-ai-infra-dev"
MANIFEST="/home/user/servicenow-ai/coordination/agents/agent-deployment-manifest.json"

echo "================================"
echo "ServiceNow AI Agent Status"
echo "================================"
echo "Session: $SESSION_ID"
echo ""

# Check if manifest exists
if [ ! -f "$MANIFEST" ]; then
  echo "❌ Agent manifest not found at $MANIFEST"
  exit 1
fi

# Display deployment info
echo "📊 Deployment Information:"
echo "  Topology: $(jq -r '.deployment.topology' "$MANIFEST")"
echo "  Max Agents: $(jq -r '.deployment.max_agents' "$MANIFEST")"
echo "  Created: $(jq -r '.deployment.created_at' "$MANIFEST")"
echo ""

# Display agent count
AGENT_COUNT=$(jq '.agents | length' "$MANIFEST")
echo "🤖 Deployed Agents: $AGENT_COUNT"
echo ""

# List all agents
echo "📋 Agent List:"
jq -r '.agents[] | "  • \(.role) (\(.type))\n    ID: \(.id)\n    Status: \(.status)"' "$MANIFEST"
echo ""

# Check tools availability
echo "🔧 Tool Availability:"
command -v terraform >/dev/null 2>&1 && echo "  ✅ Terraform $(terraform version -json | jq -r '.terraform_version')" || echo "  ❌ Terraform not found"
command -v checkov >/dev/null 2>&1 && echo "  ✅ Checkov $(checkov --version | head -1)" || echo "  ❌ Checkov not found"
command -v yamllint >/dev/null 2>&1 && echo "  ✅ yamllint $(yamllint --version)" || echo "  ❌ yamllint not found"
command -v prettier >/dev/null 2>&1 && echo "  ✅ Prettier $(prettier --version)" || echo "  ❌ Prettier not found"
command -v shfmt >/dev/null 2>&1 && echo "  ✅ shfmt $(shfmt --version)" || echo "  ❌ shfmt not found"
command -v kubectl >/dev/null 2>&1 && echo "  ✅ kubectl $(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion')" || echo "  ❌ kubectl not found"
command -v gcloud >/dev/null 2>&1 && echo "  ✅ gcloud $(gcloud version --format='value(Google Cloud SDK)')" || echo "  ❌ gcloud not found"
echo ""

# Check claude-flow
echo "🌊 Claude-Flow Status:"
if command -v npx >/dev/null 2>&1; then
  echo "  ✅ npx available"
  npx claude-flow@alpha --version 2>/dev/null || echo "  ⚠ Claude-Flow alpha - version check skipped"
else
  echo "  ❌ npx not found"
fi
echo ""

# Check memory directory
echo "💾 Memory & Coordination:"
if [ -d "/home/user/servicenow-ai/memory" ]; then
  MEMORY_SIZE=$(du -sh /home/user/servicenow-ai/memory | cut -f1)
  echo "  ✅ Memory directory: $MEMORY_SIZE"
else
  echo "  ⚠ Memory directory not found"
fi

if [ -d "/home/user/servicenow-ai/coordination" ]; then
  COORD_SIZE=$(du -sh /home/user/servicenow-ai/coordination | cut -f1)
  echo "  ✅ Coordination directory: $COORD_SIZE"
else
  echo "  ⚠ Coordination directory not found"
fi
echo ""

# Summary
echo "================================"
echo "Summary: $AGENT_COUNT agents deployed and ready"
echo "================================"
