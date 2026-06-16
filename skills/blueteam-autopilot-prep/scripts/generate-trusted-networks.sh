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
DOMAIN_COUNT=0

# Discover VPCs - avoid subshell variable loss by using heredoc
echo "Discovering VPCs in ${ALIBABA_REGION}..."
VPCS_OUTPUT=$(aliyun vpc DescribeVpcs --region "$ALIBABA_REGION" 2>&1) || {
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
      VPC_ATTR=$(aliyun vpc DescribeVpcAttribute --region "$ALIBABA_REGION" --VpcId "$VPC_ID" 2>&1) || {
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
VPNS_OUTPUT=$(aliyun vpc DescribeVpnGateways --region "$ALIBABA_REGION" 2>&1) || {
  echo -e "${YELLOW}Warning: VPN Gateway query failed (likely Forbidden.RAM — missing vpc:DescribeVpnGateways permission)${NC}"
  echo "Skipping VPN discovery. Add VPN gateways manually to trusted-networks.md if needed."
  VPN_PERMISSION_DENIED=true
}

# Count VPNs (skip if permission denied)
if [ "${VPN_PERMISSION_DENIED:-false}" = "true" ]; then
  VPN_COUNT=0
else
  VPN_COUNT=$(echo "$VPNS_OUTPUT" | grep -c '"VpnGatewayId"' || echo "0")
fi

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

# --- WAF-Protected Domain Discovery ---
echo "Discovering WAF-protected domains..."
PRIMARY_DOMAIN=""
WAF_INSTANCE=$(aliyun waf-openapi DescribeInstance --region "$ALIBABA_REGION" 2>&1) || true
WAF_INSTANCE_ID=$(echo "$WAF_INSTANCE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('InstanceId',''))" 2>/dev/null || echo "")

if [ -n "$WAF_INSTANCE_ID" ]; then
  DOMAINS_OUTPUT=$(aliyun waf-openapi DescribeDomains \
    --region "$ALIBABA_REGION" \
    --InstanceId "$WAF_INSTANCE_ID" 2>&1) || true
  DOMAIN_COUNT=$(echo "$DOMAINS_OUTPUT" | grep -c '"Domain"' || echo "0")

  cat >> "${OUTPUT_FILE}" << 'EOF'
### WAF-Protected Domains

| Domain | Access Mode | Purpose |
|--------|-------------|---------|
EOF

  if [ "$DOMAIN_COUNT" -gt 0 ]; then
    DOMAIN_NAMES=$(echo "$DOMAINS_OUTPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
domains = data.get('Domains', data.get('DomainList', []))
for d in domains:
    name = d.get('Domain', d.get('DomainName', ''))
    mode = d.get('AccessMode', d.get('AccessType', 'CNAME'))
    if name:
        print(f'{name}|{mode}')
" 2>/dev/null || echo "")

    if [ -n "$DOMAIN_NAMES" ]; then
      while IFS='|' read -r DNAME DMODE; do
        if [ -n "$DNAME" ]; then
          echo "| ${DNAME} | ${DMODE} | WAF-protected test domain |" >> "${OUTPUT_FILE}"
        fi
      done <<< "$DOMAIN_NAMES"

      # Store first domain as primary test domain
      PRIMARY_DOMAIN=$(echo "$DOMAIN_NAMES" | head -1 | cut -d'|' -f1)
    fi
  fi

  if [ "$DOMAIN_COUNT" -eq 0 ] || [ -z "$PRIMARY_DOMAIN" ]; then
    echo "| No WAF domains found | - | Add domain in WAF Console |" >> "${OUTPUT_FILE}"
  fi

  echo "" >> "${OUTPUT_FILE}"
  if [ -n "$PRIMARY_DOMAIN" ]; then
    echo "**Primary Test Domain:** ${PRIMARY_DOMAIN}" >> "${OUTPUT_FILE}"
    echo "" >> "${OUTPUT_FILE}"
  fi
else
  cat >> "${OUTPUT_FILE}" << 'EOF'
### WAF-Protected Domains

| Domain | Access Mode | Purpose |
|--------|-------------|---------|
| No WAF instance found | - | Activate WAF 3.0 first |

EOF
fi

echo -e "${GREEN}Found ${DOMAIN_COUNT} WAF-protected domain(s)${NC}"
if [ -n "$PRIMARY_DOMAIN" ]; then
  echo -e "  Primary test domain: ${GREEN}${PRIMARY_DOMAIN}${NC}"
fi

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
**WAF Domains:** ${DOMAIN_COUNT}
EOF

# --- Generate sample-attack-traffic.sh ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ATTACK_SCRIPT="${SCRIPT_DIR}/sample-attack-traffic.sh"

if [ -n "$PRIMARY_DOMAIN" ]; then
  cat > "${ATTACK_SCRIPT}" << SCRIPTEOF
#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# sample-attack-traffic.sh
#
# Auto-generated by generate-trusted-networks.sh — do not edit manually.
# Regenerate: skills/blueteam-autopilot-prep/scripts/generate-trusted-networks.sh
#
# Sends sample WAF attack traffic to: ${PRIMARY_DOMAIN}
# Region: ${ALIBABA_REGION}
# Generated: ${TIMESTAMP}
#
# Prerequisites:
#   - aliyun CLI installed and configured (credentials in .env or shell)
#   - WAF protection mode set to Block (not Observe)
# =============================================================================

TEST_DOMAIN="${PRIMARY_DOMAIN}"
ALIBABA_REGION="${ALIBABA_REGION}"
# Auto-discover account ID via STS if not already set
if [ -z "\${ACCOUNT_ID:-}" ] || [ "\${ACCOUNT_ID}" = "YOUR_ACCOUNT_ID" ]; then
  ACCOUNT_ID=\$(aliyun sts GetCallerIdentity 2>/dev/null \\
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('AccountId',''))" 2>/dev/null || echo "")
  if [ -z "\$ACCOUNT_ID" ]; then
    echo "Error: Could not discover ACCOUNT_ID via 'aliyun sts GetCallerIdentity'."
    echo "       Export it manually: export ACCOUNT_ID=<your-account-id>"
    exit 1
  fi
fi

echo "=== BlueTeam Autopilot: Sample Attack Traffic ==="
echo ""
echo "Target domain: \${TEST_DOMAIN}"
echo "Region: \${ALIBABA_REGION}"
echo ""

echo "--- SQL Injection Probe ---"
HTTP_CODE=\$(curl -s -o /dev/null -w "%{http_code}" -g \
  "http://\${TEST_DOMAIN}/?id=1%27%20OR%20%271%27%3D%271")
echo "HTTP \${HTTP_CODE} (expected: 405 — blocked by WAF)"
echo ""

echo "--- XSS Probe ---"
HTTP_CODE=\$(curl -s -o /dev/null -w "%{http_code}" -g \
  "http://\${TEST_DOMAIN}/search?q=%3Cscript%3Ealert(1)%3C%2Fscript%3E")
echo "HTTP \${HTTP_CODE} (expected: 405 — blocked by WAF)"
echo ""

echo "--- Path Traversal Probe ---"
HTTP_CODE=\$(curl -s -o /dev/null -w "%{http_code}" -g \
  "http://\${TEST_DOMAIN}/download?file=..%2F..%2Fetc%2Fpasswd")
echo "HTTP \${HTTP_CODE} (expected: 405 — blocked by WAF)"
echo ""

echo "--- Normal Traffic (should pass) ---"
HTTP_CODE=\$(curl -s -o /dev/null -w "%{http_code}" -g \
  "http://\${TEST_DOMAIN}/")
echo "HTTP \${HTTP_CODE} (expected: 200 — normal page served)"
echo ""

echo "=== Traffic sent. Waiting 30s for log propagation... ==="
sleep 30

echo ""
echo "=== Verify logs in SLS ==="
FROM_TS=\$(date -u -v-10M +%s 2>/dev/null || date -u -d '10 minutes ago' +%s)
TO_TS=\$(date -u +%s)
aliyun sls GetLogs \\
  --project "wafnew-project-\${ACCOUNT_ID}-\${ALIBABA_REGION}" \\
  --logstore "wafnew-logstore" \\
  --from "\${FROM_TS}" \\
  --to "\${TO_TS}" \\
  --query "matched_host: \${TEST_DOMAIN}-waf | SELECT final_action, final_plugin, final_rule_type LIMIT 5" \\
  --region "\${ALIBABA_REGION}" 2>&1 | head -40
echo ""
echo "Expected: Log entries with final_action: block"
SCRIPTEOF

  chmod +x "${ATTACK_SCRIPT}"
  echo ""
  echo -e "${GREEN}✓ Generated ${ATTACK_SCRIPT}${NC}"
  echo "  Run: ./sample-attack-traffic.sh"
  echo "  No \$TEST_DOMAIN env var needed — domain is hardcoded in the script."
else
  echo ""
  echo -e "${YELLOW}Skipping sample-attack-traffic.sh (no WAF domains discovered)${NC}"
fi

echo ""
echo -e "${GREEN}✓ Generated ${OUTPUT_FILE}${NC}"
echo "  - VPCs discovered: ${VPC_COUNT}"
echo "  - VPN gateways: ${VPN_COUNT}"
echo "  - WAF domains: ${DOMAIN_COUNT}"
echo ""
echo "Review the generated file and add any monitoring service IPs manually."
