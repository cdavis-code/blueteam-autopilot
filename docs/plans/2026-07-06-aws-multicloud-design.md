# AWS Multi-Cloud Extension — Design Document

**Date:** 2026-07-06
**Branch:** `aws`
**Status:** Approved for implementation

---

## Overview

Extend BlueTeam Autopilot from Alibaba Cloud-only to a multi-cloud security platform supporting both Alibaba Cloud and AWS. Users select providers via `INFRA=aliyun,aws` in `.env`. The architecture uses modular provider components loaded at runtime.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Architecture | Parallel provider components | Clean separation, easy to debug, no abstraction overhead |
| AWS services | Full parity (GuardDuty, WAF, CloudTrail, Security Hub, IAM) | Maps cleanly to existing workflows |
| Demo mode | AWS fixtures for all tools | Maintains demo-first philosophy |
| Provider loading | Runtime via `INFRA` env var | Backward compatible, opt-in multi-cloud |
| Default provider | `aliyun` | Zero change for existing users |

## Directory Structure

```
connectonion_qwen/
├── providers/
│   ├── __init__.py              # Provider registry + runtime loader
│   ├── base.py                  # Abstract provider interface
│   ├── aliyun/
│   │   ├── __init__.py
│   │   ├── tools.py             # Existing 37 tools (moved from tools.py)
│   │   └── config.py            # Aliyun-specific config
│   └── aws/
│       ├── __init__.py
│       ├── tools.py             # New AWS tools (~13 tools)
│       └── config.py            # AWS-specific config
├── tools.py                     # Thin dispatcher: loads providers per INFRA
├── plugins.py                   # Unchanged (HITL + compliance)
├── embeddings.py                # Unchanged (cloud-agnostic)
└── system_prompt.py             # Updated for multi-cloud awareness
```

## AWS Tool Mapping

| Category | Alibaba Tool | AWS Tool | Script |
|----------|-------------|----------|--------|
| Events | `list_events` | `aws_list_findings` | `aws-list-findings.sh` (Security Hub) |
| Events | `get_event_detail` | `aws_get_finding_detail` | `aws-get-finding-detail.sh` |
| Threats | `list_waf_events` | `aws_list_waf_events` | `aws-list-waf-events.sh` (WAF ACL) |
| Threats | `list_waf_security_events` | `aws_list_guardduty_findings` | `aws-list-guardduty-findings.sh` |
| Threats | `get_waf_event_detail` | `aws_get_guardduty_finding` | `aws-get-guardduty-finding.sh` |
| Audit | — | `aws_list_cloudtrail_events` | `aws-list-cloudtrail-events.sh` |
| Assets | `list_assets` | `aws_list_assets` | `aws-list-assets.sh` (EC2) |
| IAM | `list_ram_users` | `aws_list_iam_users` | `aws-list-iam-users.sh` |
| IAM | `get_user_mfa` | `aws_get_iam_mfa` | `aws-get-iam-mfa.sh` |
| IAM | `list_access_keys` | `aws_list_iam_access_keys` | `aws-list-iam-access-keys.sh` |
| Response | `execute_response_policy` | `aws_update_finding` | `aws-update-finding.sh` |
| Response | `block_waf_ips` | `aws_block_waf_ips` | `aws-block-waf-ips.sh` |
| Diag | `ping` | `aws_ping` | `aws-ping.sh` |

## Script Dispatch Pattern

Each AWS bash script follows the same demo/real dispatch as existing Alibaba scripts:

```bash
#!/usr/bin/env bash
# aws-list-guardduty-findings.sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../../.env" 2>/dev/null || true

if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  FIXTURES_DIR="$SCRIPT_DIR/../../blueteam-autopilot-core/fixtures"
  cat "$FIXTURES_DIR/aws_guardduty_findings.json"
else
  DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)
  aws guardduty list-findings --detector-id "$DETECTOR_ID" --output json
fi
```

## Workflow Integration

- **incident-response**: Detects provider from event source field, uses appropriate tools
- **iam-forensic**: Adds IAM audit tools from both providers when `INFRA=aliyun,aws`
- **threat-hunt**: Cross-cloud correlation via cloud-agnostic embeddings
- **compliance-audit**: Maps AWS Security Hub findings to SOC 2 / NIST CSF
- **continuous-monitor**: Polls both providers in daemon mode

## HITL Gating

AWS state-changing tools join the existing gate:

```python
# In providers/aws/tools.py
STATE_CHANGING_TOOLS = {
    "aws_block_waf_ips",
    "aws_update_finding",
}
```

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `INFRA` | Comma-separated provider list | `aliyun` |
| `AWS_DEFAULT_REGION` | AWS region | Auto from `aws configure` |
| `AWS_PROFILE` | AWS CLI profile | `default` |

## Implementation Phases

1. **Provider Infrastructure** — Directory structure, registry, loader, refactor existing tools
2. **AWS Core Tools** — 13 tools, bash scripts, fixture JSON files
3. **Workflow Integration** — Cloud-aware workflows, system prompt, HITL
4. **Verification** — Demo mode, real mode, E2E tests

## Files Changed Summary

| File/Directory | Action |
|----------------|--------|
| `connectonion_qwen/providers/` | Create (provider registry + loader) |
| `connectonion_qwen/providers/aliyun/` | Create (move existing tools) |
| `connectonion_qwen/providers/aws/` | Create (new AWS tools) |
| `connectonion_qwen/tools.py` | Refactor to thin dispatcher |
| `connectonion_qwen/system_prompt.py` | Add multi-cloud awareness |
| `connectonion_qwen/config.py` | Add `INFRA` config |
| `skills/blueteam-autopilot-ops/scripts/aws-*.sh` | Create (~13 scripts) |
| `skills/blueteam-autopilot-core/fixtures/aws_*.json` | Create (~13 fixtures) |
| `.env.example` | Add `INFRA` variable |
| `workflows/*/WORKFLOW.md` | Update for cloud-awareness |

No new Python dependencies. Uses `aws` CLI (already installed).
