# Common commands for this repository. Run `make` or `make help` to list them.
# No target deletes, uninstalls or overwrites anything. Removing a marketplace or a
# plugin is left to you (see docs/release-checklist.md). `tag` pushes a tag, so it is
# run by the Commander, never by Claude Code.

MARKETPLACE := su3-hokkaido-ai-ecosystem
REPO        := su3-hokkaido/su3-claude-code-agents
PLUGINS     := $(notdir $(patsubst %/,%,$(wildcard plugins/*/)))

# Pass the plugin with PLUGIN=<name>, for example: make tag PLUGIN=su3-developer-set
PLUGIN ?=

.DEFAULT_GOAL := help
.PHONY: help validate strict test-hooks check list load \
        local-add local-install tag remote-add remote-install update need-plugin

help: ## Show this help
	@awk 'BEGIN { FS = ":.*## " } /^[a-zA-Z_-]+:.*## / { printf "  %-16s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo
	@echo "Plugins: $(PLUGINS)"

# --- Checks -------------------------------------------------------------------

validate: ## Run scripts/validate.sh (needs jq; also runs claude plugin validate)
	sh scripts/validate.sh

strict: ## Run claude plugin validate . --strict
	claude plugin validate . --strict

test-hooks: ## Run the guard hook tests
	sh scripts/test-hooks.sh

check: validate strict test-hooks ## Run every check before a release

list: ## List the plugins and their versions
	@for p in $(PLUGINS); do \
	  printf '%-40s %s\n' "$$p" "$$(jq -r .version plugins/$$p/.claude-plugin/plugin.json)"; \
	done

# --- Local testing ------------------------------------------------------------

load: need-plugin ## Load one plugin without installing it: make load PLUGIN=<name>
	claude --plugin-dir ./plugins/$(PLUGIN)

local-add: ## Add this repository as a local marketplace
	claude plugin marketplace add ./

local-install: need-plugin ## Install a plugin from the local marketplace: make local-install PLUGIN=<name>
	claude plugin install $(PLUGIN)@$(MARKETPLACE)

# --- Release (run by the Commander; see docs/release-checklist.md) -----------

tag: need-plugin ## Tag one plugin and push the tag: make tag PLUGIN=<name>
	cd plugins/$(PLUGIN) && claude plugin tag --push

# --- Install from GitHub and update -------------------------------------------

remote-add: ## Add the published marketplace from GitHub
	claude plugin marketplace add $(REPO)

remote-install: need-plugin ## Install a plugin from GitHub: make remote-install PLUGIN=<name>
	claude plugin install $(PLUGIN)@$(MARKETPLACE)

update: need-plugin ## Update an installed plugin: make update PLUGIN=<name>
	claude plugin update $(PLUGIN)@$(MARKETPLACE)

need-plugin:
	@test -n "$(PLUGIN)" || { echo "Set PLUGIN=<name>. Plugins: $(PLUGINS)"; exit 1; }
