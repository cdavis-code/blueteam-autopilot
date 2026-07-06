"""Workflow engine — discover, parse, and execute WORKFLOW.md definitions."""

from __future__ import annotations

import logging
from pathlib import Path

from connectonion_qwen.config import WORKFLOWS_DIR
from workflows._engine.parser import (
    WorkflowDefinition,
    discover_workflows,
    parse_workflow,
)
from workflows._engine.runner import run_workflow as _run_workflow

logger = logging.getLogger(__name__)


def run_workflow(workflow_name: str) -> dict:
    """Execute a named workflow by looking up its WORKFLOW.md.

    Args:
        workflow_name: Name of the workflow (directory name under workflows/).

    Returns:
        Dict with execution results including phase outputs and summary.

    Raises:
        FileNotFoundError: If the workflow is not found.
    """
    workflows = discover_workflows(WORKFLOWS_DIR)

    if workflow_name not in workflows:
        available = ", ".join(workflows.keys()) if workflows else "none"
        raise FileNotFoundError(
            f"Workflow '{workflow_name}' not found. Available: {available}"
        )

    definition = parse_workflow(workflows[workflow_name])
    return _run_workflow(definition)


def list_workflows() -> dict[str, str]:
    """Return a mapping of workflow name → description for all discovered workflows."""
    workflows = discover_workflows(WORKFLOWS_DIR)
    result: dict[str, str] = {}

    for name, path in workflows.items():
        try:
            defn = parse_workflow(path)
            result[name] = defn.description
        except Exception as exc:
            logger.warning(f"Failed to parse workflow '{name}': {exc}")
            result[name] = f"(parse error: {exc})"

    return result
