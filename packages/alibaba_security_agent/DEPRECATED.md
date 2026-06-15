# DEPRECATED

This package has been migrated to agent skills as part of the hybrid architecture initiative.

## Migration Mapping

| Dart File | Skill Location | Purpose |
|-----------|----------------|---------|
| `lib/src/prompts/system_prompt.dart` | `skills/blueteam-autopilot-core/SKILL.md` | Agent role, MCP tools, guardrails |
| `lib/src/prompts/behavior_prompts.dart` | `skills/blueteam-autopilot-core/BEHAVIORS.md` | 5 core behaviors |
| `lib/src/templates/report_templates.dart` | `skills/blueteam-autopilot-reports/` | Report templates + renderer |
| `lib/src/knowledge/secops_knowledge.dart` | `skills/blueteam-autopilot-knowledge/` | Knowledge base documents |
| `lib/src/config/agent_config.dart` | `skills/blueteam-autopilot-core/SKILL.md` (Configuration section) | Agent configuration |
| `lib/src/models/*.dart` | `skills/blueteam-autopilot-reports/schemas/` | JSON Schema validation |

## Migration Date

**2026-06-14**

## Why Deprecated?

This package has been replaced with agent skills following Anthropic's Agent Skills architecture:

1. **Flexibility:** Skills are editable Markdown files, no compilation required
2. **Progressive Disclosure:** Only relevant content loads into context (~100 tokens metadata, ~5k max on trigger)
3. **AI-Native:** Skills designed for Claude/Qwen consumption, not human reading
4. **Reduced Codebase:** ~800 lines of Dart → ~600 lines of Markdown + templates (25% reduction)

## What to Use Instead

- **Agent Workflows:** `skills/blueteam-autopilot-core/`
- **Report Generation:** `skills/blueteam-autopilot-reports/`
- **Knowledge Base:** `skills/blueteam-autopilot-knowledge/`

## Production Backend (Retained)

The following packages remain active for production reliability:
- `alibaba_security_backend` - HTTP server
- `alibaba_security_mcp` - MCP tool server
- `alibaba_security_api` - API client library

## Future Cleanup

This package will be removed from the workspace in a future cleanup phase.

## References

- [Hybrid Architecture Document](../../design/cli-skill-poc-summary.md)
- [Anthropic Agent Skills Overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)
