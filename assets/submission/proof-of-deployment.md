# Proof of Alibaba Cloud Deployment

This document demonstrates that Alibaba Blueteam's backend runs on Alibaba Cloud services and APIs.

## Alibaba Cloud Services Used

| Service | API Product | Purpose |
|---------|------------|---------|
| Security Center (SAS) | `sas` | Security events, alerts, vulnerabilities, asset inventory |
| WAF 3.0 | `waf-openapi` | WAF instance discovery, attack logs, top rules, top attacker IPs |
| Simple Log Service (SLS) | `sls` | WAF log queries, project/logstore discovery, log delivery verification |
| Virtual Private Cloud (VPC) | `vpc` | Network discovery, VPC attributes, VPN gateway enumeration |
| Security Token Service (STS) | `sts` | Account identity discovery (GetCallerIdentity) |

## Code Files Demonstrating Alibaba Cloud API Usage

### 1. Security Center (SAS) APIs

| File | API Call | Line |
|------|----------|------|
| [list-events.sh](skills/blueteam-autopilot-ops/scripts/list-events.sh) | `aliyun sas describe-susp-events` | L51, L57 |
| [get-event-detail.sh](skills/blueteam-autopilot-ops/scripts/get-event-detail.sh) | `aliyun sas describe-susp-event-detail` | L49 |
| [list-alerts.sh](skills/blueteam-autopilot-ops/scripts/list-alerts.sh) | `aliyun sas describe-susp-event-detail` | L49 |
| [list-vulnerabilities.sh](skills/blueteam-autopilot-ops/scripts/list-vulnerabilities.sh) | `aliyun sas describe-vul-list` | L60 |
| [get-vulnerability-detail.sh](skills/blueteam-autopilot-ops/scripts/get-vulnerability-detail.sh) | `aliyun sas describe-vul-details` | L49 |
| [get-account-context.sh](skills/blueteam-autopilot-ops/scripts/get-account-context.sh) | `aliyun sas describe-version-config` | L44 |

### 2. WAF 3.0 APIs

| File | API Call | Line |
|------|----------|------|
| [get-waf-instance.sh](skills/blueteam-autopilot-ops/scripts/get-waf-instance.sh) | `aliyun waf-openapi describe-instance` | L41 |
| [list-waf-top-rules.sh](skills/blueteam-autopilot-ops/scripts/list-waf-top-rules.sh) | `aliyun waf-openapi describe-rule-hits-top-rule-id` | L90 |
| [list-waf-top-ips.sh](skills/blueteam-autopilot-ops/scripts/list-waf-top-ips.sh) | `aliyun waf-openapi describe-rule-hits-top-client-ip` | L90 |

### 3. Simple Log Service (SLS) APIs

| File | API Call | Line |
|------|----------|------|
| [list-waf-events.sh](skills/blueteam-autopilot-ops/scripts/list-waf-events.sh) | `aliyun sls GetLogs` | L95 |
| [verify-log-delivery.sh](skills/blueteam-autopilot-ops/scripts/verify-log-delivery.sh) | `aliyun sls GetProject`, `aliyun sls ListLogStores` | L68, L91 |
| [generate-trusted-networks.sh](skills/blueteam-autopilot-prep/scripts/generate-trusted-networks.sh) | `aliyun sls GetLogs` | L353 |

### 4. VPC APIs

| File | API Call | Line |
|------|----------|------|
| [generate-trusted-networks.sh](skills/blueteam-autopilot-prep/scripts/generate-trusted-networks.sh) | `aliyun vpc DescribeVpcs` | L69 |
| [generate-trusted-networks.sh](skills/blueteam-autopilot-prep/scripts/generate-trusted-networks.sh) | `aliyun vpc DescribeVpcAttribute` | L87 |
| [generate-trusted-networks.sh](skills/blueteam-autopilot-prep/scripts/generate-trusted-networks.sh) | `aliyun vpc DescribeVpnGateways` | L122 |

### 5. STS APIs

| File | API Call | Line |
|------|----------|------|
| [list-waf-events.sh](skills/blueteam-autopilot-ops/scripts/list-waf-events.sh) | `aliyun sts GetCallerIdentity` | L40 |

### 6. WAF 3.0 Extended APIs (prep skill)

| File | API Call | Line |
|------|----------|------|
| [SKILL.md](skills/blueteam-autopilot-prep/SKILL.md) | `aliyun waf-openapi DescribeInstance` | L342 |
| [SKILL.md](skills/blueteam-autopilot-prep/SKILL.md) | `aliyun waf-openapi DescribeDomains` | L410 |
| [SKILL.md](skills/blueteam-autopilot-prep/SKILL.md) | `aliyun waf-openapi describe-log-service-status` | L429 |
| [SKILL.md](skills/blueteam-autopilot-prep/SKILL.md) | `aliyun waf-openapi describe-resource-log-status` | L437 |
| [SKILL.md](skills/blueteam-autopilot-prep/SKILL.md) | `aliyun waf-openapi modify-resource-log-status` | L451 |

## Summary

- **5 Alibaba Cloud services** integrated
- **17 CLI scripts** making live API calls in real mode
- **25+ distinct API operations** across SAS, WAF 3.0, SLS, VPC, STS
- All API calls authenticated via RAM user credentials (AccessKey ID/Secret)
- Region dynamically discovered via `get_account_context` / STS GetCallerIdentity
- Dual-mode architecture: same scripts return fixture data in demo mode, live API data in real mode
