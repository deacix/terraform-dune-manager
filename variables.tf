# =============================================================================
# Input Variables for Dune Module
# =============================================================================
# Configuration for managing Dune Analytics queries and materialized views.

# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "team" {
  description = "Dune team/namespace name (e.g., '1inch')"
  type        = string

  validation {
    condition     = length(var.team) > 0
    error_message = "Team name cannot be empty."
  }
}

variable "dune_api_key" {
  description = "Dune API key with write permissions"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.dune_api_key) > 0
    error_message = "Dune API key cannot be empty."
  }
}

# -----------------------------------------------------------------------------
# Optional Configuration Variables
# -----------------------------------------------------------------------------

variable "query_prefix" {
  description = "Prefix for all query names (e.g., '[1inch Dashboard]')"
  type        = string
  default     = ""
}

variable "query_folder" {
  description = "Folder name for organizing queries in Dune workspace"
  type        = string
  default     = ""
}

variable "is_private" {
  description = "Default privacy setting for queries"
  type        = bool
  default     = true
}

variable "default_performance" {
  description = "Default performance tier for materialized views"
  type        = string
  default     = "medium"

  validation {
    condition     = contains(["medium", "large"], var.default_performance)
    error_message = "Performance must be 'medium' or 'large'."
  }
}

variable "workspace_folder_url" {
  description = "URL to the workspace folder (for reference)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Query Definitions
# -----------------------------------------------------------------------------

variable "queries" {
  description = <<-EOT
    Map of query definitions. Each query can specify:
    - name: Query name (without prefix)
    - description: Query description (optional)
    - sql_file: Path to SQL file (required if sql not provided)
    - sql: Inline SQL content (required if sql_file not provided)
    - tags: List of tags (optional)
    - private: Override default privacy (optional)
  EOT

  type = map(object({
    name        = string
    description = optional(string, "")
    sql_file    = optional(string)
    sql         = optional(string)
    tags        = optional(list(string), [])
    private     = optional(bool)
  }))

  default = {}

  validation {
    condition = alltrue([
      for k, v in var.queries : v.sql_file != null || v.sql != null
    ])
    error_message = "Each query must have either sql_file or sql specified."
  }
}

# -----------------------------------------------------------------------------
# Materialized View Definitions
# -----------------------------------------------------------------------------

variable "materialized_views" {
  description = <<-EOT
    Map of materialized view definitions. Each view must specify:
    - query_key: Key from the queries map that this view materializes
    - cron: Cron expression for refresh schedule
    - performance: Performance tier ('medium' or 'large', optional)
  EOT

  type = map(object({
    query_key   = string
    cron        = string
    performance = optional(string)
  }))

  default = {}

  validation {
    condition = alltrue([
      for k, v in var.materialized_views : can(regex("^[0-9*,/-]+ [0-9*,/-]+ [0-9*,/-]+ [0-9*,/-]+ [0-9*,/-]+$", v.cron))
    ])
    error_message = "Each materialized view must have a valid 5-field cron expression."
  }
}

# -----------------------------------------------------------------------------
# Advanced Options
# -----------------------------------------------------------------------------

variable "enable_state_file" {
  description = "Generate a state.yaml file compatible with the Python deploy tool"
  type        = bool
  default     = false
}

variable "state_file_path" {
  description = "Path for the generated state.yaml file"
  type        = string
  default     = "state.yaml"
}

variable "api_base_url" {
  description = "Dune API base URL (for testing or alternative endpoints)"
  type        = string
  default     = "https://api.dune.com/api/v1"
}

variable "api_timeout" {
  description = "Timeout for API requests in seconds"
  type        = number
  default     = 30
}

# -----------------------------------------------------------------------------
# Data Source Options
# -----------------------------------------------------------------------------

variable "enable_usage_monitoring" {
  description = "Enable fetching API usage and billing data"
  type        = bool
  default     = false
}

variable "enable_dataset_discovery" {
  description = "Enable listing available datasets for schema exploration"
  type        = bool
  default     = false
}

variable "enable_matview_discovery" {
  description = "Enable listing existing materialized views for state reconciliation"
  type        = bool
  default     = false
}
