local lazy = require('vgit.core.lazy')

local event = lazy('vgit.core.event')
local Layout = lazy('vgit.ui.Layout')
local Object = lazy('vgit.core.Object')
local GitTree = lazy('vgit.git.GitTree')
local console = lazy('vgit.core.console')
local git_show = lazy('vgit.git.git_show')
local Component = lazy('vgit.ui.Component')
local git_blame = lazy('vgit.git.git_blame')
local repository = lazy('vgit.git.repository')
local Element = lazy('vgit.ui.elements.Element')
local scene_setting = lazy('vgit.settings.scene')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local display_service = lazy('vgit.ui.display_service')
local ComponentManager = lazy('vgit.ui.ComponentManager')
local blame_view_setting = lazy('vgit.settings.blame_view')
local LayoutComponent = lazy('vgit.ui.components.LayoutComponent')

local BlameGutterComponent = Component:extend()

function BlameGutterComponent:component_will_mount()
  if not self._element then
    self._element = Element({
      buf_options = {
        modifiable = false,
        buflisted = false,
        bufhidden = 'wipe',
      },
      win_options = {
        winhl = 'Normal:GitBackground',
        signcolumn = 'no',
        wrap = false,
        number = false,
        cursorline = true,
      },
      win_plot = {
        focusable = false,
      },
    })
  end
end

function BlameGutterComponent:render() end

function BlameGutterComponent:component_did_mount() end

function BlameGutterComponent:get_layout_spec()
  return LayoutSpec.view(self._element, {
    width = self.props.width or '35%',
  })
end

function BlameGutterComponent:unmount()
  if not self._mounted then return end
  if self._element then
    self._element:unmount()
    self._element = nil
  end
  Component.unmount(self)
end

local BlameContentComponent = Component:extend()

function BlameContentComponent:component_will_mount()
  if not self._element then
    self._element = Element({
      buf_options = {
        modifiable = false,
        buflisted = false,
        bufhidden = 'wipe',
      },
      win_options = {
        winhl = 'Normal:GitBackground',
        signcolumn = 'no',
        wrap = false,
        number = true,
        cursorline = true,
      },
    })
  end
end

function BlameContentComponent:render() end

function BlameContentComponent:component_did_mount() end

function BlameContentComponent:get_layout_spec()
  return LayoutSpec.view(self._element, {
    flex = 1,
    focus = true,
  })
end

function BlameContentComponent:unmount()
  if not self._mounted then return end
  if self._element then
    self._element:unmount()
    self._element = nil
  end
  Component.unmount(self)
end

local BlameView = Object:extend()

BlameView.DEBOUNCE_MS = 100

function BlameView:constructor()
  return {
    _gutter_component = nil,
    _content_component = nil,
    _component_manager = nil,
    _history_stack = {},
    _current_commit = nil,
    _current_blames = {},
    _blame_segments = {},
    _opts = {
      filename = nil,
      filetype = nil,
      reponame = nil,
    },
    _destroyed = false,
    _debounce_cleanups = {},
  }
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
  self._current_blames = data.blames
  self._current_commit = nil
  self._history_stack = {}

  return self:_create_view(data)
end

function BlameView:_create_view(data)
  self._gutter_component = BlameGutterComponent()
  self._content_component = BlameContentComponent()

  local wrapper = LayoutComponent({
    spec = LayoutSpec.horizontal({
      LayoutSpec.view(self._gutter_component, { width = '35%' }),
      LayoutSpec.view(self._content_component, { flex = 1 }),
    }),
  })

  self._component_manager = ComponentManager()
  event.await()
  self._component_manager:render(Layout.screen(wrapper, {
    width = '100vw',
    height = '100vh',
  }))

  self:_render_blame(data.blames)
  self:_render_content(data.lines, data.filetype)
  self:_setup_scroll_sync()
  self:_setup_keymaps()

  return true
end

BlameView.AUTHOR_COLORS = {
  'Directory',
  'String',
  'Keyword',
  'Type',
  'Constant',
  'Special',
}

