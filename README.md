# Dune Terraform Module

[![Terraform Registry](https://img.shields.io/badge/Terraform-Registry-purple.svg)](https://registry.terraform.io/modules/deacix/manager/dune/latest)
[![Test](https://github.com/deacix/terraform-dune-manager/actions/workflows/test.yml/badge.svg)](https://github.com/deacix/terraform-dune-manager/actions/workflows/test.yml)
[![Release](https://github.com/deacix/terraform-dune-manager/actions/workflows/release.yml/badge.svg)](https://github.com/deacix/terraform-dune-manager/actions/workflows/release.yml)

Terraform module for managing Dune Analytics queries and materialized views.

## Overview

This module provides infrastructure-as-code for Dune Analytics resources. Since there's no official Dune Terraform provider, the module uses the REST API directly via shell scripts.

## Structure

```
terraform-dune-manager/
├── main.tf                # Main resource definitions
├── variables.tf           # Input variables
├── outputs.tf             # Output definitions
├── locals.tf              # Local computed values
├── versions.tf            # Provider version constraints
├── scripts/               # API helper scripts
├── tests/                 # Terraform native tests
├── examples/
│   └── simple/            # Simple standalone example
├── Makefile               # Convenience commands
└── README.md              # This file
```

## Quick Start

```bash
# 1. Set your Dune API key
export DUNE_API_KEY="your-api-key"

# 2. Initialize Terraform
make init

# 3. Preview changes
make plan

# 4. Apply changes
make apply
```

## Available Commands

| Command | Description |
|---------|-------------|
| `make init` | Initialize Terraform working directory |
| `make validate` | Validate Terraform configuration |
| `make fmt` | Format Terraform files |
| `make plan` | Preview infrastructure changes |
| `make apply` | Apply infrastructure changes |
| `make destroy` | Destroy all infrastructure |
| `make clean` | Clean up temporary files |
| `make test` | Run module tests |
| `make outputs` | Show Terraform outputs |
| `make state` | List resources in state |

## Module Features

This module provides:

### Query Management
- Create, update, and archive queries
- Unarchive queries for disaster recovery
- Control query visibility (private/public)
- SQL hash-based drift detection

### Materialized Views
- Full lifecycle management (create, update, delete)
- Configurable refresh schedules (cron expressions)
- Performance tier selection (medium/large)

### Data Discovery (Optional)
- List available datasets for schema exploration
- List existing materialized views for state reconciliation
- Monitor API usage and billing data

## Usage Example

### From Terraform Registry

```hcl
module "dune" {
  source  = "deacix/manager/dune"
  version = "~> 1.0"

  team         = "my-team"
  dune_api_key = var.dune_api_key
  query_prefix = "[Dashboard]"
  is_private   = true

  queries = {
    revenue_daily = {
      name = "Revenue Daily Totals"
      sql  = <<-SQL
        SELECT date_trunc('day', block_time) as date,
               sum(amount_usd) as revenue
        FROM dex.trades
        GROUP BY 1
      SQL
    }
  }

  materialized_views = {
    result_revenue_daily = {
      query_key = "revenue_daily"
      cron      = "0 */1 * * *"  # Every hour
    }
  }

  # Optional: Enable data discovery
  enable_usage_monitoring   = true
  enable_dataset_discovery  = true
  enable_matview_discovery  = true
}
```

### From GitHub

```hcl
module "dune" {
  source = "github.com/deacix/terraform-dune-manager?ref=v1.0.0"

  team         = "my-team"
  dune_api_key = var.dune_api_key
  # ...
}
```

## API Endpoints Implemented

### Query Management
| Endpoint | Method | Script |
|----------|--------|--------|
| `/v1/query` | POST | `create_query.sh` |
| `/v1/query/{id}` | PATCH | `update_query.sh` |
| `/v1/query/{id}` | GET | `get_query.sh` |
| `/v1/query/{id}/archive` | POST | `archive_query.sh` |
| `/v1/query/{id}/unarchive` | POST | `unarchive_query.sh` |
| `/v1/query/{id}/private` | POST | `private_query.sh` |
| `/v1/query/{id}/unprivate` | POST | `unprivate_query.sh` |

### Materialized Views
| Endpoint | Method | Script |
|----------|--------|--------|
| `/v1/materialized-views` | POST | `create_matview.sh` |
| `/v1/materialized-views` | GET | `list_matviews.sh` |
| `/v1/materialized-views/{name}` | GET | `get_matview.sh` |
| `/v1/materialized-views/{name}` | DELETE | `delete_matview.sh` |
| `/v1/materialized-views/{name}/refresh` | POST | `refresh_matview.sh` |

### Data Sources
| Endpoint | Method | Script |
|----------|--------|--------|
| `/v1/datasets` | GET | `list_datasets.sh` |
| `/v1/datasets/{ns}/{name}` | GET | `get_dataset.sh` |
| `/v1/usage` | POST | `get_usage.sh` |

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DUNE_API_KEY` | Dune Analytics API key | Yes |
| `TF_VAR_dune_api_key` | Alternative way to pass API key to Terraform | No |

## Remote State (Recommended for Teams)

For team collaboration, configure a remote backend:

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "dune/terraform.tfstate"
    region = "us-east-1"
  }
}
```

## Import Existing Resources

If you have queries deployed via other tools:

```bash
# Import a query by its Dune ID
make import KEY=revenue_daily_totals ID=6612997
```

## Testing

The module includes comprehensive tests using Terraform's native testing framework:

```bash
# Run all tests
make test

# Run tests directly
terraform test
```

### Test Coverage

| Test File | Tests | Description |
|-----------|-------|-------------|
| `unit.tftest.hcl` | 9 | Core module functionality |
| `validation.tftest.hcl` | 8 | Input validation |
| `outputs.tftest.hcl` | 6 | Output format verification |

## Comparison: Terraform vs Python Tool

| Feature | Python Tool (`dune/`) | Terraform Module |
|---------|----------------------|------------------|
| State Format | YAML (`state.yaml`) | Terraform state |
| Language | Python | HCL |
| Change Detection | SQL hash comparison | Terraform plan |
| Rollback | Manual | `terraform destroy` |
| CI/CD Integration | Custom scripts | Standard Terraform |
| Remote State | Git + state file | S3, GCS, Azure, etc. |
| Mat View Delete | Not supported | Supported |

## Requirements

- Terraform >= 1.0
- `jq` command-line tool
- `curl` command-line tool
- Dune API key with write permissions (Analyst plan or higher)

## CI/CD

This project uses GitHub Actions for continuous integration and releases following the **git flow** branching model.

### Branching Strategy (Git Flow)

| Branch | Purpose |
|--------|---------|
| `main` | Production releases (protected, tagged) |
| `develop` | Integration branch for features |
| `feature/*` | New features (PR to develop) |
| `release/*` | Release preparation (PR to main) |
| `hotfix/*` | Emergency fixes (PR to main) |

### Workflows

#### Test Workflow (`.github/workflows/test.yml`)

Runs on every push and PR to `main` and `develop`:

- **Format Check**: Ensures consistent code formatting
- **Validate**: Validates Terraform configuration
- **Test**: Runs all module tests
- **Security**: Scans for security issues with tfsec
- **Docs**: Verifies documentation exists

#### Release Workflow (`.github/workflows/release.yml`)

Handles releases when merging to `main`:

1. Validates release/hotfix PRs to main
2. Automatically calculates semantic version from commits
3. Creates git tag and GitHub release
4. Generates changelog from commit history

### Version Bumping

Version is calculated automatically based on commit message prefixes:

| Prefix | Version Bump | Example |
|--------|--------------|---------|
| `breaking:` or `major:` | Major (1.0.0 → 2.0.0) | Breaking API change |
| `feat:` or `feature:` | Minor (1.0.0 → 1.1.0) | New feature |
| (other) | Patch (1.0.0 → 1.0.1) | Bug fixes |

### Development Workflow

```bash
# 1. Create feature branch from develop
git checkout develop
git pull origin develop
git checkout -b feature/my-feature

# 2. Make changes and commit
git add .
git commit -m "feat: add new query type"

# 3. Push and create PR to develop
git push -u origin feature/my-feature
# Create PR: feature/my-feature → develop

# 4. After PR approval and merge, create release
git checkout develop
git pull origin develop
git checkout -b release/v1.2.0

# 5. PR release branch to main
git push -u origin release/v1.2.0
# Create PR: release/v1.2.0 → main

# 6. Merge triggers automatic release
```

### Hotfix Workflow

```bash
# 1. Create hotfix from main
git checkout main
git pull origin main
git checkout -b hotfix/critical-fix

# 2. Fix and commit
git commit -m "fix: critical bug in query creation"

# 3. PR to main (and backport to develop)
git push -u origin hotfix/critical-fix
```

## Related Documentation

- [Terraform Registry](https://registry.terraform.io/modules/deacix/manager/dune/latest)
- [Simple Example](examples/simple/README.md)
- [Dune API Reference](https://docs.dune.com/api-reference)
- [Terraform Module Development](https://developer.hashicorp.com/terraform/language/modules/develop)

## Drift Detection

The module includes automatic drift detection for materialized views. During `terraform plan`, it checks if the actual Dune configuration matches the expected Terraform configuration.

### What It Detects

- **Missing cron schedule**: Mat view exists but has no cron_schedule configured
- **Cron mismatch**: Mat view has a different cron_schedule than expected
- **Query ID mismatch**: Mat view is linked to a different query than expected

### How It Works

1. During `terraform plan`, the `verify_matview.sh` script queries the Dune API for each mat view
2. It compares actual values against expected Terraform configuration
3. Results are shown in the `matview_drift_status` output
4. If drift is detected, `terraform apply` will re-apply the correct configuration

### Example Output

```hcl
# terraform plan output when drift is detected:
matview_drift_status = {
  "result_1inch_live_overview" = {
    actual_cron = "null"
    message     = "DRIFT: cron_schedule is null but expected '0 * * * *'"
    status      = "drift"
  }
}
has_matview_drift = true
```

### Fixing Drift

Simply run `terraform apply` - the module will automatically re-apply the correct configuration to any mat views with drift.

```bash
terraform apply
```

### Manual Verification

You can also run the verification script directly:

```bash
export DUNE_API_KEY="your-api-key"
echo '{"name":"dune.your-team.your_matview","expected_cron":"0 * * * *","expected_query_id":"123456"}' | ./scripts/verify_matview.sh
```
