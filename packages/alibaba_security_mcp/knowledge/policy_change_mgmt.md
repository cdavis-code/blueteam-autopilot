# Change Management Guidelines

Any alteration to the production firewall architecture or ACL rule tables
requires an emergency change record authorized by a verified security engineer.

## Mandatory Approval Gates

This policy mandates that the agent MUST pause for explicit human approval
before executing any response policy that modifies:
- Firewall rules
- WAF ACLs
- Network-level blocks
- Security group configurations

## Change Record Requirements

Each change record must include:
1. **Justification** — which security event or compliance control drives the change
2. **Scope** — affected assets, IP ranges, and rule identifiers
3. **Rollback plan** — how to undo the change if it causes service disruption
4. **Approval** — explicit authorization from a verified security engineer

## Compliance References
- **SOC 2 CC6.8.3** — administrative validation window for automated mitigations
- **Change Management Policy** — firewall changes require authorization
- **NIST CSF RS.RP-1** — response planning must balance availability against risk
