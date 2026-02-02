# =============================================================================
# Simple Example: Dune Terraform Module
# =============================================================================
# This example demonstrates basic usage of the Dune Terraform module
# with inline SQL queries (no external file dependencies).
#
# Usage:
#   cd infra/terraform/examples/simple
#   export DUNE_API_KEY="your-api-key"
#   terraform init
#   terraform plan -var="dune_api_key=$DUNE_API_KEY"
#   terraform apply -var="dune_api_key=$DUNE_API_KEY"

terraform {
  required_version = ">= 1.0"
}

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------

variable "dune_api_key" {
  description = "Dune API key"
  type        = string
  sensitive   = true
}

variable "team" {
  description = "Your Dune team name"
  type        = string
  default     = "my-team"
}

# -----------------------------------------------------------------------------
# Module Configuration
# -----------------------------------------------------------------------------

module "dune" {
  source = "../../"

  # Required
  team         = var.team
  dune_api_key = var.dune_api_key

  # Optional configuration
  query_prefix        = "[Example]"
  query_folder        = "Examples"
  is_private          = true
  default_performance = "medium"

  # ==========================================================================
  # Query Definitions
  # ==========================================================================
  # Each query can use inline SQL or reference an external file.

  queries = {
    # Simple query with inline SQL
    daily_transactions = {
      name        = "Daily Transactions"
      description = "Count of daily transactions on Ethereum"
      sql         = <<-SQL
        SELECT
          date_trunc('day', block_time) as date,
          count(*) as tx_count
        FROM ethereum.transactions
        WHERE block_time >= now() - interval '7' day
        GROUP BY 1
        ORDER BY 1 DESC
      SQL
    }

    # Another example query
    top_contracts = {
      name        = "Top Contracts"
      description = "Most active contracts by transaction count"
      sql         = <<-SQL
        SELECT
          "to" as contract_address,
          count(*) as tx_count
        FROM ethereum.transactions
        WHERE 
          block_time >= now() - interval '1' day
          AND "to" IS NOT NULL
        GROUP BY 1
        ORDER BY 2 DESC
        LIMIT 100
      SQL
    }
  }

  # ==========================================================================
  # Materialized View Definitions (Optional)
  # ==========================================================================
  # Mat views cache query results and refresh on a schedule.

  materialized_views = {
    # Cache daily transactions, refresh every hour
    result_daily_transactions = {
      query_key   = "daily_transactions"
      cron        = "0 */1 * * *" # Every hour
      performance = "medium"
    }
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "query_ids" {
  description = "Map of query keys to Dune query IDs"
  value       = module.dune.query_ids
}

output "query_urls" {
  description = "Map of query keys to Dune URLs"
  value       = module.dune.query_urls
}

output "materialized_views" {
  description = "Materialized view names"
  value       = module.dune.materialized_view_names
}
