local mock = require('luassert.mock')
local logger = require('vgit.logger')

local it = it
local describe = describe
local before_each = before_each
local after_each = after_each
local eq = assert.are.same

describe('setup', function()
  it(
    'should override state highlights with highlights specified through the config',
    function()
      logger.setup({
        debug = true,
      })
      eq(logger.state:get('debug'), true)
    end
  )
end)

describe('info', function()
  before_each(function()
    vim.notify = mock(vim.notify, true)
    vim.notify.returns(5)
  end)

  after_each(function()
    mock.revert(vim.notify)
  end)

  it('should call notify passing in the appropriate arguments', function()
    logger.info('hello')
    assert.stub(vim.notify).was_called_with('hello', 'info')
  end)
end)

describe('warn', function()
  before_each(function()
    vim.notify = mock(vim.notify, true)
    vim.notify.returns(5)
  end)

  after_each(function()
    mock.revert(vim.notify)
  end)

  it('should call notify passing in the appropriate arguments', function()
    logger.warn('hello')
    assert.stub(vim.notify).was_called_with('hello', 'warn')
  end)
end)

describe('error', function()
  before_each(function()
    vim.notify = mock(vim.notify, true)
    vim.notify.returns(5)
  end)

  after_each(function()
    mock.revert(vim.notify)
  end)

  it('should call notify passing in the appropriate arguments', function()
    logger.error('hello')
    assert.stub(vim.notify).was_called_with('hello', 'error')
  end)
end)
