# INTERNAL RUNBOOK: WAF PERIMETER THREAT TRIAGE AND RECOVERY
**Document ID:** RUN-SEC-042  
**Version:** 2026.1  
**Classification:** Internal Only  

## 1. Trigger Conditions
This runbook is initiated when network perimeter analytics surface high-severity alerts from Web Application Firewall (WAF) sensors, specifically focusing on:
*   Local File Inclusion (LFI) attempts
*   Automated Vulnerability Scanner Behavior (`scanner_behavior`)
*   High-Frequency Source IP anomalies (exceeding baseline request rates)

## 2. Step-by-Step Triage Workflow
The responding analyst (or autonomous SecOps proxy) must execute the following workflow sequentially:

### Step 2.1: Contextual Discovery
1. Identify the targeted application asset, domain name, and structural cloud region ID.
2. Extract the malicious actor's source IP address and trace geographic area flags.
3. Pull matching incident payloads to confirm the specific exploit vector (e.g., verifying if traversal syntax `../../etc/passwd` is present in the logs).

### Step 2.2: Mitigation Execution (Perimeter Blocking)
If an attack chain is successfully verified, the threat must be mitigated to prevent lateral escalation:
1. Verify if an active Automation Rule / Response Policy exists within the local security controller.
2. If a matching policy exists, stage a temporary network block targeting the malicious source IP.
3. Prior to rule deployment, a human analyst must approve the mitigation token within the web dashboard to prevent accidental blocking of legitimate client endpoints (false positives).

## 3. Rollback & Post-Incident Logging
1. Document the mitigation actions, total blocked request count, and signature types.
2. Export the final ticket state to the centralized tracker platform for audit evidence collection.