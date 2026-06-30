"""Agent runtime -- core loop using Qwen Cloud's OpenAI-compatible API.

Implements the function calling loop per:
  https://docs.qwencloud.com/developer-guides/text-generation/function-calling

Uses thinking mode for complex tool orchestration per:
  https://docs.qwencloud.com/developer-guides/text-generation/thinking

Uses structured output for action proposals per:
  https://docs.qwencloud.com/developer-guides/text-generation/structured-output
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import Any, Callable

from openai import OpenAI

from agent.config import (
    DASHSCOPE_API_KEY,
    ENABLE_THINKING,
    MAX_TOOL_ROUNDS,
    QWEN_BASE_URL,
    QWEN_MODEL,
)
from agent.hitl import request_approval
from agent.system_prompt import SYSTEM_PROMPT
from agent.tools import STATE_CHANGING_TOOLS, TOOL_DEFINITIONS, execute_tool


# ---------------------------------------------------------------------------
# Callback types for CLI/UI integration
# ---------------------------------------------------------------------------

@dataclass
class AgentCallbacks:
    """Hooks for the CLI or web UI to observe agent activity."""

    on_thinking: Callable[[str], None] = lambda text: None
    on_tool_call: Callable[[str, dict], None] = lambda name, args: None
    on_tool_result: Callable[[str, str], None] = lambda name, result: None
    on_text: Callable[[str], None] = lambda text: None
    on_hitl: Callable[[str, dict, str], bool] = request_approval


# ---------------------------------------------------------------------------
# Stream aggregator
# ---------------------------------------------------------------------------

def _aggregate_stream(stream) -> dict[str, Any]:
    """Aggregate a streaming response into a single assistant message dict.

    Handles:
    - reasoning_content (thinking mode deltas)
    - content (text deltas)
    - tool_calls (function name + argument deltas)

    Per Qwen Cloud streaming docs, tool call arguments arrive incrementally
    and must be concatenated before JSON parsing.
    """
    reasoning_content = ""
    content = ""
    tool_calls_map: dict[int, dict] = {}

    for chunk in stream:
        if not chunk.choices:
            continue
        delta = chunk.choices[0].delta

        # Thinking mode reasoning content
        if hasattr(delta, "reasoning_content") and delta.reasoning_content:
            reasoning_content += delta.reasoning_content

        # Regular text content
        if hasattr(delta, "content") and delta.content:
            content += delta.content

        # Tool call deltas
        if hasattr(delta, "tool_calls") and delta.tool_calls:
            for tc_chunk in delta.tool_calls:
                idx = tc_chunk.index
                func = tc_chunk.function
                if func.arguments is None:
                    func.arguments = ""
                if idx not in tool_calls_map:
                    tool_calls_map[idx] = {
                        "id": tc_chunk.id,
                        "type": "function",
                        "function": {
                            "name": func.name or "",
                            "arguments": func.arguments,
                        },
                    }
                else:
                    tool_calls_map[idx]["function"]["arguments"] += func.arguments
                    if tc_chunk.id:
                        tool_calls_map[idx]["id"] = tc_chunk.id

    # Build the assistant message
    msg: dict[str, Any] = {"role": "assistant", "content": content or None}

    if reasoning_content:
        msg["reasoning_content"] = reasoning_content

    if tool_calls_map:
        msg["tool_calls"] = [
            tool_calls_map[i] for i in sorted(tool_calls_map.keys())
        ]

    return msg


# ---------------------------------------------------------------------------
# Agent runtime
# ---------------------------------------------------------------------------

@dataclass
class AgentResult:
    """Result of an agent run."""

    text: str
    messages: list[dict] = field(repr=False)
    tool_calls_made: int = 0


def create_client() -> OpenAI:
    """Create the Qwen Cloud OpenAI client."""
    if not DASHSCOPE_API_KEY:
        raise RuntimeError(
            "DASHSCOPE_API_KEY is not set. "
            "Add it to your .env file or export it as an environment variable."
        )
    return OpenAI(api_key=DASHSCOPE_API_KEY, base_url=QWEN_BASE_URL)


def run_agent(
    user_message: str,
    *,
    client: OpenAI | None = None,
    callbacks: AgentCallbacks | None = None,
    history: list[dict] | None = None,
) -> AgentResult:
    """Run the agent loop until Qwen produces a final answer.

    Args:
        user_message: The user's input message.
        client: Optional pre-configured OpenAI client.
        callbacks: Optional hooks for observing agent activity.
        history: Optional prior conversation messages (multi-turn support).

    Returns:
        AgentResult with the final text, full message history, and tool call count.
    """
    if client is None:
        client = create_client()
    if callbacks is None:
        callbacks = AgentCallbacks()

    # Build initial message list
    messages: list[dict] = [{"role": "system", "content": SYSTEM_PROMPT}]
    if history:
        messages.extend(history)
    messages.append({"role": "user", "content": user_message})

    tool_calls_made = 0

    for round_num in range(MAX_TOOL_ROUNDS):
        # Build request kwargs
        kwargs: dict[str, Any] = {
            "model": QWEN_MODEL,
            "messages": messages,
            "tools": TOOL_DEFINITIONS,
            "parallel_tool_calls": True,
            "stream": True,
        }

        # Enable thinking mode if configured
        if ENABLE_THINKING:
            kwargs["extra_body"] = {"enable_thinking": True}

        # Call Qwen Cloud
        stream = client.chat.completions.create(**kwargs)

        # Aggregate the streaming response
        assistant_msg = _aggregate_stream(stream)
        messages.append(assistant_msg)

        # Emit thinking content if present
        if assistant_msg.get("reasoning_content"):
            callbacks.on_thinking(assistant_msg["reasoning_content"])

        # If no tool calls, return the final answer
        if not assistant_msg.get("tool_calls"):
            final_text = assistant_msg.get("content") or ""
            callbacks.on_text(final_text)
            return AgentResult(
                text=final_text,
                messages=messages,
                tool_calls_made=tool_calls_made,
            )

        # Execute each tool call
        for tool_call in assistant_msg["tool_calls"]:
            func_name: str = tool_call["function"]["name"]
            arguments: dict = json.loads(tool_call["function"]["arguments"])
            tool_calls_made += 1

            # Notify callback
            callbacks.on_tool_call(func_name, arguments)

            # HITL gate for state-changing tools
            if func_name in STATE_CHANGING_TOOLS:
                # Run dry-run first
                dry_args = {**arguments, "dryRun": True}
                dry_run_result = execute_tool(func_name, dry_args)

                # Request approval
                approved = callbacks.on_hitl(func_name, arguments, dry_run_result)

                if not approved:
                    tool_result = json.dumps({
                        "rejected": True,
                        "reason": "User denied approval. No action was taken.",
                    })
                else:
                    # Execute for real
                    real_args = {**arguments, "dryRun": False}
                    tool_result = execute_tool(func_name, real_args)
            else:
                tool_result = execute_tool(func_name, arguments)

            # Notify callback
            callbacks.on_tool_result(func_name, tool_result)

            # Append tool result per Qwen Cloud function calling pattern
            messages.append({
                "role": "tool",
                "tool_call_id": tool_call["id"],
                "content": tool_result,
            })

    return AgentResult(
        text="Agent reached maximum tool rounds without producing a final answer.",
        messages=messages,
        tool_calls_made=tool_calls_made,
    )


def generate_proposal(
    messages: list[dict],
    *,
    client: OpenAI | None = None,
) -> dict:
    """Generate a structured action proposal using Qwen Cloud structured output.

    Per https://docs.qwencloud.com/developer-guides/text-generation/structured-output
    response_format=json_object guarantees valid JSON output.

    Args:
        messages: Current conversation history (from run_agent).
        client: Optional pre-configured OpenAI client.

    Returns:
        Parsed proposal dict with reasoning, recommendedPolicyId, etc.
    """
    if client is None:
        client = create_client()

    proposal_messages = messages + [
        {
            "role": "user",
            "content": (
                "Generate a formal action proposal as JSON with these fields: "
                "reasoning, recommendedPolicyId, expectedEffects, rollbackPlan, "
                "riskLevel (LOW/MEDIUM/HIGH), requiresApproval (always true)."
            ),
        }
    ]

    response = client.chat.completions.create(
        model=QWEN_MODEL,
        messages=proposal_messages,
        response_format={"type": "json_object"},
    )

    text = response.choices[0].message.content or "{}"
    return json.loads(text)
