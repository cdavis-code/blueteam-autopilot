# SOC 2 Type II — CC6.0 Logical Access Controls

## CC6.1: Boundary Protection and Perimeter Defense
1. All public-facing web applications hosting critical user services must be
   fronted by an active WAF capable of inspecting and blocking L7 traffic.
2. Perimeter defenses must log all blocked access attempts, input manipulation
   validation errors, and malicious traffic definitions (SQLi, XSS, LFI).
3. The security team must review perimeter security anomalies at least daily.

## CC6.8: Unauthorized Activity Triage and Mitigation
1. Threat detection mechanisms must be continuously active across all
   production ECS nodes and network load balancers.
2. If an external entity exhibits deterministic scanning behavior or targeted
   application vulnerability exploitation, automated or semi-automated
   throttling/blocking mechanisms must be initiated.
3. Every automated mitigation action must be traceable to an authoritative
   system event log and authenticated by an explicit administrative validation
   window.

## CC6.8.3: Administrative Validation Window
All state-changing security actions (firewall rule modifications, IP blocks,
WAF ACL changes) require explicit human approval before execution. This
administrative validation window is mandated by SOC 2 CC6.8.3 and cannot be
bypassed by automated systems.
