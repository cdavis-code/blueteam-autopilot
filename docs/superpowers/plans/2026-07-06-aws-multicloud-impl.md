# AWS Multi-Cloud Extension — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend BlueTeam Autopilot to support AWS alongside Alibaba Cloud via modular provider components loaded at runtime.

**Architecture:** Provider components under `connectonion_qwen/providers/` with `aliyun/` and `aws/` subdirectories. Each provider exports `tools.py` and `config.py`. Runtime loader reads `INFRA` env var (default: `aliyun`) and merges tools from active providers. Existing `tools.py` becomes a thin dispatcher.

**Tech Stack:** Python 3.10+, Bash, AWS CLI v2, Alibaba Cloud CLI (`aliyun`), SQLite (embeddings), ConnectOnion agent framework

**Design Doc:** `docs/plans/2026-07-06-aws-multicloud-design.md`

---

## File Structure

| File | Responsibility |
|------|---------------|
| `connectonion_qwen/providers/__init__.py` | Provider registry + `load_providers()` function |
| `connectonion_qwen/providers/base.py` | `Provider` Protocol class |
| `connectonion_qwen/providers/aliyun/__init__.py` | Aliyun provider registration |
| `connectonion_qwen/providers/aliyun/tools.py` | Existing 37 tools (moved from `tools.py`) |
| `connectonion_qwen/providers/aliyun/config.py` | Aliyun-specific config (region, scripts dir) |
| `connectonion_qwen/providers/aws/__init__.py` | AWS provider registration |
| `connectonion_qwen/providers/aws/tools.py` | 13 new AWS tools |
| `connectonion_qwen/providers/aws/config.py` | AWS-specific config (region, profile) |
| `connectonion_qwen/tools.py` | Thin dispatcher: imports from providers, exports `ALL_TOOLS` |
| `connectonion_qwen/config.py` | Add `INFRA` variable |
| `connectonion_qwen/plugins.py` | Merge `STATE_CHANGING_TOOLS` from all providers |
| `connectonion_qwen/system_prompt.py` | Multi-cloud awareness |
| `blueteam.py` | Import from new location |
| `.env.example` | Add `INFRA` variable |
| `skills/blueteam-autopilot-ops/scripts/aws-*.sh` | 13 AWS bash scripts |
| `skills/blueteam-autopilot-core/fixtures/aws_*.json` | 13 AWS fixture files |

---

## Phase 1: Provider Infrastructure

### Task 1: Add INFRA config variable

**Files:**
- Modify: `connectonion_qwen/config.py:22-23`
- Modify: `.env.example`

- [ ] **Step 1: Add INFRA to config.py**

Add after the `ALIBABA_REGION` line in `config.py`:

```python
# ---------------------------------------------------------------------------
# Multi-cloud provider selection (comma-separated: aliyun, aws)
# ---------------------------------------------------------------------------
INFRA: list[str] = [p.strip() for p in os.getenv("INFRA", "aliyun").split(",") if p.strip()]
```

- [ ] **Step 2: Add INFRA to .env.example**

Add to `.env.example`:

```bash
# Multi-cloud provider selection (comma-separated)
# Options: aliyun, aws, aliyun,aws
# Default: aliyun
INFRA=aliyun
```

- [ ] **Step 3: Verify config loads**

Run: `cd /Users/chrisdavis/projects/scratch/cyber && .venv/bin/python -c "from connectonion_qwen.config import INFRA; print(INFRA)"`
Expected: `['aliyun']`

- [ ] **Step 4: Commit**

```bash
git add connectonion_qwen/config.py .env.example
git commit -m "feat: add INFRA config variable for multi-cloud provider selection"
```

---

### Task 2: Create provider registry and base protocol

**Files:**
- Create: `connectonion_qwen/providers/__init__.py`
- Create: `connectonion_qwen/providers/base.py`

- [ ] **Step 1: Create providers/base.py**

