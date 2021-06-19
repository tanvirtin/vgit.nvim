local State = require('vgit.State')

local it = it
local describe = describe
local before_each = before_each
local eq = assert.are.same

describe('State:', function()
    local initial_state = {}

    before_each(function()
        initial_state = {
            foo = 'bar',
            bar = 'foo',
            baz = {
                foo = 'bar',
                bar = 'foo',
            }
        }
    end)

    describe('new', function()

        it('should bind the object provided into into the state object', function()
            local state = State.new(initial_state)
            eq(state, {
                current = initial_state,
                initial = initial_state
            })
        end)

        it('should throw error if invalid data type is provided', function()
            assert.has_error(function()
                State.new(42)
            end)
        end)

    end)

    describe('get', function()

        it('should succesfully retrieve a value given a key from the state object', function()
            local state = State.new(initial_state)
            eq(state:get('foo'), 'bar')
            eq(state:get('bar'), 'foo')
            eq(state:get('baz'), {
                foo = 'bar',
                bar = 'foo'
            })
        end)

        it('should throw an error if a state object does not have the given key', function()
            local state = State.new(initial_state)
            assert.has_error(function()
                eq(state:get('test'), nil)
            end)
        end)

    end)

    describe('set', function()

        it('should alter an existing state attribute', function()
            local state = State.new(initial_state)
            state:set('foo', 'a')
            state:set('bar', 'b')
            state:set('baz', {
                test1 = 1,
                test2 = 2,
            })
            eq(state:get('foo'), 'a')
            eq(state:get('bar'), 'b')
            eq(state:get('baz'), {
                test1 = 1,
                test2 = 2,
            })
        end)

        it('should not change the state attribute if no values are present', function()
            local state = State.new(initial_state)
            for i = 10, 1, -1 do
                assert.has_error(function()
                    state:set(i, i)
                end)
            end
            eq(state, {
                current = initial_state,
                initial = initial_state,
            })
        end)

    end)

    describe('assign', function()

        it('should not assign attributes into into state which are not in it', function()
            local initial = { foo = true }
            local state = State.new(initial)
            state:assign({
                foo = false,
                bar = true,
            });
            eq(state, {
                initial = initial,
                current = { foo = false },
            });
        end)

        it('should return unmodified state when nil value is passed', function()
            local initial = { foo = true }
            local state = State.new(initial)
            state:assign(nil);
            eq(state, {
                initial = initial,
                current = initial,
            });
        end)


        it('should assign tables which are lists', function()
            local initial = {
                is_list = { 1, 2, 3, 4, 5 },
                isnt_list = { a = 1, b = 2 }
            }
            local state = State.new(initial)
            state:assign({
                is_list = { 'a', 'b' },
                isnt_list = { a = 1, b = 2 }
            });
            eq(state, {
                initial = initial,
                current = {
                    is_list = { 'a', 'b' },
                    isnt_list = { a = 1, b = 2 }
                },
            });
        end)

        it('should throw error when there is a type mismatch', function()
            local state = State.new({
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
            })
            assert.has_error(function()
                state:assign({
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
            local initial = {
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
            }
            local state = State.new(initial)
            state:assign({
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
            local current = {
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
            }
            eq(state, {
                initial = initial,
                current = current
            });
        end)

    end)

end)
