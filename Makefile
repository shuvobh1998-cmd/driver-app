# Driver app — common dev tasks. Run `make help` for the list.
.DEFAULT_GOAL := help
.PHONY: help bootstrap models l10n codegen watch analyze format test run-dev run-staging run-prod apk clean

help: ## Show this help.
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Install deps + run all codegen (first-time setup).
	flutter pub get
	$(MAKE) codegen

models: ## Generate OpenAPI DTOs/clients from api/openapi.yaml into lib/gen.
	dart run swagger_parser

l10n: ## Generate the AppLocalizations delegate from lib/l10n/*.arb.
	flutter gen-l10n

codegen: models ## Run every generator: models -> build_runner -> l10n.
	dart run build_runner build --delete-conflicting-outputs
	$(MAKE) l10n

watch: ## Re-run build_runner on change.
	dart run build_runner watch --delete-conflicting-outputs

analyze: ## Static analysis (must be clean).
	flutter analyze

format: ## Format all Dart sources.
	dart format lib test

test: ## Run the unit/widget test suite.
	flutter test

run-dev: ## Run the dev flavor.
	flutter run --flavor dev -t lib/main_dev.dart --dart-define=ENV=dev

run-staging: ## Run the staging flavor.
	flutter run --flavor staging -t lib/main_staging.dart --dart-define=ENV=staging

run-prod: ## Run the prod flavor.
	flutter run --flavor prod -t lib/main_prod.dart --dart-define=ENV=prod

apk: ## Build the dev debug APK.
	flutter build apk --debug --flavor dev -t lib/main_dev.dart

clean: ## Remove build + generated outputs.
	flutter clean
	rm -rf lib/gen lib/l10n/gen
