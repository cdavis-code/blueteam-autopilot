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
