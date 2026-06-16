#!/usr/bin/env bash
# =============================================================================
# GRC Provider Template
# =============================================================================
# All GRC provider scripts must implement the three functions below.
# Source this file from your provider script and override each function.
#
# Contract:
#   grc_connect()           — Authenticate and validate connectivity. Returns 0 on success, 1 on failure.
#   grc_list_frameworks()   — List available compliance frameworks. Outputs JSON array of {id, name, type, description} to stdout.
#   grc_get_framework(id)   — Export a framework's controls as Markdown (with YAML frontmatter) to stdout.
#
# Environment Variables:
#   GRC_MODE          — "demo" uses fixture data, unset or "real" uses live API
#   GRC_BASE_URL      — Base URL of the GRC platform
#   GRC_EMAIL         — Authentication email (if applicable)
#   GRC_API_TOKEN     — API token (if pre-configured)
#   GRC_VERIFY_SSL    — Whether to verify SSL certificates (default: true)
#
# policies.json reference:
#   The sync orchestration script reads grc_providers.<provider_name> from
#   policies.json. Provider scripts should read their own config from there
#   or from environment variables.
# =============================================================================

set -euo pipefail

# --- Provider metadata (override these) ---
GRC_PROVIDER_NAME="template"
GRC_PROVIDER_DISPLAY_NAME="Template Provider"
GRC_PROVIDER_DESCRIPTION="Replace with your GRC platform description"

# --- Demo fixture data (override these in your provider) ---
DEMO_FRAMEWORKS='[]'
DEMO_FRAMEWORK_CONTENT=""

# =============================================================================
# grc_connect — Authenticate with the GRC platform
# =============================================================================
grc_connect() {
  if [ "${GRC_MODE:-}" = "demo" ]; then
    echo "[demo] Simulating connection to ${GRC_PROVIDER_DISPLAY_NAME}..." >&2
    return 0
  fi

  # Provider must override: authenticate and return 0 on success, 1 on failure
  echo "ERROR: grc_connect() not implemented by provider '${GRC_PROVIDER_NAME}'" >&2
  return 1
}

# =============================================================================
# grc_list_frameworks — List available compliance frameworks
# =============================================================================
grc_list_frameworks() {
  if [ "${GRC_MODE:-}" = "demo" ]; then
    echo "${DEMO_FRAMEWORKS}"
    return 0
  fi

  # Provider must override: output JSON array to stdout
  echo '[]'
  return 0
}

# =============================================================================
# grc_get_framework — Export a framework's controls as Markdown
# =============================================================================
# Arguments:
#   $1 — library_id (the unique ID of the framework in the GRC platform)
# =============================================================================
grc_get_framework() {
  local library_id="${1:-}"

  if [ -z "$library_id" ]; then
    echo "ERROR: grc_get_framework requires a library_id argument" >&2
    return 1
  fi

  if [ "${GRC_MODE:-}" = "demo" ]; then
    echo "${DEMO_FRAMEWORK_CONTENT}"
    return 0
  fi

  # Provider must override: output Markdown to stdout
  echo ""
  return 0
}

# =============================================================================
# Provider self-description (used by grc-sync.sh for status display)
# =============================================================================
grc_describe() {
  echo "${GRC_PROVIDER_DISPLAY_NAME}"
  echo "  ${GRC_PROVIDER_DESCRIPTION}"
  echo "  Provider: ${GRC_PROVIDER_NAME}"
}
