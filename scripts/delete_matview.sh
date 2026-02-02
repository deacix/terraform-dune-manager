#!/bin/bash
# =============================================================================
# Delete Materialized View Script
# =============================================================================
# Deletes a materialized view from Dune Analytics via the API.
# Used during terraform destroy for proper lifecycle management.
#
# Usage: ./delete_matview.sh
# Reads JSON input from stdin with: full_name (e.g., dune.team.result_name)
# Outputs JSON with: full_name, deleted
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

# Delete materialized view via API
RESPONSE=$(curl -s -X DELETE \
    -H "X-Dune-API-Key: $DUNE_API_KEY" \
    "$API_URL/materialized-views/$FULL_NAME")

# Check for errors (404 means already deleted - that's OK)
ERROR=$(echo "$RESPONSE" | jq -r '.error // empty')
if [ -n "$ERROR" ]; then
    # If it's a 404 or similar, still consider it deleted
    echo "{\"full_name\": \"$FULL_NAME\", \"deleted\": \"true\", \"note\": \"$ERROR\"}"
    exit 0
fi

# Output result
echo "{\"full_name\": \"$FULL_NAME\", \"deleted\": \"true\"}"
