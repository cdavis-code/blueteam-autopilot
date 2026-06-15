# BlueTeam Autopilot - Autonomous Environment Setup

> **AUTOMATION GUIDE** - How BlueTeam Autopilot skills self-configure without manual intervention.

## Overview

BlueTeam Autopilot is designed for **autonomous operation**. Rather than requiring users to manually run setup scripts and validate configurations, the agent skills automatically:

1. **Detect** environment prerequisites
2. **Generate** environment-specific configuration
3. **Validate** the complete setup
4. **Report** any issues requiring manual attention

This document explains how the automation works and what (if anything) still requires human intervention.

---

## Architecture

### Before Automation (Manual Steps)

```
User Action                    Agent Action
─────────                      ────────────
1. Set environment variables ──────► 
2. Run setup tools ────────────────► 
3. Validate configuration ─────────► 
4. Review output ──────────────────► 
5. Fix issues manually ────────────► 
6. Re-run validation ──────────────► 
```

**Problem:** User must know which scripts to run, when to run them, and how to interpret results.

### After Automation (Agent-Driven)

```
User Action                    Agent Action
─────────                      ────────────
1. "Validate my environment" ──► 2. Auto-detect prerequisites
                                 3. Auto-generate configuration
                                 4. Auto-validate setup
                                 5. Report readiness
                                 6. List manual steps (if any)
```

**Benefit:** User invokes skill once, agent handles everything else.

---

## Automated Stages

### Stage 7: Configuration Generation

**Triggered:** Automatically after Stages 1-6 pass validation.

**What the agent does:**

During Stage 7, the prep skill automatically:
1. Generates `trusted-networks.md` from your cloud infrastructure (VPCs, VPNs)
2. Validates that no hardcoded environment-specific values remain in skill files

**Behind the scenes:**

| Step | API Call | Purpose |
|------|----------|---------|
| Query VPCs | `DescribeVpcs` | Discover all VPC CIDR blocks |
| Query VPNs | `DescribeVpnGateways` | Discover VPN gateway configurations |
| Generate doc | Script logic | Populate `trusted-networks.md` with real infrastructure |
| Validate | Pattern matching | Ensure no hardcoded regions/IPs in skill files |

**Output:**

```
✓ Generated trusted-networks.md
  - VPCs discovered: 3
  - VPN gateways: 1

==========================================
✓ All checks passed!
No hardcoded environment-specific values found.
==========================================
```

**Error handling:**

If generation fails, the agent will:
1. Diagnose the error (missing CLI, wrong region, insufficient permissions)
2. Provide specific remediation steps
3. Continue with validation of other stages
4. Report the failure in the readiness summary

---

### Stage 8: Readiness Report

**Triggered:** Automatically after all validation and generation stages complete.

**What the agent produces:**

A comprehensive readiness report showing:
- ✅/❌ status for each validation stage
- Automated tasks completed (config generation, validation)
- Issues requiring manual attention
- Next steps based on result (READY vs NEEDS ATTENTION)

**Example:**

```
═══════════════════════════════════════════════════════
  BlueTeam Autopilot — Environment Readiness Report
═══════════════════════════════════════════════════════

  Region:       ap-southeast-1
  Account ID:   123456789012
  Checked at:   2026-06-14 10:30:00 UTC

  ┌──────────────────────────────────────────────────┐
  │ STAGE                    │ STATUS │ NOTES         │
  ├──────────────────────────────────────────────────┤
  │ 1. aliyun CLI installed  │ ✅     │ version 3.1.2 │
  │ 2. Credentials valid     │ ✅     │ Account: ...  │
  │ 3. RAM permissions       │ ✅     │ All policies  │
  │ 4a. Security Center      │ ✅     │ Edition: 5    │
  │ 4b. Agentic SOC          │ ✅     │ Active        │
  │ 4c. WAF 3.0              │ ✅     │ Instance: ... │
  │ 4d. WAF CNAME (DNS)     │ ✅     │ CNAME: ...    │
  │ 4e. SLS                  │ ✅     │ Projects: 2   │
  │ 5a. WAF domains          │ ✅     │ Count: 3      │
  │ 5b. WAF log delivery     │ ✅     │ Enabled       │
  │ 5c. SLS project/logstore │ ✅     │ Index: yes    │
  │ 5d. Domain-level logs    │ ✅     │ Per-domain ON │
  │ 5e. SOC detection rules  │ ⚠️     │ Manual check  │
  │ 6. End-to-end test       │ ✅     │ Logs flowing  │
  │ 7a. Generate configs     │ ✅     │ Auto-generated│
  │ 7b. Validate configs     │ ✅     │ All checks ✔  │
  │ 8. Readiness summary     │ ✅     │ Complete      │
  └──────────────────────────────────────────────────┘

  RESULT: NEEDS ATTENTION

  Automated tasks completed:
  ✅ Trusted networks generated from cloud configuration
  ✅ Configuration validated (no hardcoded values)
  ✅ Example markers verified

  Issues requiring attention:
  - [ ] Verify WAF detection rules enabled (Stage 5e - manual console check)
  - [ ] Add monitoring service IPs to trusted-networks.md

═══════════════════════════════════════════════════════
```

---

## What Still Requires Manual Intervention

Despite extensive automation, some steps **cannot** be fully automated due to:
- Alibaba Cloud API limitations (no programmatic access)
- Security considerations (require human judgment)
- Organization-specific knowledge (monitoring IPs, internal networks)

### Manual Step 1: Enable Detection Rules

**Why:** No public API exists for managing Agentic SOC detection rules.

