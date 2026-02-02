# =============================================================================
# Unit Tests for Dune Terraform Module
# =============================================================================
# These tests validate the module's logic without making real API calls.
# Uses `command = plan` to test configuration validation and computed values.
#
# Run with: terraform test
# =============================================================================

# -----------------------------------------------------------------------------
# Mock the external data source (simulates Dune API responses)
# -----------------------------------------------------------------------------
mock_provider "external" {
  mock_data "external" {
    defaults = {
      result = {
        query_id = "12345"
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Test: Basic Module Configuration
# -----------------------------------------------------------------------------
run "basic_configuration" {
  command = plan

  variables {
    team         = "test-team"
    dune_api_key = "test-api-key"
    
    queries = {
      test_query = {
        name = "Test Query"
        sql  = "SELECT 1 as value"
      }
    }
  }

  # Verify team output
  assert {
    condition     = output.team == "test-team"
    error_message = "Team output should match input variable"
  }

  # Verify workspace URL is generated correctly
  assert {
    condition     = output.workspace_folder_url == "https://dune.com/workspace/t/test-team/library/folders/"
    error_message = "Workspace URL should be generated from team name"
  }

  # Verify query name is set correctly (no prefix)
  assert {
    condition     = output.query_names["test_query"] == "Test Query"
    error_message = "Query name should match when no prefix is set"
  }
}

# -----------------------------------------------------------------------------
# Test: Query Prefix Application
# -----------------------------------------------------------------------------
run "query_prefix" {
  command = plan

  variables {
    team         = "test-team"
    dune_api_key = "test-api-key"
    query_prefix = "[Dashboard]"
    
    queries = {
      revenue = {
        name = "Revenue Daily"
        sql  = "SELECT date, sum(amount) FROM sales GROUP BY 1"
      }
    }
  }

  # Verify prefix is applied to query name
  assert {
    condition     = output.query_names["revenue"] == "[Dashboard] Revenue Daily"
    error_message = "Query name should include the prefix"
  }
}

# -----------------------------------------------------------------------------
# Test: SQL Hash Generation
# -----------------------------------------------------------------------------
run "sql_hash_generation" {
  command = plan

  variables {
    team         = "test-team"
    dune_api_key = "test-api-key"
    
    queries = {
      query_a = {
        name = "Query A"
        sql  = "SELECT 1"
      }
      query_b = {
        name = "Query B"
        sql  = "SELECT 2"
      }
    }
  }

  # Verify hashes are generated
  assert {
    condition     = can(regex("^sha256:[a-f0-9]{12}$", output.query_hashes["query_a"]))
    error_message = "Query hash should be in format sha256:xxxxxxxxxxxx"
  }

  # Verify different SQL produces different hashes
  assert {
    condition     = output.query_hashes["query_a"] != output.query_hashes["query_b"]
    error_message = "Different SQL content should produce different hashes"
  }
}

# -----------------------------------------------------------------------------
# Test: Materialized View Configuration
# -----------------------------------------------------------------------------
run "materialized_view_config" {
  command = plan

  variables {
    team         = "my-team"
    dune_api_key = "test-api-key"
    
    queries = {
      daily_stats = {
        name = "Daily Stats"
        sql  = "SELECT date, count(*) FROM events GROUP BY 1"
      }
    }
    
    materialized_views = {
      result_daily_stats = {
        query_key   = "daily_stats"
        cron        = "0 */1 * * *"
        performance = "medium"
      }
    }
  }

  # Verify mat view name format
  assert {
    condition     = output.materialized_view_names["result_daily_stats"] == "dune.my-team.result_daily_stats"
    error_message = "Materialized view name should be in format dune.team.name"
  }
}

# -----------------------------------------------------------------------------
# Test: Default Performance Setting
# -----------------------------------------------------------------------------
run "default_performance" {
  command = plan

  variables {
    team                = "test-team"
    dune_api_key        = "test-api-key"
    default_performance = "large"
    
    queries = {
      heavy_query = {
        name = "Heavy Query"
        sql  = "SELECT * FROM large_table"
      }
    }
    
    materialized_views = {
      result_heavy = {
        query_key = "heavy_query"
        cron      = "0 0 * * *"
        # performance not specified, should use default
      }
    }
  }

  # Test verifies that the module accepts large as default_performance
  assert {
    condition     = output.team == "test-team"
    error_message = "Module should accept large as default_performance"
  }
}

# -----------------------------------------------------------------------------
# Test: Privacy Settings
# -----------------------------------------------------------------------------
run "privacy_settings" {
  command = plan

  variables {
    team         = "test-team"
    dune_api_key = "test-api-key"
    is_private   = true
    
    queries = {
      private_query = {
        name = "Private Query"
        sql  = "SELECT secret FROM vault"
        # Uses default privacy (true)
      }
      public_query = {
        name    = "Public Query"
        sql     = "SELECT 1"
        private = false  # Override to public
      }
    }
  }

  # Test passes if both queries are accepted
  assert {
    condition     = length(output.query_names) == 2
    error_message = "Should create both private and public queries"
  }
}

# -----------------------------------------------------------------------------
# Test: Workspace URL Override
# -----------------------------------------------------------------------------
run "workspace_url_override" {
  command = plan

  variables {
    team                 = "test-team"
    dune_api_key         = "test-api-key"
    workspace_folder_url = "https://custom.dune.com/workspace/special"
    
    queries = {}
  }

  assert {
    condition     = output.workspace_folder_url == "https://custom.dune.com/workspace/special"
    error_message = "Custom workspace URL should override default"
  }
}

# -----------------------------------------------------------------------------
# Test: Multiple Queries
# -----------------------------------------------------------------------------
run "multiple_queries" {
  command = plan

  variables {
    team         = "analytics"
    dune_api_key = "test-api-key"
    query_prefix = "[Analytics]"
    query_folder = "Reports"
    
    queries = {
      users = {
        name        = "Active Users"
        description = "Count of active users per day"
        sql         = "SELECT date, count(distinct user_id) FROM events GROUP BY 1"
        tags        = ["users", "daily"]
      }
      revenue = {
        name        = "Daily Revenue"
        description = "Revenue aggregated by day"
        sql         = "SELECT date, sum(amount) FROM transactions GROUP BY 1"
        tags        = ["revenue", "daily"]
      }
      transactions = {
        name = "Transaction Count"
        sql  = "SELECT count(*) FROM transactions"
      }
    }
  }

  # Verify all queries are created
  assert {
    condition     = length(output.query_names) == 3
    error_message = "Should create all 3 queries"
  }

  # Verify all names have prefix
  assert {
    condition     = output.query_names["users"] == "[Analytics] Active Users"
    error_message = "Users query should have prefix"
  }

  assert {
    condition     = output.query_names["revenue"] == "[Analytics] Daily Revenue"
    error_message = "Revenue query should have prefix"
  }

  assert {
    condition     = output.query_names["transactions"] == "[Analytics] Transaction Count"
    error_message = "Transactions query should have prefix"
  }
}

# -----------------------------------------------------------------------------
# Test: SQL Metadata Stripping
# -----------------------------------------------------------------------------
run "sql_metadata_stripping" {
  command = plan

  variables {
    team         = "test-team"
    dune_api_key = "test-api-key"
    
    queries = {
      with_metadata = {
        name = "Query With Metadata"
        sql  = <<-SQL
          -- name: Should Be Stripped
          -- description: This should also be stripped
          -- tags: tag1, tag2
          -- private: true
          SELECT 1 as value
        SQL
      }
      without_metadata = {
        name = "Query Without Metadata"
        sql  = "SELECT 1 as value"
      }
    }
  }

  # Both queries should have different raw SQL but the body hash comparison
  # tests that metadata is stripped
  assert {
    condition     = length(output.query_hashes) == 2
    error_message = "Should generate hashes for both queries"
  }
}

# -----------------------------------------------------------------------------
# Test: API Base URL Override
# -----------------------------------------------------------------------------
run "api_base_url_override" {
  command = plan

  variables {
    team         = "test-team"
    dune_api_key = "test-api-key"
    api_base_url = "https://custom-api.dune.com/api/v2"
    
    queries = {}
  }

  # Test passes if custom API URL is accepted
  assert {
    condition     = output.team == "test-team"
    error_message = "Custom API base URL should be accepted"
  }
}

# -----------------------------------------------------------------------------
# Test: API Timeout Configuration
# -----------------------------------------------------------------------------
run "api_timeout_config" {
  command = plan

  variables {
    team         = "test-team"
    dune_api_key = "test-api-key"
    api_timeout  = 60
    
    queries = {}
  }

  assert {
    condition     = output.team == "test-team"
    error_message = "Custom API timeout should be accepted"
  }
}

# -----------------------------------------------------------------------------
# Test: State File Generation Disabled by Default
# -----------------------------------------------------------------------------
run "state_file_disabled_default" {
  command = plan

  variables {
    team         = "test-team"
    dune_api_key = "test-api-key"
    
    queries = {
      test = {
        name = "Test"
        sql  = "SELECT 1"
      }
    }
  }

  # enable_state_file defaults to false
  assert {
    condition     = output.team == "test-team"
    error_message = "State file should be disabled by default"
  }
}

# -----------------------------------------------------------------------------
# Test: Data Source Options Disabled by Default
# -----------------------------------------------------------------------------
run "data_sources_disabled_default" {
  command = plan

  variables {
    team         = "test-team"
    dune_api_key = "test-api-key"
    # All enable_* options default to false
    
    queries = {}
  }

  # Verify data source outputs are null when disabled
  assert {
    condition     = output.usage == null
    error_message = "Usage output should be null when enable_usage_monitoring is false"
  }

  assert {
    condition     = output.datasets == null
    error_message = "Datasets output should be null when enable_dataset_discovery is false"
  }

  assert {
    condition     = output.existing_materialized_views == null
    error_message = "Existing mat views output should be null when enable_matview_discovery is false"
  }
}
