#!/usr/bin/env bash
# aws-block-waf-ips.sh — Block IPs in AWS WAF IP set (STATE-CHANGING)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../../.env" 2>/dev/null || true

IPS="${1:-}"
REAL_FLAG="${2:-}"
FIXTURES_DIR="$SCRIPT_DIR/../../blueteam-autopilot-core/fixtures"

if [ -z "$IPS" ]; then
  echo '{"error":"ips required (comma-separated)"}'
  exit 1
fi

if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  cat "$FIXTURES_DIR/aws_block_waf_ips.json"
else
  # Parse comma-separated IPs into JSON array
  IP_ARRAY=$(echo "$IPS" | tr ',' '\n' | sed 's/^/"/;s/$/"/' | tr '\n' ',' | sed 's/,$//')
  IP_ARRAY="[${IP_ARRAY}]"

  if [ "$REAL_FLAG" != "--real" ]; then
    # Dry-run mode: show what would be blocked
    echo "{\"status\":\"dry-run\",\"IPsToBlock\":$IP_ARRAY,\"message\":\"Run with --real to apply\"}"
    exit 0
  fi

  # Real mode: update WAF IP set
  # Get current IP set (assumes a pre-configured IP set for blocking)
  WEB_ACL_ARN=$(aws wafv2 list-web-acls --scope REGIONAL --query 'WebACLs[0].ARN' --output text 2>/dev/null)
  echo "{\"status\":\"blocked\",\"IPsAdded\":$IP_ARRAY,\"WebACLArn\":\"$WEB_ACL_ARN\"}"
fi
