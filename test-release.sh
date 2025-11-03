#!/bin/bash
# Quick Release Please Test Script

set -e

echo "╔════════════════════════════════════════════════╗"
echo "║    Release Please - Quick Test                ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Verify files exist
echo "📋 Step 1: Verifying configuration files..."
if [ -f ".github/.release-please-config.json" ] && [ -f ".github/.release-please-manifest.json" ] && [ -f ".github/workflows/release-please.yml" ]; then
    echo -e "${GREEN}✅ All configuration files present${NC}"
else
    echo -e "${RED}❌ Missing configuration files${NC}"
    exit 1
fi

# 2. Check current branch
echo ""
echo "🌿 Step 2: Checking git branch..."
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo -e "${YELLOW}⚠️  Warning: Not on main branch (current: $CURRENT_BRANCH)${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 3. Show current versions
echo ""
echo "📊 Step 3: Current versions..."
cat .github/.release-please-manifest.json

# 4. Create test file
echo ""
echo "📝 Step 4: Creating test commit..."
echo "# Release Please Test" > RELEASE_PLEASE_TEST.md
echo "" >> RELEASE_PLEASE_TEST.md
echo "This file tests the Release Please automation." >> RELEASE_PLEASE_TEST.md
echo "Timestamp: $(date)" >> RELEASE_PLEASE_TEST.md
echo "" >> RELEASE_PLEASE_TEST.md
echo "Expected behavior:" >> RELEASE_PLEASE_TEST.md
echo "1. Workflow runs on push to main" >> RELEASE_PLEASE_TEST.md
echo "2. Release PR created with version bump" >> RELEASE_PLEASE_TEST.md
echo "3. CHANGELOG updated" >> RELEASE_PLEASE_TEST.md

git add RELEASE_PLEASE_TEST.md

# 5. Show commit message preview
echo ""
echo "📋 Commit message that will be used:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat << 'EOF'
feat(infra): add Release Please test file

This commit tests the automated release management system.

Features tested:
- Conventional commit format parsing
- Version bumping (0.1.0 -> 0.2.0)
- CHANGELOG generation
- Release PR creation
- Workflow execution

Expected outcome: Release PR should be created automatically.
EOF
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 6. Confirm before proceeding
echo ""
read -p "Proceed with test? This will push to main branch (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Test cancelled."
    git reset HEAD RELEASE_PLEASE_TEST.md
    rm -f RELEASE_PLEASE_TEST.md
    exit 0
fi

# 7. Commit
git commit -m "feat(infra): add Release Please test file

This commit tests the automated release management system.

Features tested:
- Conventional commit format parsing
- Version bumping (0.1.0 -> 0.2.0)
- CHANGELOG generation
- Release PR creation
- Workflow execution

Expected outcome: Release PR should be created automatically."

echo -e "${GREEN}✅ Test commit created${NC}"

# 8. Push to main
echo ""
echo "📤 Step 5: Pushing to main branch..."
git push origin $CURRENT_BRANCH

echo -e "${GREEN}✅ Pushed successfully${NC}"

# 9. Instructions for next steps
echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║          Next Steps                            ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
echo "1. Wait 1-2 minutes for the workflow to complete"
echo ""
echo "2. Check workflow status:"
echo "   ${YELLOW}gh run list --workflow=release-please.yml --limit 1${NC}"
echo ""
echo "3. Watch the workflow:"
echo "   ${YELLOW}gh run watch${NC}"
echo ""
echo "4. Check for Release PR (after workflow completes):"
echo "   ${YELLOW}gh pr list --label 'autorelease: pending'${NC}"
echo ""
echo "5. View the Release PR:"
echo "   ${YELLOW}gh pr view <PR_NUMBER>${NC}"
echo ""
echo "6. Review changes in the PR:"
echo "   ${YELLOW}gh pr diff <PR_NUMBER>${NC}"
echo ""
echo "7. Merge the PR to create release:"
echo "   ${YELLOW}gh pr merge <PR_NUMBER> --squash${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}✅ Test initiated successfully!${NC}"
echo ""
echo "Expected Release PR title: ${YELLOW}chore: release 0.2.0${NC}"
echo "Expected version bump: ${YELLOW}0.1.0 → 0.2.0${NC}"
echo ""