```python
"""Provider protocol — interface each cloud provider must implement."""

from __future__ import annotations

from typing import Callable, Protocol


class CloudProvider(Protocol):
    """Interface for cloud provider components."""

    name: str

    def get_tools(self) -> list[Callable]:
        """Return list of tool functions for this provider."""
        ...

    def get_state_changing_tools(self) -> set[str]:
        """Return set of tool names that require HITL approval."""
        ...
```

- [ ] **Step 2: Create providers/__init__.py**

```python
"""Provider registry — loads cloud providers based on INFRA config."""

from __future__ import annotations

import logging
from typing import Callable

from connectonion_qwen.config import INFRA

logger = logging.getLogger(__name__)

_registry: dict[str, type] = {}


def register_provider(name: str, provider_class: type) -> None:
    """Register a provider class by name."""
    _registry[name] = provider_class


def load_providers() -> tuple[list[Callable], set[str]]:
    """Load active providers and return (all_tools, state_changing_tools)."""
    all_tools: list[Callable] = []
    state_changing: set[str] = set()

    for provider_name in INFRA:
        if provider_name in _registry:
            provider = _registry[provider_name]()
            all_tools.extend(provider.get_tools())
            state_changing.update(provider.get_state_changing_tools())
            logger.info(f"Loaded provider: {provider_name} ({len(provider.get_tools())} tools)")
        else:
            logger.warning(f"Unknown provider: {provider_name}. Available: {list(_registry.keys())}")

    return all_tools, state_changing
```

- [ ] **Step 3: Commit**

```bash
git add connectonion_qwen/providers/
git commit -m "feat: create provider registry and base protocol"
```

---

### Task 3: Create Aliyun provider component

**Files:**
- Create: `connectonion_qwen/providers/aliyun/__init__.py`
- Create: `connectonion_qwen/providers/aliyun/config.py`
- Create: `connectonion_qwen/providers/aliyun/tools.py` (move from `connectonion_qwen/tools.py`)

- [ ] **Step 1: Create aliyun/config.py**

```python
"""Aliyun-specific configuration."""

from connectonion_qwen.config import (
    ALIBABA_REGION,
    SCRIPTS_DIR,
    FIXTURES_DIR,
    SECURITY_CENTER_MODE,
)
```

- [ ] **Step 2: Create aliyun/tools.py**

Copy the entire contents of `connectonion_qwen/tools.py` into `connectonion_qwen/providers/aliyun/tools.py`. This includes all 37 tool functions, the `_run_script` helper, `STATE_CHANGING_TOOLS`, and `ALL_TOOLS`.

Update the import at the top:

```python
from connectonion_qwen.providers.aliyun.config import SCRIPTS_DIR, SECURITY_CENTER_MODE
```

- [ ] **Step 3: Create aliyun/__init__.py**

```python
"""Aliyun cloud provider."""

from __future__ import annotations

from connectonion_qwen.providers import register_provider
from connectonion_qwen.providers.aliyun.tools import ALL_TOOLS, STATE_CHANGING_TOOLS


class AliyunProvider:
    name = "aliyun"

    def get_tools(self):
        return list(ALL_TOOLS)

    def get_state_changing_tools(self):
        return STATE_CHANGING_TOOLS


register_provider("aliyun", AliyunProvider)
```

- [ ] **Step 4: Verify import works**

Run: `.venv/bin/python -c "from connectonion_qwen.providers.aliyun import AliyunProvider; p = AliyunProvider(); print(f'{len(p.get_tools())} tools')"`
Expected: `37 tools`

- [ ] **Step 5: Commit**

```bash
git add connectonion_qwen/providers/aliyun/
git commit -m "feat: create Aliyun provider component with existing 37 tools"
```

---

### Task 4: Refactor tools.py to thin dispatcher

**Files:**
- Modify: `connectonion_qwen/tools.py` (replace entire file)

- [ ] **Step 1: Replace tools.py with thin dispatcher**

