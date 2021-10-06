local mock = require('luassert.mock')
local buffer = require('vgit.buffer')

local it = it
local describe = describe
local after_each = after_each
local before_each = before_each
local eq = assert.are.same
local api = nil

describe('current', function()
  before_each(function()
    api = mock(vim.api, true)
    api.nvim_get_current_buf.returns(5)
  end)

  after_each(function()
    mock.revert(api)
  end)

  it(
    'should call nvim_get_current_buf to retrieve the current buffer',
    function()
      eq(buffer.current(), 5)
      assert.stub(api.nvim_get_current_buf).was_called_with()
    end
  )
end)

describe('is_valid', function()
  before_each(function()
    api = mock(vim.api, true)
    api.nvim_buf_is_valid.returns(true)
    api.nvim_buf_is_loaded.returns(true)
  end)

  after_each(function()
    mock.revert(api)
  end)

  it(
    'should call nvim_buf_is_valid and nvim_buf_is_loaded with correct arguments',
    function()
      eq(buffer.is_valid(1), true)
      assert.stub(api.nvim_buf_is_valid).was_called_with(1)
      assert.stub(api.nvim_buf_is_loaded).was_called_with(1)
    end
  )
end)

describe('get_lines', function()
  before_each(function()
    api = mock(vim.api, true)
    api.nvim_buf_get_lines.returns({ 'foo', 'bar' })
  end)

  after_each(function()
    mock.revert(api)
  end)

  it('should call nvim_buf_get_lines with correct arguments', function()
    eq(buffer.get_lines(1), { 'foo', 'bar' })
    assert.stub(api.nvim_buf_get_lines).was_called_with(1, 0, -1, false)
  end)

  it(
    'should call nvim_buf_get_lines with specified start and end with correct arguments',
    function()
      eq(buffer.get_lines(1, 22, 33), { 'foo', 'bar' })
      assert.stub(api.nvim_buf_get_lines).was_called_with(1, 22, 33, false)
    end
  )
end)

describe('set_lines', function()
  before_each(function()
    api = mock(vim.api, true)
    api.nvim_buf_set_lines.returns()
  end)

  after_each(function()
    mock.revert(api)
  end)

  it(
    'should call nvim_buf_set_lines and nvim_buf_get_option with correct arguments',
    function()
      api.nvim_buf_get_option.returns(true)
      buffer.set_lines(29, { 'foo', 'bar' })
      assert.stub(api.nvim_buf_set_lines).was_called_with(
        29,
        0,
        -1,
        false,
        { 'foo', 'bar' }
      )
      assert.stub(api.nvim_buf_get_option).was_called_with(29, 'modifiable')
      assert.stub(api.nvim_buf_set_option).was_not_called_with(
        29,
        'modifiable',
        false
      )
    end
  )

  it(
    'should call nvim_buf_set_lines, nvim_buf_get_option and nvim_buf_set_option with correct arguments',
    function()
      api.nvim_buf_get_option.returns(false)
      buffer.set_lines(29, { 'foo', 'bar' })
      assert.stub(api.nvim_buf_set_lines).was_called_with(
        29,
        0,
        -1,
        false,
        { 'foo', 'bar' }
      )
      assert.stub(api.nvim_buf_get_option).was_called_with(29, 'modifiable')
      assert.stub(api.nvim_buf_set_option).was_called_with(
        29,
        'modifiable',
        false
      )
    end
  )
end)

describe('assign_options', function()
  before_each(function()
    api = mock(vim.api, true)
    api.nvim_buf_set_option.returns()
  end)

  after_each(function()
    mock.revert(api)
  end)

  it('should call nvim_buf_set_option with correct arguments', function()
    local buf = 15
    buffer.assign_options(buf, {
      foo = 'bar',
      bar = 'foo',
      baz = 'jaz',
    })
    assert.stub(api.nvim_buf_set_option).was_called_with(buf, 'foo', 'bar')
    assert.stub(api.nvim_buf_set_option).was_called_with(buf, 'bar', 'foo')
    assert.stub(api.nvim_buf_set_option).was_called_with(buf, 'baz', 'jaz')
  end)
end)

describe('add_keymap', function()
  before_each(function()
    api = mock(vim.api, true)
    api.nvim_buf_set_keymap.returns()
  end)

  after_each(function()
    mock.revert(api)
  end)

  it('should call nvim_buf_set_keymap with correct arguments', function()
    local buf = 15
    buffer.add_keymap(buf, '<enter>', '_rerender_history()')
    assert.stub(api.nvim_buf_set_keymap).was_called_with(
      buf,
      'n',
      '<enter>',
      ':lua require("vgit")._rerender_history()<CR>',
      {
        silent = true,
        noremap = true,
      }
    )
  end)
end)
