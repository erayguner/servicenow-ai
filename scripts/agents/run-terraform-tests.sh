#!/bin/bash
# Terraform Testing Script - Runs module tests with agent coordination
# Usage: ./scripts/agents/run-terraform-tests.sh [module]

set -euo pipefail

MODULE="${1:-all}"
SESSION_ID="servicenow-ai-infra-dev"
AGENT_ID="test-validator-001"
TERRAFORM_DIR="/home/user/servicenow-ai/terraform/modules"

echo "================================"
echo "Terraform Module Tests"
echo "================================"
echo "Module: $MODULE"
echo "Agent: $AGENT_ID"
echo "Session: $SESSION_ID"
echo ""

# Pre-task hook
npx claude-flow@alpha hooks pre-task --description "Terraform module tests for $MODULE" 2>/dev/null || echo "Pre-task hook skipped"

# Function to test a single module
test_module() {
  local module_name=$1
  local module_path="$TERRAFORM_DIR/$module_name"

  if [ ! -d "$module_path" ]; then
    echo "Module not found: $module_path"
    return 1
  fi

  echo "Testing module: $module_name"
  cd "$module_path"

  # Initialize
  terraform init -upgrade > /dev/null 2>&1

  # Validate
  echo "  ✓ Validating..."
  terraform validate

  # Format check
  echo "  ✓ Checking format..."
  terraform fmt -check -recursive

  # Run tests if they exist
  if [ -d "tests" ] || ls *.tftest.hcl > /dev/null 2>&1; then
    echo "  ✓ Running tests..."
    terraform test
  else
    echo "  ⚠ No tests found"
  fi

  echo "  ✅ $module_name passed!"
  echo ""
}

# Run tests
if [ "$MODULE" = "all" ]; then
  echo "Testing all modules..."
  for module_dir in "$TERRAFORM_DIR"/*; do
    if [ -d "$module_dir" ]; then
      module_name=$(basename "$module_dir")
      test_module "$module_name" || echo "❌ $module_name failed"
    fi
  done
else
  test_module "$MODULE"
fi

# Post-task hook
npx claude-flow@alpha hooks post-task --task-id "terraform-tests-$(date +%s)" 2>/dev/null || echo "Post-task hook skipped"

# Store results in memory
npx claude-flow@alpha memory store "swarm/tester/last-run" "{\"date\": \"$(date -Iseconds)\", \"module\": \"$MODULE\"}" 2>/dev/null || echo "Memory storage skipped"

echo "================================"
echo "Tests Complete!"
echo "================================"
