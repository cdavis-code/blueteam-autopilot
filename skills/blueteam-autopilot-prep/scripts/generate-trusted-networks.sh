#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# generate-trusted-networks.sh
#
# Auto-generates trusted-networks.md from Alibaba Cloud VPC/VPN configuration.
# Outputs to blueteam-autopilot-knowledge/documents/trusted-networks.md
# =============================================================================

SKILLS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_FILE="${SKILLS_ROOT}/blueteam-autopilot-knowledge/documents/trusted-networks.md"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== BlueTeam Autopilot: Trusted Networks Generator ==="
echo ""

# Verify aliyun CLI is available
if ! command -v aliyun &>/dev/null; then
  echo -e "${RED}Error: aliyun CLI not found${NC}"
  echo "Install: https://www.alibabacloud.com/help/doc-detail/139506.htm"
  exit 1
fi

# Use region from environment or default
ALIBABA_REGION="${ALIBABA_REGION:-ap-southeast-1}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "Region: ${ALIBABA_REGION}"
echo "Output: ${OUTPUT_FILE}"
echo ""

# Ensure output directory exists
mkdir -p "$(dirname "${OUTPUT_FILE}")"

# Create the document header
cat > "${OUTPUT_FILE}" << 'EOF'
# Trusted Networks

> **CRITICAL:** This file is auto-generated. Do NOT edit manually.
> Run `skills/blueteam-autopilot-prep/scripts/generate-trusted-networks.sh` to regenerate.

## Purpose

This file contains the authoritative list of trusted internal networks for
BlueTeam Autopilot incident correlation and response.

## Auto-Discovered Networks

The following networks were discovered from the Alibaba Cloud environment
at generation time.

### VPCs

EOF

# Initialize counters BEFORE discovery
VPC_COUNT=0
VPN_COUNT=0

# Discover VPCs - avoid subshell variable loss by using heredoc
echo "Discovering VPCs in ${ALIBABA_REGION}..."
VPCS_OUTPUT=$(aliyun vpc DescribeVpcs --region "$ALIBABA_REGION" --output json 2>&1) || {
  echo -e "${RED}Failed to query VPCs${NC}"
  echo "Error: ${VPCS_OUTPUT}"
  exit 1
}

# Count VPCs
VPC_COUNT=$(echo "$VPCS_OUTPUT" | grep -c '"VpcId"' || echo "0")

