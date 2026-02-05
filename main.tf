# =============================================================================
# Dune Analytics Terraform Module
# =============================================================================
# Manages Dune queries and materialized views as infrastructure-as-code.
#
# Architecture:
# - Uses external data source for create operations (captures query_id)
# - Uses null_resource with triggers for change detection
# - Supports create, update, and destroy lifecycle
#
# Note: There's no official Dune Terraform provider, so this module
# uses the REST API directly via shell scripts.
#
# IMPORTANT: The DUNE_API_KEY environment variable must be set for
# destroy operations to work properly.

# -----------------------------------------------------------------------------
# Dune Queries
# -----------------------------------------------------------------------------
# Creates and manages queries on Dune Analytics.
# Each query is tracked by its key and the SQL content hash.

# Create queries via external data source to capture query_id
data "external" "create_query" {
  for_each = var.queries

  program = ["bash", "${local.scripts_path}/create_or_get_query.sh"]

  query = {
    name       = local.query_full_names[each.key]
    sql        = local.query_body[each.key]
    is_private = tostring(local.query_privacy[each.key])
    query_id   = tostring(coalesce(each.value.query_id, 0))
  }
}

# Track queries with null_resource for lifecycle management
resource "null_resource" "queries" {
  for_each = var.queries

  # Triggers for change detection
  triggers = {
    name     = local.query_full_names[each.key]
    sql_hash = local.query_hashes[each.key]
    private  = tostring(local.query_privacy[each.key])
    # Store the query_id from the external data source
    query_id = data.external.create_query[each.key].result.query_id
    # Store API base URL for destroy provisioner (can only use self.*)
    api_base_url = var.api_base_url
  }

  # Update query when SQL changes
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      QUERY_ID="${self.triggers.query_id}"
      
      if [ -n "$QUERY_ID" ] && [ "$QUERY_ID" != "0" ]; then
        echo "Updating query ${each.key} (ID: $QUERY_ID)..."
        
        curl -s -X PATCH \
          -H "X-Dune-API-Key: $DUNE_API_KEY" \
          -H "Content-Type: application/json" \
          -d '{
            "name": ${jsonencode(local.query_full_names[each.key])},
            "query_sql": ${jsonencode(local.query_body[each.key])}
          }' \
          "${var.api_base_url}/query/$QUERY_ID" > /dev/null
        
        echo "Updated query $QUERY_ID"
      fi
    EOT

    interpreter = ["/bin/bash", "-c"]

    environment = {
      DUNE_API_KEY = var.dune_api_key
    }
  }

  # Archive query on destroy
  # Note: Uses DUNE_API_KEY from environment (must be set when running terraform destroy)
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      
      QUERY_ID="${self.triggers.query_id}"
      API_BASE="${self.triggers.api_base_url}"
      
      if [ -z "$DUNE_API_KEY" ]; then
        echo "Warning: DUNE_API_KEY not set, skipping archive"
        exit 0
      fi
      
      if [ -n "$QUERY_ID" ] && [ "$QUERY_ID" != "0" ]; then
        echo "Archiving query (ID: $QUERY_ID)..."
        
        curl -s -X POST \
          -H "X-Dune-API-Key: $DUNE_API_KEY" \
          "$API_BASE/query/$QUERY_ID/archive" > /dev/null || true
        
        echo "Archived query $QUERY_ID"
      fi
    EOT

    interpreter = ["/bin/bash", "-c"]
  }
}

# -----------------------------------------------------------------------------
# Materialized Views
# -----------------------------------------------------------------------------
# Creates and manages materialized views for cached query results.
# Each mat view is linked to a query and has a refresh schedule.

resource "null_resource" "materialized_views" {
  for_each = var.materialized_views

  # Depend on the underlying query being created first
  depends_on = [null_resource.queries]

  triggers = {
    name         = each.key
    query_key    = each.value.query_key
    query_id     = null_resource.queries[each.value.query_key].triggers.query_id
    cron         = each.value.cron
    performance  = local.mv_performance[each.key]
    team         = var.team
    api_base_url = var.api_base_url
  }

  # Create/upsert materialized view
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      QUERY_ID="${self.triggers.query_id}"
      
      if [ -z "$QUERY_ID" ] || [ "$QUERY_ID" = "0" ]; then
        echo "Error: Query ID not found for ${each.value.query_key}" >&2
        exit 1
      fi
      
      echo "Creating materialized view ${each.key} for query $QUERY_ID..."
      
      RESPONSE=$(curl -s -X POST \
        -H "X-Dune-API-Key: $DUNE_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
          "name": "${each.key}",
          "query_id": '$QUERY_ID',
          "cron_expression": "${each.value.cron}",
          "performance": "${local.mv_performance[each.key]}",
          "is_private": true
        }' \
        "${var.api_base_url}/materialized-views")
      
      # Check for errors (but don't fail - upsert behavior)
      if echo "$RESPONSE" | grep -q '"error"'; then
        echo "Warning: $RESPONSE"
      else
        echo "Created materialized view: dune.${var.team}.${each.key}"
      fi
    EOT

    interpreter = ["/bin/bash", "-c"]

    environment = {
      DUNE_API_KEY = var.dune_api_key
    }
  }

  # Delete materialized view on destroy
  # Note: Uses DUNE_API_KEY from environment (must be set when running terraform destroy)
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      
      FULL_NAME="dune.${self.triggers.team}.${self.triggers.name}"
      API_BASE="${self.triggers.api_base_url}"
      
      if [ -z "$DUNE_API_KEY" ]; then
        echo "Warning: DUNE_API_KEY not set, skipping delete"
        exit 0
      fi
      
      echo "Deleting materialized view: $FULL_NAME..."
      
      curl -s -X DELETE \
        -H "X-Dune-API-Key: $DUNE_API_KEY" \
        "$API_BASE/materialized-views/$FULL_NAME" || true
      
      echo "Deleted materialized view $FULL_NAME"
    EOT

    interpreter = ["/bin/bash", "-c"]
  }
}

