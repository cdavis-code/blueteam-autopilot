#!/usr/bin/env bash
# Shared helper: Rewrite fixture timestamps relative to "now"
# Usage: source this file, then pipe JSON through `rewrite_timestamps`
#
# This function finds the newest timestamp in the JSON, calculates the offset
# to the current time, and shifts ALL timestamps by that offset. This preserves
# the relative spacing between events while making them appear fresh.
#
# Timestamp fields handled: createdAt, timestamp, detectedAt, updatedAt

rewrite_timestamps() {
  python3 -c '
import json, sys
from datetime import datetime, timezone

TIMESTAMP_FIELDS = {"createdAt", "timestamp", "detectedAt", "updatedAt"}

def parse_iso(s):
    """Parse ISO 8601 timestamp string to datetime."""
    try:
        # Handle both "Z" suffix and "+00:00" formats
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        return None

def find_newest(obj):
    """Recursively find the newest timestamp in the JSON structure."""
    newest = None
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k in TIMESTAMP_FIELDS and isinstance(v, str):
                ts = parse_iso(v)
                if ts and (newest is None or ts > newest):
                    newest = ts
            else:
                candidate = find_newest(v)
                if candidate and (newest is None or candidate > newest):
                    newest = candidate
    elif isinstance(obj, list):
        for item in obj:
            candidate = find_newest(item)
            if candidate and (newest is None or candidate > newest):
                newest = candidate
    return newest

def shift_timestamp(v, offset):
    """Shift a single timestamp by the given offset."""
    ts = parse_iso(v)
    if ts:
        shifted = ts + offset
        return shifted.strftime("%Y-%m-%dT%H:%M:%SZ")
    return v

def shift_obj(obj, offset):
    """Recursively shift all timestamp fields in the JSON structure."""
    if isinstance(obj, dict):
        return {
            k: (shift_timestamp(v, offset) if k in TIMESTAMP_FIELDS and isinstance(v, str) else shift_obj(v, offset))
            for k, v in obj.items()
        }
    elif isinstance(obj, list):
        return [shift_obj(item, offset) for item in obj]
    return obj

# Main
try:
    data = json.load(sys.stdin)
except json.JSONDecodeError:
    # Pass through invalid JSON unchanged
    sys.stdin.seek(0)
    print(sys.stdin.read(), end="")
    sys.exit(0)

now = datetime.now(timezone.utc)
newest = find_newest(data)

if newest is None:
    # No timestamps found, pass through unchanged
    print(json.dumps(data, indent=2))
    sys.exit(0)

offset = now - newest
result = shift_obj(data, offset)
print(json.dumps(result, indent=2))
'
}
