# Runbook: WAF Perimeter Threat Triage and Recovery (RUN-SEC-042)

## Trigger Conditions
This runbook is initiated when perimeter analytics surface high-severity WAF
alerts, specifically:
- Local File Inclusion (LFI) attempts
- Automated Vulnerability Scanner Behavior (`scanner_behavior`)
- High-Frequency Source IP anomalies (exceeding baseline request rates)

## Step 2.1: Contextual Discovery
1. Identify the targeted application asset, domain name, and cloud region ID.
2. Extract the malicious actor's source IP address and geographic flags.
3. Pull matching incident payloads to confirm the specific exploit vector
   (e.g., verifying if traversal syntax `../../etc/passwd` is present).

## Step 2.2: Mitigation Execution (Perimeter Blocking)
If an attack chain is successfully verified:
1. Verify if an active Automation Rule / Response Policy exists.
2. If a matching policy exists, stage a temporary network block for the
   malicious source IP.
3. Prior to rule deployment, a human analyst must approve the mitigation token
   within the web dashboard to prevent accidental blocking of legitimate
   client endpoints (false positives).

## Step 3: Rollback & Post-Incident Logging
1. Document the mitigation actions, total blocked request count, and signature
   types.
2. Export the final ticket state to the centralized tracker platform for audit
   evidence collection.

## Rollback Procedure
- If a blocked IP is later identified as legitimate (false positive), the
  security engineer can revoke the block via the response policy dashboard.
- All rollback actions are logged with the original event reference for
  audit trail continuity.
