# =============================================================================
# Output Values for Dune Module
# =============================================================================
# Exposes query IDs, URLs, and mat view information for use by other modules.

# -----------------------------------------------------------------------------
# Query Outputs
# -----------------------------------------------------------------------------

output "query_ids" {
  description = "Map of query keys to their Dune query IDs"
  value = {
    for k, v in null_resource.queries : k => tonumber(v.triggers.query_id)
  }
}

output "query_names" {
  description = "Map of query keys to their full names (with prefix)"
  value = {
    for k, v in var.queries : k => local.query_full_names[k]
  }
}

output "query_urls" {
  description = "Map of query keys to their Dune query URLs"
  value = {
    for k, v in null_resource.queries : k => "https://dune.com/queries/${v.triggers.query_id}"
  }
}

output "query_hashes" {
  description = "Map of query keys to their SQL content hashes"
  value = {
    for k, v in var.queries : k => local.query_hashes[k]
  }
}

# -----------------------------------------------------------------------------
# Materialized View Outputs
# -----------------------------------------------------------------------------

output "materialized_view_names" {
  description = "Map of mat view keys to their full names (dune.team.name)"
  value = {
    for k, v in var.materialized_views : k => "dune.${var.team}.${k}"
  }
}

output "materialized_view_query_ids" {
  description = "Map of mat view keys to their underlying query IDs"
  value = {
    for k, v in null_resource.materialized_views : k => tonumber(v.triggers.query_id)
  }
}

# -----------------------------------------------------------------------------
# Reference URLs
# -----------------------------------------------------------------------------

output "workspace_folder_url" {
  description = "URL to the workspace folder on Dune"
  value       = local.workspace_folder_url
}

output "team" {
  description = "The Dune team name"
  value       = var.team
}

# -----------------------------------------------------------------------------
# State Export (for Python tool compatibility)
# -----------------------------------------------------------------------------

output "state_export" {
  description = "State data in format compatible with Python deploy tool"
  value = {
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
  }
  sensitive = false
}

# -----------------------------------------------------------------------------
# Data Source Outputs (Optional)
# -----------------------------------------------------------------------------

output "usage" {
  description = "API usage and billing data (credits, queries, storage)"
  value       = var.enable_usage_monitoring ? data.external.usage[0].result : null
}

output "datasets" {
  description = "Available datasets for the team"
  value       = var.enable_dataset_discovery ? data.external.datasets[0].result : null
}

output "existing_materialized_views" {
  description = "List of existing materialized views from the API"
  value       = var.enable_matview_discovery ? data.external.materialized_views_list[0].result : null
}
