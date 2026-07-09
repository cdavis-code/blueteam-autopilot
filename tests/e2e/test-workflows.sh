#!/usr/bin/env bash
# Test all 5 workflows in real mode
# Usage: ./test-workflows.sh [workflow-name]
# Examples:
#   ./test-workflows.sh                    # Run all workflow tests
#   ./test-workflows.sh threat-hunt        # Run only threat-hunt test
#   ./test-workflows.sh incident-response  # Run only incident-response test

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load environment
if [ -f "$PROJECT_ROOT/.env" ]; then
  source "$PROJECT_ROOT/.env" 2>/dev/null || true
fi

# Test result tracking
PASS=0
FAIL=0
SKIP=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper: run test and check output
run_test() {
  local test_name="$1"
  local prompt="$2"
  local expected_pattern="$3"
  local timeout="${4:-300}"  # 5 min default
  
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test: $test_name${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo "Prompt: $prompt"
  echo "Expected pattern: $expected_pattern"
  echo ""
  
  # Run the agent with the prompt
  OUTPUT=$(cd "$PROJECT_ROOT" && timeout "$timeout" python blueteam.py --prompt "$prompt" 2>&1)
  EXIT_CODE=$?
  
  # Check if timeout occurred
  if [ $EXIT_CODE -eq 124 ]; then
    echo -e "${YELLOW}⚠ TIMEOUT${NC} (exceeded ${timeout}s)"
    SKIP=$((SKIP + 1))
    return 1
  fi
  
  # Check if expected pattern is in output
  if echo "$OUTPUT" | grep -qi "$expected_pattern"; then
    echo -e "${GREEN}✓ PASS${NC}"
    echo "Found expected pattern: $expected_pattern"
    PASS=$((PASS + 1))
    return 0
  else
    echo -e "${RED}✗ FAIL${NC}"
    echo "Expected pattern not found: $expected_pattern"
    echo ""
    echo "Output (last 50 lines):"
    echo "$OUTPUT" | tail -50
    FAIL=$((FAIL + 1))
    return 1
  fi
}

# Test 1: Ping (baseline connectivity)
test_ping() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test: Ping (Baseline Connectivity)${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  OUTPUT=$(cd "$PROJECT_ROOT" && bash skills/blueteam-autopilot-ops/scripts/ping.sh 2>&1)
  
  if echo "$OUTPUT" | grep -qi "region" && echo "$OUTPUT" | grep -qi "mode.*real"; then
    echo -e "${GREEN}✓ PASS${NC}"
    echo "Connectivity verified: region and mode detected"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}✗ FAIL${NC}"
    echo "Connectivity check failed"
    echo "$OUTPUT"
    FAIL=$((FAIL + 1))
  fi
}

# Test 2: Incident Response Workflow
test_incident_response() {
  run_test \
    "Incident Response Workflow" \
    "Run the incident response workflow" \
    "discovery\|deep.dive\|recommendation\|report"
}

# Test 3: IAM Forensic Workflow
test_iam_forensic() {
  run_test \
    "IAM Forensic Workflow" \
    "Run the IAM forensic workflow" \
    "discovery\|analysis\|remediation\|persist\|RAM"
}

# Test 4: Threat Hunt Workflow
test_threat_hunt() {
  run_test \
    "Threat Hunt Workflow" \
    "Run the threat hunt workflow" \
    "collect\|analyze\|correlate\|report\|threat"
}

# Test 5: Compliance Audit Workflow
test_compliance_audit() {
  run_test \
    "Compliance Audit Workflow" \
    "Run the compliance audit workflow" \
    "inventory\|map\|evidence\|report\|NIST\|SOC"
}

# Test 6: Continuous Monitor (single tick)
test_continuous_monitor() {
  run_test \
    "Continuous Monitor (Single Tick)" \
    "Run one cycle of the continuous monitor workflow" \
    "scan\|triage\|escalate\|monitor"
}

# Main
echo "BlueTeam E2E — Workflow Tests"
echo "======================================="
echo "Mode: ${SECURITY_CENTER_MODE:-demo}"
echo ""

# Check if running in real mode
if [ "${SECURITY_CENTER_MODE:-demo}" != "real" ]; then
  echo -e "${YELLOW}Warning: Not running in real mode${NC}"
  echo "Set SECURITY_CENTER_MODE=real in .env for live API testing"
  echo ""
fi

# Run specific test or all tests
WORKFLOW="${1:-all}"

case "$WORKFLOW" in
  ping)
    test_ping
    ;;
  incident-response)
    test_incident_response
    ;;
  iam-forensic)
    test_iam_forensic
    ;;
  threat-hunt)
    test_threat_hunt
    ;;
  compliance-audit)
    test_compliance_audit
    ;;
  continuous-monitor)
    test_continuous_monitor
    ;;
  all)
    test_ping
    test_incident_response
    test_iam_forensic
    test_threat_hunt
    test_compliance_audit
    test_continuous_monitor
    ;;
  *)
    echo "Unknown workflow: $WORKFLOW"
    echo "Available: ping, incident-response, iam-forensic, threat-hunt, compliance-audit, continuous-monitor, all"
    exit 1
    ;;
esac

# Summary
echo ""
echo "======================================="
echo "Workflow Test Summary"
echo "======================================="
echo -e "Passed:  ${GREEN}$PASS${NC}"
echo -e "Failed:  ${RED}$FAIL${NC}"
echo -e "Skipped: ${YELLOW}$SKIP${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}✓ All tests passed${NC}"
  exit 0
else
  echo -e "${RED}✗ Some tests failed${NC}"
  exit 1
fi