if [ "$VPC_COUNT" -gt 0 ]; then
  echo -e "${GREEN}Found ${VPC_COUNT} VPC(s)${NC}"
  
  # Extract VPC IDs to a temporary variable to avoid subshell
  VPC_IDS=$(echo "$VPCS_OUTPUT" | grep '"VpcId"' | sed 's/.*"VpcId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  
  # Process each VPC ID using here-string (avoids subshell)
  while IFS= read -r VPC_ID; do
    if [ -n "$VPC_ID" ]; then
      VPC_ATTR=$(aliyun vpc DescribeVpcAttribute --region "$ALIBABA_REGION" --VpcId "$VPC_ID" --output json 2>&1) || {
        echo -e "${YELLOW}  Warning: Failed to get attributes for ${VPC_ID}${NC}"
        continue
      }
      
      CIDR=$(echo "$VPC_ATTR" | grep '"CidrBlock"' | head -1 | cut -d'"' -f4)
      VPC_NAME=$(echo "$VPC_ATTR" | grep '"VpcName"' | head -1 | cut -d'"' -f4)
      
      if [ -n "$CIDR" ]; then
        NAME="${VPC_NAME:-$VPC_ID}"
        echo "| ${NAME} | ${CIDR} | VPC |" >> "${OUTPUT_FILE}"
      fi
    fi
  done <<< "$VPC_IDS"
else
  echo -e "${YELLOW}No VPCs found in region ${ALIBABA_REGION}${NC}"
fi

if [ "$VPC_COUNT" -eq 0 ]; then
  echo "| No VPCs found | - | - |" >> "${OUTPUT_FILE}"
  echo -e "${YELLOW}Warning: No VPCs discovered. Check ALIBABA_REGION and RAM permissions.${NC}" >&2
fi

echo "" >> "${OUTPUT_FILE}"

# Add VPN section header
cat >> "${OUTPUT_FILE}" << 'EOF'
### VPN Gateways

| Network | CIDR | Purpose |
|---------|------|---------|
EOF

# Discover VPN Gateways - avoid subshell variable loss
echo "Discovering VPN Gateways..."
VPNS_OUTPUT=$(aliyun vpc DescribeVpnGateways --region "$ALIBABA_REGION" --output json 2>&1) || {
  echo -e "${RED}Failed to query VPN Gateways${NC}"
  echo "Error: ${VPNS_OUTPUT}"
  exit 1
}

# Count VPNs
VPN_COUNT=$(echo "$VPNS_OUTPUT" | grep -c '"VpnGatewayId"' || echo "0")

if [ "$VPN_COUNT" -gt 0 ]; then
  echo -e "${GREEN}Found ${VPN_COUNT} VPN Gateway(s)${NC}"
  
  # Extract VPN Gateway IDs to avoid subshell
  VPN_IDS=$(echo "$VPNS_OUTPUT" | grep '"VpnGatewayId"' | sed 's/.*"VpnGatewayId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  
  # Process each VPN ID using here-string (avoids subshell)
  while IFS= read -r VPN_ID; do
    if [ -n "$VPN_ID" ]; then
      echo "| ${VPN_ID} | See VPN customer gateway | VPN Gateway |" >> "${OUTPUT_FILE}"
    fi
  done <<< "$VPN_IDS"
else
  echo -e "${YELLOW}No VPN Gateways found${NC}"
fi

if [ "$VPN_COUNT" -eq 0 ]; then
  echo "| No VPN gateways found | - | - |" >> "${OUTPUT_FILE}"
fi

echo "" >> "${OUTPUT_FILE}"

# Add static sections
cat >> "${OUTPUT_FILE}" << 'EOF'
## Manual Additions

Add any monitoring service IPs, on-premise networks, or partner networks here:

| Network | CIDR | Purpose |
|---------|------|---------|
| CloudMonitor | 100.100.0.0/16 | Alibaba Cloud monitoring |
| Internal DNS | 100.64.0.0/16 | Alibaba Cloud internal DNS |

## Security Policy

All networks listed in this file are considered **trusted internal networks**
for the purposes of BlueTeam Autopilot incident correlation.

### Incident Correlation Rules

When an attack is detected, BlueTeam Autopilot MUST check the source IP
against this trusted network list:

1. **External Source (not in this file):**
   - Proceed with normal incident response
   - Propose perimeter blocking if warranted

2. **Internal Source (matches this file):**
   - **STOP** — do NOT propose immediate blocking
   - Flag as "Potentially Compromised Internal Asset"
   - Escalate to security team for investigation
   - Correlate with other internal security signals

## Rule

**CRITICAL:** Any attack originating from these IPs must be flagged as
**"Potentially Compromised Internal Asset"** — never blindly blocked.

### Escalation Procedure

1. **Do NOT** propose perimeter block (IP ACL)
2. **DO** escalate to security team for investigation
3. **Document** as potential insider threat or compromised asset
4. **Correlate** with other internal security signals
EOF

# Add generation metadata
cat >> "${OUTPUT_FILE}" << EOF

**Last Generated:** ${TIMESTAMP}
**Region:** ${ALIBABA_REGION}
**VPCs Discovered:** ${VPC_COUNT}
**VPN Gateways:** ${VPN_COUNT}
EOF

echo ""
echo -e "${GREEN}✓ Generated ${OUTPUT_FILE}${NC}"
echo "  - VPCs discovered: ${VPC_COUNT}"
echo "  - VPN gateways: ${VPN_COUNT}"
echo ""
echo "Review the generated file and add any monitoring service IPs manually."
