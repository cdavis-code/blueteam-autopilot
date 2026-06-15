---
name: blueteam-autopilot-prep
description: Validate Alibaba Cloud environment readiness for BlueTeam Autopilot — checks credentials, services (Security Center, WAF, Agentic SOC, SLS), infrastructure, and permissions.
allowed-tools:
  - Bash
  - Read
---

# BlueTeam Autopilot Environment Validator

Environment readiness skill for **BlueTeam Autopilot for Alibaba Cloud**. Guides users through validating their Alibaba Cloud environment — credentials, services, infrastructure, and permissions — before running the Autopilot solution.

## When to Use

Invoke this skill when:
- Setting up the BlueTeam Autopilot environment for the first time
- Validating that Alibaba Cloud credentials and services are properly configured
- Troubleshooting connectivity or permission issues with Security Center, WAF, Agentic SOC, or SLS
- Preparing for a demo or hackathon presentation and need to confirm the environment is ready

## Configuration

This skill requires three environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `ALIBABA_ACCESS_KEY_ID` | RAM user AccessKey ID | `LTAI5t...` |
| `ALIBABA_ACCESS_KEY_SECRET` | RAM user AccessKey Secret | `HkfZ...` |
| `ALIBABA_REGION` | Target Alibaba Cloud region | `ap-southeast-1` |

> **Important:** `ALIBABA_REGION` must be a valid region ID (e.g., `ap-southeast-1`), not a display name like "Singapore".

### Additional Local Tooling

Beyond the `aliyun` CLI (validated in Stage 1), ensure these tools are available:

| Tool | Verify | Purpose |
|------|--------|---------|
| Dart SDK ≥ 3.4 | `dart --version` | Run MCP server and CLI packages |
| Python 3.10+ | `python3 --version` | Qwen-Agent integration |
| `qwen-agent[mcp]` | `pip show qwen-agent` | AI agent loop validation |
| `dig` (DNS utils) | `dig -v` | Verify WAF CNAME resolution |
| `curl` | `curl --version` | Generate test WAF traffic |

**Optional but helpful:**
- `pip show qwen-agent` - Confirm Qwen-Agent is installed for §8 testing
- `dart --version` - Confirm Dart SDK for MCP server validation

## Validation Steps

Execute the following validation stages **in order**. The agent should **automate** these steps without requiring manual user intervention, except where explicitly noted.

> **Autonomous Operation Mode:**
> This skill is designed to run automatically during environment setup. The agent will:
> 1. Detect and validate prerequisites
> 2. Generate environment-specific configuration files
> 3. Validate the complete setup
> 4. Report any issues requiring manual attention
>
> Only stages requiring console access (detection rules, manual verification) need user interaction.

---

### Stage 1: Prerequisites — aliyun CLI Installation

**Check:** Verify the `aliyun` CLI tool is installed and accessible.

```bash
which aliyun && aliyun version
```

**If missing**, provide OS-specific installation instructions:

#### macOS (Homebrew)
```bash
brew install aliyun-cli
```

#### Linux (direct download)
```bash
# Download latest release
curl -fsSL https://aliyuncli.alicdn.com/aliyun-cli-linux-latest-amd64.tgz -o aliyun-cli.tgz
tar -xzf aliyun-cli.tgz
sudo mv aliyun /usr/local/bin/
aliyun version
```

#### Windows (Chocolatey or direct download)
```powershell
# Using Chocolatey
choco install aliyun-cli

# Or download from GitHub
# https://github.com/aliyun/aliyun-cli/releases
```

**Documentation:** https://github.com/aliyun/aliyun-cli

**After install, configure credentials:**
```bash
aliyun configure set \
  --profile blueteam \
  --mode AK \
  --access-key-id "$ALIBABA_ACCESS_KEY_ID" \
  --access-key-secret "$ALIBABA_ACCESS_KEY_SECRET" \
  --region "$ALIBABA_REGION"
```

---

### Stage 2: Credential Validation

**Check:** Verify that the provided credentials are valid and can authenticate, and derive the RAM username for later stages.

```bash
# Capture caller identity response
CALLER_IDENTITY=$(aliyun sts GetCallerIdentity \
  --access-key-id "$ALIBABA_ACCESS_KEY_ID" \
  --access-key-secret "$ALIBABA_ACCESS_KEY_SECRET" \
  --region "$ALIBABA_REGION" 2>&1)
echo "$CALLER_IDENTITY"

# Extract the short RAM username from the Arn (e.g. acs:ram::<account-id>:user/alibaba-security-mcp → alibaba-security-mcp)
export RAM_USERNAME=$(echo "$CALLER_IDENTITY" | grep -o '"Arn":"[^"]*"' | sed 's/.*:user\///'  | tr -d '"')
echo "✓ Derived RAM_USERNAME=$RAM_USERNAME"

# Extract the Alibaba Cloud Account ID for use in SLS project names and resource ARNs
export ACCOUNT_ID=$(echo "$CALLER_IDENTITY" | grep -o '"AccountId":"[^"]*"' | cut -d'"' -f4)
if [ -n "$ACCOUNT_ID" ]; then
  echo "✓ Derived ACCOUNT_ID=$ACCOUNT_ID"
else
  echo "⚠️  Could not extract ACCOUNT_ID from GetCallerIdentity response"
  echo "   You will need to manually replace YOUR_ACCOUNT_ID placeholders in later stages"
fi
```