```python
"""BlueTeam Autopilot tools — thin dispatcher for multi-cloud providers.

Loads tools from active providers based on INFRA config.
Re-exports ALL_TOOLS and STATE_CHANGING_TOOLS for backward compatibility.
"""

from __future__ import annotations

import logging

# Import providers to trigger registration
import connectonion_qwen.providers.aliyun  # noqa: F401

from connectonion_qwen.providers import load_providers

logger = logging.getLogger(__name__)

# Load tools from active providers
ALL_TOOLS, STATE_CHANGING_TOOLS = load_providers()

logger.info(f"Loaded {len(ALL_TOOLS)} tools from providers. "
            f"State-changing: {STATE_CHANGING_TOOLS}")
```

- [ ] **Step 2: Verify backward compatibility**

Run: `.venv/bin/python -c "from connectonion_qwen.tools import ALL_TOOLS, STATE_CHANGING_TOOLS; print(f'{len(ALL_TOOLS)} tools, {len(STATE_CHANGING_TOOLS)} state-changing')"`
Expected: `37 tools, 5 state-changing`

- [ ] **Step 3: Verify blueteam.py still works**

Run: `.venv/bin/python -c "from blueteam import main; print('OK')"`
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add connectonion_qwen/tools.py
git commit -m "refactor: tools.py becomes thin dispatcher for provider loading"
```

---

### Task 5: Verify demo mode still works end-to-end

- [ ] **Step 1: Run agent in demo mode with single prompt**

Run: `.venv/bin/python blueteam.py --prompt "Ping the system"`
Expected: Agent responds with ping result (region and mode detected)

- [ ] **Step 2: Run a tool directly**

Run: `.venv/bin/python -c "from connectonion_qwen.tools import ALL_TOOLS; ping = [t for t in ALL_TOOLS if t.__name__ == 'ping'][0]; print(ping())"`
Expected: JSON with region and mode info

- [ ] **Step 3: Commit any fixes if needed**

---

## Phase 2: AWS Core Tools

### Task 6: Create AWS provider component skeleton

**Files:**
- Create: `connectonion_qwen/providers/aws/__init__.py`
- Create: `connectonion_qwen/providers/aws/config.py`
- Create: `connectonion_qwen/providers/aws/tools.py`

- [ ] **Step 1: Create aws/config.py**

```python
"""AWS-specific configuration."""

from pathlib import Path

from connectonion_qwen.config import (
    SCRIPTS_DIR,
    FIXTURES_DIR,
    SECURITY_CENTER_MODE,
    _PROJECT_ROOT,
)

# AWS-specific paths (reuse same scripts/fixtures dirs)
AWS_SCRIPTS_DIR = SCRIPTS_DIR
AWS_FIXTURES_DIR = FIXTURES_DIR
```

- [ ] **Step 2: Create aws/tools.py (skeleton)**

```python
"""AWS cloud provider tools — 13 SecOps tools for AWS services.

Each tool dispatches to a bash script via subprocess, following
the same pattern as the Aliyun provider.
"""

from __future__ import annotations

import json
import logging
import os
import subprocess
from pathlib import Path

from connectonion_qwen.providers.aws.config import (
    AWS_SCRIPTS_DIR,
    AWS_FIXTURES_DIR,
    SECURITY_CENTER_MODE,
)

logger = logging.getLogger(__name__)

# AWS state-changing tools (require HITL approval)
AWS_STATE_CHANGING_TOOLS: set[str] = {
    "aws_block_waf_ips",
    "aws_update_finding",
}


def _run_aws_script(script_name: str, args: list[str] | None = None) -> str:
    """Execute an AWS bash script and return its stdout."""
    script_path: Path = AWS_SCRIPTS_DIR / script_name
    if not script_path.exists():
        return json.dumps({"error": f"Script not found: {script_path}"})

    cmd: list[str] = ["bash", str(script_path)]
    if args:
        cmd.extend(args)

    env = os.environ.copy()
    env["SECURITY_CENTER_MODE"] = SECURITY_CENTER_MODE

    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=60, env=env,
            cwd=str(AWS_SCRIPTS_DIR.parent.parent.parent),
        )
        output = result.stdout.strip()
        if result.returncode != 0 and not output:
            return json.dumps({"error": result.stderr.strip() or f"Script failed (exit {result.returncode})"})
        return output or json.dumps({"status": "ok"})
    except subprocess.TimeoutExpired:
        return json.dumps({"error": f"Script timeout: {script_name}"})
    except Exception as exc:
        return json.dumps({"error": str(exc)})


