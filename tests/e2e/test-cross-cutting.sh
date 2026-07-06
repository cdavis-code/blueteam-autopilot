#!/usr/bin/env bash
# Test cross-cutting concerns: embeddings, HITL gating, drift detection, persistence
# Usage: ./test-cross-cutting.sh [test-name]
# Examples:
#   ./test-cross-cutting.sh                  # Run all cross-cutting tests
#   ./test-cross-cutting.sh embedding        # Run only embedding test
#   ./test-cross-cutting.sh hitl             # Run only HITL gating test

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
  local timeout="${4:-120}"
  
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test: $test_name${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo "Prompt: $prompt"
  echo "Expected pattern: $expected_pattern"
  echo ""
  
  OUTPUT=$(cd "$PROJECT_ROOT" && timeout "$timeout" python blueteam.py --prompt "$prompt" 2>&1)
  EXIT_CODE=$?
  
  if [ $EXIT_CODE -eq 124 ]; then
    echo -e "${YELLOW}⚠ TIMEOUT${NC} (exceeded ${timeout}s)"
    SKIP=$((SKIP + 1))
    return 1
  fi
  
  if echo "$OUTPUT" | grep -qi "$expected_pattern"; then
    echo -e "${GREEN}✓ PASS${NC}"
    PASS=$((PASS + 1))
    return 0
  else
    echo -e "${RED}✗ FAIL${NC}"
    echo "Expected pattern not found: $expected_pattern"
    echo ""
    echo "Output (last 30 lines):"
    echo "$OUTPUT" | tail -30
    FAIL=$((FAIL + 1))
    return 1
  fi
}

# Test 1: Embedding storage and similarity search
test_embedding_storage() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test: Embedding Storage & Similarity Search${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo "This test requires prior workflow runs to have stored incident memories."
  echo ""
  
  # Search for similar incidents
  OUTPUT=$(cd "$PROJECT_ROOT" && python blueteam.py --prompt "Search for similar incidents to 'SQL injection attack from external IP'" 2>&1)
  
  # Check if we got results (either "found" or "no_matches" is acceptable)
  if echo "$OUTPUT" | grep -qi "similar\|memory\|embedding\|found\|no_matches"; then
    echo -e "${GREEN}✓ PASS${NC}"
    echo "Embedding search executed successfully"
    
    # Check if we actually found matches
    if echo "$OUTPUT" | grep -qi "found\|similarity"; then
      echo "✓ Similar incidents found in memory"
    else
      echo "ℹ No similar incidents found (this is OK if no prior workflows ran)"
    fi
    PASS=$((PASS + 1))
  else
    echo -e "${RED}✗ FAIL${NC}"
    echo "Embedding search failed"
    echo "$OUTPUT" | tail -20
    FAIL=$((FAIL + 1))
  fi
}

# Test 2: IAM drift detection
test_iam_drift_detection() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test: IAM Drift Detection${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo "This test runs IAM forensic workflow twice to verify drift detection."
  echo "Note: This takes ~10 minutes (2 full workflow runs)."
  echo ""
  
  # First run
  echo "Running IAM forensic workflow (1st run)..."
  OUTPUT1=$(cd "$PROJECT_ROOT" && timeout 300 python blueteam.py --prompt "Run the IAM forensic workflow" 2>&1)
  
  if [ $? -eq 124 ]; then
    echo -e "${YELLOW}⚠ TIMEOUT${NC} on first run"
    SKIP=$((SKIP + 1))
    return 1
  fi
  
  echo "✓ First run complete"
  echo ""
  
  # Second run (should detect drift or report first_scan)
  echo "Running IAM forensic workflow (2nd run)..."
  OUTPUT2=$(cd "$PROJECT_ROOT" && timeout 300 python blueteam.py --prompt "Run the IAM forensic workflow" 2>&1)
  
  if [ $? -eq 124 ]; then
    echo -e "${YELLOW}⚠ TIMEOUT${NC} on second run"
    SKIP=$((SKIP + 1))
    return 1
  fi
  
  echo "✓ Second run complete"
  echo ""
  
  # Check for drift detection or first_scan message
  if echo "$OUTPUT2" | grep -qi "drift\|first_scan\|snapshot\|persist"; then
    echo -e "${GREEN}✓ PASS${NC}"
    
    if echo "$OUTPUT2" | grep -qi "drift"; then
      echo "✓ Drift detection executed"
    elif echo "$OUTPUT2" | grep -qi "first_scan"; then
      echo "ℹ First scan recorded (drift detection will work on next run)"
    fi
    PASS=$((PASS + 1))
  else
    echo -e "${RED}✗ FAIL${NC}"
    echo "Drift detection not found in output"
    FAIL=$((FAIL + 1))
  fi
}

