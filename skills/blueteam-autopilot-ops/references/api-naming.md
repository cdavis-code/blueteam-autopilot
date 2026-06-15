# API Naming Conventions

Alibaba Cloud CLI uses different naming conventions than the Dart SDK. This document captures the patterns discovered during POC testing.

---

## CLI vs. Dart SDK Naming

### Security Center (SAS)

| CLI API Name (lowercase with hyphens) | Dart SDK API Name (PascalCase) | Purpose |
|---------------------------------------|-------------------------------|---------|
| `describe-susp-events` | `DescribeAlarmEventList` | List security events |
| `describe-susp-event-detail` | `DescribeSuspEventDetail` | Get event detail |
| `describe-version-config` | `DescribeVersionConfig` | Get Security Center edition |
| `describe-cloud-center-instances` | `DescribeCloudCenterInstances` | List assets |

**Product Code:** `sas` (not `tds`)

**CLI Usage:**
```bash
aliyun sas describe-susp-events --region "$ALIBABA_REGION"
```

**Dart Usage:**
```dart
await client.describeAlarmEventList(DescribeAlarmEventListRequest(regionId: region));
```

---

### WAF (waf-openapi)

| CLI API Name | Dart SDK API Name | API Version | Notes |
|--------------|-------------------|-------------|-------|
| `describe-instance` | `DescribeInstance` | 2021-10-01 | Newer API |
| `describe-domains` | `DescribeDomains` | 2021-10-01 | Uses `--InstanceId` |
| `describe-log-service-status` | `DescribeLogServiceStatus` | 2019-09-10 | Uses `--instance-id` |
| `describe-resource-log-status` | `DescribeResourceLogStatus` | 2019-09-10 | Uses `--instance-id` |

**Product Code:** `waf-openapi`

**API Version Compatibility:**

| API Version | Parameter Style | Example |
|-------------|----------------|---------|
| 2021-10-01 (newer) | PascalCase: `--InstanceId` | `--InstanceId "waf_v2intl-xxx"` |
| 2019-09-10 (older) | lowercase with hyphens: `--instance-id` | `--instance-id "waf_v2intl-xxx"` |

**CLI Usage:**
```bash
# Newer API (2021-10-01)
aliyun waf-openapi describe-instance \
  --region "$ALIBABA_REGION"

# Older API (2019-09-10) - requires explicit version
aliyun waf-openapi describe-log-service-status \
  --region "$ALIBABA_REGION" \
  --instance-id "$INSTANCE_ID" \
  --api-version 2019-09-10
```

---

### Simple Log Service (SLS)

| CLI API Name | Dart SDK API Name | Notes |
|--------------|-------------------|-------|
| `get-logs` | `GetLogs` | Query logs |
| `list-project` | `ListProject` | List SLS projects |
| `list-log-stores` | `ListLogStores` | List logstores |
| `get-index` | `GetIndex` | Get logstore index config |

**Product Code:** `sls`

**CLI Usage:**
```bash
aliyun sls get-logs \
  --project "wafnew-project-ACCOUNT_ID-REGION" \
  --logstore "wafnew-logstore" \
  --from "$FROM_TS" \
  --to "$TO_TS" \
  --query "*" \
  --region "$ALIBABA_REGION"
```

---

## Common Errors and Fixes

### Error: API name not found

**Symptom:**
```
ERROR: InvalidApiName.DescribeAlarmEventList is not found
```

**Cause:** Using Dart SDK PascalCase name with CLI

**Fix:** Use lowercase with hyphens:
```bash
# Wrong
aliyun sas DescribeAlarmEventList --region "$ALIBABA_REGION"

# Correct
aliyun sas describe-susp-events --region "$ALIBABA_REGION"
```

---

### Error: Parameter not found

**Symptom:**
```
ERROR: InvalidParameter.InstanceId is not found
```

**Cause:** Using wrong API version parameter style

**Fix:** Match parameter style to API version:
```bash
# For 2021-10-01 API
aliyun waf-openapi describe-domains --InstanceId "$ID"

# For 2019-09-10 API
aliyun waf-openapi describe-log-service-status --instance-id "$ID" --api-version 2019-09-10
```

---

### Error: Product code not found

**Symptom:**
```
ERROR: InvalidProductCode.tds is not found
```

**Cause:** Using wrong product code for Security Center

**Fix:** Use `sas` not `tds`:
```bash
# Wrong
aliyun tds describe-susp-events --region "$ALIBABA_REGION"

# Correct
aliyun sas describe-susp-events --region "$ALIBABA_REGION"
```

---

## Naming Pattern Rules

### CLI API Names
1. Convert PascalCase to lowercase
2. Insert hyphens before capital letters (except first)
3. Examples:
   - `DescribeAlarmEventList` → `describe-alarm-event-list`
   - `DescribeSuspEventDetail` → `describe-susp-event-detail`
   - `DescribeVersionConfig` → `describe-version-config`

### CLI Parameters
1. Newer APIs (2021-10-01): Keep PascalCase (`--InstanceId`)
2. Older APIs (2019-09-10): Use lowercase with hyphens (`--instance-id`)
3. When in doubt, check error message for expected parameter name

### Product Codes
| Service | Product Code | Notes |
|---------|--------------|-------|
| Security Center | `sas` | NOT `tds` |
| WAF 3.0 | `waf-openapi` | NOT `waf` |
| SLS | `sls` | Standard |
| RAM | `ram` | Standard |
| STS | `sts` | Standard |

---

## Quick Reference Card

```bash
# Security Center
aliyun sas describe-susp-events --region "$REGION"
aliyun sas describe-susp-event-detail --region "$REGION" --suspicious-event-id "$EVENT_ID"
aliyun sas describe-version-config --region "$REGION"

# WAF (newer API)
aliyun waf-openapi describe-instance --region "$REGION"
aliyun waf-openapi describe-domains --region "$REGION" --InstanceId "$INSTANCE_ID"

# WAF (older API)
aliyun waf-openapi describe-log-service-status --region "$REGION" --instance-id "$INSTANCE_ID" --api-version 2019-09-10

# SLS
aliyun sls get-logs --project "$PROJECT" --logstore "$LOGSTORE" --from "$FROM" --to "$TO" --region "$REGION"
```
