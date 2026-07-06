#!/usr/bin/env bash
# Analyze trust relationships across all RAM roles
# Usage: ./analyze-trust-relationships.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$PWD/.env" ]; then
  source "$PWD/.env" 2>/dev/null || true
elif [ -f "$(dirname "$SCRIPT_DIR")/../../../.env" ]; then
  source "$(dirname "$SCRIPT_DIR")/../../../.env" 2>/dev/null || true
fi

# ----- Demo mode -----
if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  FIXTURE_DIR="$(dirname "$SCRIPT_DIR")/../blueteam-autopilot-core/fixtures"
  FIXTURE_FILE="$FIXTURE_DIR/trust_analysis.json"
  if [ -f "$FIXTURE_FILE" ]; then
    cat "$FIXTURE_FILE"
    exit 0
  else
    echo "{\"error\": \"Fixture not found: $FIXTURE_FILE\"}"
    exit 1
  fi
fi
# ----- End demo mode -----

# Real mode: aggregate trust policies from all roles
source "$SCRIPT_DIR/_discover-region.sh"

ROLES=$(aliyun ram list-roles 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
for r in data.get('Roles', {}).get('Role', []):
    print(r['RoleName'])
" 2>/dev/null || echo "")

echo '{"TrustRelationships": ['
FIRST=true
for ROLE in $ROLES; do
  TRUST=$(aliyun ram get-role --RoleName "$ROLE" 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
role = data.get('Role', {})
tp = role.get('AssumeRolePolicyDocument', {})
stmts = tp.get('Statement', [])
for s in stmts:
    principal = s.get('Principal', {})
    if 'Service' in principal:
        print(json.dumps({'RoleName': '$ROLE', 'TrustedEntity': 'Service', 'TrustedPrincipal': principal['Service'][0], 'RiskLevel': 'LOW'}))
    elif 'RAM' in principal:
        ram = principal['RAM'][0]
        risk = 'CRITICAL' if ':root' in ram and not s.get('Condition') else 'HIGH'
        print(json.dumps({'RoleName': '$ROLE', 'TrustedEntity': 'Account', 'TrustedPrincipal': ram, 'RiskLevel': risk}))
" 2>/dev/null || echo "")
  if [ -n "$TRUST" ]; then
    if [ "$FIRST" = true ]; then
      FIRST=false
    else
      echo ","
    fi
    echo "$TRUST"
  fi
done
echo '], "Summary": {"note": "Live analysis from aliyun CLI"}}'
