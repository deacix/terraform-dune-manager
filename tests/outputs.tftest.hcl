# =============================================================================
# Output Tests for Dune Terraform Module
# =============================================================================
# These tests verify that module outputs are structured correctly.
#
# Run with: terraform test
# =============================================================================

# Mock the external data source
mock_provider "external" {
  mock_data "external" {
    defaults = {
      result = {
        query_id = "99999"
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Test: Query URL Format
# -----------------------------------------------------------------------------
run "query_url_format" {
  command = plan

  variables {
    team         = "test-team"
    dune_api_key = "test-api-key"

    queries = {
      my_query = {
        name = "My Query"
        sql  = "SELECT 1"
      }
    }
  }

  # Verify URL format
  assert {
    condition     = can(regex("^https://dune\\.com/queries/\\d+$", output.query_urls["my_query"]))
    error_message = "Query URL should be in format https://dune.com/queries/{id}"
  }
}

# -----------------------------------------------------------------------------
# Test: Materialized View Full Name Format
# -----------------------------------------------------------------------------
run "matview_name_format" {
  command = plan

  variables {
    team         = "analytics-team"
    dune_api_key = "test-api-key"

    queries = {
      stats = {
        name = "Stats"
        sql  = "SELECT count(*) FROM events"
      }
    }

    materialized_views = {
      result_stats = {
        query_key = "stats"
        cron      = "0 0 * * *"
      }
    }
  }

  # Verify mat view name format: dune.{team}.{name}
  assert {
    condition     = output.materialized_view_names["result_stats"] == "dune.analytics-team.result_stats"
    error_message = "Mat view full name should follow dune.{team}.{name} format"
  }
}

# -----------------------------------------------------------------------------
# Test: State Export Structure
# -----------------------------------------------------------------------------
run "state_export_structure" {
  command = plan

  variables {
    team         = "export-team"
    dune_api_key = "test-api-key"
    query_folder = "TestFolder"

    queries = {
      export_query = {
        name = "Export Query"
        sql  = "SELECT * FROM test"
      }
    }

    materialized_views = {
      result_export = {
        query_key   = "export_query"
        cron        = "0 */2 * * *"
        performance = "large"
      }
    }
  }

  # Verify state export has correct structure
  assert {
    condition     = output.state_export.version == "1.0"
    error_message = "State export version should be 1.0"
  }

  assert {
    condition     = output.state_export.team == "export-team"
    error_message = "State export team should match input"
  }

  # Verify queries section exists
  assert {
    condition     = can(output.state_export.queries["export_query"])
    error_message = "State export should contain query data"
  }

  # Verify materialized_views section exists
  assert {
    condition     = can(output.state_export.materialized_views["result_export"])
    error_message = "State export should contain mat view data"
  }
}

# -----------------------------------------------------------------------------
# Test: Empty Queries Output
# -----------------------------------------------------------------------------
run "empty_queries" {
  command = plan

  variables {
    team         = "test-team"
    dune_api_key = "test-api-key"
    queries      = {}
  }

  # Verify empty maps are returned
  assert {
    condition     = length(output.query_ids) == 0
    error_message = "query_ids should be empty when no queries defined"
  }

  assert {
    condition     = length(output.query_names) == 0
    error_message = "query_names should be empty when no queries defined"
  }

  assert {
    condition     = length(output.query_urls) == 0
    error_message = "query_urls should be empty when no queries defined"
  }

  assert {
    condition     = length(output.query_hashes) == 0
    error_message = "query_hashes should be empty when no queries defined"
  }
}

# -----------------------------------------------------------------------------
# Test: Empty Materialized Views Output
# -----------------------------------------------------------------------------
run "empty_matviews" {
  command = plan

  variables {
    team               = "test-team"
    dune_api_key       = "test-api-key"
    queries            = {}
    materialized_views = {}
  }

  assert {
    condition     = length(output.materialized_view_names) == 0
    error_message = "materialized_view_names should be empty when no mat views defined"
  }
}

# -----------------------------------------------------------------------------
# Test: Query Hash Consistency
# -----------------------------------------------------------------------------
run "hash_consistency" {
  command = plan

  variables {
    team         = "test-team"
    dune_api_key = "test-api-key"

    queries = {
      query_1 = {
        name = "Query 1"
        sql  = "SELECT id, name FROM users WHERE active = true"
      }
      query_2 = {
        name = "Query 2"
        sql  = "SELECT id, name FROM users WHERE active = true" # Same SQL
      }
    }
  }

  # Same SQL content should produce same hash
  assert {
    condition     = output.query_hashes["query_1"] == output.query_hashes["query_2"]
    error_message = "Identical SQL should produce identical hashes"
  }
}

# -----------------------------------------------------------------------------
# Test: Materialized View Query IDs Output
# -----------------------------------------------------------------------------
run "matview_query_ids_output" {
  command = plan

  variables {
    team         = "test-team"
    dune_api_key = "test-api-key"

    queries = {
      base_query = {
        name = "Base Query"
        sql  = "SELECT 1"
      }
    }

    materialized_views = {
      result_base = {
        query_key = "base_query"
        cron      = "0 0 * * *"
      }
    }
  }

  # Verify mat view query IDs are output
  assert {
    condition     = can(output.materialized_view_query_ids["result_base"])
    error_message = "Materialized view query IDs should be accessible"
  }
}

# -----------------------------------------------------------------------------
# Test: State Export Query Folder
# -----------------------------------------------------------------------------
run "state_export_query_folder" {
  command = plan

  variables {
    team         = "test-team"
    dune_api_key = "test-api-key"
    query_folder = "MyFolder"

    queries = {
      test = {
        name = "Test"
        sql  = "SELECT 1"
      }
    }
  }

  # Verify query folder is included in state export
  assert {
    condition     = output.state_export.queries["test"].folder == "MyFolder"
    error_message = "State export should include query folder"
  }
}

# -----------------------------------------------------------------------------
# Test: State Export Mat View Cron
# -----------------------------------------------------------------------------
run "state_export_matview_cron" {
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

    materialized_views = {
      result_test = {
        query_key = "test"
        cron      = "0 */6 * * *"
      }
    }
  }

  # Verify cron expression is included in state export
  assert {
    condition     = output.state_export.materialized_views["result_test"].cron_expression == "0 */6 * * *"
    error_message = "State export should include mat view cron expression"
  }
}
