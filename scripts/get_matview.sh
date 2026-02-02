#!/bin/bash
# =============================================================================
# Get Materialized View Script
# =============================================================================
# Retrieves details of a materialized view from Dune Analytics via the API.
# Used for drift detection and state reconciliation.
#
# Usage: ./get_matview.sh
# Reads JSON input from stdin with: full_name (e.g., dune.team.result_name)
# Outputs JSON with: id, query_id, is_private, table_size_bytes, exists
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

# Get materialized view via API
RESPONSE=$(curl -s -X GET \
    -H "X-Dune-API-Key: $DUNE_API_KEY" \
    "$API_URL/materialized-views/$FULL_NAME")

# Check for 404 or error
ERROR=$(echo "$RESPONSE" | jq -r '.error // empty')
if [ -n "$ERROR" ]; then
    echo "{\"full_name\": \"$FULL_NAME\", \"exists\": \"false\", \"error\": \"$ERROR\"}"
    exit 0
fi

# Extract fields
ID=$(echo "$RESPONSE" | jq -r '.id // empty')
QUERY_ID=$(echo "$RESPONSE" | jq -r '.query_id // empty')
IS_PRIVATE=$(echo "$RESPONSE" | jq -r '.is_private // "false"')
TABLE_SIZE=$(echo "$RESPONSE" | jq -r '.table_size_bytes // "0"')
SQL_ID=$(echo "$RESPONSE" | jq -r '.sql_id // empty')

# Output result
jq -n \
    --arg full_name "$FULL_NAME" \
    --arg id "$ID" \
    --arg query_id "$QUERY_ID" \
    --arg is_private "$IS_PRIVATE" \
    --arg table_size_bytes "$TABLE_SIZE" \
    --arg sql_id "$SQL_ID" \
    --arg exists "true" \
    '{full_name: $full_name, id: $id, query_id: $query_id, is_private: $is_private, table_size_bytes: $table_size_bytes, sql_id: $sql_id, exists: $exists}'
