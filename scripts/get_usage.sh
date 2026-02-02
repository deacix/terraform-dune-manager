#!/bin/bash
# =============================================================================
# Get Usage Script
# =============================================================================
# Retrieves API usage and billing data from Dune Analytics.
# Monitors credits consumption, query executions, and storage usage.
#
# Usage: ./get_usage.sh
# Reads JSON input from stdin with: start_date (optional), end_date (optional)
# Outputs JSON with usage metrics
#
# Environment: DUNE_API_KEY must be set

set -e

# Read input from stdin
INPUT=$(cat)

# Extract parameters
START_DATE=$(echo "$INPUT" | jq -r '.start_date // empty')
END_DATE=$(echo "$INPUT" | jq -r '.end_date // empty')
API_URL="${DUNE_API_URL:-https://api.dune.com/api/v1}"

# Validate
if [ -z "$DUNE_API_KEY" ]; then
    echo '{"error": "DUNE_API_KEY environment variable not set"}' >&2
    exit 1
fi

# Build request body
BODY="{}"
if [ -n "$START_DATE" ] && [ "$START_DATE" != "null" ]; then
    BODY=$(echo "$BODY" | jq --arg start "$START_DATE" '. + {start_date: $start}')
fi
if [ -n "$END_DATE" ] && [ "$END_DATE" != "null" ]; then
    BODY=$(echo "$BODY" | jq --arg end "$END_DATE" '. + {end_date: $end}')
fi

# Get usage via API
RESPONSE=$(curl -s -X POST \
    -H "X-Dune-API-Key: $DUNE_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$BODY" \
    "$API_URL/usage")

# Check for errors
ERROR=$(echo "$RESPONSE" | jq -r '.error // empty')
if [ -n "$ERROR" ]; then
    echo "{\"error\": \"$ERROR\"}" >&2
    exit 1
fi

# Extract fields - convert all to strings for external data source compatibility
CREDITS_USED=$(echo "$RESPONSE" | jq -r '.credits_used // "0"')
CREDITS_REMAINING=$(echo "$RESPONSE" | jq -r '.credits_remaining // "0"')
QUERIES_EXECUTED=$(echo "$RESPONSE" | jq -r '.queries_executed // "0"')
STORAGE_BYTES=$(echo "$RESPONSE" | jq -r '.storage_bytes // "0"')
BILLING_PERIOD_START=$(echo "$RESPONSE" | jq -r '.billing_period_start // empty')
BILLING_PERIOD_END=$(echo "$RESPONSE" | jq -r '.billing_period_end // empty')

# Output result
jq -n \
    --arg credits_used "$CREDITS_USED" \
    --arg credits_remaining "$CREDITS_REMAINING" \
    --arg queries_executed "$QUERIES_EXECUTED" \
    --arg storage_bytes "$STORAGE_BYTES" \
    --arg billing_period_start "$BILLING_PERIOD_START" \
    --arg billing_period_end "$BILLING_PERIOD_END" \
    '{credits_used: $credits_used, credits_remaining: $credits_remaining, queries_executed: $queries_executed, storage_bytes: $storage_bytes, billing_period_start: $billing_period_start, billing_period_end: $billing_period_end}'
