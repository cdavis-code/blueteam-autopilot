# Incident Report: {{title}}

| Field | Value |
|-------|-------|
| **Event ID** | `{{eventId}}` |
| **Severity** | {{severity}} |
| **Generated** | {{generatedAt}} |

---

## AI Summary

{{aiSummary}}

---

## Root Cause

{{rootCause}}

---

## Business Impact

{{businessImpact}}

---

## Attack Chain

{{#attackChain}}
### {{stage}}
{{description}}

{{/attackChain}}

---

## Affected Assets

{{#affectedAssets}}
- {{.}}
{{/affectedAssets}}

---

## Source IPs

{{#sourceIps}}
- `{{.}}`
{{/sourceIps}}

---

## Related CVEs

{{#relatedCves}}
- {{.}}
{{/relatedCves}}

---

## Compliance Controls

{{#complianceControls}}
- {{.}}
{{/complianceControls}}

---

## Blast Radius

{{blastRadius}}

---

## Investigation Timeline

{{#timeline}}
| {{timestamp}} | {{event}} | {{source}} |
{{/timeline}}

---

## Confidence Rating

**{{confidence}}**

---

## Recommended Actions

{{#recommendedActions}}
| {{action}} | Policy: `{{policyId}}` | Risk: {{riskLevel}} |
{{/recommendedActions}}

---

## Rollback Plan

{{rollbackPlan}}

---

## Audit Trail

{{#auditTrail}}
| {{timestamp}} | `{{tool}}` | {{summary}} |
{{/auditTrail}}
