local GitStatusStream = require('vgit.git.GitStatusStream')

local eq = assert.are.same

describe('GitStatusStream:', function()
  local directories = {}

  local function repo_with(entries, branch)
    local path = vim.fn.tempname()
    directories[#directories + 1] = path
    vim.fn.mkdir(path .. '/.git', 'p')
    vim.fn.writefile({ 'ref: refs/heads/' .. branch }, path .. '/.git/HEAD')

    local repo = { finished = true }
    repo.get_path = function()
      return path
    end
    repo.start_status = function()
      return {
        is_done = function()
          return repo.finished
        end,
        wait = function()
          return { entries = entries }
        end,
      }
    end
    return repo
  end

  after_each(function()
    for _, path in ipairs(directories) do
      vim.fn.delete(path, 'rf')
    end
    directories = {}
  end)

  it('should give every repo with its branch once all statuses finish', function()
    local changed = repo_with({ { title = 'Changes', entries = {} } }, 'main')
    local clean = repo_with({}, 'feature')

    local groups = GitStatusStream({ changed, clean }):wait()

    eq(2, #groups)
    assert.are.equal(changed, groups[1].repo)
    eq('main', groups[1].branch)
    eq('Changes', groups[1].entries[1].title)
    eq(0, #groups[2].entries)
  end)

  it('should collect only the repos whose status finished', function()
    local slow = repo_with({}, 'main')
    slow.finished = false
    local fast = repo_with({}, 'feature')

    local stream = GitStatusStream({ slow, fast })

    local first = stream:collect()
    eq(1, #first)
    eq('feature', first[1].branch)
    assert.is_false(stream:is_done())

    slow.finished = true
    eq(1, #stream:collect())
    assert.is_true(stream:is_done())
  end)

  it('should keep only the sections it is asked for', function()
    local repo = repo_with({ { title = 'Staged Changes', entries = {} }, { title = 'Changes', entries = {} } }, 'main')

    local groups = GitStatusStream({ repo }, {
      select_sections = function(sections)
        return { sections[2] }
      end,
    }):wait()

    eq({ { title = 'Changes', entries = {} } }, groups[1].entries)
  end)

  it('should run at most MAX_RUNNING statuses at once', function()
    local started = 0
    local repos = {}
    for i = 1, GitStatusStream.MAX_RUNNING + 2 do
      repos[i] = repo_with({}, 'main')
      local start_status = repos[i].start_status
      repos[i].start_status = function()
        started = started + 1
        return start_status()
      end
      repos[i].finished = false
    end

    local stream = GitStatusStream(repos)
    stream:collect()

    eq(GitStatusStream.MAX_RUNNING, started)
  end)
end)
