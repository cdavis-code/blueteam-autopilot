"""MCP server integration — connect to external MCP tools and expose them
as ConnectOnion-compatible Python functions.

Reads `.mcp.json` (or path from MCP_CONFIG_PATH env var), connects to each
configured server via stdio or SSE, discovers tools, and wraps them as sync
Python functions with proper type hints and docstrings.

Unreachable servers are skipped with a warning — existing knowledge docs
serve as fallback.
"""

from __future__ import annotations

import asyncio
import inspect
import json
import logging
import os
import re
import sys
import threading
from pathlib import Path
from typing import Any, Callable

from connectonion_qwen.config import MCP_CONFIG_PATH, _PROJECT_ROOT

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# JSON Schema → Python type mapping
# ---------------------------------------------------------------------------

_JSON_TYPE_MAP: dict[str, type] = {
    "string": str,
    "integer": int,
    "number": float,
    "boolean": bool,
    "array": list,
    "object": dict,
}


def _json_schema_to_python_type(schema: dict) -> type:
    """Convert a JSON Schema property definition to a Python type."""
    return _JSON_TYPE_MAP.get(schema.get("type", "string"), str)


# ---------------------------------------------------------------------------
# Async event loop bridge (sync ↔ async)
# ---------------------------------------------------------------------------

class _AsyncBridge:
    """Runs a persistent asyncio event loop in a daemon thread so that
    sync code can submit coroutines and block for results."""

    def __init__(self) -> None:
        self._loop: asyncio.AbstractEventLoop | None = None
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        self._loop = asyncio.new_event_loop()
        self._thread = threading.Thread(
            target=self._loop.run_forever, daemon=True, name="mcp-loop"
        )
        self._thread.start()

    def run_sync(self, coro: Any) -> Any:
        """Submit *coro* to the background loop and block until done."""
        if self._loop is None or not self._loop.is_running():
            raise RuntimeError("AsyncBridge not started")
        future = asyncio.run_coroutine_threadsafe(coro, self._loop)
        return future.result(timeout=60)

    def shutdown(self) -> None:
        if self._loop and self._loop.is_running():
            self._loop.call_soon_threadsafe(self._loop.stop)
        if self._thread:
            self._thread.join(timeout=5)
            self._thread = None
        self._loop = None


# ---------------------------------------------------------------------------
# Environment variable interpolation
# ---------------------------------------------------------------------------

_ENV_VAR_RE = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}")


