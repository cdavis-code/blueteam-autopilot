"""Provider protocol — interface each cloud provider must implement."""

from __future__ import annotations

from typing import Callable, Protocol


class CloudProvider(Protocol):
    """Interface for cloud provider components."""

    name: str

    def get_tools(self) -> list[Callable]:
        """Return list of tool functions for this provider."""
        ...

    def get_state_changing_tools(self) -> set[str]:
        """Return set of tool names that require HITL approval."""
        ...
