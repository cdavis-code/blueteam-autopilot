# BlueTeam Autopilot — End-to-End Testing Guide

Comprehensive end-to-end testing regime for validating all 5 workflows against live Alibaba Cloud APIs in real mode.

---

## Overview

The E2E test suite validates:
- **5 specialist workflows**: incident-response, iam-forensic, threat-hunt, compliance-audit, continuous-monitor
- **Sample attack delivery**: curl-based attacks through WAF to generate detectable events
- **Cross-cutting concerns**: vector embeddings, HITL gating, drift detection, state persistence
- **Autonomous SOC daemon**: continuous monitoring with attack detection

All tests run in `SECURITY_CENTER_MODE=real` with live Alibaba Cloud APIs.

---

## Prerequisites

### Required

1. **Real mode enabled**
   ```bash
   # .env
   SECURITY_CENTER_MODE=real
   DASHSCOPE_API_KEY="sk-..."
   ```

2. **Alibaba Cloud CLI configured**
   ```bash
   aliyun configure
   # Provide AccessKey ID, Secret, and region
   ```

3. **RAM permissions**
   - `AliyunYundunSASReadOnlyAccess` — Security Center
   - `AliyunYundunWAFv3FullAccess` — WAF 3.0
   - `AliyunLogFullAccess` — SLS log queries
   - `AliyunVPCReadOnlyAccess` — VPC discovery

4. **Security Center Enterprise (4) or Ultimate (5)** for Agentic SOC events
   - Basic/Advanced editions fall back to WAF-only events

5. **WAF 3.0 instance** with at least one protected domain

### Optional (for full test coverage)

6. **TEST_DOMAIN environment variable** — your WAF-protected domain
   ```bash
   export TEST_DOMAIN="ecs.yourdomain.com"
   ```
   Required for attack delivery tests. Without it, attack delivery is skipped.

---

## Quick Start

### Run the full test suite

```bash
# Set your WAF-protected domain
export TEST_DOMAIN="ecs.yourdomain.com"

# Run all tests (takes ~15-20 minutes)
bash tests/e2e/run-all-tests.sh
```

### Run with options

```bash
# Skip attack delivery (use existing events)
bash tests/e2e/run-all-tests.sh --skip-attacks

# Skip daemon test (saves ~2 minutes)
bash tests/e2e/run-all-tests.sh --skip-daemon

# Skip both
bash tests/e2e/run-all-tests.sh --skip-attacks --skip-daemon
```

---

## Test Structure

### 1. Sample Attack Delivery

**Script:** `tests/e2e/deliver-attacks.sh`

Sends 6 attack vectors via curl to your WAF-protected domain:
- SQL Injection
- Cross-Site Scripting (XSS)
- Path Traversal / LFI
- Command Injection
- Scanner Behavior (rapid requests)
- Server-Side Request Forgery (SSRF)

All attacks should be **blocked by WAF** (expect 403/406 responses). The attacks generate WAF log entries that downstream workflows can detect.

**Usage:**
```bash
# Deliver attacks and wait for SLS log delivery
TEST_DOMAIN=ecs.example.com bash tests/e2e/deliver-attacks.sh --wait

# Deliver attacks without waiting
TEST_DOMAIN=ecs.example.com bash tests/e2e/deliver-attacks.sh
```

**Expected output:**
```
[1] SQL Injection
    Classic SQL injection in query parameter
    URL: https://ecs.example.com/search?q=1' OR '1'='1'--
    ✓ Blocked by WAF (HTTP 403)

...

Attack Delivery Summary
================================================
Total attacks sent: 6
Blocked by WAF:     6
Success rate:       100%

✓ All attacks blocked — WAF is working correctly
```

---

### 2. Workflow Tests

**Script:** `tests/e2e/test-workflows.sh`

Validates each of the 5 workflows executes correctly:

| Workflow | Phases | HITL Gating | Duration |
|----------|--------|-------------|----------|
| **incident-response** | 5 (discovery → deep_dive → recommendation → action → report) | Yes (action phase) | ~3-5 min |
| **iam-forensic** | 4 (discovery → analysis → remediation → persist) | Yes (remediation phase) | ~2-4 min |
| **threat-hunt** | 4 (collect → analyze → correlate → report) | No | ~2-3 min |
| **compliance-audit** | 4 (inventory → map → evidence → report) | No | ~2-3 min |
| **continuous-monitor** | 3 (scan → triage → escalate) | No | ~1-2 min |

