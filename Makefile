# =============================================================================
# Terraform Makefile for Dune Infrastructure
# =============================================================================
# Provides convenient commands for managing Terraform deployments.
#
# Usage:
#   make init      - Initialize Terraform
#   make plan      - Preview changes
#   make apply     - Apply changes
#   make destroy   - Destroy resources
#
# Note: Set DUNE_API_KEY environment variable before running commands.

.PHONY: help init plan apply destroy validate fmt clean test

# Default target
help:
	@echo "Terraform Dune Infrastructure Commands"
	@echo ""
	@echo "Usage:"
	@echo "  make init       Initialize Terraform working directory"
	@echo "  make validate   Validate Terraform configuration"
	@echo "  make fmt        Format Terraform files"
	@echo "  make plan       Preview infrastructure changes"
	@echo "  make apply      Apply infrastructure changes"
	@echo "  make destroy    Destroy all infrastructure"
	@echo "  make clean      Clean up temporary files"
	@echo "  make test       Run module tests"
	@echo ""
	@echo "Environment:"
	@echo "  DUNE_API_KEY    Required - Your Dune API key"
	@echo "  TF_VAR_dune_api_key  Alternative way to set API key"
	@echo ""
	@echo "Examples:"
	@echo "  DUNE_API_KEY=xxx make plan"
	@echo "  DUNE_API_KEY=xxx make apply"

# Directory for the example deployment
EXAMPLE_DIR := examples/simple

# Check for API key
check-api-key:
ifndef DUNE_API_KEY
ifndef TF_VAR_dune_api_key
	$(error DUNE_API_KEY or TF_VAR_dune_api_key must be set)
endif
endif

# Initialize Terraform
init:
	cd $(EXAMPLE_DIR) && terraform init

# Validate configuration
validate: init
	cd $(EXAMPLE_DIR) && terraform validate

# Format Terraform files
fmt:
	terraform fmt -recursive .

# Preview changes
plan: check-api-key init
	@echo "Planning Terraform changes..."
	cd $(EXAMPLE_DIR) && TF_VAR_dune_api_key="$(DUNE_API_KEY)" terraform plan

# Apply changes
apply: check-api-key init
	@echo "Applying Terraform changes..."
	cd $(EXAMPLE_DIR) && TF_VAR_dune_api_key="$(DUNE_API_KEY)" terraform apply

# Apply without confirmation
apply-auto: check-api-key init
	@echo "Applying Terraform changes (auto-approve)..."
	cd $(EXAMPLE_DIR) && TF_VAR_dune_api_key="$(DUNE_API_KEY)" terraform apply -auto-approve

# Destroy resources
destroy: check-api-key
	@echo "Destroying Terraform resources..."
	cd $(EXAMPLE_DIR) && TF_VAR_dune_api_key="$(DUNE_API_KEY)" terraform destroy

# Clean up
clean:
	rm -rf $(EXAMPLE_DIR)/.terraform
	rm -f $(EXAMPLE_DIR)/.terraform.lock.hcl
	rm -f $(EXAMPLE_DIR)/terraform.tfstate*
	rm -f /tmp/dune_query_*.json

# Show outputs
outputs:
	cd $(EXAMPLE_DIR) && terraform output

# Show state
state:
	cd $(EXAMPLE_DIR) && terraform state list

# Run module tests
test:
	@echo "Running Terraform tests..."
	terraform init -upgrade > /dev/null && terraform test

# Import existing query (usage: make import KEY=revenue_daily_totals ID=6612997)
import: check-api-key
ifndef KEY
	$(error KEY must be set - the query key in your configuration)
endif
ifndef ID
	$(error ID must be set - the existing Dune query ID)
endif
	cd $(EXAMPLE_DIR) && TF_VAR_dune_api_key="$(DUNE_API_KEY)" terraform import \
		'module.dune_dashboard.null_resource.queries["$(KEY)"]' $(ID)
