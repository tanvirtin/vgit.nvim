local localization = require('vgit.localization')

local it = it
local describe = describe
local eq = assert.are.same

describe('localization:', function()

    describe('setup', function()

        it('should override state highlights with highlights specified through the config', function()
            localization.setup({
                error = 'foo',
                preview = {
                    horizontal = 'foo',
                    current = 'bar',
                    previous = 'baz',
                },
            })
            eq(localization.state:get('error'), 'foo')
            eq(localization.state:get('preview'), {
                horizontal = 'foo',
                current = 'bar',
                previous = 'baz',
            })
        end)

    end)

    describe('translate', function()

        it('should throw error on invalid argument types', function()
            localization.setup({
                error = 'foo'
            })
            assert.has_error(function()
                localization.translate(true)
            end)
            assert.has_error(function()
                localization.translate({})
            end)
            assert.has_error(function()
                localization.translate(1)
            end)
            assert.has_error(function()
                localization.translate(nil)
            end)
            assert.has_error(function()
                localization.translate(function() end)
            end)
        end)

        it('should retrieve the translation for a given key', function()
            localization.setup({
                error = 'foo',
            })
            eq(localization.translate('error'), 'foo');
        end)

        it('should retrieve nested translation', function()
            localization.setup({
                preview = {
                    horizontal = 'foo',
                    current = 'bar',
                    previous = 'baz',
                },
            })
            eq(localization.translate('preview/current'), 'bar')
            eq(localization.translate('preview/horizontal'), 'foo')
            eq(localization.translate('preview/previous'), 'baz')
        end)

        it('should throw an error if a key does not exist in translation', function()
            localization.setup()
            assert.has_error(function()
                localization.translate('foo')
            end)
        end)

        it('should handle string formatting', function()
            localization.setup({
                preview = {
                    horizontal = 'foo %s',
                },
            })
            eq(localization.translate('preview/horizontal', 'bar'), 'foo bar')
        end)

    end)

end)