# ---------------------------------------------------------------------------
# Diagnostic Tools
# ---------------------------------------------------------------------------

def aws_ping() -> str:
    """Verify AWS CLI connectivity and credentials."""
    return _run_aws_script("aws-ping.sh")


# ---------------------------------------------------------------------------
# Security Hub / GuardDuty Events
# ---------------------------------------------------------------------------

def aws_list_findings(time_range: str = "lastHour") -> str:
    """List security findings from AWS Security Hub."""
    return _run_aws_script("aws-list-findings.sh", [time_range])


def aws_get_finding_detail(finding_id: str) -> str:
    """Get detailed information about a specific Security Hub finding."""
    return _run_aws_script("aws-get-finding-detail.sh", [finding_id])


# ---------------------------------------------------------------------------
# AWS WAF
# ---------------------------------------------------------------------------

def aws_list_waf_events(time_range: str = "lastHour") -> str:
    """List recent AWS WAF blocked requests."""
    return _run_aws_script("aws-list-waf-events.sh", [time_range])


def aws_list_guardduty_findings(time_range: str = "lastHour") -> str:
    """List GuardDuty threat detection findings."""
    return _run_aws_script("aws-list-guardduty-findings.sh", [time_range])


def aws_get_guardduty_finding(finding_id: str) -> str:
    """Get detailed information about a specific GuardDuty finding."""
    return _run_aws_script("aws-get-guardduty-finding.sh", [finding_id])


# ---------------------------------------------------------------------------
# CloudTrail Audit
# ---------------------------------------------------------------------------

def aws_list_cloudtrail_events(time_range: str = "lastHour") -> str:
    """List recent CloudTrail API audit events."""
    return _run_aws_script("aws-list-cloudtrail-events.sh", [time_range])


# ---------------------------------------------------------------------------
# Assets (EC2)
# ---------------------------------------------------------------------------

def aws_list_assets() -> str:
    """List AWS EC2 instances and resources."""
    return _run_aws_script("aws-list-assets.sh")


# ---------------------------------------------------------------------------
# IAM Tools
# ---------------------------------------------------------------------------

def aws_list_iam_users() -> str:
    """List all IAM users in the AWS account."""
    return _run_aws_script("aws-list-iam-users.sh")


def aws_get_iam_mfa(user_name: str) -> str:
    """Get MFA device status for an IAM user."""
    return _run_aws_script("aws-get-iam-mfa.sh", [user_name])


def aws_list_iam_access_keys(user_name: str) -> str:
    """List access keys for an IAM user."""
    return _run_aws_script("aws-list-iam-access-keys.sh", [user_name])


# ---------------------------------------------------------------------------
# Response Tools (state-changing)
# ---------------------------------------------------------------------------

def aws_update_finding(finding_id: str, status: str = "NOTIFIED") -> str:
    """Update a Security Hub finding status. Requires human approval."""
    return _run_aws_script("aws-update-finding.sh", [finding_id, status])


def aws_block_waf_ips(ips: str, dry_run: bool = True) -> str:
    """Block attacker IPs in AWS WAF via IP set update. Requires human approval."""
    args = [ips]
    if not dry_run:
        args.append("--real")
    return _run_aws_script("aws-block-waf-ips.sh", args)


# ---------------------------------------------------------------------------
# Tool Registry
# ---------------------------------------------------------------------------

