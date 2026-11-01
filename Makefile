.PHONY: test test-unit test-scenario test-filter test-file lint format format-check check ci install-deps clean setup-hooks

LUA_VERSION ?= 5.1

# Unit specs and scenario specs run in separate processes: the scenarios spawn
# real editors, and a fresh process keeps them away from whatever three thousand
# unit tests leave behind in the one that ran before them.
test:
	$(MAKE) test-unit
	$(MAKE) test-scenario

test-unit:
	GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=protocol.file.allow GIT_CONFIG_VALUE_0=always vusted lua/

test-scenario:
	GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=protocol.file.allow GIT_CONFIG_VALUE_0=always vusted tests/

test-filter:
	GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=protocol.file.allow GIT_CONFIG_VALUE_0=always vusted --filter="$(FILTER)"

test-file:
	GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=protocol.file.allow GIT_CONFIG_VALUE_0=always vusted $(FILE)

lint:
	@if command -v luacheck >/dev/null 2>&1; then \
		luacheck lua/ tests/ --config .luacheckrc; \
	else \
		echo "luacheck not installed. Skipping..."; \
	fi

format:
	@if command -v stylua >/dev/null 2>&1; then \
		stylua --config-path stylua.toml lua/ tests/; \
	else \
		echo "stylua not installed. Skipping..."; \
	fi

format-check:
	@if command -v stylua >/dev/null 2>&1; then \
		stylua --check --config-path stylua.toml lua/ tests/; \
	else \
		echo "stylua not installed. Skipping..."; \
	fi

check: lint format-check

install-deps:
	luarocks --lua-version=$(LUA_VERSION) install vusted
	luarocks --lua-version=$(LUA_VERSION) install luacheck

clean:
	rm -rf luacov.stats.out luacov.report.out

setup-hooks:
	git config core.hooksPath .githooks
	@echo "Git hooks activated from .githooks/"

ci: check test
