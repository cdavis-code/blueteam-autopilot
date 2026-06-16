# Vulnerability Prioritization Report

| Field | Value |
|-------|-------|
| **Total Analyzed** | {{totalAnalyzed}} |
| **Ranked** | {{rankedCount}} |
| **Generated** | {{generatedAt}} |

---

## Remediation Strategy

{{remediationSteps}}

---

## Ranked Vulnerabilities

| Rank | Vul ID | Name | Severity | CVE | Asset | Remediation |
|------|--------|------|----------|-----|-------|-------------|
{{#rankedVulns}}
| {{rank}} | `{{vulId}}` | {{name}} | {{severity}} | {{cveId}} | {{assetId}} | {{remediationSteps}} |
{{/rankedVulns}}

---

## Vulnerabilities by Asset

{{#assetGrouping}}
### {{asset}}
{{#vulns}}
- `{{vulId}}` - {{name}} ({{severity}})
{{/vulns}}

{{/assetGrouping}}
