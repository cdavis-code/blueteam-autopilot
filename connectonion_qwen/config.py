"""Agent configuration -- loads from .env and provides typed access."""

import os
from pathlib import Path

from dotenv import load_dotenv

# Load .env from project root (connectonion_qwen/ is one level deep)
_PROJECT_ROOT = Path(__file__).parent.parent
load_dotenv(_PROJECT_ROOT / ".env")

# ---------------------------------------------------------------------------
# Qwen Cloud
# ---------------------------------------------------------------------------
DASHSCOPE_API_KEY: str = os.getenv("DASHSCOPE_API_KEY", "")
QWEN_MODEL: str = os.getenv("QWEN_MODEL", "qwen3.7-plus")
QWEN_BASE_URL: str = os.getenv("QWEN_BASE_URL", "https://dashscope-intl.aliyuncs.com/compatible-mode/v1")

# ---------------------------------------------------------------------------
# Alibaba Cloud (passed through to bash scripts via environment)
# ---------------------------------------------------------------------------
ALIBABA_REGION: str = os.getenv("ALIBABA_REGION", "")

# ---------------------------------------------------------------------------
# Multi-cloud provider selection (comma-separated: aliyun, aws)
# ---------------------------------------------------------------------------
INFRA: list[str] = [p.strip() for p in os.getenv("INFRA", "aliyun").split(",") if p.strip()]

# ---------------------------------------------------------------------------
# Agent behavior
# ---------------------------------------------------------------------------
SECURITY_CENTER_MODE: str = os.getenv("SECURITY_CENTER_MODE", "demo")
ENABLE_THINKING: bool = os.getenv("ENABLE_THINKING", "true").lower() == "true"

try:
    MAX_TOOL_ROUNDS: int = int(os.getenv("MAX_TOOL_ROUNDS", "20"))
except ValueError:
    MAX_TOOL_ROUNDS = 20

# ---------------------------------------------------------------------------
# MCP
# ---------------------------------------------------------------------------
MCP_CONFIG_PATH: str = os.getenv("MCP_CONFIG_PATH", ".mcp.json")

# ---------------------------------------------------------------------------
# Turso / Memory
# ---------------------------------------------------------------------------
TURSO_DATABASE_URL: str = os.getenv("TURSO_DATABASE_URL", "")
DATA_DIR: Path = _PROJECT_ROOT / "data"

# ---------------------------------------------------------------------------
# Paths (relative to project root)
# ---------------------------------------------------------------------------
SCRIPTS_DIR: Path = _PROJECT_ROOT / "skills" / "blueteam-autopilot-ops" / "scripts"
FIXTURES_DIR: Path = _PROJECT_ROOT / "skills" / "blueteam-autopilot-core" / "fixtures"
KNOWLEDGE_DIR: Path = _PROJECT_ROOT / "skills" / "blueteam-autopilot-knowledge"
WORKFLOWS_DIR: Path = _PROJECT_ROOT / "workflows"


def validate() -> list[str]:
    """Return a list of configuration warnings (empty = all good)."""
    warnings: list[str] = []
    if not DASHSCOPE_API_KEY:
        warnings.append(
            "DASHSCOPE_API_KEY is not set. "
            "The agent cannot call Qwen Cloud without it. "
            "Add DASHSCOPE_API_KEY to your .env file."
        )
    return warnings
