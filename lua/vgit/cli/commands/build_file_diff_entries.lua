local lazy = require('vgit.core.lazy')

local event = lazy('vgit.core.event')

return function(repo, files, from_ref, to_ref, layout_type)
  local funcs = {}
  for _, file in ipairs(files) do
    local filename = file.filename
    local file_old_filename = file.old_filename

    table.insert(funcs, function()
      local diff = repo:diff({
        type = 'range',
        filename = filename,
        old_filename = file_old_filename,
        from = from_ref,
        to = to_ref,
        layout_type = layout_type,
      })

      if not diff then return nil end

      local from_filename = file_old_filename or filename
      return {
        filename = filename,
        filetype = file.filetype or 'text',
        diff = diff,
        status = file,
        original_lines = repo:file_lines(from_filename, from_ref) or {},
        current_lines = repo:file_lines(filename, to_ref) or {},
      }
    end)
  end

  local results = event.all(funcs)

  local entries = {}
  for i = 1, #funcs do
    if results[i] then table.insert(entries, results[i]) end
  end

  return entries
end
