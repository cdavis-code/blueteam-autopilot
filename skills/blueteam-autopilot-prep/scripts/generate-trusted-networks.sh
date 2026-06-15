#!/usr/bin/env bash
# Generate trusted-networks.md from Alibaba Cloud VPC/VPN configuration
# Usage: ./generate-trusted-networks.sh
#
# This script queries your Alibaba Cloud environment to discover:
# - VPC CIDR blocks
# - VPN gateway configurations
# - RAM policy trusted CIDRs
#
# Prerequisites:
# - aliyun CLI installed and configured
# - ALIBABA_REGION environment variable set
# - Appropriate RAM permissions (VPC, VPN Gateway)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KNOWLEDGE_DIR="${SCRIPT_DIR}/../../blueteam-autopilot-knowledge"
OUTPUT_FILE="${KNOWLEDGE_DIR}/documents/trusted-networks.md"

# Check prerequisites
if ! command -v aliyun &> /dev/null; then
  echo "Error: aliyun CLI not found"
  echo "Install from: https://github.com/aliyun/aliyun-cli"
  exit 1
fi

if [ -z "${ALIBABA_REGION:-}" ]; then
  echo "Error: ALIBABA_REGION not set"
  echo "Create a .env file or export ALIBABA_REGION=<your-region>"
  exit 1
fi

# Verify knowledge directory exists
if [ ! -d "${KNOWLEDGE_DIR}/documents" ]; then
  echo "Error: Knowledge directory not found at ${KNOWLEDGE_DIR}"
  echo "Ensure blueteam-autopilot-knowledge skill is installed"
  exit 1
fi

echo "Generating trusted-networks.md from Alibaba Cloud configuration..."
echo "Region: ${ALIBABA_REGION}"
echo ""

# Initialize output file
cat > "${OUTPUT_FILE}" << 'HEADER'
# Trusted Networks

> **AUTO-GENERATED** - Do not edit manually. Run `./scripts/generate-trusted-networks.sh` to regenerate.
>
> **Generated:** TIMESTAMP_PLACEHOLDER
> **Region:** REGION_PLACEHOLDER

Corporate VPN and monitoring service IP ranges that must never be blindly blocked.

---

HEADER

# Replace placeholders
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
sed -i.bak "s/TIMESTAMP_PLACEHOLDER/${TIMESTAMP}/" "${OUTPUT_FILE}"
sed -i.bak "s/REGION_PLACEHOLDER/${ALIBABA_REGION}/" "${OUTPUT_FILE}"
rm -f "${OUTPUT_FILE}.bak"

# Fetch VPC CIDR blocks
echo "Fetching VPC configurations..."
VPC_COUNT=0
cat >> "${OUTPUT_FILE}" << 'EOF'
## Corporate VPN

| Network | CIDR | Purpose |
|---------|------|---------|
EOF

if VPCS=$(aliyun vpc DescribeVpcs --region "$ALIBABA_REGION" --output json 2>/dev/null); then
  VPC_COUNT=$(echo "$VPCS" | grep -c '"VpcId"' || echo "0")
  
  if [ "$VPC_COUNT" -gt 0 ]; then
    echo "$VPCS" | grep '"VpcId"' | while read -r line; do
      VPC_ID=$(echo "$line" | grep -o '"VpcId":"[^"]*"' | cut -d'"' -f4)
      CIDR=$(aliyun vpc DescribeVpcAttribute --region "$ALIBABA_REGION" --VpcId "$VPC_ID" --output json 2>/dev/null | grep '"CidrBlock"' | head -1 | cut -d'"' -f4)
      VPC_NAME=$(aliyun vpc DescribeVpcAttribute --region "$ALIBABA_REGION" --VpcId "$VPC_ID" --output json 2>/dev/null | grep '"VpcName"' | head -1 | cut -d'"' -f4)
      
      if [ -n "$CIDR" ]; then
        NAME="${VPC_NAME:-$VPC_ID}"
        echo "| ${NAME} | ${CIDR} | VPC |" >> "${OUTPUT_FILE}"
      fi
    done
  fi
