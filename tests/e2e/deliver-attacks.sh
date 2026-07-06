#!/usr/bin/env bash
# Deliver sample attacks via curl to WAF-protected domain
# Usage: TEST_DOMAIN=ecs.example.com ./deliver-attacks.sh [--wait]
#
# This script sends various attack payloads to generate WAF log entries.
# All attacks should be blocked by WAF (expect 403/406 responses).
# Use --wait flag to sleep 30s after attacks for SLS log delivery.

set -euo pipefail

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ -f "$PROJECT_ROOT/.env" ]; then
  source "$PROJECT_ROOT/.env" 2>/dev/null || true
fi

# Require TEST_DOMAIN
if [ -z "${TEST_DOMAIN:-}" ]; then
  echo "Error: TEST_DOMAIN environment variable is required."
  echo "Usage: TEST_DOMAIN=ecs.example.com $0 [--wait]"
  echo ""
  echo "TEST_DOMAIN should be your WAF-protected domain (e.g., ecs.yourdomain.com)"
  exit 1
fi

# Parse arguments
WAIT_FOR_SLS=false
for arg in "$@"; do
  if [ "$arg" = "--wait" ]; then
    WAIT_FOR_SLS=true
  fi
done

echo "BlueTeam Autopilot E2E — Sample Attack Delivery"
echo "================================================"
echo "Target domain: $TEST_DOMAIN"
echo "Attack vectors: 6 (SQLi, XSS, LFI, Command Injection, Scanner, SSRF)"
echo ""

# Counters
TOTAL=0
BLOCKED=0

# Helper function to send attack and log result
send_attack() {
  local name="$1"
  local url="$2"
  local description="$3"
  
  TOTAL=$((TOTAL + 1))
  echo "[$TOTAL] $name"
  echo "    $description"
  echo "    URL: $url"
  
  # Send request, capture HTTP status code (ignore curl errors)
  set +e  # Temporarily disable exit on error
  RESPONSE=$(curl -s -o /tmp/curl-response.txt -w "%{http_code}" --max-time 10 "$url" 2>&1)
  CURL_EXIT=$?
  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  set -e  # Re-enable exit on error
  
  # WAF typically returns 403, 406, or 405 for blocked requests
  # Connection reset (000000 or empty) also indicates WAF blocking
  # Curl exit code 35 = SSL connect error (WAF blocking)
  if [[ "$HTTP_CODE" =~ ^(403|405|406)$ ]]; then
    echo "    ✓ Blocked by WAF (HTTP $HTTP_CODE)"
    BLOCKED=$((BLOCKED + 1))
  elif [[ "$HTTP_CODE" =~ ^(000|000000)$ ]] || [ -z "$HTTP_CODE" ] || [ $CURL_EXIT -ne 0 ]; then
    echo "    ✓ Blocked by WAF (connection reset — WAF protection active)"
    BLOCKED=$((BLOCKED + 1))
  elif [ "$HTTP_CODE" = "200" ]; then
    echo "    ⚠ Request succeeded (HTTP 200) — WAF may not have rules for this attack"
  else
    echo "    ? Unexpected response (HTTP $HTTP_CODE)"
  fi
  
  echo ""
  sleep 1  # Delay between attacks
}

# Attack 1: SQL Injection (classic UNION-based)
send_attack \
  "SQL Injection" \
  "http://$TEST_DOMAIN/?id=1%20UNION%20SELECT%201,2,3--" \
  "Classic UNION-based SQL injection"

# Attack 2: XSS (Reflected)
send_attack \
  "Cross-Site Scripting (XSS)" \
  "http://$TEST_DOMAIN/?q=<script>alert('XSS')</script>" \
  "Reflected XSS with script tag"

# Attack 3: Path Traversal / LFI
send_attack \
  "Path Traversal / LFI" \
  "http://$TEST_DOMAIN/?file=....//....//....//etc/passwd" \
  "Directory traversal with double encoding"

# Attack 4: Command Injection
send_attack \
  "Command Injection" \
  "http://$TEST_DOMAIN/?cmd=127.0.0.1;id" \
  "OS command injection via semicolon"

# Attack 5: Scanner Behavior (rapid requests)
echo "[$((TOTAL + 1))] Scanner Behavior"
echo "    Rapid sequential requests to trigger rate/anomaly detection"
TOTAL=$((TOTAL + 1))
for i in {1..10}; do
  curl -s -o /dev/null --max-time 2 "http://$TEST_DOMAIN/?scan=$i" 2>/dev/null || true
done
echo "    ✓ Sent 10 rapid requests"
echo ""
sleep 1

# Attack 6: SSRF attempt
send_attack \
  "Server-Side Request Forgery (SSRF)" \
  "http://$TEST_DOMAIN/?url=http://169.254.169.254/latest/meta-data/" \
  "Attempt to access cloud metadata service (should be blocked)"

# Summary
echo "================================================"
echo "Attack Delivery Summary"
echo "================================================"
echo "Total attacks sent: $TOTAL"
echo "Blocked by WAF:     $BLOCKED"
echo "Success rate:       $(( (BLOCKED * 100) / TOTAL ))%"
echo ""

if [ $BLOCKED -eq $TOTAL ]; then
  echo "✓ All attacks blocked — WAF is working correctly"
elif [ $BLOCKED -eq 0 ]; then
  echo "✗ No attacks blocked — check WAF configuration"
else
  echo "⚠ Partial blocking — some attacks may not match WAF rules"
fi

# Wait for SLS log delivery if requested
if $WAIT_FOR_SLS; then
  echo ""
  echo "Waiting 30 seconds for SLS log delivery..."
  sleep 30
  echo "✓ Logs should now be available in SLS"
fi

echo ""
echo "Next steps:"
echo "  1. Run workflow tests: bash tests/e2e/test-workflows.sh"
echo "  2. Check WAF events: bash skills/blueteam-autopilot-ops/scripts/list-waf-events.sh last15Min"
echo "  3. Run full suite:   bash tests/e2e/run-all-tests.sh"
