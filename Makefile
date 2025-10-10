.PHONY: help test test-file test-watch lint format check ci install-deps clean

RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

help:
	@echo "$(BLUE)VGit.nvim - Makefile Commands$(NC)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:' $(MAKEFILE_LIST) | \
		grep -v '^help:' | \
		awk -F: '{print $$1}' | \
		sort | \
		awk 'BEGIN { \
			test["test"]=1; test["test-file"]=1; test["test-list"]=1; test["test-find"]=1; \
			test["test-core"]=1; test["test-git"]=1; test["test-watch"]=1; test["test-coverage"]=1; \
			quality["lint"]=1; quality["format"]=1; quality["format-check"]=1; quality["check"]=1; \
			dev["install-deps"]=1; dev["install-hooks"]=1; dev["uninstall-hooks"]=1; dev["clean"]=1; \
			ci["ci"]=1; \
			printed_test=0; printed_quality=0; printed_dev=0; printed_ci=0; printed_other=0; \
		} \
		{ \
			if ($$1 in test) { \
				if (!printed_test) { print "$(GREEN)Testing:$(NC)"; printed_test=1; } \
				printf "  $(YELLOW)%-20s$(NC)\n", $$1; \
			} else if ($$1 in quality) { \
				if (!printed_quality) { if (printed_test) print ""; print "$(GREEN)Code Quality:$(NC)"; printed_quality=1; } \
				printf "  $(YELLOW)%-20s$(NC)\n", $$1; \
			} else if ($$1 in dev) { \
				if (!printed_dev) { if (printed_test || printed_quality) print ""; print "$(GREEN)Development:$(NC)"; printed_dev=1; } \
				printf "  $(YELLOW)%-20s$(NC)\n", $$1; \
			} else if ($$1 in ci) { \
				if (!printed_ci) { if (printed_test || printed_quality || printed_dev) print ""; print "$(GREEN)CI/CD:$(NC)"; printed_ci=1; } \
				printf "  $(YELLOW)%-20s$(NC)\n", $$1; \
			} else { \
				if (!printed_other) { if (printed_test || printed_quality || printed_dev || printed_ci) print ""; print "$(GREEN)Other:$(NC)"; printed_other=1; } \
				printf "  $(YELLOW)%-20s$(NC)\n", $$1; \
			} \
		}'
	@echo ""

test:
	@lua ops/test_summary.lua tests/unit

test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "$(RED)Error: FILE parameter is required$(NC)"; \
		echo "Usage: make test-file FILE=tests/unit/core/Object_spec.lua"; \
		echo ""; \
		echo "$(YELLOW)Available test files:$(NC)"; \
		find tests -name "*_spec.lua" -type f | sort; \
		exit 1; \
	fi
	@echo "$(BLUE)Running test file: $(FILE)$(NC)"
	@echo ""
	@nvim --headless -c "PlenaryBustedFile $(FILE)"

test-core:
	@lua ops/test_summary.lua tests/unit/core

test-git:
	@lua ops/test_summary.lua tests/unit/git

test-list:
	@echo "$(BLUE)Available test files:$(NC)"
	@find tests -name "*_spec.lua" -type f | sort | sed 's|^|  |'

test-find:
	@if [ -z "$(PATTERN)" ]; then \
		echo "$(RED)Error: PATTERN parameter is required$(NC)"; \
		echo "Usage: make test-find PATTERN=git_hunks"; \
		exit 1; \
	fi
	@echo "$(BLUE)Test files matching '$(PATTERN)':$(NC)"
	@find tests -name "*_spec.lua" -type f | grep -i "$(PATTERN)" | sort | sed 's|^|  |' || echo "  $(YELLOW)No matches found$(NC)"

test-watch:
	@if ! command -v fd >/dev/null 2>&1 || ! command -v entr >/dev/null 2>&1; then \
		echo "$(RED)Error: Watch mode requires 'fd' and 'entr'$(NC)"; \
		echo ""; \
		echo "Install with:"; \
		echo "  macOS:   brew install fd entr"; \
		echo "  Ubuntu:  sudo apt install fd-find entr"; \
		echo ""; \
		echo "$(YELLOW)Alternative: Run tests manually after changes$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Starting watch mode...$(NC)"
	@echo "$(YELLOW)Watching for changes in lua/ and tests/$(NC)"
	@echo "Press Ctrl+C to stop"
	@fd -e lua . lua tests | entr -c make test

test-coverage:
	@echo "$(YELLOW)Coverage reporting not yet implemented$(NC)"
	@echo "Future: integrate luacov"

format:
	@echo "$(BLUE)Formatting code with stylua...$(NC)"
	@if command -v stylua >/dev/null 2>&1; then \
		stylua --config-path stylua.toml lua/ tests/; \
	else \
		echo "$(YELLOW)stylua not installed. Skipping...$(NC)"; \
	fi

lint:
	@echo "$(BLUE)Running luacheck...$(NC)"
	@if command -v luacheck >/dev/null 2>&1; then \
		luacheck lua/ tests/ --config .luacheckrc; \
	else \
		echo "$(YELLOW)luacheck not installed. Skipping...$(NC)"; \
	fi

format-check:
	@echo "$(BLUE)Checking code format...$(NC)"
	@if command -v stylua >/dev/null 2>&1; then \
		stylua --check --config-path stylua.toml lua/ tests/; \
	else \
		echo "$(YELLOW)stylua not installed. Skipping...$(NC)"; \
	fi

check: lint format-check

install-deps:
	@echo "$(BLUE)Installing development dependencies...$(NC)"
	@mkdir -p ~/.local/share/nvim/site/pack/vendor/start
	@if [ ! -d ~/.local/share/nvim/site/pack/vendor/start/plenary.nvim ]; then \
		echo "Installing plenary.nvim..."; \
		git clone --depth 1 https://github.com/nvim-lua/plenary.nvim \
			~/.local/share/nvim/site/pack/vendor/start/plenary.nvim; \
	else \
		echo "plenary.nvim already installed"; \
	fi
	@echo "$(GREEN)Dependencies installed!$(NC)"

install-hooks:
	@echo "$(BLUE)Installing git hooks...$(NC)"
	@if [ -f .git/hooks/pre-commit ]; then \
		echo "$(YELLOW)Pre-commit hook already exists. Backup created.$(NC)"; \
		mv .git/hooks/pre-commit .git/hooks/pre-commit.bak; \
	fi
	@ln -s ../../ops/pre_commit_hook.lua .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "$(GREEN)Git hooks installed!$(NC)"
	@echo "Pre-commit hook will run: format check + lint + tests"

uninstall-hooks:
	@echo "$(BLUE)Uninstalling git hooks...$(NC)"
	@rm -f .git/hooks/pre-commit
	@if [ -f .git/hooks/pre-commit.bak ]; then \
		mv .git/hooks/pre-commit.bak .git/hooks/pre-commit; \
	fi
	@echo "$(GREEN)Git hooks uninstalled!$(NC)"

clean:
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	@find . -name "*.log" -type f -delete
	@find . -name ".luacov" -type f -delete
	@echo "$(GREEN)Clean complete!$(NC)"

ci: check test
	@echo "$(GREEN)CI pipeline completed successfully!$(NC)"
