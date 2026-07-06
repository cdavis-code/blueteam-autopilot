#!/usr/bin/env bash
# aws-list-waf-events.sh — List AWS WAF blocked requests
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../../.env" 2>/dev/null || true

TIME_RANGE="${1:-lastHour}"
FIXTURES_DIR="$SCRIPT_DIR/../../blueteam-autopilot-core/fixtures"

if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  cat "$FIXTURES_DIR/aws_list_waf_events.json"
else
  # Get WebACL ID first
  WEB_ACL=$(aws wafv2 list-web-acls --scope REGIONAL --query 'WebACLs[0].ARN' --output text 2>/dev/null)
  if [ -z "$WEB_ACL" ] || [ "$WEB_ACL" = "None" ]; then
    echo '{"SampledRequests":[],"message":"No WAF WebACL found"}'
    exit 0
  fi
  aws wafv2 get-sampled-requests --web-acl-arn "$WEB_ACL" --rule-metric-name "ALL" \
    --scope REGIONAL --max-items 10 --output json 2>/dev/null || echo '{"SampledRequests":[]}'
fi
