local GitTask = require('vgit.git.GitTask')

local eq = assert.are.same

describe('GitTask:', function()
  local function task_of(completed)
    return {
      completed = function()
        return completed
      end,
    }
  end

  local function resolving(...)
    local results = { ... }
    local count = select('#', ...)
    return function()
      return unpack(results, 1, count)
    end
  end

  it('should report whether the underlying task completed', function()
    assert.is_true(GitTask(task_of(true), resolving()):is_done())
    assert.is_false(GitTask(task_of(false), resolving()):is_done())
  end)

  it('should wait for the resolved result', function()
    local result, err, code = GitTask(task_of(true), resolving({ 'line' }, nil, 0)):wait()

    eq({ 'line' }, result)
    assert.is_nil(err)
    eq(0, code)
  end)

  it('should map the result and share the task', function()
    local task = task_of(false)
    local mapped = GitTask(task, resolving({ 'a', 'b' })):map(function(lines)
      return #lines
    end)

    assert.is_false(mapped:is_done())
    eq(2, mapped:wait())
  end)

  it('should pass errors through a map untouched', function()
    local called = false
    local mapped = GitTask(task_of(true), resolving(nil, { 'boom' })):map(function()
      called = true
    end)

    local result, err = mapped:wait()

    assert.is_nil(result)
    eq({ 'boom' }, err)
    assert.is_false(called)
  end)
end)
