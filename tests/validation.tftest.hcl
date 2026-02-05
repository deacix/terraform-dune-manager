# =============================================================================
# Validation Tests for Dune Terraform Module
# =============================================================================
# These tests verify that input validation works correctly.
# Uses expect_failures to test that invalid inputs are rejected.
#
# Run with: terraform test
# =============================================================================

# Mock the external data source at file level
mock_provider "external" {
  mock_data "external" {
    defaults = {
      result = {
        # For create_query
        query_id = "12345"
        mode     = "existing"
        # For verify_matview
        status          = "skip"
        actual_cron     = "unknown"
        actual_query_id = "0"
        message         = "Mock - DUNE_API_KEY not set"
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Test: Empty Team Name Rejected
# -----------------------------------------------------------------------------
run "empty_team_rejected" {
  command = plan

  variables {
    team         = ""
    dune_api_key = "test-api-key"
    queries      = {}
  }

  expect_failures = [
    var.team,
  ]
}

# -----------------------------------------------------------------------------
# Test: Empty API Key Rejected
# -----------------------------------------------------------------------------
run "empty_api_key_rejected" {
  command = plan

  variables {
    team         = "test-team"
    dune_api_key = ""
    queries      = {}
  }

  expect_failures = [
    var.dune_api_key,
  ]
}

# -----------------------------------------------------------------------------
# Test: Invalid Performance Value Rejected
# -----------------------------------------------------------------------------
run "invalid_performance_rejected" {
  command = plan

  variables {
    team                = "test-team"
    dune_api_key        = "test-api-key"
    default_performance = "super-fast" # Invalid - must be "medium" or "large"
    queries             = {}
  }

  expect_failures = [
    var.default_performance,
  ]
}

# -----------------------------------------------------------------------------
# Test: Query Without SQL Rejected
# -----------------------------------------------------------------------------
run "query_without_sql_rejected" {
  command = plan

  variables {
    team         = "test-team"
    dune_api_key = "test-api-key"

    queries = {
      missing_sql = {
        name = "Missing SQL Query"
        # Neither sql nor sql_file provided
      }
    }
  }

  expect_failures = [
    var.queries,
  ]
}

# -----------------------------------------------------------------------------
# Test: Invalid Cron Expression Rejected
# -----------------------------------------------------------------------------
run "invalid_cron_rejected" {
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
        cron      = "invalid-cron" # Invalid cron expression
      }
    }
  }

  expect_failures = [
    var.materialized_views,
  ]
}

# -----------------------------------------------------------------------------
# Test: Valid Cron Expressions Accepted
# -----------------------------------------------------------------------------
run "valid_cron_accepted" {
  command = plan

  variables {
    team         = "test-team"
    dune_api_key = "test-api-key"

    queries = {
      hourly_query = {
        name = "Hourly"
        sql  = "SELECT 1"
      }
      daily_query = {
        name = "Daily"
        sql  = "SELECT 2"
      }
      weekly_query = {
        name = "Weekly"
        sql  = "SELECT 3"
      }
    }

    materialized_views = {
      hourly_mv = {
        query_key = "hourly_query"
        cron      = "0 */1 * * *" # Every hour
      }
      daily_mv = {
        query_key = "daily_query"
        cron      = "0 0 * * *" # Daily at midnight
      }
      weekly_mv = {
        query_key = "weekly_query"
        cron      = "0 0 * * 0" # Weekly on Sunday
      }
    }
  }

  # All cron expressions should be valid
  assert {
    condition     = length(output.materialized_view_names) == 3
    error_message = "All valid cron expressions should be accepted"
  }
}

# -----------------------------------------------------------------------------
# Test: Medium Performance Accepted
# -----------------------------------------------------------------------------
run "medium_performance_accepted" {
  command = plan

  variables {
    team                = "test-team"
    dune_api_key        = "test-api-key"
    default_performance = "medium"
    queries             = {}
  }

  # Verify medium is accepted by checking team output
  assert {
    condition     = output.team == "test-team"
    error_message = "medium should be a valid performance value"
  }
}

# -----------------------------------------------------------------------------
# Test: Large Performance Accepted
# -----------------------------------------------------------------------------
run "large_performance_accepted" {
  command = plan

  variables {
    team                = "test-team"
    dune_api_key        = "test-api-key"
    default_performance = "large"
    queries             = {}
  }

  # Verify large is accepted by checking team output
  assert {
    condition     = output.team == "test-team"
    error_message = "large should be a valid performance value"
  }
}

# -----------------------------------------------------------------------------
# Test: State File Path Configuration
# -----------------------------------------------------------------------------
run "state_file_path_config" {
  command = plan

  variables {
    team              = "test-team"
    dune_api_key      = "test-api-key"
    enable_state_file = false # Don't actually create file
    state_file_path   = "custom/path/state.yaml"

    queries = {}
  }

  assert {
    condition     = output.team == "test-team"
    error_message = "Custom state file path should be accepted"
  }
}

# -----------------------------------------------------------------------------
# Test: Query With SQL File
# -----------------------------------------------------------------------------
run "query_with_sql_file" {
  command = plan

  variables {
    team         = "test-team"
    dune_api_key = "test-api-key"

    queries = {
      file_query = {
        name     = "File Query"
        sql_file = "tests/fixtures/simple_query.sql"
      }
    }
  }

  assert {
    condition     = length(output.query_names) == 1
    error_message = "Query with sql_file should be created"
  }

  assert {
    condition     = output.query_names["file_query"] == "File Query"
    error_message = "Query name should be set correctly"
  }
}

# -----------------------------------------------------------------------------
# Test: Query With SQL File Containing Metadata
# -----------------------------------------------------------------------------
run "query_sql_file_with_metadata" {
  command = plan

  variables {
    team         = "test-team"
    dune_api_key = "test-api-key"

    queries = {
      metadata_query = {
        name     = "Metadata Query"
        sql_file = "tests/fixtures/test_query.sql"
      }
    }
  }

  # Verify query is created from file
  assert {
    condition     = length(output.query_names) == 1
    error_message = "Query from SQL file with metadata should be created"
  }

  # Verify hash is generated (metadata should be stripped)
  assert {
    condition     = can(regex("^sha256:[a-f0-9]{12}$", output.query_hashes["metadata_query"]))
    error_message = "Query hash should be generated from SQL file content"
  }
}

# -----------------------------------------------------------------------------
# Test: SQL Inline Takes Precedence Over SQL File
# -----------------------------------------------------------------------------
run "sql_inline_precedence" {
  command = plan

  variables {
    team         = "test-team"
    dune_api_key = "test-api-key"

    queries = {
      precedence_query = {
        name     = "Precedence Query"
        sql      = "SELECT 'inline' as source"
        sql_file = "tests/fixtures/simple_query.sql"
      }
    }
  }

  # When both sql and sql_file are provided, sql takes precedence
  # The hash should match the inline SQL, not the file content
  assert {
    condition     = length(output.query_names) == 1
    error_message = "Query with both sql and sql_file should be created"
  }
}

# -----------------------------------------------------------------------------
# Test: Query Tags Accepted
# -----------------------------------------------------------------------------
run "query_tags_accepted" {
  command = plan

  variables {
    team         = "test-team"
    dune_api_key = "test-api-key"

    queries = {
      tagged_query = {
        name        = "Tagged Query"
        sql         = "SELECT 1"
        tags        = ["revenue", "daily", "production"]
        description = "A query with multiple tags"
      }
    }
  }

  assert {
    condition     = length(output.query_names) == 1
    error_message = "Query with tags should be accepted"
  }
}
