"""Workflow definition parser — reads WORKFLOW.md files with YAML frontmatter."""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field
from pathlib import Path

import yaml

logger = logging.getLogger(__name__)


@dataclass
class PhaseDef:
    """Definition of a single workflow phase."""

    id: str
    persona: str
    tools: list[str]
    thinking: bool = False
    input: str | list[str] | None = None
    output: str = ""
    requires_hitl: bool = False
    instructions: str = ""  # Markdown body for this phase


@dataclass
class WorkflowDefinition:
    """Parsed workflow definition from a WORKFLOW.md file."""

    name: str
    description: str
    version: str = "1.0"
    requires_hitl: bool = False
    phases: list[PhaseDef] = field(default_factory=list)
    source_path: Path | None = None


def parse_workflow(workflow_path: Path) -> WorkflowDefinition:
    """Parse a WORKFLOW.md file into a WorkflowDefinition.

    The file must have YAML frontmatter delimited by '---' lines.
    The Markdown body is split into per-phase instructions using
    '## Phase: <id>' headings.

    Args:
        workflow_path: Path to the WORKFLOW.md file.

    Returns:
        Parsed WorkflowDefinition.

    Raises:
        ValueError: If frontmatter is missing or required fields are absent.
        FileNotFoundError: If workflow_path does not exist.
    """
    if not workflow_path.exists():
        raise FileNotFoundError(f"Workflow not found: {workflow_path}")

    content = workflow_path.read_text(encoding="utf-8")

    # Extract YAML frontmatter
    fm_match = re.match(r"^---\s*\n(.*?)\n---\s*\n(.*)$", content, re.DOTALL)
    if not fm_match:
        raise ValueError(
            f"Invalid WORKFLOW.md (no YAML frontmatter): {workflow_path}"
        )

    fm_text = fm_match.group(1)
    body = fm_match.group(2)

    try:
        fm = yaml.safe_load(fm_text)
    except yaml.YAMLError as exc:
        raise ValueError(f"Invalid YAML frontmatter in {workflow_path}: {exc}") from exc

    if not isinstance(fm, dict):
        raise ValueError(f"Frontmatter must be a YAML mapping: {workflow_path}")

    # Required fields
    name = fm.get("name")
    if not name:
        raise ValueError(f"Workflow missing 'name' field: {workflow_path}")

    description = fm.get("description", "")
    version = str(fm.get("version", "1.0"))
    requires_hitl = fm.get("requires-hitl", False)

    # Parse phases from frontmatter
    raw_phases = fm.get("phases", [])
    if not raw_phases:
        raise ValueError(f"Workflow has no phases defined: {workflow_path}")

    # Parse per-phase instructions from Markdown body
    phase_instructions = _parse_phase_instructions(body)

    phases: list[PhaseDef] = []
    for rp in raw_phases:
        phase_id = rp.get("id", "")
        if not phase_id:
            raise ValueError(f"Phase missing 'id' field in {workflow_path}")

        # Normalize input field
        raw_input = rp.get("input")
        if isinstance(raw_input, str):
            phase_input: str | list[str] | None = raw_input
        elif isinstance(raw_input, list):
            phase_input = raw_input
        else:
            phase_input = None

        phase = PhaseDef(
            id=phase_id,
            persona=rp.get("persona", "default"),
            tools=rp.get("tools", []),
            thinking=rp.get("thinking", False),
            input=phase_input,
            output=rp.get("output", ""),
            requires_hitl=rp.get("requires-hitl", False),
            instructions=phase_instructions.get(phase_id, ""),
        )
        phases.append(phase)

    # Validate phase graph: each phase's input must reference a prior phase's output
    _validate_phase(phases, workflow_path)

    return WorkflowDefinition(
        name=name,
        description=description,
        version=version,
        requires_hitl=requires_hitl,
        phases=phases,
        source_path=workflow_path,
    )


def _parse_phase_instructions(body: str) -> dict[str, str]:
    """Extract per-phase instructions from the Markdown body.

    Looks for headings of the form '## Phase: <id>' or '## Phase — <id>'.
    Everything under a heading (until the next heading) is that phase's instructions.
    """
    result: dict[str, str] = {}
    current_phase: str | None = None
    current_lines: list[str] = []

    for line in body.split("\n"):
        heading_match = re.match(r"^##\s+Phase[:\s—\-]+(.+)$", line, re.IGNORECASE)
        if heading_match:
            if current_phase:
                result[current_phase] = "\n".join(current_lines).strip()
            current_phase = heading_match.group(1).strip().lower()
            current_lines = []
        elif current_phase is not None:
            current_lines.append(line)

    if current_phase:
        result[current_phase] = "\n".join(current_lines).strip()

    return result


def _validate_phase(phases: list[PhaseDef], source: Path) -> None:
    """Validate that phase input/output references are satisfiable."""
    produced: set[str] = set()

    for phase in phases:
        # Check inputs reference prior outputs
        if phase.input:
            inputs = [phase.input] if isinstance(phase.input, str) else phase.input
            for inp in inputs:
                if inp not in produced:
                    logger.warning(
                        f"Phase '{phase.id}' in {source} references input "
                        f"'{inp}' which is not produced by any prior phase."
                    )

        # Register this phase's output
        if phase.output:
            produced.add(phase.output)


def discover_workflows(workflows_dir: Path) -> dict[str, Path]:
    """Discover all WORKFLOW.md files under the workflows directory.

    Returns:
        Dict mapping workflow name → path to WORKFLOW.md.
    """
    discovered: dict[str, Path] = {}

    if not workflows_dir.exists():
        return discovered

    for entry in workflows_dir.iterdir():
        if entry.is_dir() and not entry.name.startswith("_"):
            wf_file = entry / "WORKFLOW.md"
            if wf_file.exists():
                discovered[entry.name] = wf_file

    return discovered
