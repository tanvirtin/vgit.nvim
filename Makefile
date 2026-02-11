.PHONY: test test-filter lint format format-check check ci install-deps clean

LUA_VERSION ?= 5.1

test:
	GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=protocol.file.allow GIT_CONFIG_VALUE_0=always vusted

test-filter:
	GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=protocol.file.allow GIT_CONFIG_VALUE_0=always vusted --filter="$(FILTER)"

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

ci: check test
