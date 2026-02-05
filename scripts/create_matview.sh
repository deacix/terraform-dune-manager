#!/bin/bash
# =============================================================================
# Create Materialized View Script
# =============================================================================
# Creates or updates a materialized view on Dune Analytics via the API.
#
# Usage: ./create_matview.sh
# Reads JSON input from stdin with: name, query_id, cron, execution_tier
# Outputs JSON with: name, full_name, created
#
# Environment: DUNE_API_KEY must be set

set -e

# Read input from stdin
INPUT=$(cat)

# Extract parameters
NAME=$(echo "$INPUT" | jq -r '.name')
QUERY_ID=$(echo "$INPUT" | jq -r '.query_id')
CRON=$(echo "$INPUT" | jq -r '.cron')
EXECUTION_TIER=$(echo "$INPUT" | jq -r '.execution_tier // "medium"')
TEAM=$(echo "$INPUT" | jq -r '.team // empty')
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

if [ -z "$QUERY_ID" ] || [ "$QUERY_ID" = "null" ]; then
    echo '{"error": "query_id is required"}' >&2
    exit 1
fi

if [ -z "$CRON" ] || [ "$CRON" = "null" ]; then
    echo '{"error": "cron is required"}' >&2
    exit 1
fi

# Create/upsert materialized view via API
# Note: Uses correct Dune API field names: cron_schedule (not cron_expression), execution_tier (not performance)
RESPONSE=$(curl -s -X POST \
    -H "X-Dune-API-Key: $DUNE_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
        --arg name "$NAME" \
        --argjson query_id "$QUERY_ID" \
        --arg cron_schedule "$CRON" \
        --arg execution_tier "$EXECUTION_TIER" \
        '{name: $name, query_id: $query_id, cron_schedule: $cron_schedule, execution_tier: $execution_tier}')" \
    "$API_URL/materialized-views")

# Check for errors
ERROR=$(echo "$RESPONSE" | jq -r '.error // empty')
if [ -n "$ERROR" ]; then
    # Check if it's "already exists" - that's OK (upsert)
    if echo "$ERROR" | grep -qi "exist"; then
        FULL_NAME="dune.$TEAM.$NAME"
        echo "{\"name\": \"$NAME\", \"full_name\": \"$FULL_NAME\", \"created\": \"false\", \"note\": \"already exists\"}"
        exit 0
    fi
    echo "{\"error\": \"$ERROR\"}" >&2
    exit 1
fi

# Build full name
FULL_NAME="dune.$TEAM.$NAME"

# Output result
jq -n \
    --arg name "$NAME" \
    --arg full_name "$FULL_NAME" \
    '{name: $name, full_name: $full_name, created: "true"}'
