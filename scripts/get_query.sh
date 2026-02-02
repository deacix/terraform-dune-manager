#!/bin/bash
# =============================================================================
# Get Query Script
# =============================================================================
# Retrieves query details from Dune Analytics via the API.
#
# Usage: ./get_query.sh
# Reads JSON input from stdin with: query_id
# Outputs JSON with: query_id, name, sql, is_archived
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

# Get query via API
RESPONSE=$(curl -s -X GET \
    -H "X-Dune-API-Key: $DUNE_API_KEY" \
    "$API_URL/query/$QUERY_ID")

# Check for 404 or error
STATUS=$(echo "$RESPONSE" | jq -r '.error // empty')
if [ -n "$STATUS" ]; then
    echo "{\"error\": \"$STATUS\", \"exists\": \"false\"}" 
    exit 0
fi

# Extract fields
NAME=$(echo "$RESPONSE" | jq -r '.name // .base.name // empty')
SQL=$(echo "$RESPONSE" | jq -r '.sql // empty')
IS_ARCHIVED=$(echo "$RESPONSE" | jq -r '.is_archived // "false"')

# Output result
jq -n \
    --arg query_id "$QUERY_ID" \
    --arg name "$NAME" \
    --arg sql "$SQL" \
    --arg is_archived "$IS_ARCHIVED" \
    --arg exists "true" \
    '{query_id: $query_id, name: $name, sql: $sql, is_archived: $is_archived, exists: $exists}'
