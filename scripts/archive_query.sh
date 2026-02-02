#!/bin/bash
# =============================================================================
# Archive Query Script
# =============================================================================
# Archives (soft deletes) a query on Dune Analytics via the API.
#
# Usage: ./archive_query.sh
# Reads JSON input from stdin with: query_id
# Outputs JSON with: query_id, archived
#
# Environment: DUNE_API_KEY must be set

set -e

# Read input from stdin
INPUT=$(cat)

# Extract parameters
QUERY_ID=$(echo "$INPUT" | jq -r '.query_id')
API_URL="${DUNE_API_URL:-https://api.dune.com/api/v1}"

# Validate
if [ -z "$DUNE_API_KEY" ]; then
    echo '{"error": "DUNE_API_KEY environment variable not set"}' >&2
    exit 1
fi

if [ -z "$QUERY_ID" ] || [ "$QUERY_ID" = "null" ]; then
    echo '{"error": "query_id is required"}' >&2
    exit 1
fi

# Archive query via API
RESPONSE=$(curl -s -X POST \
    -H "X-Dune-API-Key: $DUNE_API_KEY" \
    "$API_URL/query/$QUERY_ID/archive")

# Check for errors (404 means already archived/deleted)
ERROR=$(echo "$RESPONSE" | jq -r '.error // empty')
if [ -n "$ERROR" ]; then
    # If 404, query doesn't exist - that's OK for destroy
    echo "{\"query_id\": \"$QUERY_ID\", \"archived\": \"true\", \"note\": \"$ERROR\"}"
    exit 0
fi

# Output result
echo "{\"query_id\": \"$QUERY_ID\", \"archived\": \"true\"}"
