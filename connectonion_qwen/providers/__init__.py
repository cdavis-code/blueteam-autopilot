"""Provider registry — loads cloud providers based on INFRA config."""

from __future__ import annotations

import logging
from typing import Callable

from connectonion_qwen.config import INFRA

logger = logging.getLogger(__name__)

_registry: dict[str, type] = {}


def register_provider(name: str, provider_class: type) -> None:
    """Register a provider class by name."""
    _registry[name] = provider_class


def load_providers() -> tuple[list[Callable], set[str]]:
    """Load active providers and return (all_tools, state_changing_tools)."""
    all_tools: list[Callable] = []
    state_changing: set[str] = set()

    for provider_name in INFRA:
        if provider_name in _registry:
            provider = _registry[provider_name]()
            all_tools.extend(provider.get_tools())
            state_changing.update(provider.get_state_changing_tools())
            logger.info(f"Loaded provider: {provider_name} ({len(provider.get_tools())} tools)")
        else:
            logger.warning(f"Unknown provider: {provider_name}. Available: {list(_registry.keys())}")

    return all_tools, state_changing
