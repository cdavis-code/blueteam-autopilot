"""AWS-specific configuration."""

from pathlib import Path

from connectonion_qwen.config import (
    SCRIPTS_DIR,
    FIXTURES_DIR,
    SECURITY_CENTER_MODE,
    _PROJECT_ROOT,
)

# AWS-specific paths (reuse same scripts/fixtures dirs)
AWS_SCRIPTS_DIR = SCRIPTS_DIR
AWS_FIXTURES_DIR = FIXTURES_DIR
