"""AWS cloud provider."""

from __future__ import annotations

from connectonion_qwen.providers import register_provider
from connectonion_qwen.providers.aws.tools import ALL_TOOLS, AWS_STATE_CHANGING_TOOLS


class AWSProvider:
    name = "aws"

    def get_tools(self):
        return list(ALL_TOOLS)

    def get_state_changing_tools(self):
        return AWS_STATE_CHANGING_TOOLS


register_provider("aws", AWSProvider)
