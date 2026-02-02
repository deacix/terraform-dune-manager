# =============================================================================
# Terraform Version Constraints
# =============================================================================
# This module requires Terraform >= 1.0 for modern language features
# including optional() in variable types and improved provider handling.

terraform {
  required_version = ">= 1.0"

  required_providers {
    # HTTP provider for Dune API calls
    # Used because there's no official Dune Terraform provider
    http = {
      source  = "hashicorp/http"
      version = ">= 3.0"
    }

    # Null provider for resource triggers and local execution
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }

    # Local provider for file operations
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }

    # External provider for custom scripts
    external = {
      source  = "hashicorp/external"
      version = ">= 2.0"
    }
  }
}
