#!/bin/bash
# verify_matview.sh - Verify materialized view state matches expected configuration
# 
# This script checks if the actual Dune mat view configuration matches
# the expected Terraform configuration. It's designed to be used as an
# external data source for drift detection.
#
# Input (via stdin as JSON):
#   - name: Full mat view name (e.g., "dune.1inch.result_1inch_live_overview")
#   - expected_cron: Expected cron expression
#   - expected_query_id: Expected query ID
#
# Output (JSON):
#   - status: "ok" if matches, "drift" if mismatch, "missing" if not found
#   - actual_cron: Actual cron schedule (or "null" if not set)
#   - actual_query_id: Actual query ID
#   - message: Human-readable status message

set -e

# Read input
INPUT=$(cat)
NAME=$(echo "$INPUT" | jq -r '.name')
EXPECTED_CRON=$(echo "$INPUT" | jq -r '.expected_cron // ""')
EXPECTED_QUERY_ID=$(echo "$INPUT" | jq -r '.expected_query_id // ""')

# Check if API key is set
if [ -z "$DUNE_API_KEY" ]; then
  echo '{"status":"skip","actual_cron":"unknown","actual_query_id":"0","message":"DUNE_API_KEY not set, skipping verification"}'
  exit 0
fi

API_BASE="${DUNE_API_BASE_URL:-https://api.dune.com/api/v1}"

# Fetch current mat view state from Dune
RESPONSE=$(curl -s -H "X-Dune-Api-Key: $DUNE_API_KEY" "$API_BASE/materialized-views/$NAME" 2>/dev/null || echo '{"error":"fetch_failed"}')

# Check if mat view exists
if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
  echo '{"status":"missing","actual_cron":"null","actual_query_id":"0","message":"Materialized view does not exist"}'
  exit 0
fi

# Extract actual values
ACTUAL_CRON=$(echo "$RESPONSE" | jq -r '.cron_schedule // "null"')
ACTUAL_QUERY_ID=$(echo "$RESPONSE" | jq -r '.query_id // 0')

# Check for drift
DRIFT=""
MESSAGE="Materialized view exists"

if [ "$ACTUAL_CRON" = "null" ] && [ -n "$EXPECTED_CRON" ]; then
  DRIFT="cron_missing"
  MESSAGE="DRIFT: cron_schedule is null but expected '$EXPECTED_CRON'"
elif [ "$ACTUAL_CRON" != "null" ] && [ "$ACTUAL_CRON" != "$EXPECTED_CRON" ] && [ -n "$EXPECTED_CRON" ]; then
  DRIFT="cron_mismatch"
  MESSAGE="DRIFT: cron_schedule is '$ACTUAL_CRON' but expected '$EXPECTED_CRON'"
fi

if [ "$ACTUAL_QUERY_ID" != "$EXPECTED_QUERY_ID" ] && [ -n "$EXPECTED_QUERY_ID" ]; then
  if [ -n "$DRIFT" ]; then
    DRIFT="$DRIFT,query_id_mismatch"
    MESSAGE="$MESSAGE; query_id is '$ACTUAL_QUERY_ID' but expected '$EXPECTED_QUERY_ID'"
  else
    DRIFT="query_id_mismatch"
    MESSAGE="DRIFT: query_id is '$ACTUAL_QUERY_ID' but expected '$EXPECTED_QUERY_ID'"
  fi
fi

if [ -n "$DRIFT" ]; then
  echo "{\"status\":\"drift\",\"actual_cron\":\"$ACTUAL_CRON\",\"actual_query_id\":\"$ACTUAL_QUERY_ID\",\"message\":\"$MESSAGE\",\"drift_type\":\"$DRIFT\"}"
else
  echo "{\"status\":\"ok\",\"actual_cron\":\"$ACTUAL_CRON\",\"actual_query_id\":\"$ACTUAL_QUERY_ID\",\"message\":\"Configuration matches\"}"
fi
