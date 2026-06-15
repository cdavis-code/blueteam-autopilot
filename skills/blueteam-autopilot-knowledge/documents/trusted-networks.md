# Trusted Networks

> **⚠️ CUSTOMIZATION REQUIRED**
>
> The IP ranges below are **EXAMPLES ONLY** using RFC 1918 private ranges and RFC 5737
> documentation addresses. **You MUST replace these with your organization's actual trusted networks.**
>
> **To generate trusted networks from your Alibaba Cloud environment,**
> invoke the `blueteam-autopilot-prep` skill. The prep skill will
> auto-generate this file from your VPC and VPN configuration.
>
> The prep skill queries your VPC configuration, VPN gateways, and RAM policies to auto-generate
> this file with your organization's actual trusted IP ranges.

Corporate VPN and monitoring service IP ranges that must never be blindly blocked.

---

## Corporate VPN

> **EXAMPLE VALUES - Replace with your organization's actual VPN ranges**

| Network | CIDR | Purpose |
|---------|------|---------|
| Internal Network A | 10.0.0.0/8 | Corporate LAN |
| Internal Network B | 172.16.0.0/12 | Corporate WLAN |
| Office VPN | 192.168.1.0/24 | Remote office access |

---

## Monitoring Services

> **EXAMPLE VALUES - Replace with your actual monitoring service IPs**

| Network | CIDR | Purpose |
|---------|------|---------|
| Uptime Monitoring | 203.0.113.0/24 | External health checks |
| Internal Monitoring | 198.51.100.0/24 | APM and log aggregation |

---

## Rule

**CRITICAL:** Any attack originating from these IPs must be flagged as
**"Potentially Compromised Internal Asset"** — never blindly blocked.

### Escalation Procedure

1. **Do NOT** propose perimeter block (IP ACL)
2. **DO** escalate to security team for investigation
3. **Document** as potential insider threat or compromised asset
4. **Correlate** with other internal security signals

### Rationale

Traffic from trusted networks indicates:
- Compromised corporate device
- Rogue insider activity
- Misconfigured monitoring service
- VPN tunnel abuse

Blocking these IPs would:
- Disrupt legitimate corporate operations
- Mask the actual security incident
- Prevent proper forensic investigation

---

## Compliance Reference

- **SOC 2 CC6.8:** Unauthorized activity triage must distinguish external vs. internal threats
- **NIST CSF DE.AE-2:** Anomalous event analysis must consider source context

---

## Update Procedure

To add/remove trusted networks:

1. Submit change request to security team
2. Update this document
3. Update WAF whitelist in console
4. Notify BlueTeam Autopilot users

**Last Updated:** 2026-06-14
