#!/bin/bash
# Release Please Setup Validation (no changes made)

echo "╔═══════════════════════════════════════════════════════╗"
echo "║    Release Please - Setup Validation                  ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0

# Test 1: Config file exists
echo -n "1. Checking .release-please-config.json... "
if [ -f ".github/.release-please-config.json" ]; then
    echo -e "${GREEN}✅ PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ FAIL${NC}"
    ((FAIL++))
fi

# Test 2: Manifest file exists
echo -n "2. Checking .release-please-manifest.json... "
if [ -f ".github/.release-please-manifest.json" ]; then
    echo -e "${GREEN}✅ PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ FAIL${NC}"
    ((FAIL++))
fi

# Test 3: Workflow file exists
echo -n "3. Checking .github/workflows/release-please.yml... "
if [ -f ".github/workflows/release-please.yml" ]; then
    echo -e "${GREEN}✅ PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ FAIL${NC}"
    ((FAIL++))
fi

# Test 4: CHANGELOG exists
echo -n "4. Checking CHANGELOG.md... "
if [ -f "CHANGELOG.md" ]; then
    echo -e "${GREEN}✅ PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ FAIL${NC}"
    ((FAIL++))
fi

# Test 5: CONTRIBUTING.md exists
echo -n "5. Checking CONTRIBUTING.md... "
if [ -f "CONTRIBUTING.md" ]; then
    echo -e "${GREEN}✅ PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ FAIL${NC}"
    ((FAIL++))
fi

# Test 6: Config JSON is valid
echo -n "6. Validating config JSON syntax... "
if command -v jq &> /dev/null; then
    if jq empty .github/.release-please-config.json 2>/dev/null; then
        echo -e "${GREEN}✅ PASS${NC}"
        ((PASS++))
    else
        echo -e "${RED}❌ FAIL (invalid JSON)${NC}"
        ((FAIL++))
    fi
else
    echo -e "${YELLOW}⚠️  SKIP (jq not installed)${NC}"
fi

# Test 7: Manifest JSON is valid
echo -n "7. Validating manifest JSON syntax... "
if command -v jq &> /dev/null; then
    if jq empty .github/.release-please-manifest.json 2>/dev/null; then
        echo -e "${GREEN}✅ PASS${NC}"
        ((PASS++))
    else
        echo -e "${RED}❌ FAIL (invalid JSON)${NC}"
        ((FAIL++))
    fi
else
    echo -e "${YELLOW}⚠️  SKIP (jq not installed)${NC}"
fi

# Test 8: Check package configuration
echo -n "8. Checking package configuration... "
if command -v jq &> /dev/null; then
    PACKAGE_COUNT=$(jq '.packages | length' .github/.release-please-config.json 2>/dev/null)
    if [ "$PACKAGE_COUNT" -ge 1 ]; then
        echo -e "${GREEN}✅ PASS ($PACKAGE_COUNT packages)${NC}"
        ((PASS++))
    else
        echo -e "${RED}❌ FAIL (no packages configured)${NC}"
        ((FAIL++))
    fi
else
    echo -e "${YELLOW}⚠️  SKIP (jq not installed)${NC}"
fi

# Test 9: Git repository check
echo -n "9. Checking git repository... "
if git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${GREEN}✅ PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ FAIL (not a git repo)${NC}"
    ((FAIL++))
fi

# Test 10: GitHub CLI installed
echo -n "10. Checking GitHub CLI... "
if command -v gh &> /dev/null; then
    echo -e "${GREEN}✅ PASS${NC}"
    ((PASS++))
else
    echo -e "${YELLOW}⚠️  WARN (gh CLI not installed)${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Display configuration details
echo -e "${BLUE}📦 Package Configuration:${NC}"
echo ""
if command -v jq &> /dev/null; then
    jq -r '.packages | to_entries[] | "  • \(.key): \(.value."package-name" // "unnamed") (type: \(.value."release-type"))"' .github/.release-please-config.json 2>/dev/null
fi

echo ""
echo -e "${BLUE}📋 Current Versions:${NC}"
echo ""
if command -v jq &> /dev/null; then
    jq -r 'to_entries[] | "  • \(.key): v\(.value)"' .github/.release-please-manifest.json 2>/dev/null
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Summary
echo -e "${BLUE}📊 Validation Summary:${NC}"
echo ""
echo -e "  Passed: ${GREEN}$PASS tests${NC}"
echo -e "  Failed: ${RED}$FAIL tests${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✅ Setup is valid and ready to use!${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "${BLUE}🚀 Next Steps:${NC}"
    echo ""
    echo "To test Release Please, run:"
    echo -e "  ${YELLOW}./test-release.sh${NC}"
    echo ""
    echo "Or manually test with:"
    echo -e "  ${YELLOW}git commit -m 'feat(infra): test release'${NC}"
    echo -e "  ${YELLOW}git push origin main${NC}"
    echo -e "  ${YELLOW}gh pr list --label 'autorelease: pending'${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Setup has issues that need to be fixed${NC}"
    exit 1
fi
