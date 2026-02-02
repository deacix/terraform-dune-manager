#!/bin/bash
# =============================================================================
# Get Dataset Script
# =============================================================================
# Retrieves detailed information about a dataset from Dune Analytics.
# Includes schema, columns, and metadata.
#
# Usage: ./get_dataset.sh
# Reads JSON input from stdin with: namespace, name
# Outputs JSON with: id, name, namespace, columns (as JSON string), exists
#
# Environment: DUNE_API_KEY must be set

set -e

# Read input from stdin
INPUT=$(cat)

# Extract parameters
NAMESPACE=$(echo "$INPUT" | jq -r '.namespace')
NAME=$(echo "$INPUT" | jq -r '.name')
API_URL="${DUNE_API_URL:-https://api.dune.com/api/v1}"

# Validate
if [ -z "$DUNE_API_KEY" ]; then
    echo '{"error": "DUNE_API_KEY environment variable not set"}' >&2
    exit 1
fi

if [ -z "$NAMESPACE" ] || [ "$NAMESPACE" = "null" ]; then
    echo '{"error": "namespace is required"}' >&2
    exit 1
fi

if [ -z "$NAME" ] || [ "$NAME" = "null" ]; then
    echo '{"error": "name is required"}' >&2
    exit 1
fi

# Get dataset via API
RESPONSE=$(curl -s -X GET \
    -H "X-Dune-API-Key: $DUNE_API_KEY" \
    "$API_URL/datasets/$NAMESPACE/$NAME")

# Check for 404 or error
ERROR=$(echo "$RESPONSE" | jq -r '.error // empty')
if [ -n "$ERROR" ]; then
    echo "{\"namespace\": \"$NAMESPACE\", \"name\": \"$NAME\", \"exists\": \"false\", \"error\": \"$ERROR\"}"
    exit 0
fi

# Extract fields
ID=$(echo "$RESPONSE" | jq -r '.id // empty')
FULL_NAME=$(echo "$RESPONSE" | jq -r '.full_name // empty')
DESCRIPTION=$(echo "$RESPONSE" | jq -r '.description // empty')
COLUMNS=$(echo "$RESPONSE" | jq -c '.columns // []')
IS_PRIVATE=$(echo "$RESPONSE" | jq -r '.is_private // "false"')

# Output result (columns as JSON string for external data source compatibility)
jq -n \
    --arg id "$ID" \
    --arg namespace "$NAMESPACE" \
    --arg name "$NAME" \
    --arg full_name "$FULL_NAME" \
    --arg description "$DESCRIPTION" \
    --arg columns "$COLUMNS" \
    --arg is_private "$IS_PRIVATE" \
    --arg exists "true" \
    '{id: $id, namespace: $namespace, name: $name, full_name: $full_name, description: $description, columns: $columns, is_private: $is_private, exists: $exists}'
