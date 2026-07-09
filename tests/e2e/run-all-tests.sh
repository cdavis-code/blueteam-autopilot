#!/usr/bin/env bash
# E2E Test Orchestrator — runs all tests in sequence
# Usage: TEST_DOMAIN=ecs.example.com ./run-all-tests.sh
#
# This script:
# 1. Validates prerequisites (real mode, aliyun CLI, TEST_DOMAIN, WAF)
# 2. Delivers sample attacks to generate events
# 3. Waits for SLS log delivery
# 4. Runs all 5 workflow tests
# 5. Runs cross-cutting tests
# 6. Optionally runs daemon test
# 7. Produces a summary report

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load environment
if [ -f "$PROJECT_ROOT/.env" ]; then
  source "$PROJECT_ROOT/.env" 2>/dev/null || true
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parse arguments
SKIP_ATTACKS=false
SKIP_DAEMON=false
for arg in "$@"; do
  case "$arg" in
    --skip-attacks) SKIP_ATTACKS=true ;;
    --skip-daemon) SKIP_DAEMON=true ;;
    --help|-h)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --skip-attacks   Skip attack delivery (use existing events)"
      echo "  --skip-daemon    Skip daemon mode test"
      echo "  --help, -h       Show this help"
      echo ""
      echo "Environment:"
      echo "  TEST_DOMAIN      WAF-protected domain (required for attacks)"
      echo "  SECURITY_CENTER_MODE  Must be 'real' for live testing"
      exit 0
      ;;
  esac
done

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  BlueTeam E2E Test Suite                        ║"
echo "║  Comprehensive validation of all workflows and features   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Track overall results
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0
START_TIME=$(date +%s)

