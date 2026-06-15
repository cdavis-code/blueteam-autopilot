#!/usr/bin/env bash
# Validate BlueTeam Autopilot skills for hardcoded environment-specific values
# Usage: ./validate-configuration.sh
#
# This script scans all skill files for:
# - Hardcoded region names (e.g., ap-southeast-1)
# - Hardcoded IP addresses and CIDR ranges
# - Hardcoded instance IDs
# - Other environment-specific values
#
# Exit codes:
# 0 = No hardcoded values found (or only in example/template sections)
# 1 = Hardcoded values found that need remediation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_ROOT="${SCRIPT_DIR}/../../blueteam-autopilot-knowledge"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "=========================================="
echo "BlueTeam Autopilot Configuration Validator"
echo "=========================================="
echo ""

# Verify knowledge directory exists
if [ ! -d "${SKILLS_ROOT}" ]; then
  echo -e "${RED}Error: Knowledge directory not found at ${SKILLS_ROOT}${NC}"
  echo "Ensure blueteam-autopilot-knowledge skill is installed"
  exit 1
fi

FOUND_ISSUES=0

# Function to check for hardcoded regions
check_regions() {
  echo "Checking for hardcoded regions..."
  
  # Search for common Alibaba Cloud region patterns
  REGIONS=$(grep -r --include="*.md" \
    -n \
    -E '(ap-southeast-[0-9]+|cn-[a-z]+-[0-9]+|us-[a-z]+-[0-9]+|eu-[a-z]+-[0-9]+)' \
    "${SKILLS_ROOT}" 2>/dev/null || true)
  
  if [ -n "$REGIONS" ]; then
    echo -e "${YELLOW}⚠ Found region references:${NC}"
    echo "$REGIONS" | while IFS= read -r line; do
      FILE=$(echo "$line" | cut -d: -f1)
      LINE_NUM=$(echo "$line" | cut -d: -f2)
      CONTENT=$(echo "$line" | cut -d: -f3-)
      
      # Check if this is in an example/template context
      if echo "$CONTENT" | grep -qE '(example|template|{{ALIBABA_REGION}}|ALIBABA_REGION.*environment|get_account_context)'; then
        echo -e "  ${GREEN}✓${NC} ${FILE}:${LINE_NUM} (acceptable - example/template context)"
      else
        echo -e "  ${RED}✗${NC} ${FILE}:${LINE_NUM} (needs remediation)"
        echo "    ${CONTENT}"
        FOUND_ISSUES=1
      fi
    done
  else
    echo -e "${GREEN}✓ No hardcoded regions found${NC}"
  fi
  
  echo ""
}

# Function to check for hardcoded IPs
check_ips() {
  echo "Checking for hardcoded IP addresses..."
  
  # Search for IP addresses (excluding localhost and documentation ranges)
  IPS=$(grep -r --include="*.md" \
    -n \
    -E '\b([0-9]{1,3}\.){3}[0-9]{1,3}(/\d+)?\b' \
    "${SKILLS_ROOT}" 2>/dev/null | grep -v '127\.0\.0\.1' || true)
  
  if [ -n "$IPS" ]; then
    echo -e "${YELLOW}⚠ Found IP address references:${NC}"
    echo "$IPS" | while IFS= read -r line; do
      FILE=$(echo "$line" | cut -d: -f1)
      LINE_NUM=$(echo "$line" | cut -d: -f2)
      CONTENT=$(echo "$line" | cut -d: -f3-)
      
      # Check if this is in an example context or RFC documentation ranges
      if echo "$CONTENT" | grep -qE '(example|EXAMPLE|RFC [0-9]+|{{|trusted-networks\.md|EXAMPLE VALUES|Corporate LAN|Corporate WLAN|Remote office|External health|APM and log)'; then
        echo -e "  ${GREEN}✓${NC} ${FILE}:${LINE_NUM} (acceptable - example/documentation)"
      else
        echo -e "  ${RED}✗${NC} ${FILE}:${LINE_NUM} (needs review)"
        echo "    ${CONTENT}"
        FOUND_ISSUES=1
      fi
    done
  else
    echo -e "${GREEN}✓ No hardcoded IP addresses found${NC}"
  fi
  
  echo ""
}

