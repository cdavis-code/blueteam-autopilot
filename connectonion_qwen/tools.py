"""BlueTeam Autopilot tools — thin dispatcher for multi-cloud providers.

Loads tools from active providers based on INFRA config.
Re-exports ALL_TOOLS and STATE_CHANGING_TOOLS for backward compatibility.
"""

from __future__ import annotations

import logging

# Import providers to trigger registration
import connectonion_qwen.providers.aliyun  # noqa: F401
import connectonion_qwen.providers.aws  # noqa: F401

from connectonion_qwen.providers import load_providers

logger = logging.getLogger(__name__)

# Load tools from active providers
ALL_TOOLS, STATE_CHANGING_TOOLS = load_providers()

logger.info(f"Loaded {len(ALL_TOOLS)} tools from providers. "
            f"State-changing: {STATE_CHANGING_TOOLS}")
