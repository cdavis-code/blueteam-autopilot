Nice, you’re at the fun part now: you’ve got live data flowing (WAF + Agentic SOC) and a working MCP server. The next step is to **prove the full loop with your code**, then **wire it into a Qwen agent**.

I’d tackle it in this order.

***

## 1. Run your MCP stack in “real” mode

From your project root:

1. **Set env vars to hit your real Alibaba account**

```bash
export ALIBABA_ACCESS_KEY_ID="...from RAM user..."
export ALIBABA_ACCESS_KEY_SECRET="...from RAM user..."
export ALIBABA_REGION="your-region"         # e.g. ap-southeast-1
export SECURITY_CENTER_MODE="real"          # or "dry-run" if you’re nervous about actions
```

Make sure this region matches where Security Center / Agentic SOC / WAF are enabled.

2. **Start the MCP server (just to sanity‑check)**

```bash
dart run packages/alibaba_security_mcp/bin/server.dart
```

It should start without throwing auth/signing errors. Kill it with Ctrl+C after confirming.

***

## 2. Use your CLI to confirm live data

This is where you validate that what you see in the Alibaba console matches what your SDK/MCP stack sees.

From the repo root:

1. **Ping**

```bash
dart run packages/alibaba_security_cli/bin/alibaba_security_cli.dart ping
```

You should see `{ ok: true, region: ..., mode: ... }`.

2. **List events** (you just created some via WAF test traffic):

```bash
dart run packages/alibaba_security_cli/bin/alibaba_security_cli.dart events list --since-minutes 60
```

You should see at least one event corresponding to your recent WAF alerts (same timeframe you see in Agentic SOC UI). [alibabacloud](https://www.alibabacloud.com/help/en/security-center/getting-started/use-agentic-soc-quickly)

3. **Inspect one event**

Grab an `eventId` from the output and run:

```bash
dart run packages/alibaba_security_cli/bin/alibaba_security_cli.dart events get --id <EVENT_ID>
dart run packages/alibaba_security_cli/bin/alibaba_security_cli.dart alerts --event-id <EVENT_ID>
```

Check that the attack chain, source (`WAF`), and attacker IPs roughly match what Agentic SOC shows in the console. [alibabacloud](https://www.alibabacloud.com/help/en/security-center/user-guide/security-alert)

4. **Try vulns (if you’ve got any)**

```bash
dart run packages/alibaba_security_cli/bin/alibaba_security_cli.dart vulns list --severity HIGH
```

If Security Center has found vulnerabilities on your ECS instance, they should appear here as well. [alibabacloud](https://www.alibabacloud.com/help/en/security-center/product-overview/introduction-to-security-center-basic)

5. **List response policies**

If you configured an IP‑blocking response per the quick‑start:

```bash
dart run packages/alibaba_security_cli/bin/alibaba_security_cli.dart policies list
```

Confirm that your policy shows up with a recognizable name/action (e.g., block WAF attack IPs). [alibabacloud](https://www.alibabacloud.com/help/zh/security-center/getting-started/use-agentic-soc-quickly)

This completes the “MCP + SDK actually talks to live Alibaba” proof.

***

## 3. Capture fixtures for demo mode (optional but highly recommended)

While you have fresh events:

1. Run the same CLI commands with `--output` or just redirect to files, e.g.:

```bash
dart run ... events list --since-minutes 60 > fixtures/events_recent.json
dart run ... events get --id <EVENT_ID> > fixtures/event_<EVENT_ID>.json
dart run ... alerts --event-id <EVENT_ID> > fixtures/alerts_<EVENT_ID>.json
```

2. Wire your API client so that when `SECURITY_CENTER_MODE=demo`, it returns data from these fixture files instead of calling Alibaba.

That will give judges an easy, no‑cloud way to run the agent later, while your “real” mode stays for you and advanced users.

***

## 4. Wire the MCP server into a Qwen agent

Now that the tools work, plug them into Qwen-Agent so you can start playing with the Autopilot behavior.

1. **Install Qwen-Agent with MCP support**

```bash
pip install -U "qwen-agent[mcp]"
```

Qwen-Agent has first‑class support for MCP via a `mcpServers` block in the tools config. [qwenlm-qwen-agent.mintlify](https://qwenlm-qwen-agent.mintlify.app/guides/mcp-integration)

2. **Create a small Python script to connect to your MCP server**

Example:

```python
from qwen_agent.agents import Assistant

llm_cfg = {
    "model": "qwen3-max",
    "model_type": "qwen_dashscope",  # or whatever backend you’re using
}

mcp_tools = [{
    "mcpServers": {
        "alibaba-security": {
            "command": "dart",
            "args": ["run", "packages/alibaba_security_mcp/bin/server.dart"],
            "env": {
                "ALIBABA_ACCESS_KEY_ID": "...",
                "ALIBABA_ACCESS_KEY_SECRET": "...",
                "ALIBABA_REGION": "your-region",
                "SECURITY_CENTER_MODE": "real"  # or "demo"
            }
        }
    }
}]

system_message = """
You are BlueTeam Autopilot, a SecOps assistant for Alibaba Cloud.
Use the Alibaba Security MCP tools to:
1) List recent security events;
2) Explain what happened;
3) Recommend a response policy, but do NOT execute it unless explicitly asked.
"""

agent = Assistant(
    llm=llm_cfg,
    system_message=system_message,
    function_list=mcp_tools,
)

# Simple REPL
while True:
    user = input("You: ")
    if not user:
        break
    resp = agent.run(user)
    print(resp["output_text"])
```

This configuration pattern (MCP server declared under `mcpServers` in `function_list`) is exactly how the Qwen-Agent docs show running custom MCP tools. [qwenlm.github](https://qwenlm.github.io/Qwen-Agent/en/guide/core_moduls/mcp/)

3. **Try some prompts**

- “List high‑severity security events from the last hour and summarize them.”  
- “For the most recent incident, explain what happened and which IPs should be blocked.”  
- “Propose a response policy I could apply to mitigate this attack.”

You should see Qwen call your MCP tools under the hood and produce useful summaries and recommendations.

***

## 5. Decide what to build next (UI vs. polish)

Once the loop is working end‑to‑end:

- If you want **fast hackathon progress**:  
  - Build a minimal web UI that calls a backend endpoint which in turn invokes the Qwen agent (with your MCP server configured) and returns incident summaries + recommended actions.

- If you want to **harden the backend first**:  
  - Add clearer error messages and logging to your MCP tools.  
  - Flesh out “demo” mode fully so others can run everything without credentials.

Given where you are, the immediate, high‑leverage next step is: **wire your MCP server into Qwen-Agent and get a couple of prompt‑driven Autopilot flows working against your live data**, then we can design the UI and demo narrative around those flows.