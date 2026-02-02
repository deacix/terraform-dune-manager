#!/bin/bash
# =============================================================================
# Create Query Script
# =============================================================================
# Creates a new query on Dune Analytics via the API.
#
# Usage: ./create_query.sh
# Reads JSON input from stdin with: name, sql, is_private
# Outputs JSON with: query_id
#
# Environment: DUNE_API_KEY must be set

set -e

# Read input from stdin
INPUT=$(cat)

# Extract parameters
NAME=$(echo "$INPUT" | jq -r '.name')
SQL=$(echo "$INPUT" | jq -r '.sql')
IS_PRIVATE=$(echo "$INPUT" | jq -r '.is_private // "true"')
API_URL="${DUNE_API_URL:-https://api.dune.com/api/v1}"

# Validate
if [ -z "$DUNE_API_KEY" ]; then
    echo '{"error": "DUNE_API_KEY environment variable not set"}' >&2
    exit 1
fi

if [ -z "$NAME" ] || [ "$NAME" = "null" ]; then
    echo '{"error": "name is required"}' >&2
    exit 1
fi

if [ -z "$SQL" ] || [ "$SQL" = "null" ]; then
    echo '{"error": "sql is required"}' >&2
    exit 1
fi

# Create query via API
RESPONSE=$(curl -s -X POST \
    -H "X-Dune-API-Key: $DUNE_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
        --arg name "$NAME" \
        --arg sql "$SQL" \
        --argjson private "$IS_PRIVATE" \
        '{name: $name, query_sql: $sql, is_private: $private}')" \
    "$API_URL/query")

# Extract query_id
QUERY_ID=$(echo "$RESPONSE" | jq -r '.query_id // .base.query_id // empty')

if [ -z "$QUERY_ID" ]; then
    # Check for error
    ERROR=$(echo "$RESPONSE" | jq -r '.error // empty')
    if [ -n "$ERROR" ]; then
        echo "{\"error\": \"$ERROR\"}" >&2
        exit 1
    fi
    echo '{"error": "Failed to extract query_id from response"}' >&2
    exit 1
fi

# Output result
echo "{\"query_id\": \"$QUERY_ID\"}"
