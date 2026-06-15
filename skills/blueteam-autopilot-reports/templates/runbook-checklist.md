# WAF Triage Runbook Checklist

**Runbook:** RUN-SEC-042 | **Event:** `{{eventId}}`

---

## Step 1: Contextual Discovery

- [ ] Identified targeted asset and domain name
- [ ] Extracted source IP and geographic flags
- [ ] Confirmed exploit vector from incident payloads
- [ ] Cross-referenced against trusted networks

---

## Step 2: Attack Chain Verification

{{#attackChain}}
- [ ] {{stage}}: {{description}}
{{/attackChain}}

---

## Step 3: Mitigation Execution

- [ ] Verified active response policy exists
- [ ] Staged temporary network block for source IP
- [ ] **Human analyst approved mitigation**

---

## Step 4: Rollback & Logging

- [ ] Documented mitigation actions and blocked count
- [ ] Exported ticket for audit evidence

---

## Compliance Evidence

{{#complianceControls}}
- [x] {{.}}
{{/complianceControls}}
