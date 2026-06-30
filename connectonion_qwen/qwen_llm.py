"""Custom Qwen Cloud LLM provider for ConnectOnion.

Subclasses ConnectOnion's LLM base class to support Qwen Cloud's DashScope
endpoint with thinking mode and streaming aggregation.

Thinking mode uses stream=True internally and aggregates the response,
preserving the quality benefit of chain-of-thought reasoning while presenting
a synchronous interface to ConnectOnion's agent loop.
"""

from __future__ import annotations

import json
import logging
from typing import Any, Dict, List, Optional, Type

import openai
from pydantic import BaseModel

from connectonion.core.llm import LLM, LLMResponse, ToolCall
from connectonion.core.usage import TokenUsage, calculate_cost, MODEL_CONTEXT_LIMITS, MODEL_PRICING

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Register Qwen models in ConnectOnion's registry
# ---------------------------------------------------------------------------
MODEL_CONTEXT_LIMITS["qwen3.7-plus"] = 131072
MODEL_CONTEXT_LIMITS["qwen-plus"] = 131072
MODEL_CONTEXT_LIMITS["qwen-max"] = 32768

MODEL_PRICING["qwen3.7-plus"] = {"input": 0.50, "output": 2.00, "cached": 0.25}
MODEL_PRICING["qwen-plus"] = {"input": 0.50, "output": 2.00, "cached": 0.25}
MODEL_PRICING["qwen-max"] = {"input": 2.00, "output": 8.00, "cached": 1.00}


class QwenCloudLLM(LLM):
    """Qwen Cloud LLM provider using DashScope's OpenAI-compatible endpoint.

    Supports thinking mode (chain-of-thought reasoning) via internal streaming
    aggregation, and parallel tool calls.
    """

    def __init__(
        self,
        api_key: Optional[str] = None,
        model: str = "qwen3.7-plus",
        base_url: str = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1",
        enable_thinking: bool = True,
        **kwargs,
    ):
        self.api_key = api_key
        if not self.api_key:
            raise ValueError(
                "Qwen Cloud API key required. Set DASHSCOPE_API_KEY in your .env file."
            )

        self.model = model
        self.base_url = base_url
        self.enable_thinking = enable_thinking

        self.client = openai.OpenAI(
            api_key=self.api_key,
            base_url=self.base_url,
        )

    def complete(
        self,
        messages: List[Dict[str, Any]],
        tools: Optional[List[Dict[str, Any]]] = None,
        **kwargs,
    ) -> LLMResponse:
        """Complete a conversation with optional tool support.

        Uses streaming internally to support Qwen Cloud's thinking mode.
        The stream is aggregated into a single response before returning.
        """
        api_kwargs: Dict[str, Any] = {
            "model": self.model,
            "messages": messages,
            "stream": True,
            **kwargs,
        }

        if tools:
            api_kwargs["tools"] = [
                {"type": "function", "function": tool} for tool in tools
            ]
            api_kwargs["parallel_tool_calls"] = True

        if self.enable_thinking:
            api_kwargs["extra_body"] = {"enable_thinking": True}

        try:
            stream = self.client.chat.completions.create(**api_kwargs)
        except openai.APIError as e:
            raise ValueError(f"Qwen Cloud API Error: {e}") from e

        # Aggregate the streaming response
        content, reasoning_content, tool_calls_map, usage_data = self._aggregate_stream(stream)

        # Build ToolCall list
        tool_calls = [
            ToolCall(
                name=tc["name"],
                arguments=tc["arguments"],
                id=tc["id"],
            )
            for tc in sorted(tool_calls_map.values(), key=lambda x: x["_idx"])
        ]

        # Build usage
        usage = None
        if usage_data:
            input_tokens = usage_data.get("prompt_tokens", 0)
            output_tokens = usage_data.get("completion_tokens", 0)
            cached_tokens = 0
            cost = calculate_cost(self.model, input_tokens, output_tokens, cached_tokens)
            usage = TokenUsage(
                input_tokens=input_tokens,
                output_tokens=output_tokens,
                cached_tokens=cached_tokens,
                cost=cost,
            )

        # Store reasoning_content in a wrapper for potential logging
        raw_response = {
            "content": content,
            "reasoning_content": reasoning_content,
        }

        return LLMResponse(
            content=content or None,
            tool_calls=tool_calls,
            raw_response=raw_response,
            usage=usage,
        )

    def structured_complete(
        self,
        messages: List[Dict],
        output_schema: Type[BaseModel],
        **kwargs,
    ) -> BaseModel:
        """Get structured Pydantic output using JSON mode."""
        schema_json = json.dumps(output_schema.model_json_schema(), indent=2)
        schema_instruction = (
            "Return ONLY valid JSON (no markdown) that matches this JSON Schema:\n"
            f"{schema_json}"
        )

        structured_messages = [{"role": "system", "content": schema_instruction}, *messages]

        response = self.client.chat.completions.create(
            model=self.model,
            messages=structured_messages,
            response_format={"type": "json_object"},
            **kwargs,
        )
        content = response.choices[0].message.content or "{}"
        return output_schema.model_validate_json(content)

    # -------------------------------------------------------------------
    # Stream aggregation (ported from agent/main.py _aggregate_stream)
    # -------------------------------------------------------------------

    @staticmethod
    def _aggregate_stream(stream):
        """Aggregate a streaming response into consolidated parts.

        Handles:
        - reasoning_content (thinking mode deltas)
        - content (text deltas)
        - tool_calls (function name + argument deltas)
        - usage (from final chunk)

        Returns:
            Tuple of (content, reasoning_content, tool_calls_map, usage_data)
        """
        reasoning_content = ""
        content = ""
        tool_calls_map: Dict[int, Dict] = {}
        usage_data = None

        for chunk in stream:
            # Capture usage from final chunk
            if hasattr(chunk, "usage") and chunk.usage:
                usage_data = {
                    "prompt_tokens": chunk.usage.prompt_tokens,
                    "completion_tokens": chunk.usage.completion_tokens,
                }

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
                            "id": tc_chunk.id or "",
                            "name": func.name or "",
                            "arguments": func.arguments,
                            "_idx": idx,
                        }
                    else:
                        tool_calls_map[idx]["arguments"] += func.arguments
                        if tc_chunk.id:
                            tool_calls_map[idx]["id"] = tc_chunk.id
                        if func.name:
                            tool_calls_map[idx]["name"] = func.name

        # Parse arguments JSON strings to dicts
        for tc in tool_calls_map.values():
            try:
                tc["arguments"] = json.loads(tc["arguments"]) if tc["arguments"] else {}
            except json.JSONDecodeError:
                logger.warning(f"Failed to parse tool arguments: {tc['arguments'][:200]}")
                tc["arguments"] = {}

        return content, reasoning_content, tool_calls_map, usage_data