def _resolve_env_vars(obj: Any) -> Any:
    """Recursively resolve ``${VAR_NAME}`` references in string values.

    Supports the standard ``${VAR}`` syntax used by Claude Desktop, Cursor,
    and other MCP hosts.  Unresolved variables become empty strings.
    """
    if isinstance(obj, str):
        def _replacer(m: re.Match) -> str:
            return os.environ.get(m.group(1), "")
        return _ENV_VAR_RE.sub(_replacer, obj)
    if isinstance(obj, dict):
        return {k: _resolve_env_vars(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_resolve_env_vars(item) for item in obj]
    return obj


# ---------------------------------------------------------------------------
# MCP config loader
# ---------------------------------------------------------------------------

def _load_mcp_config() -> dict:
    """Load and parse the MCP config file, resolving ``${VAR}`` references."""
    config_path = Path(MCP_CONFIG_PATH)
    if not config_path.is_absolute():
        config_path = _PROJECT_ROOT / config_path

    if not config_path.exists():
        return {}

    with open(config_path) as f:
        data = json.load(f)

    return _resolve_env_vars(data.get("mcpServers", {}))


# ---------------------------------------------------------------------------
# Dynamic function creation from MCP tool schemas
# ---------------------------------------------------------------------------

def _make_tool_function(
    bridge: _AsyncBridge,
    session: Any,
    server_name: str,
    tool: Any,
) -> Callable:
    """Create a sync Python function wrapping an MCP tool.

    The returned function has proper __name__, __doc__, __annotations__,
    and __defaults__ so ConnectOnion's tool_factory can introspect it.
    """
    tool_name: str = tool.name
    description: str = tool.description or f"Execute {tool_name} (from {server_name} MCP server)."
    input_schema: dict = tool.inputSchema if hasattr(tool, "inputSchema") else {}
    properties: dict = input_schema.get("properties", {})
    required_fields: list[str] = input_schema.get("required", [])

    # Build parameter annotations and defaults
    annotations: dict[str, type] = {"return": str}
    param_names: list[str] = []
    defaults: list[Any] = []

    # Sort: required params first, then optional (so defaults are trailing)
    sorted_props = sorted(
        properties.items(),
        key=lambda item: item[0] in required_fields,
        reverse=True,
    )

    for prop_name, prop_schema in sorted_props:
        py_type = _json_schema_to_python_type(prop_schema)
        annotations[prop_name] = py_type
        param_names.append(prop_name)
        if prop_name not in required_fields:
            defaults.append(prop_schema.get("default", ""))

    # The async closure that calls the MCP server
    async def _async_call(**kwargs: Any) -> str:
        try:
            result = await session.call_tool(tool_name, kwargs)
            parts: list[str] = []
            for item in result.content:
                if hasattr(item, "text"):
                    parts.append(item.text)
                else:
                    parts.append(str(item))
            return "\n".join(parts) if parts else json.dumps({"status": "ok"})
        except Exception as exc:
            logger.error(f"MCP tool call failed ({tool_name}@{server_name}): {exc}", exc_info=True)
            return json.dumps({"error": "MCP tool execution failed. Please retry.", "tool": tool_name})

    # The sync wrapper
    def _sync_wrapper(**kwargs: Any) -> str:
        return bridge.run_sync(_async_call(**kwargs))

    # Attach metadata for ConnectOnion's tool_factory
    func_name = tool_name.replace("-", "_").replace(".", "_")
    _sync_wrapper.__name__ = func_name
    _sync_wrapper.__qualname__ = func_name
    _sync_wrapper.__doc__ = description.split("\n\n")[0].strip()
    _sync_wrapper.__annotations__ = annotations
    _sync_wrapper.__defaults__ = tuple(defaults) if defaults else None

    # Build a proper inspect.Signature for advanced introspection
    params: list[inspect.Parameter] = []
    num_required = len(required_fields)
    for i, (prop_name, _) in enumerate(sorted_props):
        kind = inspect.Parameter.POSITIONAL_OR_KEYWORD
        if i < num_required:
            params.append(inspect.Parameter(prop_name, kind))
        else:
            default_idx = i - num_required
            default_val = defaults[default_idx] if default_idx < len(defaults) else ""
            params.append(inspect.Parameter(prop_name, kind, default=default_val))

    if params:
        _sync_wrapper.__signature__ = inspect.Signature(params)

    return _sync_wrapper


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

_bridge: _AsyncBridge | None = None
_context_managers: list[Any] = []
_sessions: list[Any] = []
_mcp_tools: list[Callable] = []
_server_status: dict[str, dict[str, Any]] = {}  # per-server connection status


def load_mcp_tools() -> list[Callable]:
    """Connect to configured MCP servers and return tool functions.

    Returns a list of sync Python functions, each wrapping an MCP tool.
    Unreachable servers are skipped with a warning printed to stderr.
    Safe to call multiple times — returns cached results on subsequent calls.
    """
    global _bridge, _context_managers, _sessions, _mcp_tools

    if _mcp_tools:
        return _mcp_tools  # Already loaded

    config = _load_mcp_config()
    if not config:
        return []

    _bridge = _AsyncBridge()
    _bridge.start()

    # Run the entire connection sequence as one coroutine on the background loop
    async def _connect_all() -> None:
        try:
            from mcp.client.session import ClientSession
            from mcp.client.stdio import StdioServerParameters, stdio_client
            from mcp.client.sse import sse_client
        except ImportError:
            import warnings
            warnings.warn(
                "MCP package not installed. Skipping MCP server integration. "
                "Install with: pip install 'mcp>=1.27,<2'",
                stacklevel=2,
            )
            return

        _MCP_SERVER_TIMEOUT = 10  # seconds per server
        _SSE_TIMEOUT = 5

        for server_name, server_config in config.items():
            # Skip non-dict entries (e.g. stray top-level keys like "timeout")
            if not isinstance(server_config, dict):
                _server_status[server_name] = {
                    "status": "skipped",
                    "reason": f"not a server definition (type={type(server_config).__name__})",
                    "tools": 0,
                }
                print(
                    f"  ⚠ MCP config key '{server_name}' is not a server "
                    f"definition (type={type(server_config).__name__}), skipping",
                    file=sys.stderr,
                )
                continue

            # Skip disabled servers
            if server_config.get("enabled") is False:
                _server_status[server_name] = {
                    "status": "disabled",
                    "reason": "disabled in config",
                    "tools": 0,
                }
                print(
                    f"  ⚠ MCP server '{server_name}': skipped (disabled in config)",
                    file=sys.stderr,
                )
                continue

            try:
                transport_type = server_config.get("type", "stdio")
                connect_timeout = server_config.get("timeout", _MCP_SERVER_TIMEOUT)

                if transport_type == "sse":
                    url = server_config.get("url", "")
                    headers = server_config.get("headers", {})
                    cm = sse_client(url=url, headers=headers or None, timeout=_SSE_TIMEOUT)
                else:
                    command = server_config.get("command", "")
                    args = server_config.get("args", [])
                    env = server_config.get("env", {})
                    # Merge config env with parent env (config takes precedence)
                    # StdioServerParameters needs a complete environment
                    merged_env = os.environ.copy()
                    merged_env.update(env)
                    params = StdioServerParameters(
                        command=command, args=args, env=merged_env
                    )
                    cm = stdio_client(params)

                # Enter context manager with timeout (keeps connection alive)
                streams = await asyncio.wait_for(cm.__aenter__(), timeout=connect_timeout)
                _context_managers.append(cm)
                read, write = streams

                # Create session and initialize. ClientSession must be entered
                # as a context manager so __aenter__ starts _receive_loop,
                # which routes responses to per-request streams. Without it,
                # initialize() hangs until the outer timeout. Session is kept
                # alive in _sessions and exited in shutdown_mcp().
                session = ClientSession(read, write)
                await session.__aenter__()
                _sessions.append(session)
                await asyncio.wait_for(session.initialize(), timeout=connect_timeout)

                # Discover tools
                tools_result = await asyncio.wait_for(
                    session.list_tools(), timeout=connect_timeout
                )

                for mcp_tool in tools_result.tools:
                    func = _make_tool_function(_bridge, session, server_name, mcp_tool)
                    _mcp_tools.append(func)

                tool_count = len(tools_result.tools)
                _server_status[server_name] = {
                    "status": "connected",
                    "reason": None,
                    "tools": tool_count,
                    "transport": transport_type,
                }
                print(
                    f"  ✓ MCP server '{server_name}': "
                    f"{tool_count} tools loaded",
                    file=sys.stderr,
                )

            except asyncio.TimeoutError:
                _server_status[server_name] = {
                    "status": "failed",
                    "reason": f"connection timed out after {connect_timeout}s",
                    "tools": 0,
                }
                print(
                    f"  ⚠ MCP server '{server_name}': "
                    f"skipped (connection timed out after {connect_timeout}s)",
                    file=sys.stderr,
                )
            except Exception as exc:
                _server_status[server_name] = {
                    "status": "failed",
                    "reason": f"{type(exc).__name__}: {exc}",
                    "tools": 0,
                }
                print(
                    f"  ⚠ MCP server '{server_name}': "
                    f"skipped ({type(exc).__name__}: {exc})",
                    file=sys.stderr,
                )

    try:
        _bridge.run_sync(_connect_all())
    except TimeoutError:
        print(
            "  ⚠ MCP connection timed out (60s overall limit). "
            f"Loaded {len(_mcp_tools)} tools before timeout.",
            file=sys.stderr,
        )
    except Exception as exc:
        print(
            f"  ⚠ MCP integration failed ({type(exc).__name__}: {exc}). "
            "Continuing without MCP tools.",
            file=sys.stderr,
        )

    if _mcp_tools:
        print(f"\n  Total MCP tools: {len(_mcp_tools)}", file=sys.stderr)

    return _mcp_tools


def get_mcp_status() -> dict[str, dict[str, Any]]:
    """Return per-server connection status for the /mcp slash command.

    Returns a dict keyed by server name, each value containing:
      - status: "connected" | "failed" | "disabled" | "skipped"
      - reason: error message or None
      - tools: number of tools loaded (0 if not connected)
      - transport: "stdio" | "sse" (only for connected servers)
    """
    return dict(_server_status)


def shutdown_mcp() -> None:
    """Shut down all MCP sessions, close transports, stop the event loop."""
    global _bridge, _context_managers, _sessions, _mcp_tools

    if _bridge and _sessions:
        # Exit sessions before closing their underlying stdio transports.
        async def _cleanup() -> None:
            for session in reversed(_sessions):
                try:
                    await session.__aexit__(None, None, None)
                except Exception:
                    pass
            for cm in reversed(_context_managers):
                try:
                    await cm.__aexit__(None, None, None)
                except Exception:
                    pass

        try:
            _bridge.run_sync(_cleanup())
        except Exception:
            pass

    if _bridge:
        _bridge.shutdown()
        _bridge = None

    _context_managers.clear()
    _sessions.clear()
    _mcp_tools.clear()
