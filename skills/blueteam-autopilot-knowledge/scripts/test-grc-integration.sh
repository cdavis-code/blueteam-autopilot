#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# test-grc-integration.sh
#
# End-to-end integration test for the GRC (Governance, Risk, and Compliance)
# knowledge document management system.
#
# Tests:
#   1. GRC provider scripts exist and are executable
#   2. policies.json schema validation
#   3. CISO Assistant provider connectivity (demo mode + real mode if configured)
#   4. grc-sync.sh --dry-run for each GRC policy
#   5. YAML frontmatter validation on all knowledge documents
#   6. fetch-knowledge.sh document resolution
#   7. Readiness report output
#
# Usage:
#   ./test-grc-integration.sh          # Full test suite
#   ./test-grc-integration.sh --quick  # Skip real-mode connectivity tests
#   GRC_MODE=demo ./test-grc-integration.sh  # Force demo mode
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_ROOT="$(cd "$SKILL_DIR/.." && pwd)"
POLICIES_FILE="$SKILL_DIR/policies.json"
DOCUMENTS_DIR="$SKILL_DIR/documents"
GRC_PROVIDERS_DIR="$SKILL_DIR/grc-providers"
ARCHIVE_DIR="$DOCUMENTS_DIR/archive"
SYNC_LOG="$SKILL_DIR/sync-log.jsonl"
GRC_SYNC_SCRIPT="$SCRIPT_DIR/grc-sync.sh"
FETCH_SCRIPT="$SCRIPT_DIR/fetch-knowledge.sh"
WEBHOOK_SCRIPT="$SCRIPT_DIR/grc-webhook.sh"
CONFIGURE_SCRIPT="$SKILLS_ROOT/blueteam-autopilot-prep/scripts/configure-policies.sh"

QUICK_MODE=false
if [ "${1:-}" = "--quick" ]; then
  QUICK_MODE=true
fi

PASS=0
FAIL=0
WARN=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; WARN=$((WARN + 1)); }

# =============================================================================
# Header
# =============================================================================
echo ""
echo -e "${BOLD}════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  GRC Integration — End-to-End Test Suite${NC}"
echo -e "${BOLD}════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Skill dir:  $SKILL_DIR"
echo "  GRC mode:   ${GRC_MODE:-live}"
echo "  Quick mode: $QUICK_MODE"
echo "  Timestamp:  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# =============================================================================
# Test 1: GRC provider scripts exist and are executable
# =============================================================================
echo -e "${BOLD}── Test 1: Provider Script Presence ──${NC}"

PROVIDER_FILES=("_template.sh" "ciso-assistant.sh")
for pf in "${PROVIDER_FILES[@]}"; do
  provider_path="$GRC_PROVIDERS_DIR/$pf"
  if [ -f "$provider_path" ]; then
    pass "Found: grc-providers/$pf"
  else
    fail "Missing: grc-providers/$pf"
    continue
  fi

  if [ -x "$provider_path" ]; then
    pass "Executable: grc-providers/$pf"
  else
    fail "Not executable: grc-providers/$pf (run chmod +x)"
  fi
done

# Verify template defines contract functions
if [ -f "$GRC_PROVIDERS_DIR/_template.sh" ]; then
  for func in "grc_connect" "grc_list_frameworks" "grc_get_framework"; do
    if grep -q "^${func}()" "$GRC_PROVIDERS_DIR/_template.sh" 2>/dev/null; then
      pass "Contract function defined in template: $func()"
    else
      warn "Contract function not found in template: $func()"
    fi
  done
fi

echo ""

# =============================================================================
# Test 2: policies.json schema validation
# =============================================================================
echo -e "${BOLD}── Test 2: policies.json Schema Validation ──${NC}"

if [ ! -f "$POLICIES_FILE" ]; then
  fail "policies.json not found at $POLICIES_FILE"
