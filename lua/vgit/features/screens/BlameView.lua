local lazy = require('vgit.core.lazy')

local View = lazy('vgit.ui.View')
local event = lazy('vgit.core.event')
local keymap = lazy('vgit.core.keymap')
local console = lazy('vgit.core.console')
local repository = lazy('vgit.git.repository')
local scene_setting = lazy('vgit.settings.scene')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local display_service = lazy('vgit.ui.display_service')
local blame_view_setting = lazy('vgit.settings.blame_view')
local BlameGutterComponent = lazy('vgit.ui.components.BlameGutterComponent')
local GitCommit = lazy('vgit.git.GitCommit') -- luacheck: ignore
local git_blame = lazy('vgit.git.git_blame')
local BlameContentComponent = lazy('vgit.ui.components.BlameContentComponent')

local BlameView = View:extend()

BlameView.DEBOUNCE_MS = 100

BlameView.AUTHOR_COLORS = {
  'Directory',
  'String',
  'Keyword',
  'Type',
  'Constant',
  'Special',
}

function BlameView:constructor()
  local instance = View.constructor(self)
  instance._gutter_component = nil
  instance._content_component = nil
  instance._repo = nil
  instance._history_stack = {}
  instance._current_commit = nil
  instance._current_blames = {}
  instance._blame_segments = {}
  instance._opts = {
    filename = nil,
    filetype = nil,
    reponame = nil,
  }
  return instance
end

function BlameView:create(data)
  if not data then
    console.error('[BlameView] No data provided')
    return false
  end

  if not data.blames or #data.blames == 0 then
    console.info('No blame information available')
    return false
  end

  if not data.lines then
    console.error('[BlameView] No file content')
    return false
  end

  if not data.filename then
    console.error('[BlameView] No filename')
    return false
  end

  self._opts = {
    filename = data.filename,
    filetype = data.filetype,
    reponame = data.reponame,
  }

  local repo, repo_err = repository.open(data.reponame)
  if repo_err then
    console.error('[BlameView] Failed to open repository: ' .. tostring(repo_err))
    return false
  end
  self._repo = repo

  self._current_blames = data.blames
  self._current_commit = nil
  self._history_stack = {}

  return self:_create_view(data)
end

function BlameView:_create_view(data)
  self._gutter_component = BlameGutterComponent()
  self._content_component = BlameContentComponent()

  event.await()
  self:_render(LayoutSpec.screen({
    LayoutSpec.horizontal({
      LayoutSpec.view(self._gutter_component, { width = '35%' }),
      LayoutSpec.view(self._content_component, { flex = 1 }),
    }),
  }))

  self:_render_blame(data.blames)
  self._content_component:set_props({ lines = data.lines, filetype = data.filetype })
  self:_setup_scroll_sync()
  self:setup_keymaps()

  return true
end

