"""Workflow execution context — accumulates phase outputs."""

from __future__ import annotations

from typing import Any


class WorkflowContext:
    """Shared state container passed between workflow phases.

    Each phase reads its declared `input` keys and writes its `output` key.
    The context is a simple dict — phases can read any prior phase's output.
    """

    def __init__(self, workflow_name: str) -> None:
        self.workflow_name = workflow_name
        self._data: dict[str, Any] = {}
        self.phase_outputs: dict[str, Any] = {}

    def set_output(self, phase_id: str, value: Any) -> None:
        """Store a phase's output under its phase_id."""
        self.phase_outputs[phase_id] = value
        self._data[phase_id] = value

    def get_input(self, key: str | list[str]) -> dict[str, Any]:
        """Retrieve input values by key(s).

        Args:
            key: A single phase_id or list of phase_ids to retrieve.

        Returns:
            Dict mapping phase_id → output value.
        """
        if isinstance(key, str):
            keys = [key]
        else:
            keys = key

        result: dict[str, Any] = {}
        for k in keys:
            if k in self._data:
                result[k] = self._data[k]
            else:
                result[k] = None
        return result

    def get_all_outputs(self) -> dict[str, Any]:
        """Return all phase outputs as a dict."""
        return dict(self._data)

    def to_summary(self) -> str:
        """Return a human-readable summary of accumulated context."""
        lines = [f"Workflow: {self.workflow_name}"]
        for phase_id, output in self._data.items():
            if isinstance(output, str):
                preview = output[:200] + "..." if len(output) > 200 else output
            elif isinstance(output, dict):
                import json
                preview = json.dumps(output, indent=2)[:200] + "..."
            else:
                preview = str(output)[:200]
            lines.append(f"  Phase '{phase_id}': {preview}")
        return "\n".join(lines)
