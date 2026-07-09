#!/usr/bin/env python3
"""Deterministic Markdown report renderer for BlueTeam.

Reads JSON input and template files, produces formatted Markdown output.
Replaces Dart StringBuffer-based rendering from report_templates.dart.

Usage:
    python3 render-report.py --type incident --input report.json
    python3 render-report.py --type vuln --input vulns.json
    python3 render-report.py --type action --input proposal.json
    python3 render-report.py --type checklist --input report.json
"""

import argparse
import json
import sys
from pathlib import Path
from datetime import datetime, timezone


def load_template(template_name: str) -> str:
    """Load Markdown template from templates/ directory."""
    template_path = Path(__file__).parent.parent / "templates" / f"{template_name}.md"
    if not template_path.exists():
        print(f"Error: Template '{template_name}.md' not found", file=sys.stderr)
        sys.exit(1)
    return template_path.read_text()


def substitute_template(template: str, data: dict) -> str:
    """Simple template substitution with Mustache-like syntax.
    
    Supports:
    - {{key}} - Simple variable substitution
    - {{#array}}...{{/array}} - Array iteration with {{.}} for items
    - {{#array}}...{{#nested}}...{{/nested}}...{{/array}} - Nested objects
    - {{#key}}...{{/key}} - Conditional (truthy check)
    - {{^key}}...{{/key}} - Inverse conditional (falsy check)
    """
    result = template
    
    # Handle array sections first ({{#array}}...{{/array}})
    import re
    
    # Pattern for array sections with nested objects
    array_pattern = r'\{\{#(\w+)\}\}(.*?)\{\{/\1\}\}'
    
    def render_array(match):
        key = match.group(1)
        section = match.group(2)
        value = data.get(key, [])
        
        if isinstance(value, list):
            rendered_items = []
            for item in value:
                if isinstance(item, dict):
                    # Render section for each dict item
                    item_section = section
                    for k, v in item.items():
                        item_section = item_section.replace(f'{{{{{k}}}}}', str(v))
                    rendered_items.append(item_section)
                else:
                    # Simple value substitution
                    rendered_items.append(section.replace('{{.}}', str(item)))
            return ''.join(rendered_items)
        else:
            # Fall back to conditional behavior for scalar values
            return section if value else ''
    
    result = re.sub(array_pattern, render_array, result, flags=re.DOTALL)
    
    # Handle conditional sections ({{#key}}...{{/key}} for truthy)
    # Note: only catches patterns not already consumed by array handler above
    def render_conditional(match):
        key = match.group(1)
        section = match.group(2)
        value = data.get(key)
        return section if value else ''
    
    result = re.sub(r'\{\{#(\w+)\}\}(.*?)\{\{/\1\}\}', render_conditional, result, flags=re.DOTALL)
    
    # Handle inverse conditional sections ({{^key}}...{{/key}} for falsy)
    def render_inverse(match):
        key = match.group(1)
        section = match.group(2)
        value = data.get(key)
        return section if not value else ''
    
    result = re.sub(r'\{\{\^(\w+)\}\}(.*?)\{\{/\1\}\}', render_inverse, result, flags=re.DOTALL)
    
    # Simple variable substitution
    for key, value in data.items():
        if not isinstance(value, (dict, list)):  # Skip complex types
            result = result.replace(f'{{{{{key}}}}}', str(value))
    
    return result


def render_incident_report(data: dict) -> str:
    """Render incident report from JSON data."""
    template = load_template("incident-report")
    # Add generatedAt if not present
    if "generatedAt" not in data:
        data["generatedAt"] = datetime.now(timezone.utc).isoformat()
    return substitute_template(template, data)


def render_vuln_prioritization(data: dict) -> str:
    """Render vulnerability prioritization report."""
    template = load_template("vuln-prioritization")
    
    # Add generatedAt if not present
    if "generatedAt" not in data:
        data["generatedAt"] = datetime.now(timezone.utc).isoformat()
    
    # Add rankedCount if not present
    if "rankedCount" not in data and "rankedVulns" in data:
        data["rankedCount"] = len(data["rankedVulns"])
    
    return substitute_template(template, data)


def render_action_proposal(data: dict) -> str:
    """Render action proposal for human approval."""
    template = load_template("action-proposal")
    return substitute_template(template, data)


def render_runbook_checklist(data: dict) -> str:
    """Render runbook-aligned checklist."""
    template = load_template("runbook-checklist")
    return substitute_template(template, data)


def main():
    parser = argparse.ArgumentParser(
        description="Render Markdown reports from JSON data",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 render-report.py --type incident --input report.json
  python3 render-report.py --type vuln --input vulns.json --output vulns.md
  python3 render-report.py --type action --input proposal.json
  python3 render-report.py --type checklist --input report.json
        """
    )
    parser.add_argument(
        "--type",
        required=True,
        choices=["incident", "vuln", "action", "checklist"],
        help="Report type to render"
    )
    parser.add_argument(
        "--input",
        required=True,
        help="JSON input file"
    )
    parser.add_argument(
        "--output",
        help="Output file (default: stdout)"
    )
    args = parser.parse_args()
    
    # Load JSON input
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: Input file '{args.input}' not found", file=sys.stderr)
        sys.exit(1)
    
    try:
        with open(input_path) as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in '{args.input}': {e}", file=sys.stderr)
        sys.exit(1)
    
    # Render report
    renderers = {
        "incident": render_incident_report,
        "vuln": render_vuln_prioritization,
        "action": render_action_proposal,
        "checklist": render_runbook_checklist,
    }
    
    try:
        output = renderers[args.type](data)
    except Exception as e:
        print(f"Error: Failed to render {args.type} report: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Write output
    if args.output:
        output_path = Path(args.output)
        output_path.write_text(output)
        print(f"Report written to {args.output}", file=sys.stderr)
    else:
        print(output)


if __name__ == "__main__":
    main()