# ═══════════════════════════════════════════════════════════
# PREREQUISITE VALIDATION
# ═══════════════════════════════════════════════════════════

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Phase 0: Prerequisite Validation${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check 1: Real mode
echo "Checking SECURITY_CENTER_MODE..."
if [ "${SECURITY_CENTER_MODE:-demo}" = "real" ]; then
  echo -e "${GREEN}✓ Real mode enabled${NC}"
else
  echo -e "${YELLOW}⚠ Not in real mode (SECURITY_CENTER_MODE=${SECURITY_CENTER_MODE:-demo})${NC}"
  echo "  Set SECURITY_CENTER_MODE=real in .env for live API testing"
  echo ""
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Check 2: aliyun CLI
echo "Checking aliyun CLI..."
if command -v aliyun &>/dev/null; then
  CLI_VERSION=$(aliyun version 2>/dev/null || echo "unknown")
  echo -e "${GREEN}✓ aliyun CLI installed (version: $CLI_VERSION)${NC}"
else
  echo -e "${RED}✗ aliyun CLI not found${NC}"
  echo "  Install: brew install aliyun-cli (macOS)"
  exit 1
fi

# Check 3: Credentials
echo "Checking credentials..."
if aliyun sts GetCallerIdentity &>/dev/null; then
  echo -e "${GREEN}✓ Credentials valid${NC}"
else
  echo -e "${RED}✗ Credentials invalid or not configured${NC}"
  echo "  Run: aliyun configure"
  exit 1
fi

# Check 4: TEST_DOMAIN (optional)
if [ -n "${TEST_DOMAIN:-}" ]; then
  echo -e "${GREEN}✓ TEST_DOMAIN set: $TEST_DOMAIN${NC}"
else
  echo -e "${YELLOW}⚠ TEST_DOMAIN not set — attack delivery will be skipped${NC}"
  SKIP_ATTACKS=true
fi

# Check 5: WAF instance
echo "Checking WAF instance..."
WAF_OUTPUT=$(bash "$PROJECT_ROOT/skills/blueteam-autopilot-ops/scripts/get-waf-instance.sh" 2>&1)
if echo "$WAF_OUTPUT" | grep -qi "instance.*id\|WAF.*instance"; then
  echo -e "${GREEN}✓ WAF instance discovered${NC}"
else
  echo -e "${YELLOW}⚠ WAF instance not found or not accessible${NC}"
  echo "  WAF tests may fail"
fi

echo ""
echo -e "${GREEN}✓ Prerequisites validated${NC}"
echo ""

# ═══════════════════════════════════════════════════════════
# PHASE 1: ATTACK DELIVERY
# ═══════════════════════════════════════════════════════════

if ! $SKIP_ATTACKS; then
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Phase 1: Sample Attack Delivery${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  bash "$SCRIPT_DIR/deliver-attacks.sh" --wait
  
  echo ""
  echo -e "${GREEN}✓ Attack delivery complete${NC}"
  echo ""
else
  echo -e "${YELLOW}Skipping attack delivery (--skip-attacks or TEST_DOMAIN not set)${NC}"
  echo ""
fi

# ═══════════════════════════════════════════════════════════
# PHASE 2: WORKFLOW TESTS
# ═══════════════════════════════════════════════════════════

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Phase 2: Workflow Tests (5 workflows)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

bash "$SCRIPT_DIR/test-workflows.sh" all
WORKFLOW_EXIT=$?

if [ $WORKFLOW_EXIT -eq 0 ]; then
  echo ""
  echo -e "${GREEN}✓ All workflow tests passed${NC}"
else
  echo ""
  echo -e "${YELLOW}⚠ Some workflow tests failed${NC}"
fi

echo ""

# ═══════════════════════════════════════════════════════════
# PHASE 3: CROSS-CUTTING TESTS
# ═══════════════════════════════════════════════════════════

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Phase 3: Cross-Cutting Tests${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

bash "$SCRIPT_DIR/test-cross-cutting.sh" all
CROSS_EXIT=$?

if [ $CROSS_EXIT -eq 0 ]; then
  echo ""
  echo -e "${GREEN}✓ All cross-cutting tests passed${NC}"
else
  echo ""
  echo -e "${YELLOW}⚠ Some cross-cutting tests failed${NC}"
fi

echo ""

# ═══════════════════════════════════════════════════════════
# PHASE 4: DAEMON TEST (optional)
# ═══════════════════════════════════════════════════════════

if ! $SKIP_DAEMON; then
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Phase 4: Daemon Mode Test${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "This test takes ~2 minutes (daemon startup + attack delivery + detection)"
  echo ""
  
  bash "$SCRIPT_DIR/test-daemon.sh"
  DAEMON_EXIT=$?
  
  if [ $DAEMON_EXIT -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Daemon test passed${NC}"
  else
    echo ""
    echo -e "${YELLOW}⚠ Daemon test failed${NC}"
  fi
  
  echo ""
else
  echo -e "${YELLOW}Skipping daemon test (--skip-daemon)${NC}"
  echo ""
fi

# ═══════════════════════════════════════════════════════════
# FINAL SUMMARY
# ═══════════════════════════════════════════════════════════

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  E2E Test Suite — Final Summary                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo "Duration: ${DURATION}s"
echo ""
echo "Test Phases:"
echo "  0. Prerequisites        ✓ Validated"
echo "  1. Attack Delivery      $([ $SKIP_ATTACKS = true ] && echo '⊘ Skipped' || echo '✓ Complete')"
echo "  2. Workflow Tests       $([ $WORKFLOW_EXIT -eq 0 ] && echo -e "${GREEN}✓ Passed${NC}" || echo -e "${RED}✗ Failed${NC}")"
echo "  3. Cross-Cutting Tests  $([ $CROSS_EXIT -eq 0 ] && echo -e "${GREEN}✓ Passed${NC}" || echo -e "${RED}✗ Failed${NC}")"
echo "  4. Daemon Test          $([ $SKIP_DAEMON = true ] && echo '⊘ Skipped' || ([ $DAEMON_EXIT -eq 0 ] && echo -e "${GREEN}✓ Passed${NC}" || echo -e "${RED}✗ Failed${NC}"))"
echo ""

# Overall result
if [ $WORKFLOW_EXIT -eq 0 ] && [ $CROSS_EXIT -eq 0 ] && ([ $SKIP_DAEMON = true ] || [ $DAEMON_EXIT -eq 0 ]); then
  echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║  ✓ ALL TESTS PASSED                                      ║${NC}"
  echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
  exit 0
else
  echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}║  ✗ SOME TESTS FAILED                                     ║${NC}"
  echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
  exit 1
fi
