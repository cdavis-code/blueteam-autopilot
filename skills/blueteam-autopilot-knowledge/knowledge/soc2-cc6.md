---
document_id: soc2-cc6
version: "2026.1"
source: bundled
grc_provider: ciso-assistant
framework: SOC2
last_updated: "2026-06-14"
---

<!-- BEGIN GRC EXTERNAL DATA (provider: ciso-assistant, framework: SOC2) -->

# EXECUTIVE SECURITY POLICY: SOC 2 TYPE II COMPLIANCE EXCERPT
## Section: Trust Services Criteria - CC6.0 (Logical Access Controls)

### CC6.1: Boundary Protection and Perimeter Defense
The organization protects points of entry to the infrastructure containing customer data from unauthorized access. 

#### Control Requirements:
1. All public-facing web applications hosting critical user services must be fronted by an active Web Application Firewall (WAF) capable of inspecting and blocking layer 7 malicious traffic.
2. Perimeter defenses must log all blocked access attempts, input manipulation validation errors, and malicious traffic definitions (including SQL Injection, Cross-Site Scripting, and Local File Inclusion attempts).
3. The security team must review perimeter security anomalies at least daily.

### CC6.8: Unauthorized Activity Triage and Mitigation
The organization prevents, detects, and acts upon unauthorized logical access to infrastructure assets.

#### Control Requirements:
1. Threat detection mechanisms must be continuously active across all production Elastic Compute Service (ECS) nodes and network load balancers.
2. In the event that an external entity exhibits deterministic scanning behavior or targeted application vulnerability exploitation, automated or semi-automated throttling/blocking mechanisms must be initiated to preserve system integrity.
3. Every automated mitigation action must be traceable to an authoritative system event log and authenticated by an explicit administrative validation window.
<!-- END GRC EXTERNAL DATA -->