**Usage:**
```bash
# Run all workflow tests
bash tests/e2e/test-workflows.sh

# Run specific workflow
bash tests/e2e/test-workflows.sh threat-hunt
bash tests/e2e/test-workflows.sh incident-response
bash tests/e2e/test-workflows.sh iam-forensic
bash tests/e2e/test-workflows.sh compliance-audit
bash tests/e2e/test-workflows.sh continuous-monitor

# Run baseline connectivity test only
bash tests/e2e/test-workflows.sh ping
```

**Expected behavior:**
- Each workflow runs via `python blueteam.py --prompt`
- Output is checked for expected keywords/phrases
- HITL-gated tools are auto-rejected in headless mode (no interactive approval)
- Tests report PASS/FAIL based on output pattern matching

---

### 3. Cross-Cutting Tests

**Script:** `tests/e2e/test-cross-cutting.sh`

Validates capabilities spanning multiple workflows:

| Test | Description | Duration |
|------|-------------|----------|
| **embedding** | Verify vector embeddings stored and searchable | ~30s |
| **hitl** | Verify state-changing tools are gated in headless mode | ~1 min |
| **persistence** | Verify monitor_state table exists and updated | ~10s |
| **schema** | Validate database schema (all required tables) | ~10s |
| **drift** | IAM drift detection (runs iam-forensic twice) | ~10 min |

**Usage:**
```bash
# Run all cross-cutting tests (except drift)
bash tests/e2e/test-cross-cutting.sh

# Run specific test
bash tests/e2e/test-cross-cutting.sh embedding
bash tests/e2e/test-cross-cutting.sh hitl
bash tests/e2e/test-cross-cutting.sh persistence
bash tests/e2e/test-cross-cutting.sh schema

# Run drift detection (slow — 2 full iam-forensic runs)
bash tests/e2e/test-cross-cutting.sh drift
```

**Notes:**
- Embedding test requires prior workflow runs to have stored incident memories
- Drift detection test is slow (~10 min) and skipped by default in `all` mode
- HITL gating test verifies headless mode auto-rejects state-changing tools

---

### 4. Daemon Mode Test

**Script:** `tests/e2e/test-daemon.sh`

Validates the autonomous SOC daemon:
1. Starts daemon with 15-second interval
2. Waits for first tick (baseline scan)
3. Delivers attacks via `deliver-attacks.sh`
4. Waits for second tick (should detect new attacks)
5. Verifies monitor_state persisted to database
6. Tests graceful shutdown on SIGTERM

**Usage:**
```bash
# Full daemon test (~2 minutes)
TEST_DOMAIN=ecs.example.com bash tests/e2e/test-daemon.sh

# Without attack delivery (TEST_DOMAIN not set)
bash tests/e2e/test-daemon.sh
```

**Expected behavior:**
- Daemon starts and completes first tick ("all clear" or events found)
- After attacks delivered, second tick should show escalations
- Database `monitor_state` table updated with tick count and escalation count
- Daemon exits gracefully on SIGTERM

---

## Test Execution Flow

The `run-all-tests.sh` orchestrator executes tests in this order:

```
Phase 0: Prerequisite Validation
  ✓ Check SECURITY_CENTER_MODE=real
  ✓ Check aliyun CLI installed
  ✓ Check credentials valid
  ✓ Check TEST_DOMAIN set (optional)
  ✓ Check WAF instance discovered

Phase 1: Sample Attack Delivery
  ✓ Send 6 attack vectors via curl
  ✓ Wait 30s for SLS log delivery

Phase 2: Workflow Tests (5 workflows)
  ✓ ping (baseline connectivity)
  ✓ incident-response (5 phases)
  ✓ iam-forensic (4 phases)
  ✓ threat-hunt (4 phases)
  ✓ compliance-audit (4 phases)
  ✓ continuous-monitor (3 phases)

Phase 3: Cross-Cutting Tests
  ✓ embedding storage & search
  ✓ HITL gating
  ✓ monitor state persistence
  ✓ database schema validation

Phase 4: Daemon Mode Test
  ✓ Start daemon
  ✓ First tick (baseline)
  ✓ Deliver attacks
  ✓ Second tick (detection)
  ✓ Graceful shutdown
```

**Total duration:** ~15-20 minutes (with attacks and daemon)

---

## Safety Considerations

### Read-Only Tests

These tests are **completely safe** — no state changes:
- All workflow tests (except HITL-gated phases)
- Cross-cutting tests (embedding, persistence, schema)
- Daemon test (monitoring only)

### HITL-Gated Tests

