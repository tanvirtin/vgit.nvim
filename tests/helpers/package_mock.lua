local M = {}

function M.create()
  local original_packages = {}

  local function save_package(name)
    original_packages[name] = package.loaded[name]
  end

  local function restore_packages()
    for name, module in pairs(original_packages) do
      package.loaded[name] = module
    end
    original_packages = {}
  end

  return save_package, restore_packages
end

return M
