# BlueTeam Autopilot — Mode Reference

Single source of truth for `SECURITY_CENTER_MODE` behavior across all skills.

---

## Quick Comparison

| Aspect | `real` (default) | `demo` |
|--------|------------------|--------|
| **Network** | ✅ Live Alibaba Cloud API calls | ❌ Zero network calls |
| **Credentials** | `aliyun` CLI + RAM credentials required | None required |
| **Speed** | ~1-3s per API call | Instant (local JSON read) |
| **Data source** | Security Center / WAF / SLS live API | `fixtures/*.json` files |
| **State changes** | Possible (with human approval) | Simulated only |
| **Use case** | Production incident response | Offline dev, CI, trade-show demos |
| **`blueteam-autopilot-prep`** | Runs full 8-stage validation | Skips to "simulation active" |
| **`execute_response_policy`** | Real execution (requires approval) | Returns simulated success JSON |

---

## Setting the Mode

All scripts `source .env` from the project root automatically. Set the mode in your `.env` file:

```bash
# Real mode — live Alibaba Cloud API calls
echo 'SECURITY_CENTER_MODE=real' > .env

# Demo mode — local fixture files only
echo 'SECURITY_CENTER_MODE=demo' > .env
```

You can also export the variable directly (useful for temporary overrides):

```bash
export SECURITY_CENTER_MODE=real   # or demo
```

For shell persistence, add to your profile:

```bash
echo 'export SECURITY_CENTER_MODE=real' >> ~/.bashrc   # or ~/.zshrc
```

**All scripts** check this variable at startup. In demo mode, they short-circuit before any `aliyun` CLI call and `cat` the corresponding fixture file.

---

## Real Mode

### Prerequisites

1. **aliyun CLI** installed and configured:
   ```bash
   brew install aliyun-cli
   aliyun configure set --profile blueteam --mode AK \
     --access-key-id "$ALIBABA_ACCESS_KEY_ID" \
     --access-key-secret "$ALIBABA_ACCESS_KEY_SECRET" \
     --region "$ALIBABA_REGION"
   ```

2. **RAM user** with these policies:
   - `AliyunYundunSASReadOnlyAccess` — Security Center read
   - `AliyunYundunWAFv3FullAccess` — WAF 3.0 management
   - `AliyunLogFullAccess` — SLS log queries
   - `AliyunVPCReadOnlyAccess` — VPC discovery

3. **Environment variables** in your `.env` file at project root:
   ```bash
   ALIBABA_ACCESS_KEY_ID="LTAI5t..."
   ALIBABA_ACCESS_KEY_SECRET="HkfZ..."
   ALIBABA_REGION="ap-southeast-1"
   ```

4. **Security Center** Enterprise (4) or Ultimate (5) edition for Agentic SOC features.

### Execution Flow

```
User Prompt → Core Skill (BEHAVIORS.md) → CLI Script → aliyun CLI → Alibaba Cloud API
                                                                    ↑
                                            Human approval required for │
                                            execute_response_policy ───┘
```

### Warnings

- `ping.sh` prints ⚠️ when `SECURITY_CENTER_MODE=real`
- `execute_response_policy.sh` requires `--real` flag AND human confirmation
- SOC 2 CC6.8.3 mandates administrative validation before any state change

---

## Demo Mode

### No Credentials Required

Demo mode reads JSON fixture files from the `skills/fixtures/` directory (bundled with the skills package). No Alibaba Cloud account, credentials, or `aliyun` CLI installation needed.

### How It Works

Every script contains a demo-dispatch block that runs before any API call:

```bash
if [ "${SECURITY_CENTER_MODE:-real}" = "demo" ]; then
  FIXTURE_DIR="$(dirname "$SCRIPT_DIR")/../fixtures"
  FIXTURE_FILE="$FIXTURE_DIR/events_recent.json"
  if [ -f "$FIXTURE_FILE" ]; then
    cat "$FIXTURE_FILE"
    exit 0
  fi
fi
```

### Fixture Data

See [fixtures/README.md](fixtures/README.md) for the complete fixture map and descriptions.

