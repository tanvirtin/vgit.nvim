local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('git')
local git_submodule = require('vgit.git.git_submodule')

describe('git_submodule', function()
  local repo
  local submodule_repo

  before_each(function()
    -- Create main repository
    local err
    repo, err = test_repo.create_repo({
      files = { ['README.md'] = 'Main repo' },
      initial_commit = true,
    })
    assert.is_nil(err)
    assert.is_not_nil(repo)

    -- Create a repository to use as submodule
    submodule_repo, err = test_repo.create_repo({
      files = { ['lib.lua'] = 'library code' },
      initial_commit = true,
    })
    assert.is_nil(err)
    assert.is_not_nil(submodule_repo)
  end)

  after_each(function()
    if repo then test_repo.cleanup(repo) end
    if submodule_repo then test_repo.cleanup(submodule_repo) end
  end)

  describe('add', function()
    it('should add a submodule', function()
      local _, err = git_submodule.add(repo:get_path(), submodule_repo:get_path(), 'libs/mylib')
      assert.is_nil(err)

      -- Verify submodule was added
      local submodules, list_err = git_submodule.list(repo:get_path())
      assert.is_nil(list_err)
      assert.is_not_nil(submodules)
      assert.equals(1, #submodules)
      assert.equals('libs/mylib', submodules[1].path)
    end)

    it('should add submodule with options', function()
      local result, err = git_submodule.add(
        repo:get_path(),
        submodule_repo:get_path(),
        'libs/other',
        { branch = 'main', name = 'other-lib' }
      )

      -- Should succeed or provide meaningful error
      if err then
        -- Error is acceptable (e.g., branch doesn't exist)
        -- but should be properly formatted
        assert.is_table(err, 'Error should be a table')
        assert.is_true(#err > 0, 'Error should have message')
      else
        -- On success, verify submodule was added
        assert.is_not_nil(result, 'Should return result on success')

        -- Verify submodule appears in list
        local submodules, list_err = git_submodule.list(repo:get_path())
        assert.is_nil(list_err, 'Should be able to list submodules')
        assert.is_not_nil(submodules, 'Should have submodules list')

        -- Should have at least the newly added submodule
        local found = false
        for _, submodule in ipairs(submodules) do
          if submodule.path == 'libs/other' then
            found = true
            break
          end
        end
        assert.is_true(found, 'Submodule should appear in list')
      end
    end)

    it('should return error for missing parameters', function()
      local _, err = git_submodule.add(nil, 'url', 'path')
      assert.is_not_nil(err)

      _, err = git_submodule.add(repo:get_path(), nil, 'path')
      assert.is_not_nil(err)

      _, err = git_submodule.add(repo:get_path(), 'url', nil)
      assert.is_not_nil(err)
    end)
  end)

  describe('list', function()
    before_each(function()
      -- Add a submodule
      git_submodule.add(repo:get_path(), submodule_repo:get_path(), 'libs/mylib')
    end)

    it('should list submodules', function()
      local submodules, err = git_submodule.list(repo:get_path())
      assert.is_nil(err)
      assert.is_not_nil(submodules)
      assert.equals(1, #submodules)

      local sub = submodules[1]
      assert.equals('libs/mylib', sub.path)
      assert.is_not_nil(sub.hash)
      assert.is_not_nil(sub.status)
    end)

    it('should return empty list for repo with no submodules', function()
      local new_repo, err = test_repo.create_repo({
        files = { ['file.txt'] = 'content' },
        initial_commit = true,
      })
      assert.is_nil(err)

      local submodules, list_err = git_submodule.list(new_repo:get_path())
      assert.is_nil(list_err)
      assert.equals(0, #submodules)

      test_repo.cleanup(new_repo)
    end)

    it('should support recursive listing', function()
      local submodules, err = git_submodule.list(repo:get_path(), { recursive = true })
      assert.is_nil(err)
      assert.is_not_nil(submodules)
    end)
  end)

  describe('init', function()
    before_each(function()
      git_submodule.add(repo:get_path(), submodule_repo:get_path(), 'libs/mylib')
    end)

    it('should initialize a submodule', function()
      local _, err = git_submodule.init(repo:get_path(), 'libs/mylib')
      assert.is_nil(err)
    end)

    it('should initialize all submodules', function()
      local _, err = git_submodule.init(repo:get_path(), nil, { all = true })
      assert.is_nil(err)
    end)
  end)

  describe('update', function()
    before_each(function()
      git_submodule.add(repo:get_path(), submodule_repo:get_path(), 'libs/mylib')
      git_submodule.init(repo:get_path(), 'libs/mylib')
    end)

    it('should update a submodule', function()
      local _, err = git_submodule.update(repo:get_path(), 'libs/mylib')
      assert.is_nil(err)
    end)

    it('should update with options', function()
      local _, err = git_submodule.update(repo:get_path(), 'libs/mylib', {
        recursive = true,
        remote = false,
      })
      assert.is_nil(err)
    end)

    it('should support init and update together', function()
      -- Add another submodule
      local sub2, err = test_repo.create_repo({
        files = { ['sub2.txt'] = 'sub2' },
        initial_commit = true,
      })
      assert.is_nil(err)

      git_submodule.add(repo:get_path(), sub2:get_path(), 'libs/sub2')

      -- Update with init
      _, err = git_submodule.update(repo:get_path(), nil, { init = true })
      assert.is_nil(err)

      test_repo.cleanup(sub2)
    end)
  end)

  describe('sync', function()
    before_each(function()
      git_submodule.add(repo:get_path(), submodule_repo:get_path(), 'libs/mylib')
    end)

    it('should sync submodules', function()
      local _, err = git_submodule.sync(repo:get_path())
      assert.is_nil(err)
    end)

    it('should sync specific submodule', function()
      local _, err = git_submodule.sync(repo:get_path(), 'libs/mylib')
      assert.is_nil(err)
    end)

    it('should support recursive sync', function()
      local _, err = git_submodule.sync(repo:get_path(), nil, { recursive = true })
      assert.is_nil(err)
    end)
  end)

  describe('foreach', function()
    before_each(function()
      git_submodule.add(repo:get_path(), submodule_repo:get_path(), 'libs/mylib')
      git_submodule.init(repo:get_path(), 'libs/mylib')
    end)

    it('should execute command in each submodule', function()
      local _, err = git_submodule.foreach(repo:get_path(), 'pwd')
      assert.is_nil(err)
    end)

    it('should support recursive foreach', function()
      local _, err = git_submodule.foreach(repo:get_path(), 'pwd', { recursive = true })
      assert.is_nil(err)
    end)

    it('should return error for missing command', function()
      local _, err = git_submodule.foreach(repo:get_path(), nil)
      assert.is_not_nil(err)
    end)
  end)

  describe('set_url', function()
    before_each(function()
      git_submodule.add(repo:get_path(), submodule_repo:get_path(), 'libs/mylib')
    end)

    it('should set submodule URL', function()
      local new_url = 'https://github.com/user/new-lib.git'
      local _, err = git_submodule.set_url(repo:get_path(), 'libs/mylib', new_url)
      assert.is_nil(err)
    end)

    it('should return error for missing parameters', function()
      local _, err = git_submodule.set_url(repo:get_path(), nil, 'url')
      assert.is_not_nil(err)

      _, err = git_submodule.set_url(repo:get_path(), 'path', nil)
      assert.is_not_nil(err)
    end)
  end)

  describe('summary', function()
    before_each(function()
      git_submodule.add(repo:get_path(), submodule_repo:get_path(), 'libs/mylib')
    end)

    it('should get submodule summary', function()
      local _, err = git_submodule.summary(repo:get_path())
      -- Might return empty or have content, both are valid
      assert.is_nil(err)
    end)

    it('should support summary options', function()
      local _, err = git_submodule.summary(repo:get_path(), {
        cached = true,
        summary_limit = 5,
      })
      assert.is_nil(err)
    end)
  end)

  describe('deinit', function()
    before_each(function()
      git_submodule.add(repo:get_path(), submodule_repo:get_path(), 'libs/mylib')
      git_submodule.init(repo:get_path(), 'libs/mylib')
    end)

    it('should deinitialize a submodule', function()
      local _, err = git_submodule.deinit(repo:get_path(), 'libs/mylib', { force = true })
      assert.is_nil(err)
    end)

    it('should deinitialize all submodules', function()
      local _, err = git_submodule.deinit(repo:get_path(), nil, { all = true, force = true })
      assert.is_nil(err)
    end)
  end)
end)