ALL_TOOLS: list = [
    # Diagnostics
    aws_ping,
    # Security Hub / GuardDuty
    aws_list_findings,
    aws_get_finding_detail,
    # WAF
    aws_list_waf_events,
    aws_list_guardduty_findings,
    aws_get_guardduty_finding,
    # CloudTrail
    aws_list_cloudtrail_events,
    # Assets
    aws_list_assets,
    # IAM
    aws_list_iam_users,
    aws_get_iam_mfa,
    aws_list_iam_access_keys,
    # Response
    aws_update_finding,
    aws_block_waf_ips,
]
```

- [ ] **Step 3: Create aws/__init__.py**

```python
"""AWS cloud provider."""

from __future__ import annotations

from connectonion_qwen.providers import register_provider
from connectonion_qwen.providers.aws.tools import ALL_TOOLS, AWS_STATE_CHANGING_TOOLS


class AWSProvider:
    name = "aws"

    def get_tools(self):
        return list(ALL_TOOLS)

    def get_state_changing_tools(self):
        return AWS_STATE_CHANGING_TOOLS


register_provider("aws", AWSProvider)
```

- [ ] **Step 4: Verify AWS provider loads**

Run: `.venv/bin/python -c "from connectonion_qwen.providers.aws import AWSProvider; p = AWSProvider(); print(f'{len(p.get_tools())} tools, {len(p.get_state_changing_tools())} state-changing')"`
Expected: `13 tools, 2 state-changing`

- [ ] **Step 5: Commit**

```bash
git add connectonion_qwen/providers/aws/
git commit -m "feat: create AWS provider component with 13 tools"
```

---

### Task 7: Wire AWS provider into tools.py dispatcher

**Files:**
- Modify: `connectonion_qwen/tools.py`

- [ ] **Step 1: Add AWS provider import**

Add to `tools.py` after the aliyun import:

```python
import connectonion_qwen.providers.aws  # noqa: F401
```

- [ ] **Step 2: Verify both providers load**

Run: `.venv/bin/python -c "from connectonion_qwen.config import INFRA; INFRA.append('aws'); from connectonion_qwen.providers import load_providers; import connectonion_qwen.providers.aliyun; import connectonion_qwen.providers.aws; tools, sc = load_providers(); print(f'{len(tools)} tools, {len(sc)} state-changing')"`
Expected: `50 tools, 7 state-changing`

- [ ] **Step 3: Commit**

```bash
git add connectonion_qwen/tools.py
git commit -m "feat: wire AWS provider into tools dispatcher"
```

---

### Task 8: Create AWS fixture JSON files

**Files:**
- Create: `skills/blueteam-autopilot-core/fixtures/aws_*.json` (13 files)

- [ ] **Step 1: Create aws_ping.json**

```json
{
  "status": "ok",
  "account_id": "123456789012",
  "region": "us-east-1",
  "user": "arn:aws:iam::123456789012:user/demo-user"
}
```

- [ ] **Step 2: Create aws_list_findings.json (Security Hub)**

```json
{
  "Findings": [
    {
      "Id": "us-east-1/123456789012/abc123",
      "ProductArn": "arn:aws:securityhub:us-east-1::product/aws/guardduty",
      "Title": "UnauthorizedAccess: IAMUser AnomalousBehavior",
      "Description": "An API commonly used for reconnaissance was called from an unusual IP address.",
      "Severity": {"Label": "HIGH", "Normalized": 70},
      "CreatedAt": "2026-07-06T12:00:00.000Z",
      "UpdatedAt": "2026-07-06T12:00:00.000Z",
      "WorkflowState": "NEW",
      "RecordState": "ACTIVE",
      "Resources": [{"Type": "AwsIamAccessKey", "Id": "AIDAEXAMPLE"}]
    },
    {
      "Id": "us-east-1/123456789012/def456",
      "ProductArn": "arn:aws:securityhub:us-east-1::product/aws/securityhub",
      "Title": "CIS AWS Foundations Benchmark v1.4.0 - 1.4",
      "Description": "Ensure no root account access key exists",
      "Severity": {"Label": "MEDIUM", "Normalized": 40},
      "CreatedAt": "2026-07-06T10:00:00.000Z",
      "UpdatedAt": "2026-07-06T10:00:00.000Z",
      "WorkflowState": "NEW",
      "RecordState": "ACTIVE",
      "Resources": [{"Type": "AwsAccount", "Id": "123456789012"}]
    }
  ]
}
```

- [ ] **Step 3: Create remaining fixture files**

Create these fixtures following the same pattern. Each should have realistic but safe demo data:

- `aws_get_finding_detail.json` — Single finding with full detail
- `aws_list_waf_events.json` — 2-3 WAF blocked requests
- `aws_list_guardduty_findings.json` — 2-3 GuardDuty findings
- `aws_get_guardduty_finding.json` — Single GuardDuty finding detail
- `aws_list_cloudtrail_events.json` — 3-5 CloudTrail events
- `aws_list_assets.json` — 2-3 EC2 instances
- `aws_list_iam_users.json` — 3-4 IAM users
- `aws_get_iam_mfa.json` — MFA status for a user
- `aws_list_iam_access_keys.json` — Access keys for a user
- `aws_update_finding.json` — Success response
- `aws_block_waf_ips.json` — Success response

- [ ] **Step 4: Commit**

```bash
git add skills/blueteam-autopilot-core/fixtures/aws_*.json
git commit -m "feat: add AWS demo fixture JSON files"
```

---

### Task 9: Create AWS bash scripts

**Files:**
- Create: `skills/blueteam-autopilot-ops/scripts/aws-*.sh` (13 scripts)

- [ ] **Step 1: Create aws-ping.sh**

```bash
#!/usr/bin/env bash
# aws-ping.sh — Verify AWS CLI connectivity
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../../.env" 2>/dev/null || true