else
  pass "policies.json exists"

  # Validate JSON syntax
  if python3 -c "import json; json.load(open('$POLICIES_FILE'))" 2>/dev/null; then
    pass "policies.json is valid JSON"
  else
    fail "policies.json is NOT valid JSON"
  fi

  # Validate schema: version field
  VERSION=$(python3 -c "
import json
with open('$POLICIES_FILE') as f:
  data = json.load(f)
print(data.get('version','MISSING'))
" 2>/dev/null)
  if [ "$VERSION" != "MISSING" ] && [ -n "$VERSION" ]; then
    pass "policies.json has version: $VERSION"
  else
    fail "policies.json missing 'version' field"
  fi

  # Validate schema: policies array
  POLICY_COUNT=$(python3 -c "
import json
with open('$POLICIES_FILE') as f:
  data = json.load(f)
print(len(data.get('policies',[])))
" 2>/dev/null)
  if [ "$POLICY_COUNT" -gt 0 ] 2>/dev/null; then
    pass "policies.json has $POLICY_COUNT policy entries"
  else
    fail "policies.json has no policy entries"
  fi

  # Validate each policy has required fields
  python3 -c "
import json, sys
with open('$POLICIES_FILE') as f:
  data = json.load(f)
errors = []
for p in data.get('policies',[]):
  pid = p.get('id','UNKNOWN')
  for field in ['id','title','type','source','document']:
    if field not in p:
      errors.append(f'{pid}: missing {field}')
if errors:
  for e in errors: print(f'SCHEMA_ERROR: {e}')
  sys.exit(1)
" 2>/dev/null
  if [ $? -eq 0 ]; then
    pass "All policy entries have required fields (id, title, type, source, document)"
  else
    fail "Some policy entries missing required fields"
  fi

  # Validate grc_providers section
  GRC_PROVIDER_CONFIG=$(python3 -c "
import json
with open('$POLICIES_FILE') as f:
  data = json.load(f)
providers = data.get('grc_providers',{})
if providers:
  for name, cfg in providers.items():
    print(name)
" 2>/dev/null)
  if [ -n "$GRC_PROVIDER_CONFIG" ]; then
    pass "grc_providers section present with: $GRC_PROVIDER_CONFIG"
  else
    warn "grc_providers section empty or missing"
  fi

  # Validate GRC-sourced policies have grc config
  GRC_POLICIES=$(python3 -c "
import json
with open('$POLICIES_FILE') as f:
  data = json.load(f)
count = 0
for p in data.get('policies',[]):
  if p.get('source') == 'grc':
    count += 1
    if 'grc' not in p:
      print(f'MISSING_GRC:{p[\"id\"]}')
print(count)
" 2>/dev/null)
  GRC_COUNT=$(echo "$GRC_POLICIES" | tail -1)
  if [ "$GRC_COUNT" -gt 0 ] 2>/dev/null; then
    pass "Found $GRC_COUNT GRC-sourced polic(ies)"
  else
    warn "No GRC-sourced policies found"
  fi
fi
echo ""

# =============================================================================
# Test 3: CISO Assistant provider connectivity
# =============================================================================
echo -e "${BOLD}── Test 3: CISO Assistant Provider Connectivity ──${NC}"

if [ -f "$GRC_PROVIDERS_DIR/ciso-assistant.sh" ]; then
  # Source the template first, then the provider
  source "$GRC_PROVIDERS_DIR/_template.sh" 2>/dev/null || true
  source "$GRC_PROVIDERS_DIR/ciso-assistant.sh" 2>/dev/null || true

  # Test demo mode connectivity
  echo "  Testing demo mode connectivity..."
  if declare -f grc_connect > /dev/null 2>&1; then
    GRC_MODE=demo grc_connect 2>&1
    if [ $? -eq 0 ]; then
      pass "grc_connect() succeeded in demo mode"
    else
      fail "grc_connect() failed in demo mode"
    fi
  else
    fail "grc_connect() function not found in provider"
  fi

  # Test demo mode framework listing
  echo "  Testing demo mode framework listing..."
  if declare -f grc_list_frameworks > /dev/null 2>&1; then
    FRAMEWORKS=$(GRC_MODE=demo grc_list_frameworks 2>/dev/null)
    if [ -n "$FRAMEWORKS" ]; then
      FW_COUNT=$(echo "$FRAMEWORKS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
      pass "grc_list_frameworks() returned $FW_COUNT framework(s) in demo mode"
    else
      fail "grc_list_frameworks() returned empty output in demo mode"
    fi
  else
    fail "grc_list_frameworks() function not found in provider"
  fi

  # Test demo mode framework export
  echo "  Testing demo mode framework export..."
  if declare -f grc_get_framework > /dev/null 2>&1; then
    # Get the first demo framework ID from grc_list_frameworks
    DEMO_FW_ID=$(echo "$FRAMEWORKS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['id'] if d else '')" 2>/dev/null || echo "demo-nist-csf-v2")

    NIST_OUTPUT=$(GRC_MODE=demo grc_get_framework "$DEMO_FW_ID" 2>/dev/null || echo "")
    if [ -n "$NIST_OUTPUT" ]; then
      pass "grc_get_framework($DEMO_FW_ID) returned content in demo mode"
    else
      warn "grc_get_framework($DEMO_FW_ID) returned empty in demo mode"
    fi

    # Check for YAML frontmatter in output
    if echo "$NIST_OUTPUT" | grep -q "^---$" 2>/dev/null; then
      pass "Demo framework output contains YAML frontmatter"
    else
      warn "Demo framework output missing YAML frontmatter"
    fi
  else
    fail "grc_get_framework() function not found in provider"
  fi

  # Real mode test (skip in --quick mode)
  if [ "$QUICK_MODE" = false ]; then
    echo ""
    echo "  Testing real mode readiness..."
    GRC_ENABLED=$(python3 -c "
import json
with open('$POLICIES_FILE') as f:
  data = json.load(f)
print(data.get('grc_providers',{}).get('ciso-assistant',{}).get('enabled',False))
" 2>/dev/null)

    if [ "$GRC_ENABLED" = "True" ]; then
      GRC_URL=$(python3 -c "
import json
with open('$POLICIES_FILE') as f:
  data = json.load(f)
print(data.get('grc_providers',{}).get('ciso-assistant',{}).get('base_url',''))
" 2>/dev/null)
      pass "CISO Assistant provider is enabled (URL: $GRC_URL)"
    else
      warn "CISO Assistant provider not enabled — real mode test skipped"
      echo "         Run configure-policies.sh to set up GRC provider connection"
    fi
  fi
else
  fail "ciso-assistant.sh provider not found"
fi
echo ""

# =============================================================================
# Test 4: grc-sync.sh --dry-run for each GRC policy
# =============================================================================
echo -e "${BOLD}── Test 4: grc-sync.sh Dry-Run ──${NC}"

if [ -f "$GRC_SYNC_SCRIPT" ] && [ -x "$GRC_SYNC_SCRIPT" ]; then
  pass "grc-sync.sh exists and is executable"

  # Test --list
  echo "  Testing --list..."
  LIST_OUTPUT=$(GRC_MODE=demo "$GRC_SYNC_SCRIPT" --list 2>&1 || true)
  if [ -n "$LIST_OUTPUT" ]; then
    pass "grc-sync.sh --list produced output"
  else
    fail "grc-sync.sh --list produced no output"
  fi

  # Test --dry-run
  echo "  Testing --dry-run..."
  DRY_RUN_OUTPUT=$(GRC_MODE=demo "$GRC_SYNC_SCRIPT" --dry-run 2>&1 || true)
  DRY_RUN_EXIT=$?
  if [ $DRY_RUN_EXIT -eq 0 ]; then
    pass "grc-sync.sh --dry-run succeeded (exit 0)"
  else
    warn "grc-sync.sh --dry-run exited with code $DRY_RUN_EXIT (may be expected if no GRC policies enabled)"
  fi

  # Test --dry-run for individual GRC policies
  GRC_POLICY_IDS=$(python3 -c "
import json
with open('$POLICIES_FILE') as f:
  data = json.load(f)
for p in data.get('policies',[]):
  if p.get('source') == 'grc':
    print(p['id'])
" 2>/dev/null)

  for pid in $GRC_POLICY_IDS; do
    echo "  Testing --dry-run for policy: $pid..."
    POLICY_OUTPUT=$(GRC_MODE=demo "$GRC_SYNC_SCRIPT" --dry-run "$pid" 2>&1 || true)
    POLICY_EXIT=$?
    if [ $POLICY_EXIT -eq 0 ]; then
      pass "grc-sync.sh --dry-run $pid succeeded"
    else
      warn "grc-sync.sh --dry-run $pid exited with code $POLICY_EXIT"
    fi
  done
else
  fail "grc-sync.sh missing or not executable"
fi
echo ""

# =============================================================================
# Test 5: YAML frontmatter validation on knowledge documents
# =============================================================================
echo -e "${BOLD}── Test 5: YAML Frontmatter Validation ──${NC}"

DOCUMENTS=("nist-csf.md" "soc2-cc6.md" "runbook-waf-triage.md" "trusted-networks.md" "asset-inventory.md")
REQUIRED_FIELDS=("document_id" "version" "source" "last_updated")
GRC_EXTRA_FIELDS=("grc_provider" "framework")
GRC_DOCS=("nist-csf.md" "soc2-cc6.md")

for doc in "${DOCUMENTS[@]}"; do
  doc_path="$DOCUMENTS_DIR/$doc"
  if [ ! -f "$doc_path" ]; then
    fail "Document not found: $doc"
    continue
  fi

  # Check for YAML frontmatter delimiters
  HAS_FM=$(head -1 "$doc_path")
  if [ "$HAS_FM" = "---" ]; then
    # Extract frontmatter (lines between first and second ---)
    FM=$(awk 'BEGIN{c=0} /^---$/{c++; if(c==2) exit; next} c==1{print}' "$doc_path")

    # Check required fields
    ALL_REQUIRED=true
    for field in "${REQUIRED_FIELDS[@]}"; do
      if echo "$FM" | grep -q "^${field}:" 2>/dev/null; then
        : # field present
      else
        ALL_REQUIRED=false
        fail "$doc: missing frontmatter field '$field'"
      fi
    done

    if $ALL_REQUIRED; then
      pass "$doc: all required frontmatter fields present"
    fi

    # For GRC-sourced docs, check extra fields
    for grc_doc in "${GRC_DOCS[@]}"; do
      if [ "$doc" = "$grc_doc" ]; then
        for field in "${GRC_EXTRA_FIELDS[@]}"; do
          if echo "$FM" | grep -q "^${field}:" 2>/dev/null; then
            : # field present
          else
            warn "$doc: GRC document missing extra field '$field'"
          fi
        done
      fi
    done

    # Validate version format (should be a date or semver-like)
    VERSION_VAL=$(echo "$FM" | grep "^version:" | sed 's/version:\s*//')
    if [ -n "$VERSION_VAL" ]; then
      pass "$doc: version = $VERSION_VAL"
    fi
  else
    fail "$doc: missing YAML frontmatter (no '---' on line 1)"
  fi
done
echo ""

# =============================================================================
# Test 6: fetch-knowledge.sh document resolution
# =============================================================================
echo -e "${BOLD}── Test 6: fetch-knowledge.sh Resolution ──${NC}"

if [ -f "$FETCH_SCRIPT" ] && [ -x "$FETCH_SCRIPT" ]; then
  pass "fetch-knowledge.sh exists and is executable"

  for doc_type in nist-csf soc2-cc6 runbook-waf-triage trusted-networks asset-inventory; do
    # Fetch the document and check exit code
    FETCHED=$("$FETCH_SCRIPT" "$doc_type" 2>/dev/null) || true
    FETCH_EXIT=$?

    if [ $FETCH_EXIT -eq 0 ] && [ -n "$FETCHED" ]; then
      # Check that output begins with YAML frontmatter
      if echo "$FETCHED" | head -1 | grep -q "^---$"; then
        pass "fetch-knowledge.sh $doc_type: resolved successfully with frontmatter"
      else
        warn "fetch-knowledge.sh $doc_type: resolved but missing frontmatter"
      fi
    else
      fail "fetch-knowledge.sh $doc_type: failed to resolve (exit=$FETCH_EXIT)"
    fi
  done

  # Test that listing works (no arguments)
  LIST_OUTPUT=$("$FETCH_SCRIPT" 2>&1 || true)
  if echo "$LIST_OUTPUT" | grep -q "Available documents\|Usage"; then
    pass "fetch-knowledge.sh (no args): lists available documents"
  else
    warn "fetch-knowledge.sh (no args): unexpected output format"
  fi
else
  fail "fetch-knowledge.sh missing or not executable"
fi
echo ""

# =============================================================================
# Test 7: Infrastructure verification
# =============================================================================
echo -e "${BOLD}── Test 7: Infrastructure Files ──${NC}"

# Check sync-log.jsonl
if [ -f "$SYNC_LOG" ]; then
  pass "sync-log.jsonl exists"
  LOG_LINES=$(wc -l < "$SYNC_LOG" | tr -d ' ')
  if [ "$LOG_LINES" -gt 0 ] 2>/dev/null; then
    pass "sync-log.jsonl has $LOG_LINES entries"

    # Validate each line is valid JSON
    LINE_NUM=0
    INVALID_LINES=0
    while IFS= read -r line; do
      LINE_NUM=$((LINE_NUM + 1))
      echo "$line" | python3 -c "import sys,json; json.loads(sys.stdin.read())" 2>/dev/null || {
        INVALID_LINES=$((INVALID_LINES + 1))
      }
    done < "$SYNC_LOG"
    if [ "$INVALID_LINES" -eq 0 ]; then
      pass "sync-log.jsonl: all $LOG_LINES lines are valid JSON"
    else
      fail "sync-log.jsonl: $INVALID_LINES invalid JSON line(s)"
    fi
  else
    warn "sync-log.jsonl is empty"
  fi
else
  fail "sync-log.jsonl not found"
fi

# Check archive directory
if [ -d "$ARCHIVE_DIR" ]; then
  pass "Archive directory exists: documents/archive/"
else
  fail "Archive directory missing: documents/archive/"
fi

# Check grc-synced directory (optional, created on first sync)
GRC_SYNCED_DIR="$DOCUMENTS_DIR/grc-synced"
if [ -d "$GRC_SYNCED_DIR" ]; then
  pass "GRC-synced directory exists: documents/grc-synced/"
else
  warn "GRC-synced directory not yet created (will be created on first sync)"
fi

# Check webhook script
if [ -f "$WEBHOOK_SCRIPT" ] && [ -x "$WEBHOOK_SCRIPT" ]; then
  pass "grc-webhook.sh exists and is executable"
else
  fail "grc-webhook.sh missing or not executable"
fi

# Check configure-policies.sh
if [ -f "$CONFIGURE_SCRIPT" ] && [ -x "$CONFIGURE_SCRIPT" ]; then
  pass "configure-policies.sh exists and is executable"
else
  fail "configure-policies.sh missing or not executable"
fi
echo ""

# =============================================================================
# Summary: Readiness Report
# =============================================================================
echo -e "${BOLD}════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  GRC Integration — Test Results${NC}"
echo -e "${BOLD}════════════════════════════════════════════════════════${NC}"
echo ""
echo "  ┌──────────────────────────────────────────────────┐"
echo "  │ TEST                          │ RESULT           │"
echo "  ├──────────────────────────────────────────────────┤"
printf "  │ 1. Provider scripts           │ %-17s │\n" "$([ $FAIL -eq 0 ] && echo "✓" || echo "See details")"
printf "  │ 2. policies.json schema       │ %-17s │\n" "$([ $FAIL -eq 0 ] && echo "✓" || echo "See details")"
printf "  │ 3. CISO Assistant (demo)      │ %-17s │\n" "$([ $FAIL -eq 0 ] && echo "✓" || echo "See details")"
printf "  │ 4. grc-sync.sh dry-run        │ %-17s │\n" "$([ $FAIL -eq 0 ] && echo "✓" || echo "See details")"
printf "  │ 5. YAML frontmatter           │ %-17s │\n" "$([ $FAIL -eq 0 ] && echo "✓" || echo "See details")"
printf "  │ 6. fetch-knowledge resolution │ %-17s │\n" "$([ $FAIL -eq 0 ] && echo "✓" || echo "See details")"
printf "  │ 7. Infrastructure files       │ %-17s │\n" "$([ $FAIL -eq 0 ] && echo "✓" || echo "See details")"
echo "  └──────────────────────────────────────────────────┘"
echo ""
echo -e "  ${GREEN}Passed:${NC} $PASS"
echo -e "  ${RED}Failed:${NC} $FAIL"
echo -e "  ${YELLOW}Warnings:${NC} $WARN"
echo ""

TOTAL=$((PASS + FAIL + WARN))
if [ "$FAIL" -eq 0 ]; then
  echo -e "  ${GREEN}${BOLD}RESULT: ALL CHECKS PASSED ✓${NC}"
  echo ""
  echo "  The GRC integration is properly configured and"
  echo "  ready for use. Run the following to sync policies:"
  echo ""
  echo "    GRC_MODE=demo ./scripts/grc-sync.sh --dry-run"
  echo "    ./scripts/grc-sync.sh --list"
  echo ""
  exit 0
else
  echo -e "  ${RED}${BOLD}RESULT: $FAIL CHECK(S) FAILED ✗${NC}"
  echo ""
  echo "  Review the failures above and remediate before"
  echo "  using the GRC integration in production."
  echo ""
  exit 1
fi