**What user does:**
1. Navigate to Security Center → Agentic SOC → Detection Rules
2. Verify WAF-related rules are enabled
3. Enable if disabled

**Agent support:**
- Provides direct console link
- Lists specific rule names to check
- Explains how to test rules with sample traffic

---

### Manual Step 2: Add Monitoring Service IPs

**Why:** Monitoring services are organization-specific and not discoverable via Alibaba Cloud APIs.

**What user does:**
1. Open generated `trusted-networks.md`
2. Find "Monitoring Services" section
3. Add IP ranges for:
   - Datadog agents
   - New Relic infrastructure
   - Custom APM collectors
   - External health checks (Pingdom, UptimeRobot)

**Agent support:**
- Generates all VPC/VPN trusted networks automatically
- Provides placeholder section with instructions
- Lists common monitoring services to consider

---

## Invocation Examples

### Example 1: First-Time Setup

**User:**
> "Set up my BlueTeam Autopilot environment"

**Agent:**
1. Invokes `blueteam-autopilot-prep` skill
2. Runs Stages 1-8 automatically
3. Reports: "Environment is READY" or lists issues
4. Provides manual steps if needed

---

### Example 2: Re-Validation After Changes

**User:**
> "Validate my environment after I added new VPCs"

**Agent:**
1. Re-runs `blueteam-autopilot-prep` skill
2. Detects new VPCs via `DescribeVpcs`
3. Regenerates `trusted-networks.md` with updated CIDRs
4. Validates configuration
5. Reports: "Trusted networks updated with 2 new VPCs"

---

### Example 3: Troubleshooting

**User:**
> "Why is my environment showing NEEDS ATTENTION?"

**Agent:**
1. Reviews readiness report from last validation
2. Identifies failed stages
3. Explains root cause
4. Provides specific remediation steps
5. Offers to re-run validation after fixes

---

## CI/CD Integration

The prep skill's validation stage can be integrated into CI/CD pipelines. The validation checks for hardcoded environment-specific values and verifies example markers are present across all skill documents.

**Integration approach:** Configure your pipeline to invoke the `blueteam-autopilot-prep` skill with appropriate credentials and region configuration. See the [prep skill definition](../blueteam-autopilot-prep/SKILL.md) for details on Stage 7 validation.

---

## Best Practices

### For Users

1. **Invoke prep skill regularly:**
   - After adding new VPCs or VPNs
   - After changing RAM permissions
   - Before critical incident response operations

2. **Keep monitoring IPs updated:**
   - When onboarding new monitoring tools
   - When changing APM providers
   - When adding external health checks

3. **Review readiness reports:**
   - Even if READY, skim for informational notes
   - Address NEEDS ATTENTION items promptly
   - Archive reports for audit trail

### For Developers

1. **Never hardcode environment values:**
   - Use `{{ALIBABA_REGION}}` template syntax
   - Mark all examples with "EXAMPLE" labels
   - Reference MCP tools for dynamic data

2. **Update generation scripts when:**
   - New Alibaba Cloud services are supported
   - New API endpoints become available
   - Infrastructure patterns change

3. **Test validation script:**
   - Before committing skill changes
   - After adding new knowledge documents
   - As part of PR review process

---

## Troubleshooting

### Issue: Agent doesn't auto-generate configuration

**Symptoms:**
- Prep skill completes Stages 1-6 but skips Stage 7
- `trusted-networks.md` not updated

**Diagnosis:**
1. Check if Stage 6 (end-to-end test) passed
2. Verify `ALIBABA_REGION` is set
3. Check agent has Bash tool permissions

**Fix:**
- Ensure all prerequisite stages pass
- Set `ALIBABA_REGION` in `.env` file
- Re-invoke prep skill

---

### Issue: Validation fails after generation

**Symptoms:**
- Prep skill Stage 7b reports hardcoded values in generated file
- Readiness report shows "NEEDS ATTENTION" for validation stage

**Diagnosis:**
1. Check if Stage 7a (generation) completed successfully
2. Review validation output for specific files/lines
3. Verify generated file has proper example markers

**Fix:**
- Re-invoke the prep skill to regenerate
- Manually fix reported hardcoded values
- Ensure no manual edits to auto-generated sections

---

### Issue: Monitoring IPs section empty

**Symptoms:**
- `trusted-networks.md` has placeholder text in Monitoring Services section
- No actual IP ranges listed

**Diagnosis:**
- This is **expected behavior** - monitoring IPs cannot be auto-discovered

**Fix:**
- Add your monitoring service IPs manually
- Reference your APM configuration or monitoring dashboards
- Common services: Datadog, New Relic, Pingdom, etc.

---

## Future Enhancements

Planned automation improvements:

1. **Auto-detect monitoring services:**
   - Query ECS instances for APM agents
   - Parse DNS records for health check services
   - Integration with Alibaba Cloud Monitor

2. **Auto-enable detection rules:**
   - Pending Alibaba Cloud API support
   - Console automation via browser tool (experimental)

3. **Continuous validation:**
   - Cron job to regenerate trusted networks daily
   - Webhook on VPC/VPN changes
   - Slack/Teams notifications on validation failures

4. **Multi-region support:**
   - Generate configuration for multiple regions
   - Region-specific trusted networks
   - Cross-region replication validation

---

## Related Documentation

- [SKILL.md](../blueteam-autopilot-prep/SKILL.md) - Full prep skill definition
- [ENVIRONMENT_INDEPENDENCE.md](../ENVIRONMENT_INDEPENDENCE.md) - Environment customization guide
- [IMPLEMENTATION_SUMMARY.md](../IMPLEMENTATION_SUMMARY.md) - Implementation details