These tests trigger state-changing tools but are **auto-rejected in headless mode**:
- `incident-response` workflow — action phase (WAF IP blocking, response policy execution)
- `iam-forensic` workflow — remediation phase (policy detach, key rotation, user deletion)
- `test_hitl_gating` — explicitly tests WAF IP blocking

**Behavior:** Headless mode (`--prompt` flag) auto-rejects all state-changing tools. No actual API calls are made.

### Attack Delivery

`deliver-attacks.sh` sends attack payloads to **your own WAF-protected domain**:
- Attacks are blocked by WAF (403/406 responses)
- No actual compromise occurs
- Generates WAF log entries for testing
- Safe to run repeatedly

**Important:** Only send attacks to domains you own and control. Never send attacks to production domains without coordination.

---

## Troubleshooting

### Test fails: "Credentials invalid"

```bash
# Reconfigure aliyun CLI
aliyun configure

# Verify credentials
aliyun sts GetCallerIdentity
```

### Test fails: "WAF instance not found"

```bash
# Check WAF provisioning
bash skills/blueteam-autopilot-ops/scripts/get-waf-instance.sh

# Verify region matches WAF deployment
aliyun configure list
```

### Workflow test times out

Workflows can take 3-5 minutes. If tests timeout:
- Increase timeout in test script (default: 300s)
- Check network connectivity to Alibaba Cloud APIs
- Verify Security Center edition (Enterprise/Ultimate required for full events)

### No attacks detected after delivery

SLS log delivery has a 1-5 minute delay. If attacks not detected:
- Wait longer: `deliver-attacks.sh --wait` (waits 30s)
- Check WAF logs manually: `bash skills/blueteam-autopilot-ops/scripts/list-waf-events.sh last15Min`
- Verify WAF log delivery: `bash skills/blueteam-autopilot-ops/scripts/verify-log-delivery.sh`

### Daemon test fails

Daemon test is timing-sensitive. If it fails:
- Increase sleep times in `test-daemon.sh`
- Check daemon log: `/tmp/daemon-test-*.log`
- Verify monitor_state table: `sqlite3 data/blueteam.db "SELECT * FROM monitor_state;"`

---

## Manual Testing

You can run individual workflows manually:

```bash
# Start the agent
python blueteam.py

# Try these prompts:
> Show me recent security events
> Investigate event evt-xxx-yyy
> Run the incident response workflow
> Run the IAM forensic workflow
> Run the threat hunt workflow
> Run the compliance audit workflow
> Search for similar incidents to "SQL injection attack"
> Block WAF IP 1.2.3.4  # (triggers HITL approval)
```

---

## Test Output

All tests produce colored output:
- **Green** ✓ — Test passed
- **Red** ✗ — Test failed
- **Yellow** ⚠ — Test skipped or warning
- **Blue** — Test in progress

Exit codes:
- `0` — All tests passed
- `1` — One or more tests failed

---

## File Structure

```
tests/
└── e2e/
    ├── README.md                  # This file
    ├── run-all-tests.sh           # Orchestrator (runs everything)
    ├── deliver-attacks.sh         # Sample curl attacks via WAF
    ├── test-workflows.sh          # Per-workflow validation
    ├── test-cross-cutting.sh      # Embeddings, HITL, drift, persistence
    └── test-daemon.sh             # Daemon mode validation
```

---

## Continuous Integration

To run E2E tests in CI:

```yaml
# .github/workflows/e2e.yml
name: E2E Tests
on:
  schedule:
    - cron: '0 6 * * *'  # Daily at 6am UTC
  workflow_dispatch:

jobs:
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup aliyun CLI
        run: |
          curl -sL https://aliyun-cli-install.oss-ap-southeast-1.aliyuncs.com/install.sh | sh
          aliyun configure set \
            --mode AK \
            --region ${{ secrets.ALIBABA_REGION }} \
            --access-key-id ${{ secrets.ALIBABA_ACCESS_KEY_ID }} \
            --access-key-secret ${{ secrets.ALIBABA_ACCESS_KEY_SECRET }}
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.12'
      
      - name: Install dependencies
        run: pip install -r requirements.txt
      
      - name: Run E2E tests
        env:
          DASHSCOPE_API_KEY: ${{ secrets.DASHSCOPE_API_KEY }}
          SECURITY_CENTER_MODE: real
          TEST_DOMAIN: ${{ secrets.TEST_DOMAIN }}
        run: bash tests/e2e/run-all-tests.sh --skip-daemon
```

---

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review workflow definitions in `workflows/*/WORKFLOW.md`
3. Check agent logs in `data/blueteam.db`
4. Open an issue on GitHub

---

## License

MIT License — Copyright (c) 2026 Chris Davis
