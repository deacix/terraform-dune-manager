# =============================================================================
# Local Values for Dune Module
# =============================================================================
# Computed values used across the module resources.

locals {
  # Workspace folder URL
  workspace_folder_url = coalesce(
    var.workspace_folder_url,
    "https://dune.com/workspace/t/${var.team}/library/folders/${var.query_folder}"
  )

  # Load SQL content from files or use inline SQL
  query_sql = {
    for k, v in var.queries : k => coalesce(
      v.sql,
      v.sql_file != null ? file(v.sql_file) : null
    )
  }

  # Extract SQL body by removing metadata header comments
  # This uses a simple approach: split by lines, filter out metadata comments
  query_body = {
    for k, v in local.query_sql : k => join("\n", [
      for line in split("\n", v) :
      line if !startswith(trimspace(line), "-- name:") &&
      !startswith(trimspace(line), "-- description:") &&
      !startswith(trimspace(line), "-- tags:") &&
      !startswith(trimspace(line), "-- private:")
    ])
  }

  # Compute SHA256 hash of normalized SQL content (first 12 chars)
  # Normalize by joining all whitespace into single spaces
  query_hashes = {
    for k, v in local.query_body : k => "sha256:${substr(sha256(trimspace(v)), 0, 12)}"
  }

  # Build full query names with prefix
  query_full_names = {
    for k, v in var.queries : k => var.query_prefix != "" ? "${var.query_prefix} ${v.name}" : v.name
  }

  # Determine privacy for each query
  query_privacy = {
    for k, v in var.queries : k => coalesce(v.private, var.is_private)
  }

  # Materialized view performance settings
  mv_performance = {
    for k, v in var.materialized_views : k => coalesce(v.performance, var.default_performance)
  }

  # Script paths
  scripts_path = "${path.module}/scripts"
}