function BlameView:_get_author_hl(author)
  local hash = 0
  for c = 1, #author do
    hash = hash + string.byte(author, c)
  end
  local colors = self.AUTHOR_COLORS
  return colors[(hash % #colors) + 1]
end

function BlameView:_compute_blame_segments(blames)
  return git_blame.compute_segments(blames)
end

function BlameView:_render_blame(blames)
  self._gutter_component:set_props({
    blames = blames,
    get_author_hl = function(author)
      return self:_get_author_hl(author)
    end,
  })
  self._blame_segments = self:_compute_blame_segments(blames)
end

function BlameView:blame_down()
  if #self._blame_segments == 0 then return end
  self._content_component:with_element(function(el)
    local current_lnum = el:get_lnum()
    for i = 1, #self._blame_segments do
      local segment = self._blame_segments[i]
      if current_lnum < segment.start then
        el:set_lnum(segment.start)
        return
      end
      if current_lnum >= segment.start and current_lnum <= segment.finish then
        if i < #self._blame_segments then el:set_lnum(self._blame_segments[i + 1].start) end
        return
      end
    end
  end)
end

function BlameView:blame_up()
  if #self._blame_segments == 0 then return end
  self._content_component:with_element(function(el)
    local current_lnum = el:get_lnum()
    for i = #self._blame_segments, 1, -1 do
      local segment = self._blame_segments[i]
      if current_lnum > segment.start then
        el:set_lnum(segment.start)
        return
      end
      if current_lnum >= segment.start and current_lnum <= segment.finish then
        if i > 1 then el:set_lnum(self._blame_segments[i - 1].start) end
        return
      end
    end
  end)
end

function BlameView:_setup_scroll_sync()
  self._gutter_component:with_element(function(el)
    el:set_win_option('scrollbind', true)
    el:set_win_option('cursorbind', true)
  end)
  self._content_component:with_element(function(el)
    el:set_win_option('scrollbind', true)
    el:set_win_option('cursorbind', true)
  end)
end

function BlameView:enter_parent()
  local lnum = self._content_component:with_element(function(el)
    return el:get_lnum()
  end)
  if not lnum then return end
  local blame = self._current_blames[lnum]

  if not blame then return end

  if blame:is_uncommitted() then
    console.info('Line is uncommitted')
    return
  end

  local parent_hash = blame.parent_hash
  if not parent_hash or parent_hash == '' then
    console.info('No parent commit (initial commit)')
    return
  end

  table.insert(self._history_stack, {
    commit = self._current_commit,
    filename = self._opts.filename,
    lnum = lnum,
  })

  local parent_filename = blame.old_filename or self._opts.filename

  local new_blames, blame_err = self._repo:blame_list(parent_filename, parent_hash)
  if blame_err or not new_blames or #new_blames == 0 then
    table.remove(self._history_stack)
    console.error(blame_err or 'Failed to get blame at parent commit')
    return
  end

  local new_lines, lines_err = self._repo:file_lines(parent_filename, parent_hash)
  if lines_err or not new_lines then
    table.remove(self._history_stack)
    console.error(lines_err or 'Failed to get file content at parent commit')
    return
  end

  self._current_commit = parent_hash
  self._current_blames = new_blames
  self._opts.filename = parent_filename

  self:_refresh_view(new_blames, new_lines, lnum)
end

function BlameView:go_back()
  if #self._history_stack == 0 then
    console.info('Already at the latest blame')
    return
  end

  local entry = table.remove(self._history_stack)
  local filename = entry.filename

  local commit = entry.commit
  local new_blames, blame_err
  local new_lines, lines_err

  local ref = commit or 'HEAD'
  new_blames, blame_err = self._repo:blame_list(filename, ref)
  new_lines, lines_err = self._repo:file_lines(filename, ref)

  if blame_err or not new_blames or #new_blames == 0 then
    console.error(blame_err or 'Failed to restore blame')
    return
  end

  if lines_err or not new_lines then
    console.error(lines_err or 'Failed to restore file content')
    return
  end

  self._current_commit = commit
  self._current_blames = new_blames

  self._opts.filename = filename
  self:_refresh_view(new_blames, new_lines, entry.lnum)
end

function BlameView:show_commit_diff()
  local lnum = self._content_component:with_element(function(el)
    return el:get_lnum()
  end)
  if not lnum then return end
  local blame = self._current_blames[lnum]
  if not blame then return end

  if blame:is_uncommitted() then
    console.info('Line is uncommitted')
    return
  end

  local commit_hash = blame.commit_hash or blame.hash
  local parent_hash = blame.parent_hash or (commit_hash .. '~1')
  local filename = blame.filename or self._opts.filename

  local repo, repo_err = repository.current()
  if repo_err then
    console.error(repo_err)
    return
  end

  local layout_type = scene_setting:get('diff_preference') or 'unified'

  local diff, diff_err = repo:diff({
    type = 'blame',
    filename = filename,
    old_filename = blame.old_filename,
    blame_commit = commit_hash,
    parent_commit = parent_hash,
    layout_type = layout_type,
  })

  if diff_err then
    console.debug.error(diff_err)
    return
  end
  if not diff then
    console.info('No changes in this commit for this file')
    return
  end

  self:destroy()
  event.await()

  display_service.show_diff({
    type = 'file',
    diff = diff,
    filename = filename,
    filetype = self._opts.filetype,
    layout_type = layout_type,
    is_live = false,
  })
end

function BlameView:_fetch_commit_diffs(commit_hash)
  local repo, repo_err = repository.current()
  if repo_err then return nil, repo_err end

  local tree = repo:tree(commit_hash)

  local commit, commit_err = tree:commit()
  if commit_err then return nil, 'Failed to get commit info: ' .. tostring(commit_err) end

  local files, files_err = tree:files()
  if files_err then return nil, 'Failed to get commit files: ' .. tostring(files_err) end

  if not files or #files == 0 then return nil, nil end

  local layout_type = scene_setting:get('diff_preference') or 'unified'
  local parent_hash = commit.parent_hash or ''
  local from_ref = parent_hash ~= '' and parent_hash or GitCommit.EMPTY_TREE_HASH
  local to_ref = commit.commit_hash or commit.hash

  local funcs = {}
  for _, file in ipairs(files) do
    local filename = file.filename
    local file_old_filename = file.old_filename

    funcs[#funcs + 1] = function()
      local diff, diff_err = repo:diff({
        type = 'range',
        filename = filename,
        old_filename = file_old_filename,
        from = from_ref,
        to = to_ref,
        layout_type = layout_type,
      })

      if diff_err then
        console.debug.error(diff_err)
        return nil
      end
      if not diff then return nil end

      local from_filename = file_old_filename or filename
      return {
        filename = filename,
        filetype = file.get_filetype and file:get_filetype() or 'text',
        diff = diff,
        status = file,
        original_lines = repo:file_lines(from_filename, from_ref) or {},
        current_lines = repo:file_lines(filename, to_ref) or {},
      }
    end
  end

  local results = event.all(funcs)

  local entries = {}
  for i = 1, #funcs do
    if results[i] then entries[#entries + 1] = results[i] end
  end

  return { entries = entries, commit_hash = commit_hash, layout_type = layout_type }
end

function BlameView:show_commit_project_diff()
  local lnum = self._content_component:with_element(function(el)
    return el:get_lnum()
  end)
  if not lnum then return end
  local blame = self._current_blames[lnum]
  if not blame then return end

  if blame:is_uncommitted() then
    console.info('Line is uncommitted')
    return
  end

  local commit_hash = blame.commit_hash or blame.hash
  local result, err = self:_fetch_commit_diffs(commit_hash)

  if err then
    console.error(err)
    return
  end

  if not result or #result.entries == 0 then
    console.info('No diffs available for this commit')
    return
  end

  self:destroy()
  event.await()

  display_service.show_diff({
    type = 'files',
    entries = {
      {
        title = string.format('Commit: %s', commit_hash:sub(1, 7)),
        entries = result.entries,
      },
    },
    layout_type = result.layout_type,
  })
end

function BlameView:_refresh_view(blames, lines, target_lnum)
  self:_render_blame(blames)
  self._content_component:set_props({ lines = lines, filetype = self._opts.filetype })

  if target_lnum then
    local max_lnum = #lines
    if target_lnum > max_lnum then target_lnum = max_lnum end
    if target_lnum < 1 then target_lnum = 1 end

    self._content_component:with_element(function(el)
      el:set_lnum(target_lnum)
    end)
  end
end

function BlameView:setup_keymaps()
  local components = { self._content_component, self._gutter_component }

  self:_setup_quit_keymap()

  local enter_fn = self:_make_debounced(function()
    self:enter_parent()
  end)
  local back_fn = self:_make_debounced(function()
    self:go_back()
  end)
  local diff_fn = self:_make_debounced(function()
    self:show_commit_diff()
  end)
  local project_diff_fn = self:_make_debounced(function()
    self:show_commit_project_diff()
  end)

  local blame_keymaps = blame_view_setting:get('keymaps')

  local blame_down_fn = function()
    self:blame_down()
  end
  local blame_up_fn = function()
    self:blame_up()
  end

  local enter_key = keymap.get_key(blame_keymaps.enter)
  local back_key = keymap.get_key(blame_keymaps.back)
  local diff_key = keymap.get_key(blame_keymaps.diff)
  local project_diff_key = keymap.get_key(blame_keymaps.project_diff)
  local down_key = keymap.get_key(blame_keymaps.down)
  local up_key = keymap.get_key(blame_keymaps.up)

  for _, component in ipairs(components) do
    if enter_key then component:set_keymap({ mode = 'n', key = enter_key }, enter_fn) end
    if back_key then component:set_keymap({ mode = 'n', key = back_key }, back_fn) end
    if diff_key then component:set_keymap({ mode = 'n', key = diff_key }, diff_fn) end
    if project_diff_key then component:set_keymap({ mode = 'n', key = project_diff_key }, project_diff_fn) end
    if down_key then component:set_keymap({ mode = 'n', key = down_key }, blame_down_fn) end
    if up_key then component:set_keymap({ mode = 'n', key = up_key }, blame_up_fn) end
  end
end

return BlameView
