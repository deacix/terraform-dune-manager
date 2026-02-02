#!/bin/bash
# =============================================================================
# Unprivate Query Script
# =============================================================================
# Makes a query public on Dune Analytics via the API.
# Public queries can be found and queried by anyone.
#
# Usage: ./unprivate_query.sh
# Reads JSON input from stdin with: query_id
# Outputs JSON with: query_id, is_private
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

# Make query public via API
RESPONSE=$(curl -s -X POST \
    -H "X-Dune-API-Key: $DUNE_API_KEY" \
    "$API_URL/query/$QUERY_ID/unprivate")

# Check for errors
ERROR=$(echo "$RESPONSE" | jq -r '.error // empty')
if [ -n "$ERROR" ]; then
    echo "{\"error\": \"$ERROR\"}" >&2
    exit 1
fi

# Output result
echo "{\"query_id\": \"$QUERY_ID\", \"is_private\": \"false\"}"
