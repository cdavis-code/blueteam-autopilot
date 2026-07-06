"""Aliyun cloud provider."""

from __future__ import annotations

from connectonion_qwen.providers import register_provider
from connectonion_qwen.providers.aliyun.tools import ALL_TOOLS, STATE_CHANGING_TOOLS


class AliyunProvider:
    name = "aliyun"

    def get_tools(self):
        return list(ALL_TOOLS)

    def get_state_changing_tools(self):
        return STATE_CHANGING_TOOLS


register_provider("aliyun", AliyunProvider)