fi

if [ "$VPC_COUNT" -eq 0 ]; then
  echo "| No VPCs found | - | - |" >> "${OUTPUT_FILE}"
  echo "Warning: No VPCs discovered. Check ALIBABA_REGION and RAM permissions." >&2
fi

echo "" >> "${OUTPUT_FILE}"

# Fetch VPN Gateway configurations
echo "Fetching VPN Gateway configurations..."
cat >> "${OUTPUT_FILE}" << 'EOF'
---

## VPN Gateways

| Network | CIDR | Purpose |
|---------|------|---------|
EOF

VPN_COUNT=0
if VPNS=$(aliyun vpc DescribeVpnGateways --region "$ALIBABA_REGION" --output json 2>/dev/null); then
  VPN_COUNT=$(echo "$VPNS" | grep -c '"VpnGatewayId"' || echo "0")
  
  if [ "$VPN_COUNT" -gt 0 ]; then
    echo "$VPNS" | grep '"VpnGatewayId"' | while read -r line; do
      VPN_ID=$(echo "$line" | grep -o '"VpnGatewayId":"[^"]*"' | cut -d'"' -f4)
      # VPN gateways don't have a single CIDR, so we note the gateway
      echo "| ${VPN_ID} | See VPN customer gateway | VPN Gateway |" >> "${OUTPUT_FILE}"
    done
  fi
fi

if [ "$VPN_COUNT" -eq 0 ]; then
  echo "| No VPN gateways found | - | - |" >> "${OUTPUT_FILE}"
fi

echo "" >> "${OUTPUT_FILE}"

# Add static sections
cat >> "${OUTPUT_FILE}" << 'EOF'
---

## Monitoring Services

> Add your monitoring service IP ranges below
> Query from your cloud monitoring configuration or APM settings

| Network | CIDR | Purpose |
|---------|------|---------|
| (Add your monitoring IPs) | - | - |

---

## Rule

**CRITICAL:** Any attack originating from these IPs must be flagged as
**"Potentially Compromised Internal Asset"** — never blindly blocked.

### Escalation Procedure

1. **Do NOT** propose perimeter block (IP ACL)
2. **DO** escalate to security team for investigation
3. **Document** as potential insider threat or compromised asset
4. **Correlate** with other internal security signals

### Rationale

Traffic from trusted networks indicates:
- Compromised corporate device
- Rogue insider activity
- Misconfigured monitoring service
- VPN tunnel abuse

Blocking these IPs would:
- Disrupt legitimate corporate operations
- Mask the actual security incident
- Prevent proper forensic investigation

---

## Compliance Reference

- **SOC 2 CC6.8:** Unauthorized activity triage must distinguish external vs. internal threats
- **NIST CSF DE.AE-2:** Anomalous event analysis must consider source context

---

## Update Procedure

To regenerate this file from cloud configuration:

```bash
./scripts/generate-trusted-networks.sh
```

To manually add/remove trusted networks:

1. Run the generation script (recommended)
2. OR edit the "Monitoring Services" section above
3. Update WAF whitelist in console
4. Notify BlueTeam Autopilot users

EOF

# Add generation metadata
cat >> "${OUTPUT_FILE}" << EOF
**Last Generated:** ${TIMESTAMP}
**Region:** ${ALIBABA_REGION}
**VPCs Discovered:** ${VPC_COUNT}
**VPN Gateways:** ${VPN_COUNT}
EOF

echo ""
echo "✓ Generated ${OUTPUT_FILE}"
echo "  - VPCs discovered: ${VPC_COUNT}"
echo "  - VPN gateways: ${VPN_COUNT}"
echo ""
echo "Review the generated file and add any monitoring service IPs manually."
