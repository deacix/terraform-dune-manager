#!/bin/bash
# =============================================================================
# Refresh Materialized View Script
# =============================================================================
# Triggers a refresh of a materialized view on Dune Analytics.
#
# Usage: ./refresh_matview.sh
# Reads JSON input from stdin with: full_name
# Outputs JSON with: full_name, triggered
#
# Environment: DUNE_API_KEY must be set

set -e

# Read input from stdin
INPUT=$(cat)

# Extract parameters
FULL_NAME=$(echo "$INPUT" | jq -r '.full_name')
API_URL="${DUNE_API_URL:-https://api.dune.com/api/v1}"

# Validate
if [ -z "$DUNE_API_KEY" ]; then
    echo '{"error": "DUNE_API_KEY environment variable not set"}' >&2
    exit 1
fi

if [ -z "$FULL_NAME" ] || [ "$FULL_NAME" = "null" ]; then
    echo '{"error": "full_name is required"}' >&2
    exit 1
fi

# Trigger refresh via API
RESPONSE=$(curl -s -X POST \
    -H "X-Dune-API-Key: $DUNE_API_KEY" \
    "$API_URL/materialized-views/$FULL_NAME/refresh")

# Check for errors
ERROR=$(echo "$RESPONSE" | jq -r '.error // empty')
if [ -n "$ERROR" ]; then
    echo "{\"error\": \"$ERROR\"}" >&2
    exit 1
fi

# Output result
echo "{\"full_name\": \"$FULL_NAME\", \"triggered\": \"true\"}"