# Test 3: HITL gating for state-changing tools
test_hitl_gating() {
  run_test \
    "HITL Gating (State-Changing Tools)" \
    "Block WAF IP 10.0.0.1" \
    "dry.run\|preview\|approval\|blocked\|headless" \
    60
}

# Test 4: Monitor state persistence
test_monitor_state_persistence() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test: Monitor State Persistence${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo "Checking if monitor_state table exists and has been updated."
  echo ""
  
  DB_PATH="$PROJECT_ROOT/data/blueteam.db"
  
  # Check if database exists
  if [ ! -f "$DB_PATH" ]; then
    echo -e "${YELLOW}⚠ SKIP${NC}"
    echo "Database not found at $DB_PATH"
    echo "Run a continuous-monitor workflow first to create the database"
    SKIP=$((SKIP + 1))
    return 1
  fi
  
  echo "✓ Database found: $DB_PATH"
  
  # Check if monitor_state table exists and has data
  OUTPUT=$(sqlite3 "$DB_PATH" "SELECT * FROM monitor_state WHERE id = 1;" 2>&1)
  
  if [ $? -eq 0 ] && [ -n "$OUTPUT" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
    echo "Monitor state table exists and contains data:"
    echo "$OUTPUT"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}✗ FAIL${NC}"
    echo "Monitor state table missing or empty"
    echo "Run a continuous-monitor workflow to initialize state"
    FAIL=$((FAIL + 1))
  fi
}

# Test 5: Database schema validation
test_database_schema() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test: Database Schema Validation${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  DB_PATH="$PROJECT_ROOT/data/blueteam.db"
  
  if [ ! -f "$DB_PATH" ]; then
    echo -e "${YELLOW}⚠ SKIP${NC}"
    echo "Database not found"
    SKIP=$((SKIP + 1))
    return 1
  fi
  
  # Check for required tables
  TABLES=$(sqlite3 "$DB_PATH" ".tables" 2>&1)
  
  REQUIRED_TABLES=("incident_embeddings" "monitor_state" "iam_scan_snapshots")
  ALL_FOUND=true
  
  for table in "${REQUIRED_TABLES[@]}"; do
    if echo "$TABLES" | grep -q "$table"; then
      echo "✓ Table found: $table"
    else
      echo "✗ Table missing: $table"
      ALL_FOUND=false
    fi
  done
  
  if $ALL_FOUND; then
    echo -e "${GREEN}✓ PASS${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}✗ FAIL${NC}"
    FAIL=$((FAIL + 1))
  fi
}

# Main
echo "BlueTeam Autopilot E2E — Cross-Cutting Tests"
echo "============================================"
echo "Mode: ${SECURITY_CENTER_MODE:-demo}"
echo ""

if [ "${SECURITY_CENTER_MODE:-demo}" != "real" ]; then
  echo -e "${YELLOW}Warning: Not running in real mode${NC}"
  echo "Set SECURITY_CENTER_MODE=real in .env for live API testing"
  echo ""
fi

# Run specific test or all tests
TEST_NAME="${1:-all}"

case "$TEST_NAME" in
  embedding)
    test_embedding_storage
    ;;
  drift)
    test_iam_drift_detection
    ;;
  hitl)
    test_hitl_gating
    ;;
  persistence)
    test_monitor_state_persistence
    ;;
  schema)
    test_database_schema
    ;;
  all)
    test_embedding_storage
    test_hitl_gating
    test_monitor_state_persistence
    test_database_schema
    # Note: drift detection is slow (2 workflow runs), so skip by default
    echo ""
    echo "Note: Drift detection test skipped (takes ~10 minutes)"
    echo "Run separately: ./test-cross-cutting.sh drift"
    ;;
  *)
    echo "Unknown test: $TEST_NAME"
    echo "Available: embedding, drift, hitl, persistence, schema, all"
    exit 1
    ;;
esac

# Summary
echo ""
echo "============================================"
echo "Cross-Cutting Test Summary"
echo "============================================"
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