# Function to check for hardcoded instance IDs
check_instance_ids() {
  echo "Checking for hardcoded instance/resource IDs..."
  
  # Search for Alibaba Cloud resource ID patterns
  IDS=$(grep -r --include="*.md" \
    -n \
    -E '(i-[a-z0-9-]+|sg-[a-z0-9-]+|vpc-[a-z0-9-]+|waf-[a-z0-9-]+|rds-[a-z0-9-]+)' \
    "${SKILLS_ROOT}" 2>/dev/null || true)
  
  if [ -n "$IDS" ]; then
    echo -e "${YELLOW}⚠ Found resource ID references:${NC}"
    echo "$IDS" | while IFS= read -r line; do
      FILE=$(echo "$line" | cut -d: -f1)
      LINE_NUM=$(echo "$line" | cut -d: -f2)
      CONTENT=$(echo "$line" | cut -d: -f3-)
      
      # Check if this is in an example/template context
      if echo "$CONTENT" | grep -qE '(example|Example|EXAMPLE|template|i-prod-|i-demo-)'; then
        echo -e "  ${GREEN}✓${NC} ${FILE}:${LINE_NUM} (acceptable - example)"
      else
        echo -e "  ${RED}✗${NC} ${FILE}:${LINE_NUM} (needs review)"
        echo "    ${CONTENT}"
        FOUND_ISSUES=1
      fi
    done
  else
    echo -e "${GREEN}✓ No hardcoded instance IDs found${NC}"
  fi
  
  echo ""
}

# Function to check for missing example markers
check_example_markers() {
  echo "Checking for missing example markers..."
  
  # Check trusted-networks.md has proper markers
  if [ -f "${SKILLS_ROOT}/documents/trusted-networks.md" ]; then
    if ! grep -q "EXAMPLE" "${SKILLS_ROOT}/documents/trusted-networks.md"; then
      echo -e "${RED}✗${NC} trusted-networks.md missing EXAMPLE markers"
      FOUND_ISSUES=1
    else
      echo -e "${GREEN}✓${NC} trusted-networks.md has example markers"
    fi
  fi
  
  # Check asset-inventory.md has proper markers
  if [ -f "${SKILLS_ROOT}/documents/asset-inventory.md" ]; then
    if ! grep -q "EXAMPLE" "${SKILLS_ROOT}/documents/asset-inventory.md"; then
      echo -e "${RED}✗${NC} asset-inventory.md missing EXAMPLE markers"
      FOUND_ISSUES=1
    else
      echo -e "${GREEN}✓${NC} asset-inventory.md has example markers"
    fi
  fi
  
  echo ""
}

# Function to check for dynamic data instructions
check_dynamic_instructions() {
  echo "Checking for dynamic data instructions..."
  
  # Check if SKILL.md files reference MCP tools for dynamic data
  if grep -q "get_account_context" "${SKILLS_ROOT}/../blueteam-autopilot-core/SKILL.md" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Core SKILL.md references get_account_context"
  else
    echo -e "${YELLOW}⚠${NC} Core SKILL.md should reference get_account_context for dynamic data"
  fi
  
  echo ""
}

# Run all checks
check_regions
check_ips
check_instance_ids
check_example_markers
check_dynamic_instructions

# Summary
echo "=========================================="
if [ "$FOUND_ISSUES" -eq 0 ]; then
  echo -e "${GREEN}✓ All checks passed!${NC}"
  echo "No hardcoded environment-specific values found."
else
  echo -e "${RED}✗ Validation failed${NC}"
  echo "Please remediate the issues listed above."
  echo ""
  echo "Run './scripts/generate-trusted-networks.sh' to auto-generate trusted networks"
  echo "from your Alibaba Cloud configuration."
fi
echo "=========================================="

exit $FOUND_ISSUES