# -----------------------------------------------------------------------------
# Data Sources (Optional)
# -----------------------------------------------------------------------------
# Read-only data sources for monitoring and discovery.

# Fetch API usage and billing data
data "external" "usage" {
  count = var.enable_usage_monitoring ? 1 : 0

  program = ["bash", "${local.scripts_path}/get_usage.sh"]

  query = {
    start_date = ""
    end_date   = ""
  }
}

# List available datasets for discovery
data "external" "datasets" {
  count = var.enable_dataset_discovery ? 1 : 0

  program = ["bash", "${local.scripts_path}/list_datasets.sh"]

  query = {
    owner  = var.team
    limit  = "100"
    offset = ""
  }
}

# List existing materialized views for state reconciliation
data "external" "materialized_views_list" {
  count = var.enable_matview_discovery ? 1 : 0

  program = ["bash", "${local.scripts_path}/list_matviews.sh"]

  query = {
    limit  = "100"
    offset = ""
  }
}

# -----------------------------------------------------------------------------
# State File Generation (Optional)
# -----------------------------------------------------------------------------
# Generates a state.yaml file compatible with the Python deploy tool.

resource "local_file" "state_yaml" {
  count = var.enable_state_file ? 1 : 0

  filename = var.state_file_path
  content = yamlencode({
    version       = "1.0"
    team          = var.team
    last_deployed = timestamp()
    queries = {
      for k, v in null_resource.queries : k => {
        query_id   = tonumber(v.triggers.query_id)
        name       = local.query_full_names[k]
        folder     = var.query_folder
        sql_hash   = local.query_hashes[k]
        version    = 1
        created_at = timestamp()
        updated_at = timestamp()
      }
    }
    materialized_views = {
      for k, v in null_resource.materialized_views : k => {
        full_name       = "dune.${var.team}.${k}"
        query_key       = var.materialized_views[k].query_key
        query_id        = tonumber(null_resource.queries[var.materialized_views[k].query_key].triggers.query_id)
        cron_expression = var.materialized_views[k].cron
        performance     = local.mv_performance[k]
        created_at      = timestamp()
      }
    }
  })

  depends_on = [
    null_resource.queries,
    null_resource.materialized_views,
  ]
}

# -----------------------------------------------------------------------------
# Materialized View Drift Detection
# -----------------------------------------------------------------------------
# Verifies that actual Dune mat view configuration matches Terraform state.
# This runs during `terraform plan` to detect configuration drift.

data "external" "verify_matview" {
  for_each = var.materialized_views

  program = ["bash", "${local.scripts_path}/verify_matview.sh"]

  query = {
    name             = "dune.${var.team}.${each.key}"
    expected_cron    = each.value.cron
    expected_query_id = tostring(coalesce(var.queries[each.value.query_key].query_id, 0))
  }
}

# Output drift detection results for visibility
output "matview_drift_status" {
  description = "Drift detection status for each materialized view"
  value = {
    for k, v in data.external.verify_matview : k => {
      status      = v.result.status
      actual_cron = v.result.actual_cron
      message     = v.result.message
    }
  }
}

# Check for any drift and output a warning
output "has_matview_drift" {
  description = "True if any materialized view has configuration drift"
  value = anytrue([
    for k, v in data.external.verify_matview : v.result.status == "drift" || v.result.status == "missing"
  ])
}

# Resource to force re-apply when drift is detected
resource "null_resource" "matview_drift_check" {
  for_each = {
    for k, v in data.external.verify_matview : k => v
    if v.result.status == "drift" || v.result.status == "missing"
  }

  # Force recreation when drift is detected
  triggers = {
    drift_status = each.value.result.status
    drift_message = each.value.result.message
    timestamp = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "=========================================="
      echo "DRIFT DETECTED: ${each.key}"
      echo "Status: ${each.value.result.status}"
      echo "Message: ${each.value.result.message}"
      echo "Actual cron: ${each.value.result.actual_cron}"
      echo "Expected cron: ${var.materialized_views[each.key].cron}"
      echo "=========================================="
      echo ""
      echo "Re-applying materialized view configuration..."
      
      QUERY_ID="${null_resource.queries[var.materialized_views[each.key].query_key].triggers.query_id}"
      
      curl -s -X POST \
        -H "X-Dune-API-Key: $DUNE_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
          "name": "${each.key}",
          "query_id": '$QUERY_ID',
          "cron_expression": "${var.materialized_views[each.key].cron}",
          "performance": "${local.mv_performance[each.key]}",
          "is_private": true
        }' \
        "${var.api_base_url}/materialized-views"
      
      echo ""
      echo "Mat view ${each.key} configuration re-applied."
    EOT

    interpreter = ["/bin/bash", "-c"]

    environment = {
      DUNE_API_KEY = var.dune_api_key
    }
  }
}
