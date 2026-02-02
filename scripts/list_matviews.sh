#!/bin/bash
# =============================================================================
# List Materialized Views Script
# =============================================================================
# Lists all materialized views owned by the account on Dune Analytics.
# Used for state reconciliation and discovery.
#
# Usage: ./list_matviews.sh
# Reads JSON input from stdin with: limit (optional), offset (optional)
# Outputs JSON with: count, materialized_views (as JSON string)
#
# Environment: DUNE_API_KEY must be set

set -e

# Read input from stdin
INPUT=$(cat)

# Extract parameters
LIMIT=$(echo "$INPUT" | jq -r '.limit // "100"')
OFFSET=$(echo "$INPUT" | jq -r '.offset // "0"')
API_URL="${DUNE_API_URL:-https://api.dune.com/api/v1}"

# Validate
if [ -z "$DUNE_API_KEY" ]; then
    echo '{"error": "DUNE_API_KEY environment variable not set"}' >&2
    exit 1
fi

# Build query string
QUERY_STRING="limit=$LIMIT"
if [ "$OFFSET" != "0" ] && [ "$OFFSET" != "null" ]; then
    QUERY_STRING="$QUERY_STRING&offset=$OFFSET"
fi

# List materialized views via API
RESPONSE=$(curl -s -X GET \
    -H "X-Dune-API-Key: $DUNE_API_KEY" \
    "$API_URL/materialized-views?$QUERY_STRING")

# Check for errors
ERROR=$(echo "$RESPONSE" | jq -r '.error // empty')
if [ -n "$ERROR" ]; then
    echo "{\"error\": \"$ERROR\"}" >&2
    exit 1
fi

# Extract fields - note: external data source requires all values to be strings
MATVIEWS=$(echo "$RESPONSE" | jq -c '.materialized_views // []')
NEXT_OFFSET=$(echo "$RESPONSE" | jq -r '.next_offset // ""')
COUNT=$(echo "$RESPONSE" | jq -r '.materialized_views | length // "0"')

# Output result (materialized_views as JSON string for external data source compatibility)
jq -n \
    --arg count "$COUNT" \
    --arg next_offset "$NEXT_OFFSET" \
    --arg materialized_views "$MATVIEWS" \
    '{count: $count, next_offset: $next_offset, materialized_views: $materialized_views}'
