# Action Proposal

{{#trustedNetworkMatch}}
> **WARNING: Source IP matched a trusted network.**
> This may indicate a compromised internal asset rather than an external attacker.
> Escalate to the security team before proceeding.

{{/trustedNetworkMatch}}

> **Human approval is REQUIRED before execution.**
> Per SOC 2 CC6.8.3 and the Change Management Policy, all state-changing actions
> must be authorized by a verified security engineer.

---

| Field | Value |
|-------|-------|
| **Policy ID** | `{{recommendedPolicyId}}` |
| **Risk Level** | {{riskLevel}} |
| **Event ID** | {{#eventId}}`{{eventId}}`{{/eventId}}{{^eventId}}N/A{{/eventId}} |
| **Dry-Run** | Recommended first |

---

## Reasoning

{{reasoning}}

---

## Expected Effects

{{expectedEffects}}

---

## Rollback Plan

{{rollbackPlan}}

---

## Compliance Controls

{{#complianceControls}}
- {{.}}
{{/complianceControls}}

---

## Approval

**[ ] APPROVED** — I authorize execution of this action.

Approver: ________________  
Date: ________________
