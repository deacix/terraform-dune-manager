#!/bin/bash
# =============================================================================
# Create or Get Query Script
# =============================================================================
# Either returns an existing query_id or creates a new query on Dune.
#
# Usage: ./create_or_get_query.sh
# Reads JSON input from stdin with: name, sql, is_private, query_id (optional)
#
# Logic:
# 1. If query_id is provided and valid, verify it exists and return it
# 2. Otherwise, search for an existing query by exact name match
# 3. If found (and not archived), return that ID
# 4. If not found, create a new query
#
# This ensures query_ids remain STABLE and don't drift in terraform state.
#
# Environment: DUNE_API_KEY must be set

set -e

# Read input from stdin
INPUT=$(cat)

# Extract parameters
NAME=$(echo "$INPUT" | jq -r '.name')
SQL=$(echo "$INPUT" | jq -r '.sql')
IS_PRIVATE=$(echo "$INPUT" | jq -r '.is_private // "true"')
EXISTING_ID=$(echo "$INPUT" | jq -r '.query_id // empty')
API_URL="${DUNE_API_URL:-https://api.dune.com/api/v1}"

# Validate API key
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

# -----------------------------------------------------------------------------
# Step 1: If existing query_id is provided, verify it exists and return it
# -----------------------------------------------------------------------------
if [ -n "$EXISTING_ID" ] && [ "$EXISTING_ID" != "null" ] && [ "$EXISTING_ID" != "0" ]; then
    # Verify the query exists
    VERIFY_RESPONSE=$(curl -s \
        -H "X-Dune-API-Key: $DUNE_API_KEY" \
        "$API_URL/query/$EXISTING_ID" 2>/dev/null || echo '{}')
    
    VERIFIED_ID=$(echo "$VERIFY_RESPONSE" | jq -r '.query_id // empty')
    IS_ARCHIVED=$(echo "$VERIFY_RESPONSE" | jq -r '.is_archived // false')
    
    if [ -n "$VERIFIED_ID" ]; then
        # If query is archived, unarchive it first
        if [ "$IS_ARCHIVED" = "true" ]; then
            echo "Query $EXISTING_ID is archived, unarchiving..." >&2
            curl -s -X POST \
                -H "X-Dune-API-Key: $DUNE_API_KEY" \
                "$API_URL/query/$EXISTING_ID/unarchive" > /dev/null || true
        fi
        echo "{\"query_id\": \"$EXISTING_ID\", \"mode\": \"existing\"}"
        exit 0
    fi
    # If query doesn't exist at all, fall through to search/create
fi

# -----------------------------------------------------------------------------
# Step 2: Search for existing query by name
# -----------------------------------------------------------------------------
# Use the /queries endpoint to list all queries owned by this API key
# Then filter locally by exact name match

SEARCH_RESPONSE=$(curl -s \
    -H "X-Dune-API-Key: $DUNE_API_KEY" \
    "$API_URL/queries?limit=1000" 2>/dev/null || echo '{"queries":[]}')

# Find query with exact name match that is not archived
# Note: API returns 'id' field, and list endpoint doesn't include is_archived status
FOUND_ID=$(echo "$SEARCH_RESPONSE" | jq -r --arg name "$NAME" \
    '.queries[]? | select(.name == $name) | .id' | head -1)

if [ -n "$FOUND_ID" ] && [ "$FOUND_ID" != "null" ]; then
    echo "{\"query_id\": \"$FOUND_ID\", \"mode\": \"found\"}"
    exit 0
fi

# -----------------------------------------------------------------------------
# Step 3: Create new query (no existing query found)
# -----------------------------------------------------------------------------
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
    ERROR=$(echo "$RESPONSE" | jq -r '.error // empty')
    if [ -n "$ERROR" ]; then
        echo "{\"error\": \"$ERROR\"}" >&2
        exit 1
    fi
    echo '{"error": "Failed to extract query_id from response"}' >&2
    exit 1
fi

echo "{\"query_id\": \"$QUERY_ID\", \"mode\": \"created\"}"
