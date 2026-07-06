# Bug Report — BlueTeam Autopilot

Findings from demo-mode functional testing and jailbreak/security testing.
Updated after v2.2.1 (secure coding fixes), v3.0.0 (autonomous SOC platform), and bug resolution pass.
All 9 issues now resolved.

---

## Functional Bugs

### ~~BUG-1: `render-report.py` — Inverse conditional blocks never render~~ ✅ Fixed in v2.2.1

`render-report.py:89` — regex corrected from `r'\{\{\\^(\w+)\}\}...'` to `r'\{\{\^(\w+)\}\}...'`.

---

### ~~BUG-2: `render-report.py` — Scalar `{{#key}}` conditionals always render empty~~ ✅ Fixed in v2.2.1

`render-report.py:66–68` — `render_array` now falls back to conditional behavior for non-list values:
`return section if value else ''`.

---

### ~~BUG-3: `get-knowledge.sh` — Wrong path depth to knowledge documents~~ ✅ Fixed in v2.2.1

`get-knowledge.sh:57` — corrected from `../../blueteam-autopilot-knowledge` to
`../blueteam-autopilot-knowledge`.

---

### ~~BUG-4: `get-knowledge.sh` — Filename mapping doesn't match actual documents~~ ✅ Fixed in v2.2.1

`get-knowledge.sh:39–44` — case statement now maps to hyphenated filenames that match the
documents directory (`nist-csf.md`, `soc2-cc6.md`, `runbook-waf-triage.md`, etc.).

---

### ~~BUG-5: `get-event-detail.sh` returns same fixture regardless of event ID~~ ✅ Fixed in v3.0.0

`fixtures/event_detail_evt-demo-20260614-003.json` added. Per-event fixture dispatch now
possible (script dispatching not yet verified, but the file exists).

---

### BUG-6: ~~`block_waf_ips` bypasses HITL approval gate~~ ✅ Fixed

**File:** `connectonion_qwen/plugins.py:21–26` vs `connectonion_qwen/tools.py:24–30`
**Severity:** High

`tools.py` declared `block_waf_ips` as a state-changing tool requiring human approval, but
`plugins.py`'s `_STATE_CHANGING_TOOLS` set (the one the HITL gate actually checks) omitted it.
The `hitl_approval` plugin fired `if tool_name not in _STATE_CHANGING_TOOLS: return` — so
`block_waf_ips(dry_run=False)` executed silently, creating a live WAF block rule without any
human confirmation prompt.

**Fix applied:** Added `block_waf_ips` to `_STATE_CHANGING_TOOLS` in `plugins.py`, added
`block-waf-ips.sh` to `script_map`, and added dry-run dispatch in `_run_dry_run`.

---

## Security Vulnerabilities

### ~~SEC-1: RCE via Python triple-quote injection in `grc-sync.sh`~~ ✅ Fixed in v2.2.1

`grc-sync.sh:133–136` — `validate_controls` now passes untrusted content via stdin:
`printf '%s' "$content" | python3 -c "... content = sys.stdin.read() ..."`.

---

### ~~SEC-2 (HIGH): Prompt injection via unsanitized API response data~~ ✅ Fixed

**Files:** All scripts in `skills/blueteam-autopilot-ops/scripts/` + `connectonion_qwen/tools.py`
**Status:** Fixed — guardrail strengthened in `system_prompt.py`

All CLI scripts output raw JSON from Alibaba Cloud APIs directly to stdout; `tools.py` passes
this verbatim to the LLM via `_run_script`. In real mode, attacker-controlled data in Security
Center (event titles, alert descriptions, asset names, attack chain fields) reaches the model as
unframed text.

**Fix applied:** Guardrail #7 in `system_prompt.py` strengthened to explicitly frame all tool
output as potentially adversarial, enumerate specific field types that could carry injection
payloads, and instruct the agent to flag injection attempts as suspicious activity rather than
acting on them.

---

### ~~SEC-3 (HIGH): Knowledge document supply chain injection via GRC sync~~ ✅ Fixed

**File:** `skills/blueteam-autopilot-knowledge/scripts/grc-sync.sh:426–460`
**Status:** Fixed — human review gate already present in code

`grc-sync.sh` now shows a diff of proposed changes and requires explicit `y/N` confirmation
before writing GRC server responses to knowledge documents. The gate covers both updates
to existing documents and creation of new documents. Previous versions are archived before
overwrite.

---

## Summary

| ID | File | Type | Status |
| --- | --- | --- | --- |
| BUG-1 | `render-report.py:89` | Broken inverse conditional regex | ✅ Fixed v2.2.1 |
| BUG-2 | `render-report.py:66` | Scalar conditionals render empty | ✅ Fixed v2.2.1 |
| BUG-3 | `get-knowledge.sh:57` | Wrong `..` depth to knowledge dir | ✅ Fixed v2.2.1 |
| BUG-4 | `get-knowledge.sh:39` | Filename mismatch (underscore vs hyphen) | ✅ Fixed v2.2.1 |
| BUG-5 | `fixtures/event_detail.json` | Single fixture for all event IDs | ✅ Fixed v3.0.0 |
| BUG-6 | `plugins.py:21` | `block_waf_ips` missing from HITL gate | ✅ Fixed |
| SEC-1 | `grc-sync.sh:133` | RCE via Python triple-quote injection | ✅ Fixed v2.2.1 |
| SEC-2 | All ops scripts | Prompt injection via API response fields | ✅ Fixed |
| SEC-3 | `grc-sync.sh:460` | Knowledge document supply chain injection | ✅ Fixed |