All fixture data is **synthetic but realistic**:
- RFC 5737 TEST-NET IP ranges (`203.0.113.0/24`)
- Example domain `ecs.example.com`
- Realistic attack chains (SQLi, XSS, LFI, RCE, brute force)
- Real CVE references with CVSS scores
- All severity levels represented

### Capturing Real Fixtures

To update fixtures from a live environment:

```bash
# Capture security events
aliyun sas describe-susp-events --region "$ALIBABA_REGION" > skills/fixtures/events_recent.json

# Capture vulnerabilities
aliyun sas describe-vul-list --region "$ALIBABA_REGION" > skills/fixtures/vulnerabilities.json

# Capture WAF events
aliyun sls GetLogs --project "wafnew-project-..." --logstore "wafnew-logstore" ... > skills/fixtures/waf_events.json
```

**Always sanitize before committing**: replace real IPs, domain names, and account IDs with example placeholders.

---

## Common Workflows

### Demo Mode — Quick Start (5 minutes)

```bash
echo 'SECURITY_CENTER_MODE=demo' > .env
source .env

# Health check
./skills/blueteam-autopilot-ops/scripts/ping.sh
# → Returns ping.json fixture — "status": "ok", "mode": "demo"

# List recent security events
./skills/blueteam-autopilot-ops/scripts/list-events.sh
# → Returns events_recent.json — 6 events across all severities

# Get event detail
./skills/blueteam-autopilot-ops/scripts/get-event-detail.sh evt-demo-20260614-001
# → Returns event_detail.json — full attack chain

# List assets
./skills/blueteam-autopilot-ops/scripts/list-assets.sh
# → Returns assets.json — 5 ECS instances
```

### Real Mode — Production Incident Response

```bash
echo 'SECURITY_CENTER_MODE=real' > .env
source .env

# Validate environment first
# (uses blueteam-autopilot-prep skill)

# Start investigation
./skills/blueteam-autopilot-ops/scripts/ping.sh
./skills/blueteam-autopilot-ops/scripts/list-events.sh lastHour HIGH
./skills/blueteam-autopilot-ops/scripts/get-event-detail.sh evt-xxx-yyy
```

---

## Skill-Specific Mode Behavior

| Skill | `real` Behavior | `demo` Behavior |
|-------|----------------|-----------------|
| **blueteam-autopilot-core** | MCP tools / CLI scripts call live APIs | Reads fixtures; states "demo mode" at analysis start |
| **blueteam-autopilot-ops** | All 17 scripts call `aliyun` CLI | All scripts read `fixtures/*.json` |
| **blueteam-autopilot-prep** | Runs full 8-stage validation | Reports "simulation active" and skips |
| **blueteam-autopilot-knowledge** | Reads local Markdown documents | Same — knowledge docs are local files |
| **blueteam-autopilot-reports** | Generates reports from live data | Generates reports from fixture data |
| **alibaba-security-ops** | Calls `aliyun` CLI directly | Reads fixtures (same dispatch pattern) |

---

## Switching Modes

Modes can be switched at any time by editing `.env` or re-exporting the variable:

```bash
# Switch to demo for a quick test
echo 'SECURITY_CENTER_MODE=demo' > .env
./skills/blueteam-autopilot-ops/scripts/list-events.sh

# Or temporarily override for a single invocation
SECURITY_CENTER_MODE=demo ./skills/blueteam-autopilot-ops/scripts/list-events.sh

# Switch back to real for production work
echo 'SECURITY_CENTER_MODE=real' > .env
./skills/blueteam-autopilot-ops/scripts/list-events.sh
```

Each script invocation independently checks the current value — no restart required.

---

## References

- [fixtures/README.md](fixtures/README.md) — Fixture file map and capture instructions
- [blueteam-autopilot-core/SKILL.md](blueteam-autopilot-core/SKILL.md) — Core agent skill with execution modes section
- [blueteam-autopilot-ops/SKILL.md](blueteam-autopilot-ops/SKILL.md) — CLI operations with demo fixture column
- [blueteam-autopilot-core/BEHAVIORS.md](blueteam-autopilot-core/BEHAVIORS.md) — Core behaviors with mode notes
