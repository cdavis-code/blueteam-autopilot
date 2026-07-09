# Trusted Networks

> **CRITICAL:** This file is auto-generated. Do NOT edit manually.
> Run `skills/blueteam-autopilot-prep/scripts/generate-trusted-networks.sh` to regenerate.

## Purpose

This file contains the authoritative list of trusted internal networks for
BlueTeam incident correlation and response.

## Auto-Discovered Networks

The following networks were discovered from the Alibaba Cloud environment
at generation time.

### VPCs

| vpc-t4n2seg99q50x17e21x9u | 172.16.0.0/12 | VPC |

### VPN Gateways

| Network | CIDR | Purpose |
|---------|------|---------|
| No VPN gateways found | - | - |

### WAF-Protected Domains

| Domain | Access Mode | Purpose |
|--------|-------------|---------|
| ecs.muayid.com | CNAME | WAF-protected test domain |

**Primary Test Domain:** ecs.muayid.com

## Manual Additions

Add any monitoring service IPs, on-premise networks, or partner networks here:

| Network | CIDR | Purpose |
|---------|------|---------|
| CloudMonitor | 100.100.0.0/16 | Alibaba Cloud monitoring |
| Internal DNS | 100.64.0.0/16 | Alibaba Cloud internal DNS |

## Security Policy

All networks listed in this file are considered **trusted internal networks**
for the purposes of BlueTeam incident correlation.

### Incident Correlation Rules

When an attack is detected, BlueTeam MUST check the source IP
against this trusted network list:

1. **External Source (not in this file):**
   - Proceed with normal incident response
   - Propose perimeter blocking if warranted

2. **Internal Source (matches this file):**
   - **STOP** — do NOT propose immediate blocking
   - Flag as "Potentially Compromised Internal Asset"
   - Escalate to security team for investigation
   - Correlate with other internal security signals

## Rule

**CRITICAL:** Any attack originating from these IPs must be flagged as
**"Potentially Compromised Internal Asset"** — never blindly blocked.

### Escalation Procedure

1. **Do NOT** propose perimeter block (IP ACL)
2. **DO** escalate to security team for investigation
3. **Document** as potential insider threat or compromised asset
4. **Correlate** with other internal security signals

**Last Generated:** 2026-07-09T19:17:56Z
**Region:** ap-southeast-1
**VPCs Discovered:** 1
**VPN Gateways:** 0
**WAF Domains:** 1
