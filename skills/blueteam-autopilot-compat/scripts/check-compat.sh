#!/usr/bin/env bash
# CLI Compatibility Checker for BlueTeam Autopilot
# Validates that the installed aliyun CLI is compatible with project scripts.
#
# Usage: ./check-compat.sh [--real]
#   --real  Run live API tests (requires credentials and SECURITY_CENTER_MODE=real)
#   Default: Demo mode — command existence checks only, no API calls
#
# Exit codes:
#   0 = All checks passed
#   1 = One or more checks failed
#   2 = CLI not installed or baseline not found

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASELINE_FILE="$(dirname "$SCRIPT_DIR")/references/cli-baseline.json"
MODE="${SECURITY_CENTER_MODE:-demo}"
LIVE_TEST=false

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --real) LIVE_TEST=true; MODE="real" ;;
  esac
done

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Counters
PASS=0
FAIL=0
WARN=0
SKIP=0

echo "╔══════════════════════════════════════════════════════════╗"
echo "║   BlueTeam Autopilot — CLI Compatibility Checker        ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ── Check 1: aliyun CLI installed ──
echo -e "${CYAN}Stage 1: CLI Installation${NC}"
if ! command -v aliyun &>/dev/null; then
  echo -e "  ${RED}✗ aliyun CLI not found${NC}"
  echo "  Install: brew install aliyun-cli (macOS)"
  exit 2
fi
CLI_VERSION=$(aliyun version 2>/dev/null || echo "unknown")
echo -e "  ${GREEN}✓ aliyun CLI installed (version: $CLI_VERSION)${NC}"
echo ""

# ── Check 2: Baseline file ──
echo -e "${CYAN}Stage 2: Baseline File${NC}"
if [ ! -f "$BASELINE_FILE" ]; then
  echo -e "  ${RED}✗ Baseline not found: $BASELINE_FILE${NC}"
  exit 2
fi
BASELINE_VERSION=$(python3 -c "import json; d=json.load(open('$BASELINE_FILE')); print(d['meta'].get('cli_version_tested','unknown'))" 2>/dev/null || echo "unknown")
BASELINE_DATE=$(python3 -c "import json; d=json.load(open('$BASELINE_FILE')); print(d['meta'].get('last_validated','unknown'))" 2>/dev/null || echo "unknown")
BASELINE_COUNT=$(python3 -c "import json; d=json.load(open('$BASELINE_FILE')); print(len(d['commands']))" 2>/dev/null || echo "0")
echo -e "  ${GREEN}✓ Baseline loaded ($BASELINE_COUNT commands)${NC}"
echo "    Tested with CLI version: $BASELINE_VERSION"
echo "    Last validated: $BASELINE_DATE"
if [ "$CLI_VERSION" != "$BASELINE_VERSION" ]; then
  echo -e "  ${YELLOW}⚠ Version mismatch: installed=$CLI_VERSION, baseline=$BASELINE_VERSION${NC}"
  WARN=$((WARN+1))
fi
echo ""

# ── Check 3: Command existence ──
echo -e "${CYAN}Stage 3: Command Existence Checks${NC}"
echo "  Verifying each CLI command is recognized by the installed version..."
echo ""

