# Trusted Networks / IP Whitelist

Corporate office IP ranges and uptime monitoring services are considered
trusted. If an attack originates from a corporate VPN IP or known monitoring
endpoint, the agent MUST flag it as a **"Potentially Compromised Internal
Asset"** rather than simply blacklisting it.

## Trusted Sources

- Corporate VPN egress IPs
- Uptime monitoring service IPs (e.g., Pingdom, Datadog Synthetics)
- CI/CD runner IPs used for deployment health checks

## Escalation Rules

Before proposing any IP block, cross-reference the source IP against this
trusted network list. If a match is found, escalate as a potential insider
threat rather than executing a perimeter block.

**Never blindly block a trusted IP.** Instead:
1. Flag the event as "Potentially Compromised Internal Asset"
2. Recommend investigation of the source host for compromise indicators
3. Escalate to the security engineering team for manual triage
