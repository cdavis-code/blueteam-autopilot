# Environment Independence Guide

This document explains how BlueTeam Autopilot skills achieve environment independence and how to customize them for your organization.

---

## Overview

BlueTeam Autopilot skills are designed to be **region-agnostic** and **environment-independent**. All environment-specific values (regions, IP addresses, CIDR ranges, instance IDs) are either:

1. **Dynamic** - Fetched at runtime via MCP tools
2. **Template variables** - Marked with `{{VARIABLE}}` syntax for substitution
3. **Clearly labeled examples** - Marked with "EXAMPLE" or "NOTE" callouts

This ensures the skills work across any Alibaba Cloud region and any organizational setup without modification.

---

## Architecture

### Dynamic Data Sources

| Data Type | Source | MCP Tool / Script |
|-----------|--------|-------------------|
| Active region | Environment variable | `get_account_context` |
| Asset inventory | Cloud infrastructure | `list_assets` |
| Trusted networks | VPC/VPN config | `blueteam-autopilot-prep` skill (Stage 7) |
| WAF instances | Cloud resources | `get_waf_instance_info` |
| Security events | Security Center | `list_security_events` |

### Template Variables

The following template syntax is used throughout skill documents:

| Variable | Description | Example |
|----------|-------------|---------|
| `{{ALIBABA_REGION}}` | Active Alibaba Cloud region | `ap-southeast-1` |
| `{{WAF_INSTANCE_ID}}` | WAF instance identifier | `waf_v2intl_public_intl-sg-xxx` |
| `{{VPC_CIDR}}` | VPC CIDR block | `10.0.0.0/8` |

These variables should be populated from:
- MCP tool responses (`get_account_context`, `list_assets`)
- Environment variables (`$ALIBABA_REGION`)
- Generated configuration files (via scripts)

---

## Customization Guide

### Step 1: Set Environment Variables

Create a `.env` file in your project root:

```bash
#!/bin/bash
export ALIBABA_ACCESS_KEY_ID="your-access-key-id"
export ALIBABA_ACCESS_KEY_SECRET="your-access-key-secret"
export ALIBABA_REGION="<your-region>"  # e.g., ap-southeast-1, us-east-1, eu-west-1
export SECURITY_CENTER_MODE="real"  # or "dry-run"
```

Source it before running any scripts:

```bash
source .env
```

### Step 2: Auto-Generate Configuration (Recommended)

> **AUTONOMOUS MODE:** Simply invoke the prep skill:
> ```
> "Validate my BlueTeam Autopilot environment"
> ```
> The agent will automatically:
> 1. Validate your environment (Stages 1-6)
> 2. Generate trusted networks (Stage 7a)
> 3. Validate configuration (Stage 7b)
> 4. Produce readiness report (Stage 8)
>
> See [AUTONOMOUS_SETUP.md](AUTONOMOUS_SETUP.md) for details.

### Step 3: Verify MCP Integration

Test that MCP tools return correct data for your environment:

```bash
# Check region and account context
aliyun sas describe-version-config --region "$ALIBABA_REGION"

# List assets
aliyun sas DescribeInstances --region "$ALIBABA_REGION"

# List VPCs
aliyun vpc DescribeVpcs --region "$ALIBABA_REGION"
```

---

## What's Already Generic

The following components are **already environment-independent**:

✅ **Compliance controls** - NIST CSF and SOC 2 controls are region-agnostic  
✅ **MCP tool schemas** - All tools use dynamic parameters  
✅ **Operational scripts** - All use `$ALIBABA_REGION` from environment  
✅ **Behavior definitions** - Agent behaviors work in any region  
✅ **Report templates** - Templates use placeholders for runtime data  

---

## What Requires Customization

The following components **require your input**:

⚠️ **Trusted networks** - Invoke the `blueteam-autopilot-prep` skill to auto-generate  
⚠️ **Asset inventory examples** - Replace with `list_assets` output or use MCP tool  
⚠️ **Monitoring service IPs** - Manually add to `trusted-networks.md`  
⚠️ **WAF instance IDs** - Discovered at runtime via `get_waf_instance_info`  

---

## Validation Checklist

Before deploying BlueTeam Autopilot in production:

- [ ] `.env` file created with correct region
- [ ] `blueteam-autopilot-prep` skill invoked and passed validation
- [ ] MCP tools return correct data for your environment
- [ ] Trusted networks reviewed and approved by security team
- [ ] WAF instance exists in your region
- [ ] Security Center edition supports Agentic SOC (Enterprise or Ultimate)

---

## Troubleshooting

### Issue: "No VPCs discovered"

**Cause:** Incorrect region or insufficient RAM permissions

**Solution:**
```bash
# Verify region is correct
echo $ALIBABA_REGION

# Test VPC access manually
aliyun vpc DescribeVpcs --region "$ALIBABA_REGION"

# Check RAM permissions
aliyun ram ListPoliciesForUser --UserName "<your-user>"
```

### Issue: Validation fails with hardcoded regions

**Cause:** Region reference outside example/template context

**Solution:**
- Check the file and line reported by the prep skill validation
- If it's in operational documentation, replace with `{{ALIBABA_REGION}}` or MCP tool reference
- If it's in example code, add "EXAMPLE" marker or move to example section

### Issue: MCP tools return wrong region

**Cause:** Environment variable not set or incorrect

**Solution:**
```bash
# Check current value
echo $ALIBABA_REGION

# Source .env file
source .env

# Verify with ping
# (via MCP tool: ping should return your region)
```

---

## Best Practices

1. **Never hardcode regions in operational documents** - Use `get_account_context` or `$ALIBABA_REGION`
2. **Always mark examples clearly** - Use "EXAMPLE", "NOTE", or `{{VARIABLE}}` syntax
3. **Let the prep skill generate** - Invoke the prep skill to auto-generate environment-specific documents
4. **Validate before deployment** - Invoke the prep skill validation as part of your deployment process
5. **Document customizations** - Keep a `CUSTOMIZATIONS.md` file noting what was changed
6. **Regenerate periodically** - Re-invoke the prep skill when infrastructure changes

---

## Related Documentation

- [SKILL.md](../blueteam-autopilot-core/SKILL.md) - Core skill with environment independence notice
- [compliance-quick-ref.md](../blueteam-autopilot-core/references/compliance-quick-ref.md) - Generic compliance references
- [trusted-networks.md](../blueteam-autopilot-knowledge/documents/trusted-networks.md) - Generated trusted network config
- [asset-inventory.md](../blueteam-autopilot-knowledge/documents/asset-inventory.md) - Asset inventory with example markers

---

**Last Updated:** 2026-06-14  
**Version:** 1.0.0
