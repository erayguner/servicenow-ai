#!/bin/bash
# Security Scan Script - Runs Checkov with agent coordination
# Usage: ./scripts/agents/run-security-scan.sh [directory]

set -euo pipefail

SCAN_DIR="${1:-/home/user/servicenow-ai/terraform}"
SESSION_ID="servicenow-ai-infra-dev"
AGENT_ID="security-auditor-001"

echo "================================"
echo "Security Scan with Checkov"
echo "================================"
echo "Directory: $SCAN_DIR"
echo "Agent: $AGENT_ID"
echo "Session: $SESSION_ID"
echo ""

# Pre-task hook
npx claude-flow@alpha hooks pre-task --description "Security scan with Checkov on $SCAN_DIR" 2>/dev/null || echo "Pre-task hook skipped"

# Run Checkov security scan
echo "Running Checkov security scan..."
checkov -d "$SCAN_DIR" \
  --framework terraform \
  --output cli \
  --output json \
  --output-file-path /home/user/servicenow-ai/coordination/sessions \
  --soft-fail || true

# Post-task hook
npx claude-flow@alpha hooks post-task --task-id "security-scan-$(date +%s)" 2>/dev/null || echo "Post-task hook skipped"

# Store results in memory
FINDINGS_COUNT=$(checkov -d "$SCAN_DIR" --framework terraform --quiet | grep -c "Check:" || echo "0")
npx claude-flow@alpha memory store "swarm/security/last-scan" "{\"date\": \"$(date -Iseconds)\", \"findings\": $FINDINGS_COUNT, \"directory\": \"$SCAN_DIR\"}" 2>/dev/null || echo "Memory storage skipped"

echo ""
echo "================================"
echo "Scan Complete!"
echo "Findings: $FINDINGS_COUNT"
echo "Results: /home/user/servicenow-ai/coordination/sessions/results_json.json"
echo "================================"
