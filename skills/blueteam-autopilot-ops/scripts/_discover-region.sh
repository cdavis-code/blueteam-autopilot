#!/usr/bin/env bash
# Region auto-discovery: env var → aliyun CLI config → config.json → error
# Source this file in scripts that need $ALIBABA_REGION
#
# Discovery chain:
#   1. ALIBABA_REGION environment variable (explicit override)
#   2. aliyun configure get (CLI profile default)
#   3. ~/.aliyun/config.json (direct parse)
#   4. Error with guidance

if [ -z "${ALIBABA_REGION:-}" ]; then
  ALIBABA_REGION=$(aliyun configure get 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('region_id',''))" 2>/dev/null || true)
fi

if [ -z "${ALIBABA_REGION:-}" ] && [ -f "$HOME/.aliyun/config.json" ]; then
  ALIBABA_REGION=$(python3 -c "
import json
try:
    cfg = json.load(open('$HOME/.aliyun/config.json'))
    current = cfg.get('current', 'default')
    for p in cfg.get('profiles', []):
        if p.get('name') == current:
            print(p.get('region_id', ''))
            break
except:
    pass
" 2>/dev/null || true)
fi

if [ -z "${ALIBABA_REGION:-}" ]; then
  echo "Error: Could not determine region automatically"
  echo "Options:"
  echo "  1. Run 'aliyun configure' to set a default region"
  echo "  2. Create a .env file with ALIBABA_REGION=ap-southeast-1"
  echo "  3. Export: export ALIBABA_REGION=ap-southeast-1"
  exit 1
fi

export ALIBABA_REGION
