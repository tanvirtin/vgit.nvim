local mock = require('luassert.mock')
local logger = require('vgit.logger')

local it = it
local describe = describe
local before_each = before_each
local after_each = after_each
local eq = assert.are.same

describe('setup', function()
    it('should override state highlights with highlights specified through the config', function()
        logger.setup({
            debug = true,
        })
        eq(logger.state:get('debug'), true)
    end)
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

describe('debug', function()
    it('should not store messages if debug state is turned off', function()
        logger.setup({
            debug = false,
            debug_logs = {},
        })
        for i = 1, 100 do
            logger.debug(string.format('foo bar - %s', i))
        end
        eq(logger.state:get('debug_logs'), {})
    end)

    it('should store messages if debug state is turned on', function()
        logger.setup({
            debug = true,
            debug_logs = {},
        })
        for i = 1, 2 do
            logger.debug(string.format('foo bar - %s', i))
        end
        eq(logger.state:get('debug_logs'), {
            string.format('VGit[%s][unknown]: %s', os.date('%H:%M:%S'), vim.fn.escape('foo bar - 1', '"')),
            string.format('VGit[%s][unknown]: %s', os.date('%H:%M:%S'), vim.fn.escape('foo bar - 2', '"')),
        })
    end)

    it('should show unknown as source if no fn source is provided', function()
        logger.setup({
            debug = true,
            debug_logs = {},
        })
        for i = 1, 2 do
            logger.debug(string.format('foo bar - %s', i))
        end
        eq(logger.state:get('debug_logs'), {
            string.format('VGit[%s][unknown]: %s', os.date('%H:%M:%S'), vim.fn.escape('foo bar - 1', '"')),
            string.format('VGit[%s][unknown]: %s', os.date('%H:%M:%S'), vim.fn.escape('foo bar - 2', '"')),
        })
    end)

    it('should be able to accept a table as an input and concatenate the strings together', function()
        logger.setup({
            debug = true,
            debug_logs = {},
        })
        logger.debug({
            'foo',
            'bar',
            'baz',
        })
        eq(logger.state:get('debug_logs'), {
            string.format('VGit[%s][unknown]: %s', os.date('%H:%M:%S'), vim.fn.escape('foo, bar, baz', '"')),
        })
    end)

    it('should show fn source if provided', function()
        logger.setup({
            debug = true,
            debug_logs = {},
        })
        logger.debug({
            'foo',
            'bar',
            'baz',
        }, 'logger_spec')
        eq(logger.state:get('debug_logs'), {
            string.format('VGit[%s][logger_spec]: %s', os.date('%H:%M:%S'), vim.fn.escape('foo, bar, baz', '"')),
        })
    end)
end)