# Extract unique product+command pairs from baseline
COMMANDS=$(python3 -c "
import json
d = json.load(open('$BASELINE_FILE'))
seen = set()
for cmd in d['commands']:
    key = f\"{cmd['product']} {cmd['command']}\"
    if key not in seen:
        seen.add(key)
        scripts = [c['script'] for c in d['commands'] if c['product'] == cmd['product'] and c['command'] == cmd['command']]
        print(f\"{cmd['product']}|{cmd['command']}|{','.join(scripts)}\")
" 2>/dev/null)

CURRENT_PRODUCT=""
while IFS='|' read -r product command scripts; do
  [ -z "$product" ] && continue

  if [ "$product" != "$CURRENT_PRODUCT" ]; then
    echo -e "  ${CYAN}── $product ──${NC}"
    CURRENT_PRODUCT="$product"
  fi

  # Check if command exists by running --help and checking exit code
  set +e
  aliyun "$product" "$command" --help &>/dev/null
  HELP_EXIT=$?
  set -e

  if [ $HELP_EXIT -ne 0 ]; then
    echo -e "  ${RED}✗ $command${NC} — command not recognized"
    echo -e "    ${RED}Affected: $scripts${NC}"
    FAIL=$((FAIL+1))
  else
    echo -e "  ${GREEN}✓ $command${NC} — recognized"
    PASS=$((PASS+1))
  fi
done <<< "$COMMANDS"

echo ""

# ── Check 4: Parameter validation ──
echo -e "${CYAN}Stage 4: Parameter Checks${NC}"
echo "  Verifying required parameters are accepted by each command..."
echo ""

PARAM_CHECKS=$(python3 -c "
import json
d = json.load(open('$BASELINE_FILE'))
seen = set()
for cmd in d['commands']:
    key = f\"{cmd['product']} {cmd['command']}\"
    if key not in seen:
        seen.add(key)
        params = ' '.join(cmd.get('params', []))
        scripts = [c['script'] for c in d['commands'] if c['product'] == cmd['product'] and c['command'] == cmd['command']]
        print(f\"{cmd['product']}|{cmd['command']}|{params}|{','.join(scripts)}\")
" 2>/dev/null)

CURRENT_PRODUCT=""
while IFS='|' read -r product command params scripts; do
  [ -z "$product" ] && continue

  if [ "$product" != "$CURRENT_PRODUCT" ]; then
    echo -e "  ${CYAN}── $product ──${NC}"
    CURRENT_PRODUCT="$product"
  fi

  if [ -z "$params" ]; then
    echo -e "  ${GREEN}✓ $command${NC} — no required params"
    PASS=$((PASS+1))
    continue
  fi

  # Get help output and check each param
  set +e
  HELP_OUTPUT=$(aliyun "$product" "$command" --help 2>&1)
  set -e
  MISSING_PARAMS=""

  for param in $params; do
    # Skip --region (global flag, always accepted)
    if [ "$param" = "--region" ]; then
      continue
    fi
    # Check if the param name appears in help (with or without --)
    clean_param=$(echo "$param" | sed 's/^--//')
    if ! echo "$HELP_OUTPUT" | grep -qi "$clean_param"; then
      MISSING_PARAMS="$MISSING_PARAMS $param"
    fi
  done

  if [ -n "$MISSING_PARAMS" ]; then
    echo -e "  ${YELLOW}⚠ $command${NC} — params not found in help:$MISSING_PARAMS"
    echo -e "    ${YELLOW}Affected: $scripts${NC}"
    WARN=$((WARN+1))
  else
    echo -e "  ${GREEN}✓ $command${NC} — all params accepted"
    PASS=$((PASS+1))
  fi
done <<< "$PARAM_CHECKS"

echo ""

# ── Stage 5: Live API tests (real mode only) ──
if [ "$LIVE_TEST" = true ] && [ "$MODE" = "real" ]; then
  echo -e "${CYAN}Stage 5: Live API Response Structure Tests${NC}"
  echo "  Running smoke tests against live Alibaba Cloud APIs..."
  echo ""

  # Source region discovery
  source "$SCRIPT_DIR/../../blueteam-autopilot-ops/scripts/_discover-region.sh" 2>/dev/null || true

  # Load .env if available
  if [ -f "$PWD/.env" ]; then
    source "$PWD/.env" 2>/dev/null || true
  elif [ -f "$(dirname "$SCRIPT_DIR")/../../../.env" ]; then
    source "$(dirname "$SCRIPT_DIR")/../../../.env" 2>/dev/null || true
  fi

  # Test a few key commands for response structure
  LIVE_TESTS=(
    "sas|describe-version-config|--region $ALIBABA_REGION|Version"
    "waf-openapi|describe-instance|--region $ALIBABA_REGION|InstanceId"
    "sts|GetCallerIdentity||AccountId"
    "cloud-siem|ListAutomateResponseConfigs|--Version 2022-06-16 --region $ALIBABA_REGION --PageSize 10 --CurrentPage 1|TotalCount"
  )

  for test_entry in "${LIVE_TESTS[@]}"; do
    IFS='|' read -r product command params expected_field <<< "$test_entry"
    echo -e "  ${CYAN}Testing: $product $command${NC}"

    RESULT=$(aliyun "$product" $command $params 2>&1 || true)
    EXIT_CODE=$?

    if echo "$RESULT" | grep -qi "error\|not found\|unknown command"; then
      echo -e "  ${RED}✗ $product $command${NC} — API call failed"
      echo -e "    ${RED}$RESULT${NC}" | head -3
      FAIL=$((FAIL+1))
    elif [ -n "$expected_field" ] && ! echo "$RESULT" | grep -q "$expected_field"; then
      echo -e "  ${RED}✗ $product $command${NC} — missing expected field: $expected_field"
      FAIL=$((FAIL+1))
    else
      echo -e "  ${GREEN}✓ $product $command${NC} — response structure OK"
      PASS=$((PASS+1))
    fi
  done

  echo ""
else
  echo -e "${CYAN}Stage 5: Live API Tests${NC}"
  echo "  Skipped (demo mode). Run with --real or SECURITY_CENTER_MODE=real for live API tests."
  SKIP=$((SKIP+1))
  echo ""
fi

# ── Summary ──
echo "═══════════════════════════════════════════════════════════"
echo "  Compatibility Report"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "  CLI Version:    $CLI_VERSION"
echo "  Baseline:       $BASELINE_VERSION (validated $BASELINE_DATE)"
echo "  Mode:           $MODE"
echo ""
echo -e "  ${GREEN}Passed:  $PASS${NC}"
echo -e "  ${RED}Failed:  $FAIL${NC}"
echo -e "  ${YELLOW}Warnings: $WARN${NC}"
echo -e "  Skipped: $SKIP"
echo ""

if [ $FAIL -gt 0 ]; then
  echo -e "  ${RED}╔═══════════════════════════════════════════════════════╗${NC}"
  echo -e "  ${RED}║  COMPATIBILITY ISSUES DETECTED                       ║${NC}"
  echo -e "  ${RED}║  Some CLI commands may need updating.                ║${NC}"
  echo -e "  ${RED}║  See blueteam-autopilot-compat SKILL.md for          ║${NC}"
  echo -e "  ${RED}║  remediation guidance.                               ║${NC}"
  echo -e "  ${RED}╚═══════════════════════════════════════════════════════╝${NC}"
  exit 1
else
  echo -e "  ${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
  echo -e "  ${GREEN}║  ALL CHECKS PASSED                                   ║${NC}"
  echo -e "  ${GREEN}║  CLI is compatible with BlueTeam Autopilot scripts.  ║${NC}"
  echo -e "  ${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
  exit 0
fi
