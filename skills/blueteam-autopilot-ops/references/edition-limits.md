# Security Center Edition Limitations

Different Security Center editions have different API access levels. This document outlines the limitations and workarounds.

---

## Edition Matrix

| Edition | Code | Price Tier | Agentic SOC | Event Listing | API Access |
|---------|------|------------|-------------|---------------|------------|
| Basic | 1 | Free | ❌ | ❌ (timeout) | Limited |
| Anti-virus | 2 | Low | ❌ | Limited | Limited |
| Advanced | 3 | Medium | ❌ | Limited | Partial |
| Enterprise | 4 | High | ✅ | ✅ Full access | Full |
| Ultimate | 5 | Highest | ✅ | ✅ Full access | Full + Premium |

---

## How to Check Your Edition

```bash
aliyun sas describe-version-config --region "$ALIBABA_REGION" 2>&1 | \
  python3 -c "import sys, json; data=json.load(sys.stdin); print(f'Edition Code: {data.get(\"VersionConfig\", {}).get(\"Edition\", \"N/A\")}')"
```

**Edition Codes:**
- 1 = Basic
- 2 = Anti-virus
- 3 = Advanced
- 4 = Enterprise
- 5 = Ultimate

---

## API Access by Edition

### Security Center Event APIs

| API | Basic (1) | Anti-virus (2) | Advanced (3) | Enterprise (4) | Ultimate (5) |
|-----|-----------|----------------|--------------|----------------|--------------|
| `describe-susp-events` | ❌ Timeout | ⚠️ Limited | ⚠️ Limited | ✅ Full | ✅ Full |
| `describe-susp-event-detail` | ❌ 403 | ⚠️ Partial | ⚠️ Partial | ✅ Full | ✅ Full |
| `describe-version-config` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `describe-cloud-center-instances` | ✅ | ✅ | ✅ | ✅ | ✅ |

### Agentic SOC APIs

| Feature | Basic (1) | Anti-virus (2) | Advanced (3) | Enterprise (4) | Ultimate (5) |
|---------|-----------|----------------|--------------|----------------|--------------|
| Response Policies | ❌ | ❌ | ❌ | ✅ | ✅ |
| Execute Policy | ❌ | ❌ | ❌ | ✅ | ✅ |
| Detection Rules | ❌ | ❌ | ❌ | ✅ | ✅ |

---

## Symptoms of Edition Limitations

### Timeout on Event Listing

**Symptom:**
```bash
$ aliyun sas describe-susp-events --region "ap-southeast-1"
# Command hangs for 10+ seconds, then times out
```

**Root Cause:** Basic/Advanced edition does not support Agentic SOC event listing API

**Workarounds:**

#### Workaround 1: Query SLS Directly (Recommended for Basic/Advanced)

WAF logs still flow to SLS even on Basic edition:

```bash
# Query WAF logs from SLS (works on all editions)
FROM_TS=$(date -u -v-1H +%s)
TO_TS=$(date -u +%s)
aliyun sls GetLogs \
  --project "wafnew-project-ACCOUNT_ID-$ALIBABA_REGION" \
  --logstore "wafnew-logstore" \
  --from "$FROM_TS" \
  --to "$TO_TS" \
  --query "*" \
  --line 50 \
  --region "$ALIBABA_REGION"
```

#### Workaround 2: Use WAF-Specific Tools

WAF tools work independently of Security Center edition:

```bash
# List WAF top IPs (works on all editions with WAF enabled)
aliyun waf-openapi describe-instance --region "$ALIBABA_REGION"

# Query WAF logs via SLS
../blueteam-autopilot-ops/scripts/list-waf-events.sh lastHour
```

#### Workaround 3: Upgrade to Enterprise

1. Go to [Security Center Purchase Page](https://common-buy-intl.alibabacloud.com/?commodityCode=swas_intl)
2. Select **Enterprise** edition
3. Complete purchase
4. Wait 5-10 minutes for upgrade to propagate
5. Verify:
   ```bash
   aliyun sas describe-version-config --region "$ALIBABA_REGION"
   ```

---

### 403 Forbidden on Agentic SOC APIs

**Symptom:**
```bash
$ aliyun sas describe-susp-event-detail --region "ap-southeast-1" --suspicious-event-id "evt-xxx"
ERROR: Forbidden.RAM - You are not authorized to perform this action
```

**Root Cause:** Agentic SOC APIs require Enterprise/Ultimate edition

**Workaround:** Same as timeout workarounds above

---

## What Works on Basic Edition

| Feature | Status | Notes |
|---------|--------|-------|
| WAF instance discovery | ✅ | `describe-instance` |
| WAF domain listing | ✅ | `describe-domains` |
| WAF log delivery to SLS | ✅ | Requires manual enablement |
| SLS log queries | ✅ | Direct SLS API access |
| Asset listing | ✅ | `describe-cloud-center-instances` |
| Version config check | ✅ | `describe-version-config` |
| Agentic SOC events | ❌ | Requires Enterprise+ |
| Response policies | ❌ | Requires Enterprise+ |
| Policy execution | ❌ | Requires Enterprise+ |

---

## Upgrade Recommendation

**For Development/Testing:**
- Basic edition is sufficient for:
  - Testing WAF integration
  - Querying SLS logs
  - Validating asset discovery
- Not sufficient for:
  - Agentic SOC workflows
  - Response policy testing

**For Production:**
- Enterprise edition recommended for:
  - Full Agentic SOC feature access
  - Automated response policies
  - Complete event visibility
- Ultimate edition for:
  - Premium support
  - Advanced analytics
  - Custom detection rules

---

## Migration Path

If you're currently on Basic/Advanced and need Agentic SOC features:

1. **Immediate:** Use SLS direct queries for WAF logs
   ```bash
   ../blueteam-autopilot-ops/scripts/list-waf-events.sh lastHour
   ```

2. **Short-term:** Upgrade to Enterprise edition
   - Wait 5-10 minutes after upgrade
   - Verify edition: `aliyun sas describe-version-config`

3. **Long-term:** Migrate from CLI scripts to MCP tools
   - MCP server (`alibaba_security_mcp`) handles edition limitations gracefully
   - Provides unified interface regardless of edition
   - Type-safe responses with error handling

---

## Troubleshooting

### "API works sometimes, fails others"

This is typical of Advanced edition — some APIs have partial access. Check which specific APIs are limited:

```bash
# Test each API
aliyun sas describe-susp-events --region "$ALIBABA_REGION" 2>&1 | head -5
aliyun sas describe-susp-event-detail --region "$ALIBABA_REGION" --suspicious-event-id "test" 2>&1 | head -5
```

### "Upgraded but still getting 403"

1. Wait 10-15 minutes for upgrade to propagate
2. Verify edition actually changed:
   ```bash
   aliyun sas describe-version-config --region "$ALIBABA_REGION"
   ```
3. Check if Edition code is now 4 or 5
4. If still showing old edition, contact Alibaba Cloud support
