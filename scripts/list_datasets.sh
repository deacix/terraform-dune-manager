#!/bin/bash
# =============================================================================
# List Datasets Script
# =============================================================================
# Lists available datasets from Dune Analytics via the API.
# Used for data discovery and schema exploration.
#
# Usage: ./list_datasets.sh
# Reads JSON input from stdin with: owner (optional), limit (optional), offset (optional)
# Outputs JSON with: count, datasets (as JSON string), next_offset
#
# Environment: DUNE_API_KEY must be set

set -e

# Read input from stdin
INPUT=$(cat)

# Extract parameters
OWNER=$(echo "$INPUT" | jq -r '.owner // empty')
LIMIT=$(echo "$INPUT" | jq -r '.limit // "100"')
OFFSET=$(echo "$INPUT" | jq -r '.offset // ""')
API_URL="${DUNE_API_URL:-https://api.dune.com/api/v1}"

# Validate
if [ -z "$DUNE_API_KEY" ]; then
    echo '{"error": "DUNE_API_KEY environment variable not set"}' >&2
    exit 1
fi

# Build query string
QUERY_STRING="limit=$LIMIT"
if [ -n "$OWNER" ] && [ "$OWNER" != "null" ]; then
    QUERY_STRING="$QUERY_STRING&owner=$OWNER"
fi
if [ -n "$OFFSET" ] && [ "$OFFSET" != "null" ]; then
    QUERY_STRING="$QUERY_STRING&offset=$OFFSET"
fi

# List datasets via API
RESPONSE=$(curl -s -X GET \
    -H "X-Dune-API-Key: $DUNE_API_KEY" \
    "$API_URL/datasets?$QUERY_STRING")

# Check for errors
ERROR=$(echo "$RESPONSE" | jq -r '.error // empty')
if [ -n "$ERROR" ]; then
    echo "{\"error\": \"$ERROR\"}" >&2
    exit 1
fi

# Extract fields - note: external data source requires all values to be strings
DATASETS=$(echo "$RESPONSE" | jq -c '.datasets // []')
NEXT_OFFSET=$(echo "$RESPONSE" | jq -r '.next_offset // ""')
COUNT=$(echo "$RESPONSE" | jq -r '.datasets | length // "0"')

# Output result (datasets as JSON string for external data source compatibility)
jq -n \
    --arg count "$COUNT" \
    --arg next_offset "$NEXT_OFFSET" \
    --arg datasets "$DATASETS" \
    '{count: $count, next_offset: $next_offset, datasets: $datasets}'
