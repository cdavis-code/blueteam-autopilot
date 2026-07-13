#!/usr/bin/env python3
"""Shared helper functions for BlueTeam scripts.

Replaces _discover-region.sh and _rewrite-timestamps.sh with Python equivalents.
"""

from __future__ import annotations

import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path


TIMESTAMP_FIELDS = {"createdAt", "timestamp", "detectedAt", "updatedAt"}


def discover_region() -> str:
    """Auto-discover Alibaba Cloud region.

    Discovery chain:
      1. ALIBABA_REGION environment variable (explicit override)
      2. aliyun configure get (CLI profile default)
      3. ~/.aliyun/config.json (direct parse)
      4. Raise error with guidance

    Returns:
        Region string (e.g., 'ap-southeast-1')

    Raises:
        RuntimeError: If region cannot be determined
    """
    # 1. Check environment variable
    region = os.environ.get("ALIBABA_REGION", "").strip()
    if region:
        return region

    # 2. Try aliyun CLI
    try:
        result = subprocess.run(
            ["aliyun", "configure", "get"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode == 0:
            config = json.loads(result.stdout)
            region = config.get("region_id", "").strip()
            if region:
                return region
    except (subprocess.TimeoutExpired, FileNotFoundError, json.JSONDecodeError):
        pass

    # 3. Parse config.json directly
    config_path = Path.home() / ".aliyun" / "config.json"
    if config_path.exists():
        try:
            with open(config_path) as f:
                config = json.load(f)
            current = config.get("current", "default")
            for profile in config.get("profiles", []):
                if profile.get("name") == current:
                    region = profile.get("region_id", "").strip()
                    if region:
                        return region
        except (json.JSONDecodeError, OSError):
            pass

    # 4. Error with guidance
    raise RuntimeError(
        "Could not determine Alibaba Cloud region automatically.\n"
        "Options:\n"
        "  1. Run 'aliyun configure' to set a default region (recommended)\n"
        "  2. Export an override for this session: export ALIBABA_REGION=ap-southeast-1"
    )


def parse_iso_timestamp(s: str) -> datetime | None:
    """Parse ISO 8601 timestamp string to datetime."""
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        return None


def find_newest_timestamp(obj: dict | list) -> datetime | None:
    """Recursively find the newest timestamp in a JSON structure."""
    newest = None

    if isinstance(obj, dict):
        for key, value in obj.items():
            if key in TIMESTAMP_FIELDS and isinstance(value, str):
                ts = parse_iso_timestamp(value)
                if ts and (newest is None or ts > newest):
                    newest = ts
            else:
                candidate = find_newest_timestamp(value)
                if candidate and (newest is None or candidate > newest):
                    newest = candidate
    elif isinstance(obj, list):
        for item in obj:
            candidate = find_newest_timestamp(item)
            if candidate and (newest is None or candidate > newest):
                newest = candidate

    return newest


def shift_timestamp(value: str, offset_seconds: float) -> str:
    """Shift a single timestamp by the given offset."""
    ts = parse_iso_timestamp(value)
    if ts:
        from datetime import timedelta
        shifted = ts + timedelta(seconds=offset_seconds)
        return shifted.strftime("%Y-%m-%dT%H:%M:%SZ")
    return value


def shift_timestamps_in_obj(obj: dict | list, offset_seconds: float) -> dict | list:
    """Recursively shift all timestamp fields in a JSON structure."""
    if isinstance(obj, dict):
        return {
            key: (
                shift_timestamp(value, offset_seconds)
                if key in TIMESTAMP_FIELDS and isinstance(value, str)
                else shift_timestamps_in_obj(value, offset_seconds)
            )
            for key, value in obj.items()
        }
    elif isinstance(obj, list):
        return [shift_timestamps_in_obj(item, offset_seconds) for item in obj]
    return obj


def rewrite_timestamps(data: dict | list) -> dict | list:
    """Shift fixture timestamps relative to 'now' for fresh appearance.

    Finds the newest timestamp in the data, calculates the offset to current time,
    and shifts ALL timestamps by that offset. This preserves relative spacing
    between events while making them appear recent.

    Args:
        data: JSON structure (dict or list) containing timestamps

    Returns:
        Same structure with timestamps shifted to appear recent
    """
    now = datetime.now(timezone.utc)
    newest = find_newest_timestamp(data)

    if newest is None:
        # No timestamps found, return unchanged
        return data

    # Calculate offset in seconds
    offset_seconds = (now - newest).total_seconds()

    return shift_timestamps_in_obj(data, offset_seconds)


def load_fixture(fixture_name: str, fixtures_dir: Path | None = None) -> str:
    """Load a fixture JSON file and return its contents as a string.

    Args:
        fixture_name: Name of the fixture file (e.g., 'ping.json')
        fixtures_dir: Directory containing fixtures (defaults to BLUETEAM_FIXTURES_DIR env var)

    Returns:
        JSON string with timestamps rewritten, or error JSON if not found
    """
    if fixtures_dir is None:
        fixtures_dir = Path(os.environ.get("BLUETEAM_FIXTURES_DIR", ""))

    fixture_path = fixtures_dir / fixture_name

    if not fixture_path.exists():
        return json.dumps({
            "error": f"Fixture not found: {fixture_path}. "
                     f"Run 'aliyun sas describe-version-config > {fixture_path}' to capture."
        })

    with open(fixture_path) as f:
        data = json.load(f)

    # Rewrite timestamps to appear fresh
    data = rewrite_timestamps(data)

    return json.dumps(data, indent=2)


if __name__ == "__main__":
    # Test discover_region
    try:
        region = discover_region()
        print(f"Region: {region}")
    except RuntimeError as e:
        print(f"Error: {e}")
