---
name: blueteam-autopilot-compat
description: Validate aliyun CLI compatibility with BlueTeam scripts — detects breaking changes in CLI commands, parameters, and response structures.
allowed-tools:
  - Bash
  - Read
---

# BlueTeam CLI Compatibility Checker

Compatibility validation skill for **BlueTeam for Alibaba Cloud**. Detects when the installed `aliyun` CLI has changed in ways that could break the project's scripts, and provides remediation guidance.

## When to Use

Invoke this skill when:
- Upgrading the `aliyun` CLI to a new version (`brew upgrade aliyun-cli`)
- A script fails with an unexpected CLI error (command not found, invalid parameter, response parse error)
- Before a demo or presentation to confirm the environment is current
- Periodically as part of maintenance to catch CLI drift
- After pulling new project changes that may reference different CLI commands

## Mode Support

| Mode | Behavior |
|------|----------|
| `demo` (default) | Command existence and parameter checks only — no API calls |
| `real` | Full validation including live API response structure tests |

## How It Works

The skill compares the installed `aliyun` CLI against a **baseline** stored in `references/cli-baseline.json`. The baseline records:

- The CLI version that was tested
- Every CLI command used by project scripts
- Required parameters for each command
- Expected response fields from each API call

### Validation Stages

1. **CLI Installation** — Verify `aliyun` CLI is installed and report version
2. **Baseline Load** — Load the command baseline and check version alignment
3. **Command Existence** — Verify each baseline command is recognized by the installed CLI (`aliyun <product> <command> --help`)
4. **Parameter Checks** — Verify required parameters are accepted (appear in `--help` output)
5. **Live API Tests** (real mode only) — Run smoke tests against live APIs and verify response structure contains expected fields

### Baseline File

The baseline (`references/cli-baseline.json`) covers **26 CLI commands** across 6 product namespaces:

| Namespace | Commands | Used By |
|-----------|----------|---------|
| `sas` | `describe-susp-events`, `describe-susp-event-detail`, `describe-vul-list`, `describe-vul-details`, `describe-cloud-center-instances`, `describe-version-config` | ops scripts |
| `waf-openapi` | `describe-instance`, `describe-rule-hits-top-rule-id`, `describe-rule-hits-top-client-ip`, `DescribeInstance`, `DescribeDomains` | ops scripts, prep |
| `sls` | `GetProject`, `ListLogStores`, `GetLogs` | ops scripts, prep |
| `cloud-siem` | `ListAutomateResponseConfigs`, `UpdateAutomateResponseConfigStatus` | ops scripts (Enterprise edition required) |
| `sts` | `GetCallerIdentity` | ops scripts |
| `vpc` | `DescribeVpcs`, `DescribeVpcAttribute`, `DescribeVpnGateways` | prep |

## Running the Check

### Demo Mode (default)

```bash
python ./scripts/check_compat.py
```

Verifies command existence and parameter acceptance without making any API calls.

### Real Mode (live API tests)

```bash
SECURITY_CENTER_MODE=real python ./scripts/check_compat.py --real
```

Adds live API smoke tests that verify response structures contain expected fields.

## Interpreting Results

### All Checks Passed

The installed CLI is compatible. No action needed.

### Version Mismatch Warning

```
⚠ Version mismatch: installed=3.5.0, baseline=3.4.2
```

This is informational. The CLI may still be compatible — run the check to confirm. If all command existence and parameter checks pass, the version difference is cosmetic.

### Command Not Found

```
✗ describe-susp-events — command not recognized
  Affected: list_events.py
```

The CLI no longer recognizes this command. Possible causes:
- Alibaba Cloud renamed the API endpoint
- The CLI version changed command naming conventions (e.g., PascalCase → lowercase-hyphen)

**Remediation:**
1. Check `aliyun sas help` for the current command list
2. Search Alibaba Cloud API documentation for the replacement command
3. Update the affected script(s) to use the new command
4. Update `references/cli-baseline.json` with the new command
5. Re-run the compatibility check

### Parameter Not Accepted

```
⚠ describe-susp-events — params not found in help: --time-range
  Affected: list_events.py
```

The command exists but a parameter is no longer recognized. Possible causes:
- The API parameter was renamed or deprecated
- The CLI changed parameter format (e.g., `--TimeRange` → `--time-range`)

**Remediation:**
1. Run `aliyun sas describe-susp-events --help` to see current parameters
2. Identify the replacement parameter name
3. Update the affected script(s)
4. Update `references/cli-baseline.json`
5. Re-run the compatibility check

### Response Field Missing (real mode)

```
✗ sas describe-version-config — missing expected field: VersionConfig
```

The API call succeeded but the response structure changed. This is a breaking change.

**Remediation:**
1. Run the command manually and inspect the raw response
2. Identify the new field names or structure
3. Update the Python parsing code in the affected script(s)
4. Update `references/cli-baseline.json` with new expected fields
5. Re-run the compatibility check

## Updating the Baseline

After fixing compatibility issues, update the baseline:

```bash
# Update the version and date
python3 -c "
import json
from datetime import date
d = json.load(open('references/cli-baseline.json'))
d['meta']['cli_version_tested'] = '$(aliyun version)'
d['meta']['last_validated'] = '$(date +%Y-%m-%d)'
json.dump(d, open('references/cli-baseline.json', 'w'), indent=2)
"
```

## Integration with Other Skills

| Skill | Relationship |
|-------|-------------|
| `blueteam-autopilot-prep` | Run prep first for environment setup, then compat to validate CLI compatibility |
| `blueteam-autopilot-ops` | Compat checks validate that ops scripts will work with the current CLI |
| `blueteam-autopilot-core` | If CLI commands change, the agent's tool definitions in SKILL.md may also need updating |

## Limitations

- The `aliyun` CLI has no changelog API — we cannot automatically determine what changed between versions
- Command existence checks use `--help` output, which may not catch runtime-only issues
- Live API tests require valid credentials and may incur API costs
- The `cloud-siem` product (response policies) requires Security Center Enterprise edition or higher
- The baseline must be manually updated when new commands are added to project scripts
