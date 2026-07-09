#!/usr/bin/env bash
# Block IPs in WAF via IP blacklist defense rule
# Usage: ./block-waf-ips.sh <ip1> [ip2] [ip3] ... [--dry-run]
# Example: ./block-waf-ips.sh 1.2.3.4 5.6.7.8
# Example: ./block-waf-ips.sh 1.2.3.4 --dry-run

set -euo pipefail

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$PWD/.env" ]; then
  source "$PWD/.env" 2>/dev/null || true
elif [ -f "${BLUETEAM_PROJECT_ROOT:-$(dirname "$SCRIPT_DIR")/..}/.env" ]; then
  source "${BLUETEAM_PROJECT_ROOT:-$(dirname "$SCRIPT_DIR")/..}/.env" 2>/dev/null || true
fi

# ----- Demo mode: simulated response -----
if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  echo '{"status": "ok", "mode": "demo", "message": "WAF IP block simulated (demo mode). No API calls made.", "ips_blocked": []}'
  exit 0
fi
# ----- End demo mode -----

source "$SCRIPT_DIR/_discover-region.sh"

log() { if [ "${AGENT_MODE:-}" != "1" ]; then echo "$@"; fi; }

# Parse arguments
IPS=()
DRY_RUN=false
for arg in "$@"; do
  if [ "$arg" = "--dry-run" ]; then
    DRY_RUN=true
  else
    IPS+=("$arg")
  fi
done

if [ ${#IPS[@]} -eq 0 ]; then
  echo "Usage: $0 <ip1> [ip2] ... [--dry-run]"
  echo "Example: $0 1.2.3.4 5.6.7.8"
  echo "Example: $0 1.2.3.4 --dry-run"
  exit 1
fi

log "Blocking ${#IPS[@]} IP(s) in WAF..."
log "Region: $ALIBABA_REGION"
log "IPs: ${IPS[*]}"
log "Mode: $(if $DRY_RUN; then echo 'dry-run'; else echo 'live'; fi)"
log "---"

# Auto-discover WAF instance ID
WAF_INSTANCE_ID="${WAF_INSTANCE_ID:-}"
if [ -z "$WAF_INSTANCE_ID" ]; then
  WAF_INSTANCE_ID=$(aliyun waf-openapi describe-instance \
    --region "$ALIBABA_REGION" 2>/dev/null | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get("InstanceId", d.get("Data", {}).get("InstanceId", "")))
except:
    print("")
' 2>/dev/null)

  if [ -z "$WAF_INSTANCE_ID" ]; then
    echo '{"error": "Could not discover WAF instance ID. Set WAF_INSTANCE_ID or run ./get-waf-instance.sh first."}'
    exit 1
  fi
fi

# Discover first template ID
TEMPLATE_ID=$(aliyun waf-openapi describe-defense-templates \
  --region "$ALIBABA_REGION" \
  --instance-id "$WAF_INSTANCE_ID" \
  --page-number 1 \
  --page-size 1 \
  2>/dev/null | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    templates = d.get("Templates", [])
    print(templates[0]["TemplateId"] if templates else "")
except:
    print("")
' 2>/dev/null)

if [ -z "$TEMPLATE_ID" ]; then
  echo '{"error": "Could not discover WAF template ID. Ensure WAF has a protection template."}'
  exit 1
fi

# Build IP address JSON array
IP_JSON=$(printf '%s\n' "${IPS[@]}" | python3 -c '
import sys, json
ips = [line.strip() for line in sys.stdin if line.strip()]
print(json.dumps(ips))
')

# Build rule name with timestamp
RULE_NAME="autopilot-block-$(date -u +%Y%m%d%H%M%S)"

# Build the rules JSON
RULES_JSON=$(python3 -c "
import json
rule = {
    'name': '$RULE_NAME',
    'remoteAddr': $IP_JSON,
    'action': 'block',
    'status': 1
}
print(json.dumps(json.dumps([rule])))
")

if $DRY_RUN; then
  python3 -c "
import json
result = {
    'status': 'dry-run',
    'mode': 'dry-run',
    'message': 'No API call made. Below is what would be executed.',
    'waf_instance_id': '$WAF_INSTANCE_ID',
    'template_id': '$TEMPLATE_ID',
    'rule_name': '$RULE_NAME',
    'ips_to_block': $IP_JSON,
    'defense_scene': 'ip_blacklist',
    'action': 'block',
    'command': 'aliyun waf-openapi create-defense-rule --region $ALIBABA_REGION --instance-id $WAF_INSTANCE_ID --template-id $TEMPLATE_ID --defense-scene ip_blacklist --rules ...'
}
print(json.dumps(result, indent=2))
"
  exit 0
fi

# Execute the IP block
RAW_OUTPUT=$(aliyun waf-openapi create-defense-rule \
  --region "$ALIBABA_REGION" \
  --instance-id "$WAF_INSTANCE_ID" \
  --template-id "$TEMPLATE_ID" \
  --defense-scene ip_blacklist \
  --rules "$RULES_JSON" \
  2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  python3 -c "
import json
result = {
    'status': 'error',
    'error': '''$RAW_OUTPUT''',
    'exit_code': $EXIT_CODE,
    'ips_attempted': $IP_JSON
}
print(json.dumps(result, indent=2))
"
  exit $EXIT_CODE
fi

# Parse success response
python3 -c "
import json
result = {
    'status': 'ok',
    'mode': 'live',
    'message': 'IP blacklist rule created successfully.',
    'waf_instance_id': '$WAF_INSTANCE_ID',
    'template_id': '$TEMPLATE_ID',
    'rule_name': '$RULE_NAME',
    'defense_scene': 'ip_blacklist',
    'ips_blocked': $IP_JSON,
    'action': 'block'
}
print(json.dumps(result, indent=2))
"
