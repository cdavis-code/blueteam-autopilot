---
name: blueteam-autopilot-ops
description: >
  Operational CLI workflows for Alibaba Cloud Security Center and WAF.
  Use when executing security event queries, deep-dive investigations,
  or verifying log delivery via aliyun CLI commands.
allowed-tools:
  - Bash
---

# BlueTeam Autopilot - Operations

Operational CLI workflows wrapping `aliyun` commands for Security Center and WAF operations.

## Prerequisites

1. **aliyun CLI installed:** Verify with `aliyun version`
2. **Credentials configured:** Set environment variables or use `.env` file:
   ```bash
   export ALIBABA_ACCESS_KEY_ID="your-access-key-id"
   export ALIBABA_ACCESS_KEY_SECRET="your-access-key-secret"
   export ALIBABA_REGION="<your-region>"  # e.g., ap-southeast-1, us-east-1
   ```
   > **NOTE:** Replace `<your-region>` with your actual Alibaba Cloud region.
   > All scripts use `$ALIBABA_REGION` dynamically—no hardcoded values.
3. **Security Center edition:** Agentic SOC features require Enterprise (4) or Ultimate (5)
   - Check edition: `aliyun sas describe-version-config --region "$ALIBABA_REGION"`

## Script Catalog

| Script | Purpose | Usage |
|--------|---------|-------|
| `list-events.sh` | List Security Center events | `./list-events.sh [time_range] [severity]` |
| `get-event-detail.sh` | Event deep-dive with attack chain | `./get-event-detail.sh <event_id>` |
| `list-waf-events.sh` | WAF security events from SLS | `./list-waf-events.sh [time_range] [attack_type]` |
| `verify-log-delivery.sh` | Verify SLS log delivery | `./verify-log-delivery.sh` |

### Time Range Options

All scripts accept these time range values:
- `last15Min`, `lastHour`, `last4Hours`, `last24Hours`, `last7Days`, `last30Days`
- Default: `lastHour`

### Severity Options

- `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`
- Default: all severities

---

## API Naming Conventions

**CRITICAL:** Alibaba Cloud CLI requires **lowercase API names with hyphens**, different from Dart SDK's PascalCase.

| CLI (lowercase with hyphens) | Dart SDK (PascalCase) |
|------------------------------|----------------------|
| `describe-susp-events` | `DescribeAlarmEventList` |
| `describe-susp-event-detail` | `DescribeSuspEventDetail` |
| `describe-version-config` | `DescribeVersionConfig` |

For complete naming conventions, see [references/api-naming.md](references/api-naming.md).

---

## Security Center Edition Limitations

| Edition | Code | Agentic SOC | Event Listing API | Workaround |
|---------|------|-------------|-------------------|------------|
| Basic | 1 | ❌ | ❌ (timeout) | Use SLS direct queries |
| Anti-virus | 2 | ❌ | Limited | Use SLS direct queries |
| Advanced | 3 | ❌ | Limited | Use SLS direct queries |
| Enterprise | 4 | ✅ | ✅ Full access | N/A |
| Ultimate | 5 | ✅ | ✅ Full access | N/A |

**If scripts timeout or return 403:** Your account may be on Basic/Advanced edition.
See [references/edition-limits.md](references/edition-limits.md) for workarounds.

---

## Error Handling

### Common Errors

| Error | Cause | Remedy |
|-------|-------|--------|
| `aliyun: command not found` | CLI not installed | `brew install aliyun-cli` (macOS) |
| `InvalidAccessKeyId.NotFound` | Wrong AccessKey ID | Check `.env` file, regenerate in RAM Console |
| `SignatureDoesNotMatch` | Wrong AccessKey Secret | Copy secret again, no trailing whitespace |
| `Forbidden.RAM` | Missing RAM policy | Attach `AliyunYundunSASReadOnlyAccess` policy |
| API timeout (10s) | Basic edition limitation | Use SLS direct queries or upgrade edition |
| `describe-susp-events: command not found` | Wrong API name format | Use lowercase with hyphens, not PascalCase |

### JSON Parsing

All scripts pipe output through `python3 -m json.tool` for formatting. If JSON parsing fails:
1. Check API returned actual data (not error message)
2. Verify credentials are valid
3. Check Security Center edition supports the API

---

## Integration with Core Skill

These scripts are called from [blueteam-autopilot-core](../blueteam-autopilot-core/) behaviors:

- **Behavior 1 (Discovery):** `list-events.sh`
- **Behavior 2 (Deep-Dive):** `get-event-detail.sh`
- **Behavior 5 (Reporting):** WAF events via `list-waf-events.sh`

Alternatively, use MCP tools directly if available:
- `list_security_events` instead of `list-events.sh`
- `get_security_event_detail` instead of `get-event-detail.sh`

---

## Troubleshooting

### No Events Returned

1. Verify time range is correct (events may be outside window)
2. Check Security Center edition supports event listing
3. Try broader time range: `./list-events.sh last24Hours`

### API Returns 403

1. Check RAM permissions: `AliyunYundunSASReadOnlyAccess` required
2. Verify credentials are active (not expired STS tokens)
3. Check if API is temporarily unavailable (retry after 2-3 minutes)

### WAF Events Not Found

1. Verify WAF instance exists: `aliyun waf-openapi describe-instance --region "$ALIBABA_REGION"`
2. Check log delivery is enabled (use `verify-log-delivery.sh`)
3. Ensure WAF logs are flowing to SLS
