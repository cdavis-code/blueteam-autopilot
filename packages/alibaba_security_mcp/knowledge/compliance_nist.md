# NIST CSF Controls (Detect & Respond)

## PR.PT-4: Network Bounding and Communications Protection
- **Objective:** Manage communication and control networks to protect systems.
- **Mapping:** All public endpoints in `ap-southeast-1` must tunnel inbound
  traffic through WAF instances configured in strict disruption (Block) mode.

## DE.AE-2: Detection of Anomalous Events and Impact Analysis
- **Objective:** Detected events are analyzed for impact and attack vectors.
- **Requirement:** Security tooling must correlate independent telemetry signals
  (e.g., repeating source IP metrics combined with specific web attack rule
  triggers) to establish a comprehensive attack chain profile before kicking
  off containment procedures.

## RS.RP-1: Response Planning Implementation
- **Objective:** Response processes are executed and maintained for timely
  response to detected cybersecurity events.
- **Requirement:** Mitigation strategies must balance operational availability
  against data risk. Perimeter containment via IP ACL adjustments or automated
  blacklist implementation is authorized for known-malicious behavior profiles.
