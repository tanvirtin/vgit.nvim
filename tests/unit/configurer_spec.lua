local configurer = require('vgit.configurer')

local it = it
local describe = describe

describe('configurer:', function()

      describe('assign', function()

        it('should not assign attributes into into state which are not in it', function()
            local state = configurer.assign({
                foo = true,
            }, {
                foo = false,
                bar = true,
            });
            assert.are.same(state, { foo = false });
        end)

        it('should return unmodified state when nil value is passed', function()
            local state = configurer.assign({
                foo = true,
                bar = true,
            }, nil)
            assert.are.same(state, {
                foo = true,
                bar = true,
            })
        end)

        it('should throw error when there is a type mismatch', function()
            assert.has_error(function()
                configurer.assign({
                    foo = true,
                    bar = {
                        baz = {
                            a = {
                                b = {}
                            },
                            foo = {
                                bar = {
                                    baz = true
                                },
                                a = {
                                    c = 4
                                }
                            }
                        }
                    }
                    }, {
                    foo = 'what',
                    bar = {
                        baz = {
                            foo = {
                                bar = {
                                    baz = false
                                },
                            }
                        }
                    }
                })
            end)
        end)

        it('should successfully assign nested objects', function()
            local state = configurer.assign({
                foo = true,
                bar = {
                    baz = {
                        a = {
                            b = {}
                        },
                        foo = {
                            bar = {
                                baz = true
                            },
                            a = {
                                c = 4
                            }
                        }
                    }
                }
            }, {
                foo = false,
                bar = {
                    baz = {
                        foo = {
                            bar = {
                                baz = false
                            },
                        }
                    }
                }
            });
            assert.are.same(state, {
                foo = false,
                bar = {
                    baz = {
                        a = {
                            b = {}
                        },
                        foo = {
                            bar = {
                                baz = false
                            },
                            a = {
                                c = 4
                            }
                        }
                    }
                }
            });
        end)

    end)

end)
