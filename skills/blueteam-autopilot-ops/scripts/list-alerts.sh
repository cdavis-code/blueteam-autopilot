#!/usr/bin/env bash
# List alerts for a security event, grouped by source
# Usage: ./list-alerts.sh <event_id>

set -euo pipefail

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$PWD/.env" ]; then
  source "$PWD/.env" 2>/dev/null || true
elif [ -f "$(dirname "$SCRIPT_DIR")/../../../.env" ]; then
  source "$(dirname "$SCRIPT_DIR")/../../../.env" 2>/dev/null || true
fi

# ----- Demo mode: return fixture data -----
if [ "${SECURITY_CENTER_MODE:-real}" = "demo" ]; then
  FIXTURE_DIR="$(dirname "$SCRIPT_DIR")/../blueteam-autopilot-core/fixtures"
  FIXTURE_FILE="$FIXTURE_DIR/alerts.json"
  if [ -f "$FIXTURE_FILE" ]; then
    cat "$FIXTURE_FILE"
    exit 0
  else
    echo "{\"error\": \"Fixture not found: $FIXTURE_FILE. Run 'aliyun sas describe-susp-event-detail > $FIXTURE_FILE' to capture.\"}"
    exit 1
  fi
fi
# ----- End demo mode -----

if [ -z "${ALIBABA_REGION:-}" ]; then
  echo "Error: ALIBABA_REGION not set"
  echo "Create a .env file or export ALIBABA_REGION=ap-southeast-1"
  exit 1
fi

EVENT_ID="${1:-}"
if [ -z "$EVENT_ID" ]; then
  echo "Usage: $0 <event_id>"
  echo "Example: $0 evt-xxx-yyy-zzz"
  exit 1
fi

echo "Fetching alerts for event..."
echo "Region: $ALIBABA_REGION"
echo "Event ID: $EVENT_ID"
echo "---"


# Call Security Center API to get event detail with alerts
aliyun sas describe-susp-event-detail \
  --region "$ALIBABA_REGION" \
  --suspicious-event-id "$EVENT_ID" \
  2>&1 | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    alert_list = data.get('Data', {}).get('AlertList', [])
    
    if not alert_list:
        print('No alerts found for this event')
        sys.exit(0)
    
    # Group by data source
    by_source = {}
    for alert in alert_list:
        source = alert.get('DataSource', 'Unknown')
        if source not in by_source:
            by_source[source] = []
        by_source[source].append(alert)
    
    print(f'Found {len(alert_list)} alert(s) grouped by source:')
    print()
    
    for source, alerts in sorted(by_source.items()):
        print(f'[{source}] ({len(alerts)} alert(s))')
        for alert in alerts:
            alert_id = alert.get('AlertId', 'N/A')
            severity = alert.get('Severity', 'N/A')
            message = alert.get('AlertName', 'N/A')
            print(f'  - {alert_id}: {message} (severity: {severity})')
        print()
    
except Exception as e:
    print(f'Parse error: {e}', file=sys.stderr)
    sys.exit(1)
"

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -ne 0 ]; then
  echo ""
  echo "Error: Failed to fetch alerts (exit code: $EXIT_CODE)"
  echo ""
  echo "Possible causes:"
  echo "1. Event ID does not exist"
  echo "2. Missing RAM permissions: AliyunYundunSASReadOnlyAccess"
  echo "3. Security Center edition does not support this API"
  exit $EXIT_CODE
fi
