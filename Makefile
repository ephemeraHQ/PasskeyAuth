.PHONY: help
help: ## Print help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' \
	$(MAKEFILE_LIST) | sort

.PHONY: secrets
secrets: ## Generate Secrets.swift from .env
	./Scripts/generate_secrets.sh

.PHONY: entitlements
entitlements: ## Generate entitlements file from .env
	./Scripts/generate_entitlements.sh

.PHONY: generate
generate: secrets entitlements ## Generate all configuration files