FIXTURES_DIR="$SCRIPT_DIR/../../blueteam-autopilot-core/fixtures"

if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  cat "$FIXTURES_DIR/aws_ping.json"
else
  ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
  REGION=$(aws configure get region 2>/dev/null || echo "unknown")
  USER_ARN=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)
  echo "{\"status\":\"ok\",\"account_id\":\"$ACCOUNT_ID\",\"region\":\"$REGION\",\"user\":\"$USER_ARN\"}"
fi
```

- [ ] **Step 2: Create aws-list-findings.sh**

```bash
#!/usr/bin/env bash
# aws-list-findings.sh — List Security Hub findings
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../../.env" 2>/dev/null || true

TIME_RANGE="${1:-lastHour}"
FIXTURES_DIR="$SCRIPT_DIR/../../blueteam-autopilot-core/fixtures"

if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  cat "$FIXTURES_DIR/aws_list_findings.json"
else
  # Calculate time filter
  NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  HOURS_AGO=1
  case "$TIME_RANGE" in
    last15Min) HOURS_AGO=0 ;;
    lastHour) HOURS_AGO=1 ;;
    last4Hours) HOURS_AGO=4 ;;
    last24Hours) HOURS_AGO=24 ;;
    last7Days) HOURS_AGO=168 ;;
  esac
  SINCE=$(date -u -v-${HOURS_AGO}H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

  aws securityhub get-findings \
    --filters "{\"CreatedAt\":[{\"DateRange\":{\"Value\":$HOURS_AGO,\"Unit\":\"HOURS\"}}]}" \
    --max-results 20 \
    --output json
fi
```

- [ ] **Step 3: Create remaining AWS scripts**

Create the remaining 11 scripts following the same pattern:
- `aws-get-finding-detail.sh` — `aws securityhub get-findings --finding-ids`
- `aws-list-waf-events.sh` — `aws wafv2 get-sampled-requests`
- `aws-list-guardduty-findings.sh` — `aws guardduty list-findings`
- `aws-get-guardduty-finding.sh` — `aws guardduty get-findings`
- `aws-list-cloudtrail-events.sh` — `aws cloudtrail lookup-events`
- `aws-list-assets.sh` — `aws ec2 describe-instances`
- `aws-list-iam-users.sh` — `aws iam list-users`
- `aws-get-iam-mfa.sh` — `aws iam list-mfa-devices`
- `aws-list-iam-access-keys.sh` — `aws iam list-access-keys`
- `aws-update-finding.sh` — `aws securityhub batch-update-findings`
- `aws-block-waf-ips.sh` — `aws wafv2 update-ip-set`

Each script: demo mode returns fixture, real mode calls `aws` CLI.

- [ ] **Step 4: Make all scripts executable**

```bash
chmod +x skills/blueteam-autopilot-ops/scripts/aws-*.sh
```

- [ ] **Step 5: Test demo mode for each script**

Run: `for f in skills/blueteam-autopilot-ops/scripts/aws-*.sh; do echo "--- $(basename $f) ---"; bash "$f" 2>&1 | head -3; echo; done`
Expected: Each script outputs fixture JSON

- [ ] **Step 6: Commit**

```bash
git add skills/blueteam-autopilot-ops/scripts/aws-*.sh
git commit -m "feat: add 13 AWS bash scripts with demo/real dispatch"
```

---

## Phase 3: Workflow Integration

### Task 10: Update system prompt for multi-cloud

**Files:**
- Modify: `connectonion_qwen/system_prompt.py`

- [ ] **Step 1: Add multi-cloud awareness to system prompt**

Add after the mode declaration (around line 16):

```python
## Cloud Providers

Active providers: {', '.join(INFRA)}
- "aliyun" — Alibaba Cloud Security Center, WAF, SLS, RAM
- "aws" — AWS Security Hub, GuardDuty, WAF, CloudTrail, IAM

When investigating events, check the event source to determine which provider's tools to use.
AWS tools are prefixed with `aws_` (e.g., `aws_list_findings`, `aws_block_waf_ips`).
```

Update the f-string to include `INFRA`:

```python
from connectonion_qwen.config import INFRA
```

- [ ] **Step 2: Verify system prompt renders**

Run: `.venv/bin/python -c "from connectonion_qwen.system_prompt import SYSTEM_PROMPT; print(SYSTEM_PROMPT[:200])"`
Expected: System prompt includes cloud providers section

- [ ] **Step 3: Commit**

```bash
git add connectonion_qwen/system_prompt.py
git commit -m "feat: add multi-cloud provider awareness to system prompt"
```

---

### Task 11: Update plugins.py for multi-provider HITL

**Files:**
- Modify: `connectonion_qwen/plugins.py`

- [ ] **Step 1: Update HITL gate to use merged state-changing tools**

The HITL plugin currently has its own `_STATE_CHANGING_TOOLS` set. Update it to import from the merged set:

```python
from connectonion_qwen.tools import STATE_CHANGING_TOOLS as _STATE_CHANGING_TOOLS
```

Remove the hardcoded set at line 21-26.

- [ ] **Step 2: Verify HITL still works**

Run: `.venv/bin/python -c "from connectonion_qwen.plugins import _STATE_CHANGING_TOOLS; print(_STATE_CHANGING_TOOLS)"`
Expected: Set includes both aliyun and AWS state-changing tools (when both providers active)

- [ ] **Step 3: Commit**

```bash
git add connectonion_qwen/plugins.py
git commit -m "refactor: HITL gate uses merged state-changing tools from all providers"
```

---

### Task 12: Update workflow WORKFLOW.md files for cloud awareness

**Files:**
- Modify: `workflows/incident-response/WORKFLOW.md`
- Modify: `workflows/threat-hunt/WORKFLOW.md`
- Modify: `workflows/compliance-audit/WORKFLOW.md`

- [ ] **Step 1: Add cloud provider note to each workflow**

Add a brief note to each workflow's description section:

```markdown
## Cloud Provider Awareness

This workflow supports both Alibaba Cloud and AWS. When investigating events,
check the event source to determine which provider's tools to use:
- Alibaba Cloud events use tools like `list_events`, `get_event_detail`
- AWS events use tools like `aws_list_findings`, `aws_get_finding_detail`
```

- [ ] **Step 2: Commit**

```bash
git add workflows/
git commit -m "docs: add cloud provider awareness to workflow definitions"
```

---

## Phase 4: Verification

### Task 13: End-to-end demo mode verification

- [ ] **Step 1: Verify aliyun-only mode (default)**

Run: `.venv/bin/python -c "from connectonion_qwen.tools import ALL_TOOLS; print(f'{len(ALL_TOOLS)} tools')"`
Expected: `37 tools`

- [ ] **Step 2: Verify dual-provider mode**

Run: `INFRA=aliyun,aws .venv/bin/python -c "from connectonion_qwen.tools import ALL_TOOLS; print(f'{len(ALL_TOOLS)} tools')"`
Expected: `50 tools`

- [ ] **Step 3: Verify AWS-only mode**

Run: `INFRA=aws .venv/bin/python -c "from connectonion_qwen.tools import ALL_TOOLS; print(f'{len(ALL_TOOLS)} tools')"`
Expected: `13 tools`

- [ ] **Step 4: Run agent with dual providers in demo mode**

Run: `INFRA=aliyun,aws .venv/bin/python blueteam.py --prompt "Ping both cloud providers"`
Expected: Agent calls both `ping` and `aws_ping`

- [ ] **Step 5: Run an AWS-specific query**

Run: `INFRA=aliyun,aws .venv/bin/python blueteam.py --prompt "List AWS Security Hub findings"`
Expected: Agent calls `aws_list_findings` and returns demo data

- [ ] **Step 6: Commit any fixes**

---

### Task 14: Update .env.example and AGENTS.md

**Files:**
- Modify: `.env.example`
- Modify: `AGENTS.md`

- [ ] **Step 1: Verify .env.example has INFRA**

Already added in Task 1. Verify it's present.

- [ ] **Step 2: Update AGENTS.md with multi-cloud documentation**

Add a section to AGENTS.md:

```markdown
## Multi-Cloud Support

The agent supports multiple cloud providers via the `INFRA` environment variable:

| Value | Providers Loaded |
|-------|-----------------|
| `aliyun` (default) | Alibaba Cloud only |
| `aws` | AWS only |
| `aliyun,aws` | Both providers |

AWS tools are prefixed with `aws_` (e.g., `aws_list_findings`, `aws_ping`).
```

- [ ] **Step 3: Commit**

```bash
git add AGENTS.md
git commit -m "docs: add multi-cloud support documentation to AGENTS.md"
```

---

### Task 15: Final integration test and commit

- [ ] **Step 1: Run full agent startup in demo mode**

Run: `.venv/bin/python blueteam.py --prompt "List all available tools"`
Expected: Shows 37 tools (default aliyun-only)

- [ ] **Step 2: Run with dual providers**

Run: `INFRA=aliyun,aws .venv/bin/python blueteam.py --prompt "List all available tools"`
Expected: Shows 50 tools (37 aliyun + 13 aws)

- [ ] **Step 3: Verify HITL gating for AWS tools**

Run: `INFRA=aliyun,aws .venv/bin/python -c "from connectonion_qwen.tools import STATE_CHANGING_TOOLS; print(STATE_CHANGING_TOOLS)"`
Expected: Includes `aws_block_waf_ips` and `aws_update_finding`

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "v3.1.0: AWS multi-cloud support with 13 new tools

- Provider component architecture (connectonion_qwen/providers/)
- 13 AWS tools: Security Hub, GuardDuty, WAF, CloudTrail, IAM
- INFRA env var for runtime provider selection (default: aliyun)
- Demo mode fixtures for all AWS tools
- Workflow cloud awareness
- HITL gating for AWS state-changing tools"
```

---

## Summary

| Phase | Tasks | Files | Description |
|-------|-------|-------|-------------|
| 1 | 1-5 | 6 | Provider infrastructure, registry, refactor |
| 2 | 6-9 | 28 | AWS tools, scripts, fixtures |
| 3 | 10-12 | 5 | System prompt, plugins, workflows |
| 4 | 13-15 | 2 | Verification, docs, final commit |
| **Total** | **15** | **~41** | Full multi-cloud extension |
