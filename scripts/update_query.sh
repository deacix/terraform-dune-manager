#!/bin/bash
# =============================================================================
# Update Query Script
# =============================================================================
# Updates an existing query on Dune Analytics via the API.
#
# Usage: ./update_query.sh
# Reads JSON input from stdin with: query_id, name, sql
# Outputs JSON with: query_id, updated
#
# Environment: DUNE_API_KEY must be set

set -e

# Read input from stdin
INPUT=$(cat)

# Extract parameters
QUERY_ID=$(echo "$INPUT" | jq -r '.query_id')
NAME=$(echo "$INPUT" | jq -r '.name // empty')
SQL=$(echo "$INPUT" | jq -r '.sql')
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

if [ -z "$SQL" ] || [ "$SQL" = "null" ]; then
    echo '{"error": "sql is required"}' >&2
    exit 1
fi

# Build request body
if [ -n "$NAME" ] && [ "$NAME" != "null" ]; then
    BODY=$(jq -n --arg name "$NAME" --arg sql "$SQL" '{name: $name, query_sql: $sql}')
else
    BODY=$(jq -n --arg sql "$SQL" '{query_sql: $sql}')
fi

# Update query via API
RESPONSE=$(curl -s -X PATCH \
    -H "X-Dune-API-Key: $DUNE_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$BODY" \
    "$API_URL/query/$QUERY_ID")

# Check for errors
ERROR=$(echo "$RESPONSE" | jq -r '.error // empty')
if [ -n "$ERROR" ]; then
    echo "{\"error\": \"$ERROR\"}" >&2
    exit 1
fi

# Output result
echo "{\"query_id\": \"$QUERY_ID\", \"updated\": \"true\"}"
