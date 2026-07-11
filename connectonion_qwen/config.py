"""Agent configuration -- loads from .env and provides typed access."""

import json
import logging
import os
import subprocess
from pathlib import Path

from dotenv import load_dotenv

logger = logging.getLogger(__name__)

# Load .env with priority order:
# 1. Current working directory (where blueteam is executed from)
# 2. ~/.blueteam/.env (Homebrew/pip install location)
# 3. Project root (development/git clone location)
_cwd_env = Path.cwd() / ".env"
_home_env = Path.home() / ".blueteam" / ".env"
_PROJECT_ROOT = Path(os.environ.get("BLUETEAM_PROJECT_ROOT", Path(__file__).parent.parent))
_project_env = _PROJECT_ROOT / ".env"

if _cwd_env.exists():
    load_dotenv(_cwd_env)
    logger.info(f"Loaded .env from current directory: {_cwd_env}")
elif _home_env.exists():
    load_dotenv(_home_env)
    logger.info(f"Loaded .env from home directory: {_home_env}")
else:
    load_dotenv(_project_env)
    logger.info(f"Loaded .env from project root: {_project_env}")


# ---------------------------------------------------------------------------
# Auto-discover Alibaba Cloud vars from CLI config when not in .env
# ---------------------------------------------------------------------------

def _discover_aliyun_env() -> None:
    """Populate os.environ with Alibaba Cloud vars from aliyun configure.

    Users who run `aliyun configure` instead of putting credentials in .env
    need these vars forwarded to subprocesses so `run_command` can reference
    $ALIBABA_REGION, $ALIBABA_ACCESS_KEY_ID, etc. in bash commands.
    """
    if os.getenv("ALIBABA_REGION") and os.getenv("ALIBABA_ACCESS_KEY_ID"):
        return  # Already set — nothing to discover

    # Discover region from aliyun configure
    if not os.getenv("ALIBABA_REGION"):
        try:
            result = subprocess.run(
                ["aliyun", "configure", "get", "region"],
                capture_output=True, text=True, timeout=5,
            )
            if result.returncode == 0 and result.stdout.strip():
                region = result.stdout.strip()
                os.environ["ALIBABA_REGION"] = region
                logger.info(f"Discovered ALIBABA_REGION={region} from aliyun configure")
        except Exception:
            pass  # aliyun CLI may not be installed

    # Discover credentials from ~/.aliyun/config.json
    if not os.getenv("ALIBABA_ACCESS_KEY_ID"):
        config_path = Path.home() / ".aliyun" / "config.json"
        if config_path.exists():
            try:
                with open(config_path) as f:
                    config = json.load(f)
                current = config.get("current", "")
                for profile in config.get("profiles", []):
                    if profile.get("name") == current:
                        key_id = profile.get("access_key_id", "")
                        key_secret = profile.get("access_key_secret", "")
                        if key_id:
                            os.environ["ALIBABA_ACCESS_KEY_ID"] = key_id
                            logger.info(f"Discovered ALIBABA_ACCESS_KEY_ID={key_id[:4]}****{key_id[-4:]}")
                        if key_secret:
                            os.environ["ALIBABA_ACCESS_KEY_SECRET"] = key_secret
                            logger.info("Discovered ALIBABA_ACCESS_KEY_SECRET (masked)")
                        if key_id or key_secret:
                            break
            except Exception:
                pass  # Config file may be malformed


_discover_aliyun_env()

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
# Agent behavior
# ---------------------------------------------------------------------------
SECURITY_CENTER_MODE: str = os.getenv("SECURITY_CENTER_MODE", "demo")
ENABLE_THINKING: bool = os.getenv("ENABLE_THINKING", "true").lower() == "true"

try:
    MAX_TOOL_ROUNDS: int = int(os.getenv("MAX_TOOL_ROUNDS", "50"))
except ValueError:
    MAX_TOOL_ROUNDS = 50

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
# Paths (skills-first discovery for pip install, git clone, npx skills, auto-sync)
# ---------------------------------------------------------------------------


def _resolve_dir(subdir: str, fallback_skill: str = "") -> Path:
    """Find a resource directory across install methods.

    Search order:
    1. BLUETEAM_PROJECT_ROOT env var (explicit override)
    2. skills/<skill>/<subdir> relative to project root (local or synced)
    3. ~/.blueteam/skills/<skill>/<subdir> (auto-synced location)
    4. blueteam_data/<subdir> relative to this file (pip install fallback)
    """
    # 1. Env var override
    env_root = os.environ.get("BLUETEAM_PROJECT_ROOT")
    if env_root:
        candidate = Path(env_root) / "skills" / fallback_skill / subdir
        if candidate.is_dir():
            return candidate

    # 2. Local skills directory (git clone or npx skills add)
    candidate = _PROJECT_ROOT / "skills" / fallback_skill / subdir
    if candidate.is_dir():
        return candidate

    # 3. Auto-synced location (~/.blueteam/)
    synced = Path.home() / ".blueteam" / "skills" / fallback_skill / subdir
    if synced.is_dir():
        return synced

    # 4. Package-relative blueteam_data (pip install fallback with symlinks)
    candidate = _PROJECT_ROOT / "blueteam_data" / subdir
    if candidate.is_dir():
        return candidate

    # Return the local path even if missing — tools will report errors
    return _PROJECT_ROOT / "skills" / fallback_skill / subdir


SCRIPTS_DIR: Path = _resolve_dir("scripts", "blueteam-autopilot-ops")
FIXTURES_DIR: Path = _resolve_dir("fixtures", "blueteam-autopilot-core")
KNOWLEDGE_DIR: Path = _resolve_dir("knowledge", "blueteam-autopilot-knowledge")
PREP_SCRIPTS_DIR: Path = _resolve_dir("scripts", "blueteam-autopilot-prep")
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
