.DEFAULT_GOAL := help

VERSION = $(shell cat VERSION)

# Plugin paths
plugin_root = .
lua_src = $(plugin_root)/lua

################################################################################
# Development 
DEVELOPMENT: ## ##############################################################

.PHONY: setup
setup: ## one-time development environment setup
	@echo "Setting up inka-nvim development environment..."
	@echo "Checking dependencies..."
	@if ! command -v inka2 >/dev/null 2>&1; then \
		echo "⚠️  inka2 CLI not found. Install with: pip install inka2"; \
	else \
		echo "✅ inka2 CLI found: $$(inka2 --version)"; \
	fi
	@echo "✅ Pure Lua plugin setup complete!"
	@echo ""
	@echo "Required dependencies:"
	@echo "- plenary.nvim: Testing framework (required for tests)"
	@echo ""
	@echo "Optional dependencies:"
	@echo "- inka2: CLI tool for inka2 flashcard processing"

.PHONY: dev  
dev: setup ## setup and open development environment
	@echo "Opening Neovim for inka-nvim development..."
	nvim .

.PHONY: check
check: test lint ## comprehensive check (lint + tests)

################################################################################
# Testing
TESTING: ## ##################################################################

.PHONY: test
test: ## run full test suite with plenary.nvim
	@echo "Running inka-nvim test suite..."
	@failed=0; \
	for test_file in tests/inka-nvim/*_spec.lua; do \
		echo ""; \
		echo "Testing: $$(basename $$test_file)"; \
		echo "========================================"; \
		output=$$(nvim --headless --noplugin \
			-u tests/minimal_init.lua \
			-c "PlenaryBustedFile $$test_file" \
			+qa! 2>&1); \
		echo "$$output" | grep -v "^$$" | sed 's/^/  /'; \
		if echo "$$output" | grep -q "Tests Failed"; then \
			failed=1; \
		fi; \
	done; \
	echo ""; \
	if [ $$failed -eq 1 ]; then \
		echo "❌ Some tests failed"; \
		exit 1; \
	else \
		echo "✅ All tests passed!"; \
	fi

.PHONY: test-summary
test-summary: ## run test suite with summary output only
	@echo "Running inka-nvim test suite (summary mode)..."
	@failed=0; \
	for test_file in tests/inka-nvim/*_spec.lua; do \
		echo ""; \
		echo "Testing: $$(basename $$test_file)"; \
		echo "========================================"; \
		output=$$(nvim --headless --noplugin \
			-u tests/minimal_init.lua \
			-c "PlenaryBustedFile $$test_file" \
			+qa! 2>&1); \
		echo "$$output" | grep -E "(Success:|Failed :|Errors :)" | tail -3; \
		if echo "$$output" | grep -q "Tests Failed"; then \
			failed=1; \
		fi; \
	done; \
	echo ""; \
	if [ $$failed -eq 1 ]; then \
		echo "❌ Some tests failed"; \
		exit 1; \
	else \
		echo "✅ All tests passed!"; \
	fi

.PHONY: test-verbose
test-verbose: ## run test suite with full verbose output
	@echo "Running inka-nvim test suite (verbose mode)..."
	@failed=0; \
	for test_file in tests/inka-nvim/*_spec.lua; do \
		echo ""; \
		echo "Testing: $$(basename $$test_file)"; \
		echo "========================================"; \
		nvim --headless --noplugin \
			-u tests/minimal_init.lua \
			-c "PlenaryBustedFile $$test_file" \
			+qa!; \
		if [ $$? -ne 0 ]; then \
			failed=1; \
		fi; \
	done; \
	echo ""; \
	if [ $$failed -eq 1 ]; then \
		echo "❌ Some tests failed"; \
		exit 1; \
	else \
		echo "✅ All tests passed!"; \
	fi

.PHONY: test-interactive
test-interactive: ## run tests in interactive mode
	@echo "Running tests in interactive Neovim..."
	nvim -c "lua require('plenary.test_harness').test_directory('tests/inka-nvim', {minimal_init = 'tests/minimal_init.lua'})"

.PHONY: test-file
test-file: ## run specific test file (usage: make test-file FILE=detection_spec.lua)
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=detection_spec.lua"; \
		exit 1; \
	fi
	@echo "Running test file: $(FILE)"
	@nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedFile tests/inka-nvim/$(FILE)" +qa!

.PHONY: test-detection
test-detection: ## run detection tests specifically
	@$(MAKE) test-file FILE=detection_spec.lua

.PHONY: test-markers  
test-markers: ## run marker tests specifically
	@$(MAKE) test-file FILE=markers_spec.lua

.PHONY: test-commands
test-commands: ## run command tests specifically
	@$(MAKE) test-file FILE=commands_spec.lua

.PHONY: test-integration
test-integration: ## run integration tests specifically
	@$(MAKE) test-file FILE=integration_spec.lua

.PHONY: test-debug
test-debug: ## run tests with debug output enabled
	@echo "Running tests with debug output..."
	@nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "lua require('inka-nvim').setup({debug = true})" \
		-c "PlenaryBustedDirectory tests/inka-nvim/" +qa!

################################################################################
# Code Quality
QUALITY: ## ##################################################################

.PHONY: lint
lint: ## run Lua linting (stylua if available)
	@if command -v stylua >/dev/null 2>&1; then \
		echo "Running stylua formatting check..."; \
		stylua --check $(lua_src); \
	else \
		echo "stylua not found - install with: cargo install stylua"; \
		echo "Skipping lint check"; \
	fi

.PHONY: format
format: ## format Lua code with stylua
	@if command -v stylua >/dev/null 2>&1; then \
		echo "Formatting Lua code with stylua..."; \
		stylua $(lua_src); \
	else \
		echo "stylua not found - install with: cargo install stylua"; \
		exit 1; \
	fi

.PHONY: luacheck
luacheck: ## run luacheck for static analysis (if available)
	@if command -v luacheck >/dev/null 2>&1; then \
		echo "Running luacheck..."; \
		luacheck $(lua_src) --globals vim; \
	else \
		echo "luacheck not found - install with: luarocks install luacheck"; \
		echo "Skipping luacheck"; \
	fi

################################################################################
# Plugin Validation
PLUGIN: ## ###################################################################

.PHONY: validate-plugin
validate-plugin: ## validate plugin structure and functionality
	@echo "Validating inka-nvim plugin structure..."
	@[ -f "lua/inka-nvim/init.lua" ] && echo "✅ Main module" || echo "❌ Missing main module"
	@[ -f "plugin/inka-nvim.vim" ] && echo "✅ Plugin loader" || echo "❌ Missing plugin loader"
	@[ -f "doc/inka-nvim.txt" ] && echo "✅ Help documentation" || echo "⚠️  Missing help docs (will be created)"
	@[ -d "tests" ] && echo "✅ Test directory" || echo "❌ Missing tests"
	@[ -f "tests/minimal_init.lua" ] && echo "✅ Test framework" || echo "❌ Missing test framework"
	@[ -d "tests/fixtures" ] && echo "✅ Test fixtures" || echo "❌ Missing test fixtures"

.PHONY: install-dev
install-dev: ## show development installation instructions
	@echo "For development, add this to your Neovim config:"
	@echo ""
	@echo "-- Using lazy.nvim"
	@echo "{"
	@echo "  'inka-nvim',"
	@echo "  dev = true,"
	@echo "  dir = '$(PWD)',"
	@echo "  ft = 'markdown',"
	@echo "  config = function()"
	@echo "    require('inka-nvim').setup({"
	@echo "      debug = true -- Enable for development"
	@echo "    })"
	@echo "  end"
	@echo "}"
	@echo ""
	@echo "Then run: :Lazy reload inka-nvim"

.PHONY: test-plugin-loading
test-plugin-loading: ## test plugin loading in minimal environment
	@echo "Testing plugin loading..."
	@nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "lua print('Plugin loaded: ' .. tostring(pcall(require, 'inka-nvim')))" \
		-c "lua require('inka-nvim').setup({debug = true})" \
		-c "lua print('Commands available: ' .. tostring(vim.fn.exists(':InkaEdit') == 2))" \
		+qa!

################################################################################
# Documentation & Examples
DOCS: ## #####################################################################

.PHONY: example-usage
example-usage: ## show example usage of the plugin
	@echo "=== Inka-nvim Usage Example ==="
	@echo ""
	@echo "1. Open a markdown file with inka2 content:"
	@echo "   nvim example.md"
	@echo ""
	@echo "2. Position cursor within an inka2 card (between --- sections)"
	@echo ""
	@echo "3. Enter editing mode:"
	@echo "   :InkaEdit"
	@echo ""
	@echo "4. Edit the content normally (answer markers '>' are hidden)"
	@echo ""
	@echo "5. Save and restore markers:"
	@echo "   :InkaSave"
	@echo ""
	@echo "6. Check status anytime:"
	@echo "   :InkaStatus"
	@echo ""
	@echo "=== Test with fixture files ==="
	@echo "Try with: tests/fixtures/basic_cards.md"

.PHONY: demo
demo: ## run interactive demo
	@echo "Starting inka-nvim demo..."
	@echo "Opening basic_cards.md fixture file..."
	@nvim -u tests/minimal_init.lua tests/fixtures/basic_cards.md \
		-c "lua print('Demo: Position cursor on a question and run :InkaEdit')" \
		-c "lua print('Available commands: :InkaEdit, :InkaSave, :InkaStatus')"

################################################################################
# Cleanup
CLEANUP: ## ##################################################################

.PHONY: clean
clean: ## remove temporary files
	@echo "Cleaning up inka-nvim..."
	find . -name "*.tmp" -delete 2>/dev/null || true
	find . -name "*.log" -delete 2>/dev/null || true
	find . -name ".DS_Store" -delete 2>/dev/null || true
	@echo "✅ Cleanup complete"

################################################################################
# Version Management \
VERSIONING: ## ###############################################################

.PHONY: bump-major
bump-major: check-github-token ## bump major version, tag and push
	bump-my-version bump --commit --tag major
	git push
	git push --tags
	@$(MAKE) create-release

.PHONY: bump-minor
bump-minor: check-github-token ## bump minor version, tag and push
	bump-my-version bump --commit --tag minor
	git push
	git push --tags
	@$(MAKE) create-release

.PHONY: bump-patch
bump-patch: check-github-token ## bump patch version, tag and push
	bump-my-version bump --commit --tag patch
	git push
	git push --tags
	@$(MAKE) create-release

.PHONY: create-release
create-release: check-github-token ## create a release on GitHub via the gh cli
	@if ! command -v gh &>/dev/null; then \
		echo "You do not have the GitHub CLI (gh) installed. Please create the release manually."; \
		exit 1; \
	else \
		echo "Creating GitHub release for v$(VERSION)"; \
		gh release create "v$(VERSION)" --generate-notes --latest; \
	fi

.PHONY: check-github-token
check-github-token: ## check if GITHUB_TOKEN is set
	@if [ -z "$$GITHUB_TOKEN" ]; then \
		echo "GITHUB_TOKEN is not set. Please export your GitHub token before running this command."; \
		exit 1; \
	fi
	@echo "GITHUB_TOKEN is set"

.PHONY: version
version: ## show current version
	@echo "inka-nvim version: $(VERSION)"

################################################################################
# Documentation \
DOCUMENTATION: ## ############################################################

.PHONY: docs
docs: ## generate and update documentation
	@echo "Updating inka-nvim documentation..."
	@echo "✅ README.md - comprehensive user documentation"
	@echo "✅ CLAUDE.md - development guidance"
	@echo ""
	@echo "Help tags need regeneration in Neovim:"
	@echo "  :helptags doc/"

.PHONY: check-docs
check-docs: ## validate documentation
	@echo "Checking documentation consistency..."
	@grep -q "$(VERSION)" README.md && echo "✅ Version in README.md" || echo "⚠️  Version not found in README.md"
	@grep -q "$(VERSION)" lua/inka-nvim/init.lua && echo "✅ Version in init.lua" || echo "⚠️  Version not found in init.lua"

################################################################################
# Help
HELP: ## #####################################################################

define PRINT_HELP_PYSCRIPT
import re, sys

for line in sys.stdin:
	match = re.match(r'^([%a-zA-Z0-9_-]+):.*?## (.*)$$', line)
	if match:
		target, help = match.groups()
		if target != "dummy":
			print("\033[36m%-20s\033[0m %s" % (target, help))
endef
export PRINT_HELP_PYSCRIPT

.PHONY: help
help:
	@python -c "$$PRINT_HELP_PYSCRIPT" < $(MAKEFILE_LIST)