**Expected:** A JSON response with `AccountId`, `Arn`, and `Type` fields. `RAM_USERNAME` and `ACCOUNT_ID` are extracted from the response and exported for use in later stages.

**If FAIL — common issues and remedies:**

| Error | Cause | Remedy |
|-------|-------|--------|
| `InvalidAccessKeyId.NotFound` | Wrong or deactivated AccessKey ID | Generate new credentials in [RAM Console](https://ram.console.alibabacloud.com/users) |
| `SignatureDoesNotMatch` | Wrong AccessKey Secret | Copy the secret again from RAM Console; ensure no trailing whitespace |
| `InvalidAccessKeyId` + `Forbidden` | Credentials are STS tokens that expired | Refresh STS credentials or switch to long-lived AK/SK |

**Docs:** [RAM User Management](https://www.alibabacloud.com/help/en/ram/user-guide/create-a-ram-user)

---

### Stage 3: RAM Permission Validation

**Check:** Verify the RAM user has the required policies attached for all BlueTeam Autopilot services.

#### Required Policies

| Policy | Service | Purpose |
|--------|---------|---------|
| `AliyunYundunSASReadOnlyAccess` | Security Center | Read alerts, events, vulnerabilities |
| `AliyunYundunWAFFullAccess` | WAF 3.0 | Manage WAF domains, log status, response policies |
| `AliyunLogFullAccess` | Simple Log Service (SLS) | Read WAF logs, manage logstores |
| `AliyunYundunSASFullAccess` | Security Center (full) | Execute response policies (optional, for real mode) |
| `AliyunRAMReadOnlyAccess` | RAM | Verify own permissions (optional but helpful) |

> **Self-Verification Tip:** Attaching `AliyunRAMReadOnlyAccess` lets the RAM user run `aliyun ram ListPoliciesForUser --UserName "$RAM_USERNAME"` to audit their own permissions without console access.

**Validation commands:**

```bash
# Load environment variables if not already set
if [ -z "$ALIBABA_ACCESS_KEY_ID" ]; then
  if [ -f .env ]; then
    source .env
    echo "✓ Loaded environment variables from .env"
  else
    echo "⚠️  Environment variables not set. Please create a .env file or export them manually."
    echo "   Required: ALIBABA_ACCESS_KEY_ID, ALIBABA_ACCESS_KEY_SECRET, ALIBABA_REGION"
  fi
fi

# Test Security Center access (uses 'sas' product code, not 'tds')
aliyun sas DescribeVersionConfig --region "$ALIBABA_REGION" 2>&1 | head -5

# Test WAF access (discover instance first)
aliyun waf-openapi DescribeInstance --region "$ALIBABA_REGION" 2>&1 | head -10

# Test SLS access
aliyun sls ListProject --region "$ALIBABA_REGION" 2>&1 | head -5

# Self-verification (optional, requires AliyunRAMReadOnlyAccess)
# Uses $RAM_USERNAME derived from Stage 2 GetCallerIdentity Arn
aliyun ram ListPoliciesForUser --UserName "$RAM_USERNAME" 2>&1 | grep -o '"PolicyName":"[^"]*"'
```

**If FAIL — `Forbidden.RAM` or `Forbidden` errors:**

```bash
# Attach policies via CLI (requires RAM admin access)
aliyun ram AttachPolicyToUser \
  --PolicyType System \
  --PolicyName AliyunYundunSASReadOnlyAccess \
  --UserName "$RAM_USERNAME"

aliyun ram AttachPolicyToUser \
  --PolicyType System \
  --PolicyName AliyunYundunWAFFullAccess \
  --UserName "$RAM_USERNAME"

aliyun ram AttachPolicyToUser \
  --PolicyType System \
  --PolicyName AliyunLogFullAccess \
  --UserName "$RAM_USERNAME"
```

Or attach via [RAM Console → Users → your user → Permissions → Add permissions](https://ram.console.alibabacloud.com/users).

**Docs:** [RAM Policy Management](https://www.alibabacloud.com/help/en/ram/user-guide/grant-permissions-to-a-ram-user)

---

### Stage 4: Service Enablement Check

Verify each required Alibaba Cloud service is activated in the target region.

#### 4.1 Security Center

```bash
aliyun sas DescribeVersionConfig --region "$ALIBABA_REGION" 2>&1
```

**Expected:** Response with `VersionConfig` showing edition info (Basic, Anti-virus, Advanced, Enterprise, or Ultimate).

**If service not enabled:**
- Go to [Security Center Console](https://yundun.console.alibabacloud.com/?p=sas)
- Click **Activate** or **Upgrade** to at least the **Advanced** edition for Agentic SOC support
- **Docs:** [Activate Security Center](https://www.alibabacloud.com/help/en/security-center/getting-started/activate-security-center)

#### 4.2 Agentic SOC

```bash
# Agentic SOC is part of Security Center Enterprise/Ultimate
# Verify by checking Security Center edition (must be Enterprise or Ultimate)
aliyun sas DescribeVersionConfig --region "$ALIBABA_REGION" 2>&1 | grep -o '"Edition":[0-9]*'
# Edition codes: 1=Basic, 2=Anti-virus, 3=Advanced, 4=Enterprise, 5=Ultimate
```

**Expected:** Edition value ≥ 4 (Enterprise or Ultimate).

**If check FAILS (API returns 403 or edition < 4):**

**Option A — Edition too low (Basic/Anti-virus/Advanced):**
1. Upgrade to Enterprise or Ultimate edition:
   - Go to [Security Center Purchase Page](https://common-buy-intl.alibabacloud.com/?commodityCode=swas_intl)
   - Select **Enterprise** (recommended for production) or **Ultimate**
   - Complete the purchase
2. Wait 5-10 minutes for the upgrade to propagate
3. Re-run the validation:
   ```bash
   aliyun sas DescribeVersionConfig --region "$ALIBABA_REGION" 2>&1 | grep -o '"Edition":[0-9]*'
   ```
4. Verify Edition value is now 4 or 5

**Option B — API temporarily unavailable (403 error):**
1. This is a transient issue with the Security Center API
2. Wait 2-3 minutes and retry the command
3. If still failing, verify manually via console:
   - Go to [Security Center Console](https://yundun.console.alibabacloud.com/?p=sas)
   - Check the edition banner at the top of the page
   - If it shows "Enterprise" or "Ultimate", Agentic SOC is available
4. Continue with other validation stages and retry this check last

**Docs:** [Agentic SOC Quick Start](https://www.alibabacloud.com/help/en/security-center/getting-started/use-agentic-soc-quickly)
**Purchase:** [Security Center Upgrade](https://common-buy-intl.alibabacloud.com/?commodityCode=swas_intl)

#### 4.3 WAF 3.0

```bash
aliyun waf-openapi DescribeInstance --region "$ALIBABA_REGION" 2>&1
```

**Expected:** Response containing `InstanceId` (e.g., `waf_v2intl_public_intl-sg-...`).

**If no WAF instance found:**
- Go to [WAF Console](https://yundun.console.alibabacloud.com/?p=waf)
- Purchase or activate WAF 3.0
- **Docs:** [WAF 3.0 Getting Started](https://www.alibabacloud.com/help/en/waf/web-application-firewall-3-0/getting-started/get-started-with-waf-3)

#### 4.4 WAF-Protected Domain (CNAME Verification)

After confirming WAF instance exists, verify your test domain is properly configured:

```bash
# Replace with your actual test domain
export TEST_DOMAIN="ecs.yourdomain.com"

# Verify DNS points to WAF CNAME
dig +short CNAME $TEST_DOMAIN
```

**Expected:** Should return a CNAME ending in `*.aliyunwaf*.com` (e.g., `ecs.yourdomain.com.waf.alikunlun.com`).

**If CNAME not found or incorrect:**
1. Verify domain is added in WAF Console → Website Access
2. Update your DNS provider to point the domain to the WAF CNAME
3. Wait for DNS propagation (usually 5-15 minutes)
4. Re-run the `dig` command

> **Common Mistake:** Forgetting to update DNS at your registrar after adding the domain to WAF. The WAF console shows the CNAME target — copy it exactly.

#### 4.5 Simple Log Service (SLS)

```bash
aliyun sls ListProject --region "$ALIBABA_REGION" 2>&1
```

**Expected:** List of SLS projects (at minimum, a WAF-related project like `wafnew-project-*`).

**If SLS not activated:**
- Go to [SLS Console](https://sls.console.alibabacloud.com/)
- Click **Activate Log Service**
- **Docs:** [SLS Quick Start](https://www.alibabacloud.com/help/en/log-service/getting-started/quick-start)

---

### Stage 5: Infrastructure Validation

Verify the specific infrastructure components required by the BlueTeam Autopilot solution.

#### 5.1 WAF Instance and Protected Domains

```bash
# Get WAF instance ID (use python3 for reliable JSON parsing)
INSTANCE_ID=$(aliyun waf-openapi DescribeInstance --region "$ALIBABA_REGION" 2>&1 | \
  python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('InstanceId',''))" 2>/dev/null)

if [ -z "$INSTANCE_ID" ]; then
  echo "❌ No WAF instance found. Please activate WAF 3.0 first."
  exit 1
fi

echo "✓ WAF Instance ID: $INSTANCE_ID"

# List protected domains (note: --InstanceId with PascalCase for 2021-10-01 API version)
aliyun waf-openapi DescribeDomains \
  --region "$ALIBABA_REGION" \
  --InstanceId "$INSTANCE_ID" 2>&1
```

**Expected:** At least one protected domain with CNAME access mode.

**If no domains configured:**
1. Go to [WAF Console → Website Access](https://yundun.console.alibabacloud.com/?p=waf)
2. Click **Add Domain**
3. Enter your domain (e.g., `ecs.yourdomain.com`)
4. Set **Access Mode** to **CNAME**
5. Update your DNS to point to the WAF CNAME
- **Docs:** [Add a Domain to WAF](https://www.alibabacloud.com/help/en/waf/web-application-firewall-3-0/getting-started/get-started-with-waf-3)

#### 5.2 WAF Log Delivery to SLS

```bash
# Check instance-level log service status (requires explicit API version)
# Note: Use lowercase API name format: describe-log-service-status
aliyun waf-openapi describe-log-service-status \
  --region "$ALIBABA_REGION" \
  --instance-id "$INSTANCE_ID" \
  --api-version 2019-09-10 2>&1

# Check domain-level log collection (replace DOMAIN with your domain-waf identifier)
# Note: WAF resource identifiers use the format "domain.com-waf"
aliyun waf-openapi describe-resource-log-status \
  --region "$ALIBABA_REGION" \
  --instance-id "$INSTANCE_ID" \
  --resources "your-domain.com-waf" \
  --api-version 2019-09-10 2>&1
```

**Expected:** 
- Instance level: `"Status":1` or `"LogServiceEnabled":true`
- Domain level: `"LogEnabled":1` or similar active status

**If check FAILS (API returns 403 — transient unavailability):**

**Immediate workaround — Verify via SLS directly:**
1. Skip the WAF API check and verify logs are actually flowing to SLS:
   ```bash
   FROM_TS=$(date -u -v-30M +%s 2>/dev/null || date -u -d '30 minutes ago' +%s)
   TO_TS=$(date -u +%s)
   aliyun sls GetLogs \
     --project "wafnew-project-${ACCOUNT_ID}-$ALIBABA_REGION" \
     --logstore "wafnew-logstore" \
     --from "$FROM_TS" \
     --to "$TO_TS" \
     --query "*" \
     --line 5 \
     --region "$ALIBABA_REGION" 2>&1 | head -50
   ```
2. If you see WAF logs, **log delivery is working** — proceed to next stage
3. If no logs, log delivery may not be configured — follow the console steps below

**Console configuration (if logs are NOT flowing):**
1. Go to [WAF Console → Detection and Response → Log Service](https://yundun.console.alibabacloud.com/?p=waf)
2. Click **Authorize** if prompted (refreshes the SLS service-linked role)
3. Toggle **Log Service** to ON (instance-level)
4. In **Protected Domains**, find your domain (note: it may show as `domain.com-waf`) and toggle **Log Collection** to ON
5. Wait 2-5 minutes for the configuration to propagate
6. Generate test traffic and verify logs appear in SLS (see Stage 6)

**If API check succeeds but shows log delivery is DISABLED:**
1. Go to [WAF Console → Detection and Response → Log Service](https://yundun.console.alibabacloud.com/?p=waf)
2. Click **Authorize** if prompted (refreshes the SLS service-linked role)
3. Toggle **Log Service** to ON (instance-level)
4. In **Protected Domains**, find your domain (note: it may show as `domain.com-waf`) and toggle **Log Collection** to ON
5. Wait 2-5 minutes for the configuration to propagate
6. Re-run the validation commands

> **Known issue:** The API `modify-resource-log-status` may return `CreateEtlMetaFailed` when enabling domain-level log collection programmatically. Use the **WAF Console UI** as a workaround.

**Docs:** [WAF Log Service Configuration](https://www.alibabacloud.com/help/en/waf/web-application-firewall-3-0/use-cases/best-practices-for-pushing-api-security-alerts)

#### 5.3 SLS Project and Logstore

```bash
# List SLS projects (look for WAF-related project)
aliyun sls ListProject --region "$ALIBABA_REGION" 2>&1 | grep -i waf

# Check for WAF logstore in the project (replace PROJECT_NAME)
aliyun sls ListLogStores \
  --project "wafnew-project-${ACCOUNT_ID}-$ALIBABA_REGION" \
  --region "$ALIBABA_REGION" 2>&1

# Verify index exists on the logstore
aliyun sls GetIndex \
  --project "wafnew-project-${ACCOUNT_ID}-$ALIBABA_REGION" \
  --logstore "wafnew-logstore" \
  --region "$ALIBABA_REGION" 2>&1 | head -20
```

**Expected:** A WAF project with a logstore (`wafnew-logstore`) and an active index.

**If missing:**
- The WAF Log Service setup (Stage 5.2) should auto-create the SLS project and logstore
- If not, create manually via [SLS Console](https://sls.console.alibabacloud.com/)
- **Docs:** [SLS Project Management](https://www.alibabacloud.com/help/en/log-service/user-guide/manage-a-project)

#### 5.4 WAF Domain-Level Log Collection

> **Critical:** Instance-level log enablement is not enough — each domain must have log collection explicitly enabled.

**Console verification (most reliable):**
1. Go to [WAF Console → Detection and Response → Log Service](https://yundun.console.alibabacloud.com/?p=waf)
2. In **Protected Domains** section, find your domain
3. Verify **Log Collection** toggle is ON for your domain (note: it shows as `domain.com-waf`)
4. If OFF, toggle it ON and wait 2-5 minutes for propagation

**Important notes:**
- Domain identifiers in WAF use the format `your-domain.com-waf` (note the `-waf` suffix)
- The global "Log Service" toggle enables it at the instance level, but you still need per-domain enablement
- If the API check in Stage 5.2 returns 403, verify via console — logs may still be flowing to SLS even if the API is temporarily unavailable

#### 5.5 Agentic SOC Detection Rules

> **Note:** There is no direct CLI API to verify Agentic SOC detection rules. Verify manually in the console.

**Manual verification steps:**

1. **Navigate to Detection Rules:**
   - Go to [Security Center → Agentic SOC → Detection Rules](https://yundun.console.alibabacloud.com/?p=sas)
   - You should see a list of predefined detection rules

2. **Verify WAF-related rules are enabled:**
   - Look for rules with names like:
     - "WAF SQL Injection Attack"
     - "WAF XSS Attack"
     - "WAF Malicious File Upload"
     - "WAF Command Injection"
   - Ensure the **Status** column shows **Enabled** for these rules
   - If any are disabled, click the toggle switch to enable them

3. **Verify rule configuration:**
   - Click on each WAF-related rule to review its configuration
   - Ensure the **Alert Level** is set appropriately (Medium or High recommended)
   - Verify **Notification** settings are configured if you want email/SMS alerts

**If no detection rules appear or all are disabled:**

**Remedy 1 — Rules are disabled:**
1. Enable the WAF-related rules manually:
   - Go to [Security Center → Agentic SOC → Detection Rules](https://yundun.console.alibabacloud.com/?p=sas)
   - Select the checkboxes next to WAF-related rules
   - Click **Enable** (or use individual toggle switches)
2. Wait 1-2 minutes for rules to activate
3. Generate test traffic (see Stage 6) and verify events appear

**Remedy 2 — No rules appear at all:**
1. Verify Security Center edition is Enterprise or Ultimate:
   ```bash
   aliyun sas DescribeVersionConfig --region "$ALIBABA_REGION" 2>&1 | grep -o '"Edition":[0-9]*'
   ```
2. If edition < 4, upgrade to Enterprise/Ultimate (see Stage 4.2)
3. After upgrade, wait 10-15 minutes for Agentic SOC features to activate
4. Refresh the Detection Rules page

**Remedy 3 — Rules exist but no events after test traffic:**
1. Confirm WAF logs are flowing to SLS (verify via Stage 5.2 workaround or Stage 6)
2. Ensure test traffic actually hits WAF (check WAF block status):
   ```bash
   curl -v -g "http://your-domain.com/?id=1%27%20OR%201%3D1" 2>&1 | grep -i "waf\|block\|403"
   ```
3. Check Agentic SOC event dashboard:
   - Go to [Security Center → Agentic SOC → Events](https://yundun.console.alibabacloud.com/?p=sas)
   - Filter by time range (last 1 hour)
   - Look for WAF-related events
4. If still no events, the detection rules may need tuning:
   - Contact Alibaba Cloud support or refer to [Agentic SOC Configuration docs](https://www.alibabacloud.com/help/en/security-center/getting-started/use-agentic-soc-quickly)

**Docs:** [Agentic SOC Configuration](https://www.alibabacloud.com/help/en/security-center/getting-started/use-agentic-soc-quickly)

---

### Stage 6: End-to-End Connectivity Test

Run a final integration test to confirm the full pipeline works.

```bash
# 1. Ping Security Center (uses 'sas' product code)
aliyun sas DescribeVersionConfig --region "$ALIBABA_REGION" 2>&1 | grep -o '"Edition":[0-9]*'

# 2. Generate test WAF traffic (replace with your domain)
# If using rtk hook, use: rtk curl instead of curl
curl -s -o /dev/null -w "%{http_code}" -g "http://your-domain.com/?id=1%27%20OR%201%3D1"

# 3. Wait for log propagation
sleep 30

# 4. Verify logs arrived in SLS
FROM_TS=$(date -u -v-10M +%s 2>/dev/null || date -u -d '10 minutes ago' +%s)
TO_TS=$(date -u +%s)
aliyun sls GetLogs \
  --project "wafnew-project-${ACCOUNT_ID}-$ALIBABA_REGION" \
  --logstore "wafnew-logstore" \
  --from "$FROM_TS" \
  --to "$TO_TS" \
  --query "*" \
  --line 3 \
  --region "$ALIBABA_REGION" 2>&1 | head -40
```

> **Note:** If WAF APIs return 403 "system unavailable" errors (transient issue), verify log delivery directly via SLS (step 4) as a fallback.

**Expected:** WAF access logs with `final_action: block` for the SQLi test request.

---

### Stage 7: Automated Configuration Generation

> **AUTOMATED:** This stage runs automatically after successful validation of Stages 1-6.
> No user intervention required unless script execution fails.

After confirming the environment is properly configured, **automatically generate** environment-specific configuration files.

#### 7.1 Generate Trusted Networks Document

**Action:** Execute the trusted networks generation script to auto-populate VPC CIDR blocks and VPN gateway configurations from your Alibaba Cloud environment.

```bash
# Run generation script (requires ALIBABA_REGION to be set)
# Script is located in the prep skill's scripts/ directory and outputs
# to blueteam-autopilot-knowledge/documents/trusted-networks.md
./scripts/generate-trusted-networks.sh
```

**Expected Output:**
```
Generating trusted-networks.md from Alibaba Cloud configuration...
Region: ap-southeast-1

Fetching VPC configurations...
Fetching VPN Gateway configurations...

✓ Generated /path/to/trusted-networks.md
  - VPCs discovered: 3
  - VPN gateways: 1

Review the generated file and add any monitoring service IPs manually.
```

**What this does:**
- Queries `DescribeVpcs` API to discover all VPC CIDR blocks
- Queries `DescribeVpnGateways` API to discover VPN configurations
- Populates the `trusted-networks.md` document with your actual infrastructure
- Marks the document as "AUTO-GENERATED" to prevent manual edits

**If script fails:**

| Error | Cause | Remedy |
|-------|-------|--------|
| `aliyun CLI not found` | Stage 1 not completed | Complete Stage 1 first |
| `ALIBABA_REGION not set` | Missing environment variable | Set `ALIBABA_REGION` in `.env` file |
| `Forbidden.RAM` | Missing VPC/VPN permissions | Attach `AliyunVPCReadOnlyAccess` policy |
| No VPCs discovered | Wrong region or no VPCs | Verify `ALIBABA_REGION` matches your VPC location |

**Post-generation action:**
- The script auto-generates VPC/VPN trusted networks
- **Manual step:** Add monitoring service IPs to the "Monitoring Services" section in `trusted-networks.md`
- Common monitoring IPs to add:
  - Datadog agents
  - New Relic infrastructure
  - Custom APM collectors
  - External health check services (e.g., Pingdom, UptimeRobot)

#### 7.2 Validate Configuration

**Action:** Run the configuration validator to ensure no hardcoded environment-specific values remain in skill files.

```bash
# Run validation script
./scripts/validate-configuration.sh
```

**Expected Output (success):**
```
==========================================
BlueTeam Autopilot Configuration Validator
==========================================

Checking for hardcoded regions...
✓ No hardcoded regions found

Checking for hardcoded IP addresses...
✓ No hardcoded IP addresses found

Checking for hardcoded instance/resource IDs...
✓ No hardcoded instance IDs found

Checking for missing example markers...
✓ trusted-networks.md has example markers
✓ asset-inventory.md has example markers

Checking for dynamic data instructions...
✓ Core SKILL.md references get_account_context

==========================================
✓ All checks passed!
No hardcoded environment-specific values found.
==========================================
```

**If validation fails:**

The script will identify specific files and lines containing hardcoded values:

```
✗ Validation failed
Please remediate the issues listed above.

Run './scripts/generate-trusted-networks.sh' to auto-generate trusted networks
from your Alibaba Cloud configuration.
```

**Common failures and remedies:**

| Failure | Cause | Fix |
|---------|-------|-----|
| Hardcoded region `ap-southeast-1` | Example values not marked | Replace with `{{ALIBABA_REGION}}` or mark as example |
| Hardcoded IPs in non-example files | Manual edits to skill files | Run `generate-trusted-networks.sh` to regenerate |
| Missing example markers | Incomplete migration | Add "EXAMPLE" markers per ENVIRONMENT_INDEPENDENCE.md |

#### 7.3 Update Asset Inventory (Optional)

**Action:** If asset discovery is needed, generate the asset inventory document.

```bash
# Use MCP tool to discover assets (preferred)
# OR generate from CLI if MCP not available
aliyun ecs DescribeInstances --region "$ALIBABA_REGION" --output json > /tmp/ecs-instances.json

# Generate asset-inventory.md from discovered instances
# (See scripts/generate-asset-inventory.sh if available)
```

**Note:** Asset inventory is typically discovered dynamically via `list_assets` MCP tool at runtime. Pre-generating the document is optional and for reference purposes only.

---

### Stage 8: Environment Readiness Summary

> **AUTOMATED:** This stage produces the final readiness report automatically.

After completing all validation and generation stages, produce a comprehensive readiness report.

**Readiness Report Format:**

```
═══════════════════════════════════════════════════════
  BlueTeam Autopilot — Environment Readiness Report
═══════════════════════════════════════════════════════

  Region:       <ALIBABA_REGION>
  Account ID:   <from GetCallerIdentity>
  Checked at:   <timestamp>

  ┌──────────────────────────────────────────────────┐
  │ STAGE                    │ STATUS │ NOTES         │
  ├──────────────────────────────────────────────────┤
  │ 1. aliyun CLI installed  │ ✅/❌   │ version X.Y.Z │
  │ 2. Credentials valid     │ ✅/❌   │ Account: ...  │
  │ 3. RAM permissions       │ ✅/❌   │ Missing: ...  │
  │ 4a. Security Center      │ ✅/❌   │ Edition: ...  │
  │ 4b. Agentic SOC          │ ✅/❌   │ Active/...    │
  │ 4c. WAF 3.0              │ ✅/❌   │ Instance: ... │
  │ 4d. WAF CNAME (DNS)     │ ✅/❌   │ CNAME: ...    │
  │ 4e. SLS                  │ ✅/❌   │ Projects: N   │
  │ 5a. WAF domains          │ ✅/❌   │ Count: N      │
  │ 5b. WAF log delivery     │ ✅/❌   │ Enabled/...   │
  │ 5c. SLS project/logstore │ ✅/❌   │ Index: yes/no │
  │ 5d. Domain-level logs    │ ✅/❌   │ Per-domain ON │
  │ 5e. SOC detection rules  │ ✅/❌   │ Events: N     │
  │ 6. End-to-end test       │ ✅/❌   │ Logs flowing  │
  │ 7a. Generate configs     │ ✅/❌   │ Auto-generated│
  │ 7b. Validate configs     │ ✅/❌   │ All checks ✔  │
  │ 8. Readiness summary     │ ✅/❌   │ Complete      │
  └──────────────────────────────────────────────────┘

  RESULT: <READY / NEEDS ATTENTION>

  Automated tasks completed:
  ✅ Trusted networks generated from cloud configuration
  ✅ Configuration validated (no hardcoded values)
  ✅ Example markers verified

  Issues requiring attention:
  - [list each failed check with remediation link]
  - [ ] Add monitoring service IPs to trusted-networks.md (manual)

═══════════════════════════════════════════════════════
```

**Next Steps Based on Result:**

- **If READY:** Environment is fully configured. Proceed to use BlueTeam Autopilot skills for incident response.
- **If NEEDS ATTENTION:** Address listed issues, then re-run this skill to validate.



## Remediation Quick Reference

This section provides step-by-step fixes for common issues identified in the readiness report.

### Issue 4b: Agentic SOC API Temporarily Unavailable (403)

**Symptom:** `DescribeLogServiceStatus` returns 403 "system unavailable"

**Root Cause:** Transient Security Center API service disruption

**Fix (choose one):**

**Option 1 — Retry with delay:**
```bash
# Wait 2-3 minutes, then retry
sleep 120
aliyun sas DescribeVersionConfig --region "$ALIBABA_REGION" 2>&1 | grep -o '"Edition":[0-9]*'
```

**Option 2 — Manual verification via console:**
1. Open [Security Center Console](https://yundun.console.alibabacloud.com/?p=sas)
2. Look at the edition banner at the top
3. If it shows **Enterprise** or **Ultimate**, Agentic SOC is available
4. Document this in your readiness report and continue with other checks

**Option 3 — Skip and verify later:**
- Continue with Stages 5 and 6
- After completing all other checks, return to this validation
- By that time, the API is usually available

**When to escalate:** If API remains unavailable for >30 minutes, contact Alibaba Cloud support.

---

### Issue 5b: WAF Log Delivery API Check Failed (But SLS Logs Flowing)

**Symptom:** WAF API returns 403, but SLS shows logs are arriving

**Root Cause:** Same transient API issue as 4b, but log delivery is actually working

**Verification (confirm log delivery is working):**
```bash
# Check recent WAF logs in SLS
FROM_TS=$(date -u -v-30M +%s 2>/dev/null || date -u -d '30 minutes ago' +%s)
TO_TS=$(date -u +%s)
aliyun sls GetLogs \
  --project "wafnew-project-${ACCOUNT_ID}-$ALIBABA_REGION" \
  --logstore "wafnew-logstore" \
  --from "$FROM_TS" \
  --to "$TO_TS" \
  --query "*" \
  --line 10 \
  --region "$ALIBABA_REGION" 2>&1 | head -80
```

**If logs appear:**
- ✅ **WAF log delivery is working correctly**
- ✅ **No action needed** — the API check failure is a false negative
- Document: "Log delivery verified via SLS (API temporarily unavailable)"
- Proceed to next stage

**If NO logs appear:**
- Log delivery may not be configured
- Follow the console configuration steps in Stage 5.2
- After enabling, wait 5 minutes and re-check SLS

**When to escalate:** Never — if SLS shows logs, log delivery is working regardless of API status.

---

### Issue 5d: SOC Detection Rules Not Verified Programmatically

**Symptom:** No CLI API exists to check Agentic SOC detection rules

**Root Cause:** Alibaba Cloud hasn't exposed detection rule management via public API

**Manual Verification Steps:**

1. **Check detection rules are enabled:**
   - Open [Security Center → Agentic SOC → Detection Rules](https://yundun.console.alibabacloud.com/?p=sas)
   - Look for these WAF-related rules:
     - WAF SQL Injection Attack
     - WAF XSS Attack
     - WAF Malicious File Upload
     - WAF Command Injection
   - Ensure **Status** shows **Enabled** for each

2. **Test with real traffic:**
   ```bash
   # Generate test SQLi traffic
   curl -s -o /dev/null -w "%{http_code}" -g "http://your-domain.com/?id=1%27%20OR%201%3D1"
   ```

3. **Verify events appear:**
   - Open [Security Center → Agentic SOC → Events](https://yundun.console.alibabacloud.com/?p=sas)
   - Filter: Last 1 hour
   - Look for WAF-related security events
   - If events appear, detection rules are working ✅

**If rules are disabled:**
1. Select the WAF-related rules (checkboxes)
2. Click **Enable** or use toggle switches
3. Wait 1-2 minutes
4. Re-test with traffic from step 2

**If no events after test traffic:**
1. Verify WAF actually blocked the request:
   ```bash
   curl -v -g "http://your-domain.com/?id=1%27%20OR%201%3D1" 2>&1 | grep -i "waf\|block\|403"
   ```
2. If WAF didn't block, check WAF protection mode in console
3. If WAF blocked but no Agentic SOC event, rules may need tuning — contact Alibaba Cloud support

**Documentation:**
- [Agentic SOC Quick Start](https://www.alibabacloud.com/help/en/security-center/getting-started/use-agentic-soc-quickly)
- [Detection Rule Configuration](https://www.alibabacloud.com/help/en/security-center/getting-started/use-agentic-soc-quickly)

---

## Troubleshooting Reference

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `Forbidden.RAM` on any API call | Missing RAM policy | Attach required policy (Stage 3) |
| `InvalidApi` on WAF commands | Using wrong API version | Ensure `--api-version 2019-09-10` or use `waf-openapi` |
| WAF API name not found (e.g., `DescribeLogServiceStatus`) | CLI expects lowercase API names | Use lowercase with hyphens: `describe-log-service-status` |
| Parameter `--InstanceId` not found | Wrong API version or parameter case | Newer APIs (2021-10-01) use `--InstanceId`; older (2019-09-10) use `--instance-id` |
| `Log.Control.UserLogOpenedError` | WAF SLS already enabled at instance level | Proceed to domain-level log config |
| `Log.Control.CreateEtlMetaFailed` | WAF backend issue creating ETL metadata | Use WAF Console UI instead of CLI |
| `Log.Control.ModifyUserLogTooFrequent` | Rate limited on log toggle changes | Wait 2 minutes and retry |
| Empty SLS logs after test traffic | Domain-level log collection not enabled | Enable per-domain in WAF Console (Stage 5.2) |
| WAF domain identifier mismatch | Using `domain.com` instead of `domain.com-waf` | WAF resources use `-waf` suffix internally |
| `DescribeInstance` returns empty | No WAF instance in region | Activate WAF 3.0 (Stage 4.3) |
| `403 RequestError: system is unavailable` | Transient API unavailability | Wait 2 minutes and retry; verify via SLS directly as fallback |

## Key Documentation Links

- [Security Center Overview](https://www.alibabacloud.com/help/en/security-center/)
- [Agentic SOC Quick Start](https://www.alibabacloud.com/help/en/security-center/getting-started/use-agentic-soc-quickly)
- [WAF 3.0 Getting Started](https://www.alibabacloud.com/help/en/waf/web-application-firewall-3-0/getting-started/get-started-with-waf-3)
- [WAF Log Delivery Best Practices](https://www.alibabacloud.com/help/en/waf/web-application-firewall-3-0/use-cases/best-practices-for-pushing-api-security-alerts)
- [SLS Quick Start](https://www.alibabacloud.com/help/en/log-service/getting-started/quick-start)
- [RAM User Guide](https://www.alibabacloud.com/help/en/ram/user-guide/create-a-ram-user)
- [aliyun CLI on GitHub](https://github.com/aliyun/aliyun-cli)
- [Alibaba Cloud OpenAPI Explorer](https://api.alibabacloud.com/document)

## Important Notes

### WAF API Version Compatibility

WAF has two API versions with different parameter naming conventions:

- **Version 2021-10-01** (newer): Uses `--InstanceId` (PascalCase)
- **Version 2019-09-10** (older): Uses `--instance-id` (lowercase with hyphens)

Always check error messages for the correct parameter format when switching between API versions.

### Product Code Clarification

- **Security Center**: Uses product code `sas` (not `tds`)
- **WAF 3.0**: Uses product code `waf-openapi`
- **SLS**: Uses product code `sls`

### Environment Variables

If environment variables are not set in your shell, the skill will attempt to load them from a `.env` file in the current directory. Ensure your `.env` file contains:

```bash
export ALIBABA_ACCESS_KEY_ID="your-access-key-id"
export ALIBABA_ACCESS_KEY_SECRET="your-access-key-secret"
export ALIBABA_REGION="ap-southeast-1"
```

## Quick Start

### Option A: Fully Automated (Recommended)

The agent will automatically execute all validation and generation stages:

1. **Invoke this skill:** "Validate my BlueTeam Autopilot environment"
2. **Agent runs Stages 1-6:** Validates credentials, services, permissions
3. **Agent runs Stage 7:** Auto-generates trusted networks and validates configuration
4. **Agent produces Stage 8:** Readiness report with any issues
5. **Manual steps (if needed):**
   - Add monitoring service IPs to `trusted-networks.md`
   - Enable detection rules via console (Stage 5e)

### Option B: Manual Step-by-Step

If you prefer manual control, follow the validation stages in order:

1. **Set environment variables:**
   ```bash
   export ALIBABA_ACCESS_KEY_ID="your-key"
   export ALIBABA_ACCESS_KEY_SECRET="your-secret"
   export ALIBABA_REGION="ap-southeast-1"
   ```

2. **Agent validates environment (Stages 1-6)**

3. **Agent generates configuration (Stage 7):**
   ```bash
   ./scripts/generate-trusted-networks.sh
   ./scripts/validate-configuration.sh
   ```

4. **Review readiness report (Stage 8)**

### Prerequisites

- `aliyun` CLI installed and configured
- RAM user with required policies (Stage 3)
- Security Center Enterprise or Ultimate edition
- WAF 3.0 activated with at least one protected domain
