-- Coverage matrix: every CLI command must be exercised by a scenario or be listed
-- in UNCOVERED_ALLOWED with a reason. The list may only shrink: once a command is
-- covered, the test fails until it is removed from the list.
local router_path = 'lua/vgit/cli/router.lua'

local UNCOVERED_ALLOWED = {}

local function read(path)
  return table.concat(vim.fn.readfile(path), '\n')
end

local function scenario_source()
  local chunks = {}
  for _, file in ipairs(vim.fn.glob('tests/scenarios/*_spec.lua', false, true)) do
    if not file:find('coverage_spec', 1, true) then chunks[#chunks + 1] = read(file) end
  end
  return table.concat(chunks, '\n')
end

describe('scenario coverage matrix', function()
  it('requires every command to have a scenario or an allowlist entry', function()
    local commands = {}
    for name in read(router_path):gmatch('\n  ([%w_]+) = \'vgit%.cli%.commands%.') do
      commands[#commands + 1] = name
    end
    assert.is_true(#commands > 0, 'found no commands in the router')

    local source = scenario_source()
    local missing = {}
    for _, name in ipairs(commands) do
      local used = source:find('VGit ' .. name, 1, true)
        or source:find('open = \'' .. name .. '\'', 1, true)
        or source:find('\'' .. name .. '\'', 1, true)
      if not used then missing[#missing + 1] = name end
    end

    table.sort(missing)
    local unexpected, stale = {}, {}
    for _, name in ipairs(missing) do
      if not UNCOVERED_ALLOWED[name] then unexpected[#unexpected + 1] = name end
    end
    local missing_set = {}
    for _, name in ipairs(missing) do
      missing_set[name] = true
    end
    for name in pairs(UNCOVERED_ALLOWED) do
      if not missing_set[name] then stale[#stale + 1] = name end
    end
    table.sort(stale)

    assert.are.same({}, unexpected, 'commands with no scenario (add one, or allowlist with a reason)')
    assert.are.same({}, stale, 'commands now covered: remove them from UNCOVERED_ALLOWED')
  end)
end)
