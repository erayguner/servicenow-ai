#!/bin/bash
# Code Review Script - Runs formatting and linting checks
# Usage: ./scripts/agents/run-code-review.sh [files...]

set -euo pipefail

SESSION_ID="servicenow-ai-infra-dev"
AGENT_ID="code-reviewer-001"
TARGET_FILES="${@:-.}"

echo "================================"
echo "Code Quality Review"
echo "================================"
echo "Target: $TARGET_FILES"
echo "Agent: $AGENT_ID"
echo "Session: $SESSION_ID"
echo ""

# Pre-task hook
npx claude-flow@alpha hooks pre-task --description "Code quality review" 2>/dev/null || echo "Pre-task hook skipped"

ISSUES_FOUND=0

# Terraform formatting
echo "Checking Terraform formatting..."
if terraform fmt -check -recursive -diff "$TARGET_FILES" 2>/dev/null; then
  echo "  ✅ Terraform formatting OK"
else
  echo "  ❌ Terraform formatting issues found"
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# YAML linting
echo ""
echo "Checking YAML files..."
if find "$TARGET_FILES" -name "*.yaml" -o -name "*.yml" | xargs yamllint -c /home/user/servicenow-ai/.yamllint.yaml 2>/dev/null; then
  echo "  ✅ YAML linting OK"
else
  echo "  ❌ YAML linting issues found"
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# Shell script formatting
echo ""
echo "Checking shell scripts..."
if find "$TARGET_FILES" -name "*.sh" | xargs shfmt -d 2>/dev/null; then
  echo "  ✅ Shell formatting OK"
else
  echo "  ❌ Shell formatting issues found"
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# Prettier formatting
echo ""
echo "Checking JSON/Markdown files..."
if prettier --check "$TARGET_FILES/**/*.{json,md}" 2>/dev/null; then
  echo "  ✅ Prettier formatting OK"
else
  echo "  ⚠ Prettier formatting issues (non-blocking)"
fi

# Post-task hook
npx claude-flow@alpha hooks post-task --task-id "code-review-$(date +%s)" 2>/dev/null || echo "Post-task hook skipped"

# Store results
npx claude-flow@alpha memory store "swarm/reviewer/last-review" "{\"date\": \"$(date -Iseconds)\", \"issues\": $ISSUES_FOUND}" 2>/dev/null || echo "Memory storage skipped"

echo ""
echo "================================"
echo "Review Complete!"
echo "Issues Found: $ISSUES_FOUND"
echo "================================"

exit $ISSUES_FOUND
