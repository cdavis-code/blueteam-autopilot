# DEPRECATED

This package has been migrated to agent skills as part of the hybrid architecture initiative.

## Migration Mapping

| Dart File | Skill Location | Purpose |
|-----------|----------------|---------|
| CLI wrapper commands | `skills/blueteam-autopilot-ops/scripts/` | Bash scripts wrapping aliyun CLI |
| API naming conventions | `skills/blueteam-autopilot-ops/references/api-naming.md` | CLI vs. Dart SDK naming |
| Edition limitations | `skills/blueteam-autopilot-ops/references/edition-limits.md` | Security Center edition matrix |

### Script Migration

| CLI Command | Script Replacement |
|-------------|-------------------|
| `list_security_events` | `scripts/list-events.sh` |
| `get_event_detail` | `scripts/get-event-detail.sh` |
| `list_waf_events` | `scripts/list-waf-events.sh` |
| `verify_log_delivery` | `scripts/verify-log-delivery.sh` |

## Migration Date

**2026-06-14**

## Why Deprecated?

This package has been replaced with operational CLI skills:

1. **No Compilation:** Bash scripts work immediately, no `dart pub get` or compile step
2. **Direct CLI Integration:** Scripts call `aliyun` CLI directly, tested against real APIs
3. **Better Error Handling:** Scripts include troubleshooting guidance and edition workarounds
4. **Reduced Codebase:** ~400 lines of Dart → ~350 lines of bash scripts (12.5% reduction)

## What to Use Instead

- **Event Listing:** `skills/blueteam-autopilot-ops/scripts/list-events.sh`
- **Event Deep-Dive:** `skills/blueteam-autopilot-ops/scripts/get-event-detail.sh`
- **WAF Events:** `skills/blueteam-autopilot-ops/scripts/list-waf-events.sh`
- **Log Verification:** `skills/blueteam-autopilot-ops/scripts/verify-log-delivery.sh`

## Production Backend (Retained)

The following packages remain active for production reliability:
- `alibaba_security_backend` - HTTP server
- `alibaba_security_mcp` - MCP tool server
- `alibaba_security_api` - API client library

**Note:** The MCP server (`alibaba_security_mcp`) provides type-safe tool definitions that can be used as an alternative to CLI scripts when available.

## Future Cleanup

This package will be removed from the workspace in a future cleanup phase.

## References

- [Hybrid Architecture Document](../../design/cli-skill-poc-summary.md)
- [API Naming Conventions](../../skills/blueteam-autopilot-ops/references/api-naming.md)
- [Edition Limitations](../../skills/blueteam-autopilot-ops/references/edition-limits.md)
