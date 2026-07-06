---
name: continuous-monitor
description: Autonomous SOC monitoring — scan for new events, triage severity, escalate high-severity findings
version: 1.0
requires-hitl: false
phases:
  - id: scan
    persona: sentinel
    tools: [get_monitor_state, get_account_context, list_security_events, get_waf_instance_info, list_waf_security_events, list_assets]
    thinking: false
    output: new_events
  - id: triage
    persona: analyst
    tools: [get_security_event_detail, list_alerts_for_event, search_similar_incidents, get_knowledge_document]
    thinking: true
    input: new_events
    output: triage_results
  - id: escalate
    persona: dispatcher
    tools: [store_incident_memory, update_monitor_state, generate_incident_report]
    thinking: false
    input: triage_results
    output: escalation_report
---
# Continuous Monitor Workflow

Autonomous SOC monitoring cycle. Runs on each daemon tick.
Executes 3 phases: scan → triage → escalate.

## Phase: scan

Fetch new security events since the last monitoring check:

1. Call `get_monitor_state` to retrieve the `last_check_timestamp`.
   - If null (first run), use the default time range (lastHour).
   - If set, use a time range that covers events since that timestamp.
2. Call `get_account_context` to establish region and edition.
3. Call `list_security_events` with the appropriate time range.
4. If Security Center events are empty (Basic/Advanced edition), fall back to WAF:
   - Call `get_waf_instance_info` to confirm WAF is active.
   - Call `list_waf_security_events` with the same time range.
5. Call `list_assets` to cross-reference affected assets.

Categorize discovered events by severity:
- **CRITICAL**: Immediate escalation required
- **HIGH**: Escalate with full context
- **MEDIUM**: Log and brief assessment
- **LOW**: Count only, no detailed analysis

Produce a structured inventory of new events grouped by severity.
If no new events found, report "all clear" and proceed to escalate phase
to update the monitor state timestamp.

## Phase: triage

Analyze each significant event and check for known patterns:

For each **CRITICAL** and **HIGH** event:
1. Call `get_security_event_detail` to extract attack chain, source IPs, CVEs.
2. Call `list_alerts_for_event` for underlying alert grouping.
3. Call `search_similar_incidents` with a description of the event
   (attack type + source IP + affected asset) to check institutional memory.
   - If similarity > 0.8: classify as **"recurring pattern"** — reference the
     previous incident and note if remediation was applied.
   - If similarity < 0.5: classify as **"novel threat"** — flag for attention.
   - Otherwise: classify as **"known pattern"** — similar to past events.
4. Optionally call `get_knowledge_document` to check trusted networks —
   if a source IP matches a trusted network, flag as potential insider threat.

For each **MEDIUM** event:
- Brief assessment: attack type, source IP, affected asset.
- No deep-dive unless patterns suggest coordinated attack.

**LOW** events are counted but not analyzed.

Produce a triage report with:
- Events classified by severity and novelty (novel/recurring/known)
- Insider threat indicators (trusted network matches)
- Recurring pattern references (previous incident IDs)
- Recommended escalation level for each event

## Phase: escalate

Produce the escalation summary and update monitoring state:

1. Count escalations by severity:
   - `critical_count`: Number of CRITICAL events
   - `high_count`: Number of HIGH events
   - `medium_count`: Number of MEDIUM events (logged, not escalated)
   - `low_count`: Number of LOW events (counted only)

2. For each CRITICAL and HIGH event:
   - Call `store_incident_memory` with a concise description including:
     attack type, severity, source IP, affected asset, novelty classification.
   - This builds institutional memory for future similarity search.

3. Call `update_monitor_state` with the escalation count:
   - Pass `escalations=critical_count + high_count`
   - This advances the last_check_timestamp for the next tick.

4. Produce a concise escalation summary for the daemon to display:
   - If escalations > 0: Format as alert with severity, event details,
     and recommended actions. Mark recurring patterns.
   - If no escalations: Brief "all clear" with event counts.
   - Include tick metadata: timestamp, events scanned, escalations.

The output should be concise enough for console display — the daemon
prints this directly. Use clear severity markers and keep descriptions
to one line per event.
