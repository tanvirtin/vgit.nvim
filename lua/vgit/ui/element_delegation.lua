local function define_single_element_methods(Class)
  -- Chainable methods

  function Class:set_lines(lines)
    self:with_element(function(el)
      el:set_lines(lines)
    end)
    return self
  end

  function Class:clear_lines()
    self:with_element(function(el)
      el:clear_lines()
    end)
    return self
  end

  function Class:set_cursor(cursor)
    self:with_element(function(el)
      el:set_cursor(cursor)
    end)
    return self
  end

  function Class:set_lnum(lnum)
    self:with_element(function(el)
      el:set_lnum(lnum)
    end)
    return self
  end

  function Class:scroll_to(pos, offset)
    self:with_element(function(el)
      el:scroll_to(pos, offset)
    end)
    return self
  end

  function Class:reset_cursor()
    self:with_element(function(el)
      el:reset_cursor()
    end)
    return self
  end

  function Class:set_width(width)
    self:with_element(function(el)
      el:set_width(width)
    end)
    return self
  end

  function Class:set_height(height)
    self:with_element(function(el)
      el:set_height(height)
    end)
    return self
  end

  function Class:focus()
    self:with_element(function(el)
      el:focus()
    end)
    return self
  end

  function Class:start_insert()
    self:with_element(function(el)
      el:start_insert()
    end)
    return self
  end

  function Class:stop_insert()
    self:with_element(function(el)
      el:stop_insert()
    end)
    return self
  end

  function Class:set_filetype(filetype)
    self:with_element(function(el)
      el:set_filetype(filetype)
    end)
    return self
  end

  function Class:clear_extmarks()
    self:with_element(function(el)
      el:clear_extmarks()
    end)
    return self
  end

  function Class:clear_extmark_lnums()
    self:with_element(function(el)
      el:clear_extmark_lnums()
    end)
    return self
  end

  function Class:clear_extmark_texts()
    self:with_element(function(el)
      el:clear_extmark_texts()
    end)
    return self
  end

  function Class:clear_extmark_signs()
    self:with_element(function(el)
      el:clear_extmark_signs()
    end)
    return self
  end

  function Class:clear_extmark_highlights(...)
    local args = { ... }
    self:with_element(function(el)
      el:clear_extmark_highlights(unpack(args))
    end)
    return self
  end

  function Class:set_keymap(opts_or_mode, callback_or_key, handler, desc)
    self:with_element(function(el)
      el:set_keymap(opts_or_mode, callback_or_key, handler, desc)
    end)
    return self
  end

  function Class:on(event_name, callback)
    self:with_element(function(el)
      el:on(event_name, callback)
    end)
    return self
  end

  function Class:attach_to_changes(callback)
    self:with_element(function(el)
      el:attach_to_changes(callback)
    end)
    return self
  end

  function Class:call(callback)
    self:with_element(function(el)
      el:call(callback)
    end)
    return self
  end

  function Class:set_win_option(key, value)
    self:with_element(function(el)
      el:set_win_option(key, value)
    end)
    return self
  end

  function Class:enable_cursorline()
    self:with_element(function(el)
      el:enable_cursorline()
    end)
    return self
  end

  function Class:disable_cursorline()
    self:with_element(function(el)
      el:disable_cursorline()
    end)
    return self
  end

  function Class:attach_to_renderer(callback)
    self:with_element(function(el)
      el:attach_to_renderer(callback)
    end)
    return self
  end

  function Class:detach_from_renderer()
    self:with_element(function(el)
      el:detach_from_renderer()
    end)
    return self
  end

  -- Return-value methods

  function Class:get_lines()
    return self:with_element(function(el)
      return el:get_lines()
    end)
  end

  function Class:get_line_count()
    return self:with_element(function(el)
      return el:get_line_count()
    end)
  end

  function Class:get_cursor()
    return self:with_element(function(el)
      return el:get_cursor()
    end)
  end

  function Class:get_lnum()
    return self:with_element(function(el)
      return el:get_lnum()
    end)
  end

  function Class:get_width()
    return self:with_element(function(el)
      return el:get_width()
    end)
  end

  function Class:get_height()
    return self:with_element(function(el)
      return el:get_height()
    end)
  end

  function Class:get_filetype()
    return self:with_element(function(el)
      return el:get_filetype()
    end)
  end

  function Class:is_focused()
    return self:with_element(function(el)
      return el:is_focused()
    end)
  end

  function Class:is_valid()
    return self:with_element(function()
      return true
    end) or false
  end

  function Class:place_extmark_text(opts)
    if self._element and self._element:is_valid() then return self._element:place_extmark_text(opts) end
  end

  function Class:place_extmark_lnum(opts)
    if self._element and self._element:is_valid() then return self._element:place_extmark_lnum(opts) end
  end

  function Class:place_extmark_sign(opts)
    if self._element and self._element:is_valid() then return self._element:place_extmark_sign(opts) end
  end

  function Class:place_extmark_highlight(opts)
    if self._element and self._element:is_valid() then return self._element:place_extmark_highlight(opts) end
  end
end

return define_single_element_methods
