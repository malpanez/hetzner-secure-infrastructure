.PHONY: help test test-terraform test-ansible test-molecule clean install-deps deploy validate

# Colors for output
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
WHITE  := $(shell tput -Txterm setaf 7)
CYAN   := $(shell tput -Txterm setaf 6)
RED    := $(shell tput -Txterm setaf 1)
RESET  := $(shell tput -Txterm sgr0)

# Project variables
PROJECT_NAME := hetzner-secure-infrastructure
TERRAFORM_DIR := terraform/environments/production
ANSIBLE_DIR := ansible
DOCS_DIR := docs

## Help
help: ## Show this help
	@echo ''
	@echo '${CYAN}${PROJECT_NAME}${RESET}'
	@echo ''
	@echo 'Usage:'
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} { \
		if (/^[a-zA-Z_-]+:.*?##.*$$/) {printf "  ${YELLOW}%-25s${GREEN}%s${RESET}\n", $$1, $$2} \
		else if (/^## .*$$/) {printf "\n  ${CYAN}%s${RESET}\n", substr($$1,4)} \
		}' $(MAKEFILE_LIST)

## Testing
test: test-terraform test-ansible ## Run all tests

test-terraform: ## Run Terratest (infrastructure tests)
	@echo "${GREEN}Running Terratest...${RESET}"
	cd terraform/test && go test -v -timeout 30m

test-terraform-short: ## Run Terratest (short mode - single server only)
	@echo "${GREEN}Running Terratest (short mode)...${RESET}"
	cd terraform/test && go test -v -timeout 15m -short

test-ansible: ## Run all Ansible tests (syntax + molecule)
	@echo "${GREEN}Running Ansible tests...${RESET}"
	$(MAKE) test-ansible-syntax
	$(MAKE) test-molecule

test-ansible-syntax: ## Check Ansible playbook syntax
	@echo "${GREEN}Checking Ansible syntax...${RESET}"
	cd ansible && ansible-playbook playbooks/site.yml --syntax-check

test-molecule: ## Run Molecule tests for all roles
	@echo "${GREEN}Running Molecule tests for all roles...${RESET}"
	@cd ansible/roles && \
	for role in */; do \
		if [ -d "$$role/molecule" ]; then \
			echo "${YELLOW}Testing role: $$role${RESET}"; \
			(cd "$$role" && molecule test) || exit 1; \
		fi; \
	done

test-molecule-role: ## Run Molecule test for specific role (usage: make test-molecule-role ROLE=nginx-wordpress)
	@if [ -z "$(ROLE)" ]; then \
		echo "${YELLOW}Usage: make test-molecule-role ROLE=<role-name>${RESET}"; \
		exit 1; \
	fi
	@echo "${GREEN}Testing role: $(ROLE)${RESET}"
	cd ansible/roles/$(ROLE) && molecule test

## Deployment
deploy: ## Deploy infrastructure (Terraform + Ansible)
	@echo "${GREEN}Deploying infrastructure...${RESET}"
	./scripts/deploy.sh

deploy-terraform: ## Provision infrastructure with Terraform only
	@echo "${GREEN}Provisioning with Terraform...${RESET}"
	cd terraform/environments/production && terraform init && terraform apply

deploy-ansible: ## Configure servers with Ansible only
	@echo "${GREEN}Configuring with Ansible...${RESET}"
	cd ansible && ansible-playbook -i inventory/hetzner.yml playbooks/site.yml --ask-vault-pass

## Validation
validate: validate-terraform validate-ansible ## Validate all configurations

validate-terraform: ## Validate Terraform configuration
	@echo "${GREEN}Validating Terraform...${RESET}"
	cd terraform/environments/production && terraform fmt -check && terraform validate

validate-ansible: ## Validate Ansible configuration
	@echo "${GREEN}Validating Ansible...${RESET}"
	cd ansible && ansible-playbook playbooks/site.yml --syntax-check
	cd ansible && ansible-lint playbooks/site.yml || true

## Cleanup
clean: ## Clean up test artifacts
	@echo "${GREEN}Cleaning up...${RESET}"
	find . -type d -name ".molecule" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.retry" -delete 2>/dev/null || true
	cd terraform/test && go clean || true

## Prerequisites
install-deps: ## Install testing dependencies
	@echo "${GREEN}Installing dependencies...${RESET}"
	@echo "${YELLOW}Installing Go dependencies...${RESET}"
	cd terraform/test && go mod download
	@echo "${YELLOW}Installing Python dependencies...${RESET}"
	pip3 install --user -r requirements-dev.txt
	@echo "${YELLOW}Installing Ansible collections...${RESET}"
	cd ansible && ansible-galaxy collection install -r requirements.yml
	@echo "${YELLOW}Installing pre-commit hooks...${RESET}"
	pre-commit install --install-hooks
	pre-commit install --hook-type commit-msg
	@echo "${GREEN}✓ Dependencies installed${RESET}"

check-env: ## Check required environment variables
	@echo "${GREEN}Checking environment variables...${RESET}"
	@test -n "$(HCLOUD_TOKEN)" || (echo "${RED}Error: HCLOUD_TOKEN not set${RESET}" && exit 1)
	@echo "${GREEN}✓ Environment OK${RESET}"

## Quality & Security
lint: lint-terraform lint-ansible lint-yaml ## Run all linters

lint-terraform: ## Lint Terraform with tflint
	@echo "${GREEN}Running Terraform linters...${RESET}"
	@echo "${YELLOW}Formatting check...${RESET}"
	cd terraform && terraform fmt -check -recursive
	@echo "${YELLOW}Running tflint...${RESET}"
	cd terraform && tflint --init && tflint --format compact
	@echo "${GREEN}✓ Terraform linting complete${RESET}"

lint-ansible: ## Lint Ansible with ansible-lint
	@echo "${GREEN}Running Ansible linters...${RESET}"
	cd $(ANSIBLE_DIR) && ansible-lint --force-color playbooks/site.yml
	@echo "${GREEN}✓ Ansible linting complete${RESET}"

lint-yaml: ## Lint YAML files
	@echo "${GREEN}Running YAML linter...${RESET}"
	yamllint -c .yamllint.yml . || true
	@echo "${GREEN}✓ YAML linting complete${RESET}"

format: ## Auto-format all code
	@echo "${GREEN}Formatting code...${RESET}"
	cd terraform && terraform fmt -recursive
	@echo "${GREEN}✓ Formatting complete${RESET}"

security-scan: ## Run security scans
	@echo "${GREEN}Running security scans...${RESET}"
	@echo "${YELLOW}Scanning Terraform with tfsec...${RESET}"
	tfsec terraform/ --minimum-severity MEDIUM || true
	@echo "${YELLOW}Scanning for secrets...${RESET}"
	gitleaks detect --source . --verbose || true
	@echo "${GREEN}✓ Security scan complete${RESET}"

pre-commit: ## Run pre-commit hooks on all files
	@echo "${GREEN}Running pre-commit hooks...${RESET}"
	pre-commit run --all-files

## Monitoring & Health
health-check: ## Check infrastructure health
	@echo "${GREEN}Running health checks...${RESET}"
	cd $(ANSIBLE_DIR) && ansible all -i inventory/hetzner.yml -m ping
	@echo "${GREEN}✓ Health check complete${RESET}"

logs: ## Show recent logs from monitoring
	@echo "${GREEN}Fetching logs...${RESET}"
	cd $(ANSIBLE_DIR) && ansible all -i inventory/hetzner.yml -m shell -a "journalctl -n 50"

## Backup & Recovery
backup: ## Create backup of all data
	@echo "${GREEN}Creating backup...${RESET}"
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/hetzner.yml playbooks/backup.yml

restore: ## Restore from backup
	@echo "${YELLOW}⚠️  This will restore from backup${RESET}"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/hetzner.yml playbooks/restore.yml; \
	fi

## Documentation
docs-serve: ## Serve documentation locally
	@echo "${GREEN}Serving documentation...${RESET}"
	@command -v mkdocs >/dev/null 2>&1 || pip3 install --user mkdocs-material
	mkdocs serve

docs-build: ## Build documentation
	@echo "${GREEN}Building documentation...${RESET}"
	@command -v mkdocs >/dev/null 2>&1 || pip3 install --user mkdocs-material
	mkdocs build

## Maintenance
update: ## Update all dependencies
	@echo "${GREEN}Updating dependencies...${RESET}"
	pre-commit autoupdate
	cd $(ANSIBLE_DIR) && ansible-galaxy collection install -r requirements.yml --force
	cd terraform/test && go get -u ./...
	@echo "${GREEN}✓ Dependencies updated${RESET}"

upgrade-servers: ## Upgrade all servers
	@echo "${YELLOW}⚠️  This will upgrade all packages on servers${RESET}"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/hetzner.yml playbooks/upgrade.yml; \
	fi

## CI/CD
ci: validate lint test ## Run full CI pipeline (validate + lint + test)
	@echo "${GREEN}✓ CI pipeline completed successfully${RESET}"

ci-fast: validate lint test-terraform-short ## Run fast CI pipeline (skip molecule tests)
	@echo "${GREEN}✓ Fast CI pipeline completed${RESET}"

## Status & Info
status: ## Show project status
	@echo "${CYAN}=== Project Status ===${RESET}"
	@echo ""
	@echo "${YELLOW}Git:${RESET}"
	@git status -s || echo "${RED}Not a git repository${RESET}"
	@echo ""
	@echo "${YELLOW}Terraform:${RESET}"
	@cd $(TERRAFORM_DIR) && terraform version 2>/dev/null || echo "${RED}Terraform not installed${RESET}"
	@echo ""
	@echo "${YELLOW}Ansible:${RESET}"
	@ansible --version 2>/dev/null | head -n1 || echo "${RED}Ansible not installed${RESET}"
	@echo ""
	@echo "${YELLOW}Pre-commit:${RESET}"
	@pre-commit --version 2>/dev/null || echo "${RED}Pre-commit not installed${RESET}"

version: ## Show all tool versions
	@echo "${CYAN}=== Tool Versions ===${RESET}"
	@echo "${YELLOW}Terraform:${RESET} $$(terraform version -json 2>/dev/null | jq -r '.terraform_version' || echo 'Not installed')"
	@echo "${YELLOW}Ansible:${RESET} $$(ansible --version 2>/dev/null | head -n1 | awk '{print $$2}' || echo 'Not installed')"
	@echo "${YELLOW}Python:${RESET} $$(python3 --version 2>/dev/null | awk '{print $$2}' || echo 'Not installed')"
	@echo "${YELLOW}Go:${RESET} $$(go version 2>/dev/null | awk '{print $$3}' || echo 'Not installed')"
	@echo "${YELLOW}Docker:${RESET} $$(docker --version 2>/dev/null | awk '{print $$3}' | tr -d ',' || echo 'Not installed')"

.DEFAULT_GOAL := help