function BlameView:_get_author_hl(author)
  local hash = 0
  for c = 1, #author do
    hash = hash + string.byte(author, c)
  end
  local colors = self.AUTHOR_COLORS
  return colors[(hash % #colors) + 1]
end

function BlameView:_render_blame(blames)
  local lines = {}
  local highlights = {}
  local line_highlights = {}
  local line_count = #blames
  local group_index = 0

  local i = 1
  while i <= line_count do
    local blame = blames[i]
    local hash = blame.commit_hash or blame.hash
    local group_start = i

    while i <= line_count do
      local b = blames[i]
      local h = b.commit_hash or b.hash
      if h ~= hash then break end
      i = i + 1
    end
    local group_end = i - 1

    local is_uncommitted = blame:is_uncommitted()
    local bg_hl = group_index % 2 == 0 and 'GitBlameEven' or 'GitBlameOdd'
    group_index = group_index + 1

    local short_hash = ''
    if not is_uncommitted then short_hash = (blame:short_hash() or ''):sub(1, 7) end

    local message = blame.message or blame.commit_message or ''
    if #message > 35 then message = message:sub(1, 34) .. '..' end

    local age_display = ''
    if blame.author_time then
      local age = blame:age()
      if age then age_display = age.display end
    end

    local author = blame.author or 'Unknown'
    if #author > 16 then author = author:sub(1, 15) .. '..' end

    local initial = ''
    if not is_uncommitted and #author > 0 then initial = author:sub(1, 1):upper() end

    -- Line 1: initial  short_hash  commit_message  age
    local line1
    if is_uncommitted then
      line1 = '  Uncommitted'
    else
      line1 = string.format(' %s %s  %s  %s', initial, short_hash, message, age_display)
    end
    lines[#lines + 1] = line1
    line_highlights[#line_highlights + 1] = { row = group_start - 1, hl = bg_hl }

    if is_uncommitted then
      highlights[#highlights + 1] = {
        row = group_start - 1,
        hl = 'GitComment',
        from = 0,
        to = #line1,
      }
    else
      local author_hl = self:_get_author_hl(author)
      -- Initial
      highlights[#highlights + 1] = {
        row = group_start - 1,
        hl = author_hl,
        from = 1,
        to = 1 + #initial,
      }
      -- Short hash
      local hash_start = 1 + #initial + 1
      highlights[#highlights + 1] = {
        row = group_start - 1,
        hl = 'NonText',
        from = hash_start,
        to = hash_start + #short_hash,
      }
      -- Commit message
      local msg_start = hash_start + #short_hash + 2
      highlights[#highlights + 1] = {
        row = group_start - 1,
        hl = 'Normal',
        from = msg_start,
        to = msg_start + #message,
      }
      -- Age
      if #age_display > 0 then
        local age_start = msg_start + #message + 2
        highlights[#highlights + 1] = {
          row = group_start - 1,
          hl = 'GitComment',
          from = age_start,
          to = age_start + #age_display,
        }
      end
    end

    -- Line 2: author name (if group has 2+ lines)
    if group_end > group_start then
      local line2
      if is_uncommitted then
        line2 = '  '
      else
        local author_hl = self:_get_author_hl(author)
        line2 = string.format('   %s', author)
        highlights[#highlights + 1] = {
          row = group_start,
          hl = author_hl,
          from = 3,
          to = 3 + #author,
        }
      end
      lines[#lines + 1] = line2
      line_highlights[#line_highlights + 1] = { row = group_start, hl = bg_hl }
    end

    -- Remaining lines: continuation markers
    for j = group_start + 2, group_end do
      lines[#lines + 1] = ''
      line_highlights[#line_highlights + 1] = { row = j - 1, hl = bg_hl }
    end
  end

  -- Ensure gutter has exactly the same number of lines as content
  while #lines < line_count do
    lines[#lines + 1] = ''
  end

  self._gutter_component:with_element(function(el)
    el:set_lines(lines)
    el:clear_extmark_highlights()

    for _, lh in ipairs(line_highlights) do
      el:place_extmark_highlight({
        hl = lh.hl,
        row = lh.row,
        line_hl = true,
      })
    end

    for _, h in ipairs(highlights) do
      el:place_extmark_highlight({
        hl = h.hl,
        row = h.row,
        col_range = { from = h.from, to = h.to },
      })
    end

    self._blame_segments = self:_compute_blame_segments(blames)
  end)
end

function BlameView:_render_content(lines, filetype)
  self._content_component:with_element(function(el)
    el:set_lines(lines)
    if filetype then el:set_filetype(filetype) end
  end)
end

function BlameView:_compute_blame_segments(blames)
  local segments = {}
  local line_count = #blames
  local i = 1

  while i <= line_count do
    local blame = blames[i]
    local hash = blame.commit_hash or blame.hash
    local segment_start = i

    while i <= line_count do
      local b = blames[i]
      local h = b.commit_hash or b.hash
      if h ~= hash then break end
      i = i + 1
    end
    local segment_end = i - 1

    table.insert(segments, {
      start = segment_start,
      finish = segment_end,
    })
  end

  return segments
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

  local parent_hash = blame.parent_hash or blame._parent_hash
  if not parent_hash or parent_hash == '' then
    console.info('No parent commit (initial commit)')
    return
  end

  table.insert(self._history_stack, {
    commit = self._current_commit,
    filename = self._opts.filename,
    lnum = lnum,
  })

  local reponame = self._opts.reponame
  local parent_filename = blame.old_filename or self._opts.filename

  local new_blames, blame_err = git_blame.list(reponame, parent_filename, parent_hash)
  if blame_err or not new_blames or #new_blames == 0 then
    table.remove(self._history_stack)
    console.error(blame_err or 'Failed to get blame at parent commit')
    return
  end

  local new_lines, lines_err = git_show.lines(reponame, parent_filename, parent_hash)
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
  local reponame = self._opts.reponame
  local filename = entry.filename

  local commit = entry.commit
  local new_blames, blame_err
  local new_lines, lines_err

  if commit then
    new_blames, blame_err = git_blame.list(reponame, filename, commit)
    new_lines, lines_err = git_show.lines(reponame, filename, commit)
  else
    new_blames, blame_err = git_blame.list(reponame, filename, 'HEAD')
    new_lines, lines_err = git_show.lines(reponame, filename, 'HEAD')
  end

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
  local parent_hash = blame.parent_hash or blame._parent_hash or (commit_hash .. '~1')
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

  local repo, repo_err = repository.current()
  if repo_err then
    console.error(repo_err)
    return
  end

  local tree = GitTree(repo, commit_hash)

  local commit, commit_err = tree:commit()
  if commit_err then
    console.error('Failed to get commit info: ' .. tostring(commit_err))
    return
  end

  local files, files_err = tree:files()
  if files_err then
    console.error('Failed to get commit files: ' .. tostring(files_err))
    return
  end

  if not files or #files == 0 then
    console.info('No files changed in this commit')
    return
  end

  local layout_type = scene_setting:get('diff_preference') or 'unified'
  local parent_hash = commit.parent_hash or ''
  local from_ref = parent_hash ~= '' and parent_hash or nil
  local to_ref = commit.commit_hash or commit.hash

  local funcs = {}
  for _, file in ipairs(files) do
    local filename = file.filename
    local file_old_filename = file.old_filename

    table.insert(funcs, function()
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
    end)
  end

  local results = event.all(funcs)

  local entries = {}
  for i = 1, #funcs do
    if results[i] then table.insert(entries, results[i]) end
  end

  if #entries == 0 then
    console.info('No diffs available for this commit')
    return
  end

  local data = {
    type = 'files',
    entries = {
      {
        title = string.format('Commit: %s', commit_hash:sub(1, 7)),
        entries = entries,
      },
    },
    layout_type = layout_type,
  }

  self:destroy()
  event.await()

  display_service.show_diff(data)
end

function BlameView:_refresh_view(blames, lines, target_lnum)
  self:_render_blame(blames)
  self:_render_content(lines, self._opts.filetype)

  if target_lnum then
    local max_lnum = #lines
    if target_lnum > max_lnum then target_lnum = max_lnum end
    if target_lnum < 1 then target_lnum = 1 end

    self._content_component:with_element(function(el)
      el:set_lnum(target_lnum)
    end)
  end
end

function BlameView:get_key(keymap)
  if type(keymap) == 'string' then
    return keymap
  elseif type(keymap) == 'table' then
    return keymap.key
  end
  return nil
end

function BlameView:_setup_keymaps()
  local scene_keymaps = scene_setting:get('keymaps')
  local components = { self._content_component, self._gutter_component }

  if scene_keymaps and scene_keymaps.quit then
    local quit_key = self:get_key(scene_keymaps.quit)
    if quit_key then
      for _, component in ipairs(components) do
        component:set_keymap({
          mode = 'n',
          key = quit_key,
        }, function()
          self:destroy()
        end)
      end
    end
  end

  local enter_fn, enter_cleanup = event.debounce_async(function()
    self:enter_parent()
  end, self.DEBOUNCE_MS)
  table.insert(self._debounce_cleanups, enter_cleanup)

  local back_fn, back_cleanup = event.debounce_async(function()
    self:go_back()
  end, self.DEBOUNCE_MS)
  table.insert(self._debounce_cleanups, back_cleanup)

  local diff_fn, diff_cleanup = event.debounce_async(function()
    self:show_commit_diff()
  end, self.DEBOUNCE_MS)
  table.insert(self._debounce_cleanups, diff_cleanup)

  local project_diff_fn, project_diff_cleanup = event.debounce_async(function()
    self:show_commit_project_diff()
  end, self.DEBOUNCE_MS)
  table.insert(self._debounce_cleanups, project_diff_cleanup)

  local blame_keymaps = blame_view_setting:get('keymaps')

  local blame_down_fn = function()
    self:blame_down()
  end
  local blame_up_fn = function()
    self:blame_up()
  end

  for _, component in ipairs(components) do
    component:set_keymap({
      mode = 'n',
      key = '<CR>',
    }, enter_fn)

    component:set_keymap({
      mode = 'n',
      key = '<BS>',
    }, back_fn)

    component:set_keymap({
      mode = 'n',
      key = 'd',
    }, diff_fn)

    component:set_keymap({
      mode = 'n',
      key = 'D',
    }, project_diff_fn)

    if blame_keymaps and blame_keymaps.down then
      local down_key = self:get_key(blame_keymaps.down)
      if down_key then component:set_keymap({
        mode = 'n',
        key = down_key,
      }, blame_down_fn) end
    end

    if blame_keymaps and blame_keymaps.up then
      local up_key = self:get_key(blame_keymaps.up)
      if up_key then component:set_keymap({
        mode = 'n',
        key = up_key,
      }, blame_up_fn) end
    end
  end
end

function BlameView:destroy()
  if self._destroyed then return end
  self._destroyed = true

  for _, cleanup in ipairs(self._debounce_cleanups) do
    cleanup()
  end
  self._debounce_cleanups = {}

  if self._component_manager then self._component_manager:destroy() end
end

return BlameView
