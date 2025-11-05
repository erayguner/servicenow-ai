.PHONY: help pre-commit pre-commit-terraform pre-commit-python pre-commit-secrets pre-commit-install pre-commit-update terraform-fmt terraform-validate terraform-test clean

# Default target
help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2}'

# Pre-commit targets
pre-commit: ## Run all pre-commit hooks on all files
	@echo "🔍 Running all pre-commit hooks..."
	pre-commit run --all-files

pre-commit-install: ## Install pre-commit hooks
	@echo "📦 Installing pre-commit hooks..."
	pre-commit install
	@echo "✅ Pre-commit hooks installed!"

pre-commit-update: ## Update pre-commit hooks to latest versions
	@echo "⬆️  Updating pre-commit hooks..."
	pre-commit autoupdate
	@echo "✅ Hooks updated! Review changes with: git diff .pre-commit-config.yaml"

pre-commit-terraform: ## Run only Terraform pre-commit hooks
	@echo "🏗️  Running Terraform hooks..."
	pre-commit run terraform_fmt --all-files
	pre-commit run terraform_validate --all-files

pre-commit-python: ## Run only Python pre-commit hooks
	@echo "🐍 Running Python hooks..."
	pre-commit run ruff-check --all-files
	pre-commit run ruff-format --all-files

pre-commit-secrets: ## Run only secrets detection
	@echo "🔐 Scanning for secrets..."
	pre-commit run detect-secrets --all-files

pre-commit-k8s: ## Run only Kubernetes linting
	@echo "☸️  Running Kubernetes linting..."
	pre-commit run kube-linter-system --all-files

pre-commit-fix: ## Run hooks that auto-fix issues
	@echo "🔧 Running auto-fix hooks..."
	pre-commit run trailing-whitespace --all-files
	pre-commit run end-of-file-fixer --all-files
	pre-commit run pretty-format-json --all-files
	pre-commit run terraform_fmt --all-files

# Terraform targets
terraform-fmt: ## Format all Terraform files
	@echo "📝 Formatting Terraform files..."
	@find terraform -name "*.tf" -exec dirname {} \; | sort -u | while read dir; do \
		echo "Formatting $$dir"; \
		terraform fmt "$$dir"; \
	done
	@echo "✅ Terraform files formatted!"

terraform-validate: ## Validate all Terraform modules
	@echo "✅ Validating Terraform modules..."
	@for dir in terraform/modules/*/; do \
		module=$$(basename "$$dir"); \
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
		echo "📦 Validating: $$module"; \
		cd "$$dir" && terraform init -backend=false > /dev/null 2>&1 && terraform validate && cd - > /dev/null || exit 1; \
	done
	@echo "✅ All modules valid!"

terraform-test: ## Run Terraform tests for all modules
	@echo "🧪 Running Terraform tests..."
	@passed=0; failed=0; \
	for dir in terraform/modules/*/tests; do \
		if [ -d "$$dir" ]; then \
			module=$$(basename $$(dirname "$$dir")); \
			echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
			echo "🧪 Testing: $$module"; \
			cd "$$(dirname "$$dir")" && terraform test && passed=$$((passed + 1)) || failed=$$((failed + 1)); \
			cd - > /dev/null; \
		fi; \
	done; \
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
	echo "📊 Results: ✅ $$passed passed, ❌ $$failed failed"; \
	[ $$failed -eq 0 ] || exit 1

terraform-init: ## Initialize all Terraform modules
	@echo "🔧 Initializing Terraform modules..."
	@for dir in terraform/modules/*/; do \
		module=$$(basename "$$dir"); \
		echo "Initializing $$module"; \
		cd "$$dir" && terraform init -backend=false > /dev/null 2>&1 || echo "⚠️  Failed: $$module"; \
		cd - > /dev/null; \
	done
	@echo "✅ Initialization complete!"

# Clean targets
clean: ## Clean Terraform and pre-commit cache
	@echo "🧹 Cleaning caches..."
	@find terraform -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find terraform -type f -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	@pre-commit clean 2>/dev/null || true
	@echo "✅ Caches cleaned!"

clean-terraform: ## Clean only Terraform cache
	@echo "🧹 Cleaning Terraform cache..."
	@find terraform -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find terraform -type f -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	@echo "✅ Terraform cache cleaned!"

# Git helpers
git-pre-commit: pre-commit ## Alias for pre-commit (convenience)

# Quick checks
quick-check: ## Run quick checks (no Terraform validate)
	@echo "⚡ Running quick checks..."
	pre-commit run trailing-whitespace --all-files
	pre-commit run end-of-file-fixer --all-files
	pre-commit run check-yaml --all-files
	pre-commit run check-json --all-files
	pre-commit run terraform_fmt --all-files
	@echo "✅ Quick checks passed!"

# Full CI simulation
ci: ## Simulate full CI pipeline locally
	@echo "🚀 Running full CI simulation..."
	@echo ""
	@echo "Step 1: Pre-commit hooks"
	@$(MAKE) pre-commit
	@echo ""
	@echo "Step 2: Terraform validation"
	@$(MAKE) terraform-validate
	@echo ""
	@echo "Step 3: Terraform tests"
	@$(MAKE) terraform-test
	@echo ""
	@echo "✅ CI simulation complete!"

# Development helpers
dev-setup: pre-commit-install terraform-init ## Setup development environment
	@echo "✅ Development environment ready!"

dev-check: quick-check ## Quick development check before commit
	@echo "✅ Ready to commit!"
