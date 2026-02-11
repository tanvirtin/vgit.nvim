-- Mock GitQueryBuilder before requiring git_submodule
local captured_args = {}
local captured_reponame = nil
local mock_execute_result = nil
local mock_execute_err = nil

local real_builder = package.loaded['vgit.git.GitQueryBuilder']
package.loaded['vgit.git.GitQueryBuilder'] = setmetatable({}, {
  __call = function(_, reponame)
    captured_reponame = reponame
    captured_args = {}
    local builder = {}
    local mt = {
      __index = function(_, key)
        if key == 'execute' then
          return function()
            return mock_execute_result, mock_execute_err
          end
        end
        return function(self, ...)
          local args = { ... }
          for _, a in ipairs(args) do
            captured_args[#captured_args + 1] = tostring(a)
          end
          return self
        end
      end,
    }
    setmetatable(builder, mt)
    return builder
  end,
})

local git_submodule = require('vgit.git.git_submodule')

local eq = assert.are.same

describe('git_submodule:', function()
  before_each(function()
    captured_args = {}
    captured_reponame = nil
    mock_execute_result = nil
    mock_execute_err = nil
  end)

  after_each(function()
    -- nothing to clean up
  end)

  -- Restore real builder on teardown
  teardown(function()
    package.loaded['vgit.git.GitQueryBuilder'] = real_builder
    package.loaded['vgit.git.git_submodule'] = nil
  end)

  describe('list()', function()
    it('should error when reponame is nil', function()
      local result, err = git_submodule.list(nil)
      assert.is_nil(result)
      eq({ 'reponame is required' }, err)
    end)

    it('should propagate execute error', function()
      mock_execute_err = { 'something went wrong' }
      local result, err = git_submodule.list('/repo')
      assert.is_nil(result)
      eq({ 'something went wrong' }, err)
    end)

    it('should handle empty output', function()
      mock_execute_result = {}
      local result, err = git_submodule.list('/repo')
      assert.is_nil(err)
      eq({}, result)
    end)

    it('should parse initialized submodule (space prefix)', function()
      mock_execute_result = {
        ' abc1234567890abcdef1234567890abcdef123456 path/to/sub (v1.0)',
      }
      local result, err = git_submodule.list('/repo')
      assert.is_nil(err)
      eq(1, #result)
      eq('initialized', result[1].status)
      eq('abc1234567890abcdef1234567890abcdef123456', result[1].hash)
      eq('path/to/sub', result[1].path)
      eq('v1.0', result[1].ref)
    end)

    it('should parse uninitialized submodule (- prefix)', function()
      mock_execute_result = {
        '-abc123def456 lib/dependency',
      }
      local result, err = git_submodule.list('/repo')
      assert.is_nil(err)
      eq(1, #result)
      eq('uninitialized', result[1].status)
      eq('abc123def456', result[1].hash)
      eq('lib/dependency', result[1].path)
      assert.is_nil(result[1].ref)
    end)

    it('should parse modified submodule (+ prefix)', function()
      mock_execute_result = {
        '+abc123def456 vendor/pkg (heads/main)',
      }
      local result, err = git_submodule.list('/repo')
      assert.is_nil(err)
      eq(1, #result)
      eq('modified', result[1].status)
      eq('abc123def456', result[1].hash)
      eq('vendor/pkg', result[1].path)
      eq('heads/main', result[1].ref)
    end)

    it('should parse conflicts submodule (U prefix)', function()
      mock_execute_result = {
        'Uabc123def456 ext/conflict (v2.3)',
      }
      local result, err = git_submodule.list('/repo')
      assert.is_nil(err)
      eq(1, #result)
      eq('conflicts', result[1].status)
      eq('abc123def456', result[1].hash)
      eq('ext/conflict', result[1].path)
      eq('v2.3', result[1].ref)
    end)

    it('should parse submodule without ref tag', function()
      mock_execute_result = {
        ' abc123def456 path/no/ref',
      }
      local result, err = git_submodule.list('/repo')
      assert.is_nil(err)
      eq(1, #result)
      eq('initialized', result[1].status)
      eq('abc123def456', result[1].hash)
      eq('path/no/ref', result[1].path)
      assert.is_nil(result[1].ref)
    end)

    it('should handle multiple submodules', function()
      mock_execute_result = {
        ' aaa111 sub1 (v1.0)',
        '-bbb222 sub2',
        '+ccc333 sub3 (v2.0)',
        'Uddd444 sub4 (v3.0)',
      }
      local result, err = git_submodule.list('/repo')
      assert.is_nil(err)
      eq(4, #result)

      eq('initialized', result[1].status)
      eq('aaa111', result[1].hash)
      eq('sub1', result[1].path)
      eq('v1.0', result[1].ref)

      eq('uninitialized', result[2].status)
      eq('bbb222', result[2].hash)
      eq('sub2', result[2].path)
      assert.is_nil(result[2].ref)

      eq('modified', result[3].status)
      eq('ccc333', result[3].hash)
      eq('sub3', result[3].path)
      eq('v2.0', result[3].ref)

      eq('conflicts', result[4].status)
      eq('ddd444', result[4].hash)
      eq('sub4', result[4].path)
      eq('v3.0', result[4].ref)
    end)

    it('should pass --recursive option', function()
      mock_execute_result = {}
      git_submodule.list('/repo', { recursive = true })
      assert.is_not_nil(captured_reponame)
      -- captured_args should include: 'submodule', 'status', '--recursive'
      eq('submodule', captured_args[1])
      eq('status', captured_args[2])
      eq('--recursive', captured_args[3])
    end)

    it('should pass --cached option', function()
      mock_execute_result = {}
      git_submodule.list('/repo', { cached = true })
      eq('submodule', captured_args[1])
      eq('status', captured_args[2])
      eq('--cached', captured_args[3])
    end)
  end)

  describe('add()', function()
    it('should error when reponame is nil', function()
      local result, err = git_submodule.add(nil, 'url', 'path')
      assert.is_nil(result)
      eq({ 'reponame is required' }, err)
    end)

    it('should error when url is nil', function()
      local result, err = git_submodule.add('/repo', nil, 'path')
      assert.is_nil(result)
      eq({ 'url is required' }, err)
    end)

    it('should error when path is nil', function()
      local result, err = git_submodule.add('/repo', 'https://example.com/repo.git', nil)
      assert.is_nil(result)
      eq({ 'path is required' }, err)
    end)

    it('should pass basic args: submodule, add, url, path', function()
      mock_execute_result = {}
      git_submodule.add('/repo', 'https://example.com/repo.git', 'lib/sub')
      eq('/repo', captured_reponame)
      eq({
        'submodule',
        'add',
        'https://example.com/repo.git',
        'lib/sub',
      }, captured_args)
    end)

    it('should pass force option', function()
      mock_execute_result = {}
      git_submodule.add('/repo', 'https://example.com/repo.git', 'lib/sub', { force = true })
      eq({
        'submodule',
        'add',
        '-f',
        'https://example.com/repo.git',
        'lib/sub',
      }, captured_args)
    end)

    it('should pass force option via f alias', function()
      mock_execute_result = {}
      git_submodule.add('/repo', 'https://example.com/repo.git', 'lib/sub', { f = true })
      eq({
        'submodule',
        'add',
        '-f',
        'https://example.com/repo.git',
        'lib/sub',
      }, captured_args)
    end)

    it('should pass branch option', function()
      mock_execute_result = {}
      git_submodule.add('/repo', 'https://example.com/repo.git', 'lib/sub', { branch = 'develop' })
      eq({
        'submodule',
        'add',
        '-b',
        'develop',
        'https://example.com/repo.git',
        'lib/sub',
      }, captured_args)
    end)

    it('should pass branch option via b alias', function()
      mock_execute_result = {}
      git_submodule.add('/repo', 'https://example.com/repo.git', 'lib/sub', { b = 'main' })
      eq({
        'submodule',
        'add',
        '-b',
        'main',
        'https://example.com/repo.git',
        'lib/sub',
      }, captured_args)
    end)

    it('should pass depth option', function()
      mock_execute_result = {}
      git_submodule.add('/repo', 'https://example.com/repo.git', 'lib/sub', { depth = 1 })
      eq({
        'submodule',
        'add',
        '--depth',
        '1',
        'https://example.com/repo.git',
        'lib/sub',
      }, captured_args)
    end)

    it('should pass name option', function()
      mock_execute_result = {}
      git_submodule.add('/repo', 'https://example.com/repo.git', 'lib/sub', { name = 'my-sub' })
      eq({
        'submodule',
        'add',
        '--name',
        'my-sub',
        'https://example.com/repo.git',
        'lib/sub',
      }, captured_args)
    end)

    it('should pass reference option', function()
      mock_execute_result = {}
      git_submodule.add('/repo', 'https://example.com/repo.git', 'lib/sub', { reference = '/local/mirror' })
      eq({
        'submodule',
        'add',
        '--reference',
        '/local/mirror',
        'https://example.com/repo.git',
        'lib/sub',
      }, captured_args)
    end)

    it('should pass all options together', function()
      mock_execute_result = {}
      git_submodule.add('/repo', 'https://example.com/repo.git', 'lib/sub', {
        force = true,
        branch = 'develop',
        depth = 5,
        name = 'my-sub',
        reference = '/mirror',
      })
      eq({
        'submodule',
        'add',
        '-f',
        '-b',
        'develop',
        '--depth',
        '5',
        '--name',
        'my-sub',
        '--reference',
        '/mirror',
        'https://example.com/repo.git',
        'lib/sub',
      }, captured_args)
    end)
  end)

  describe('init()', function()
    it('should error when reponame is nil', function()
      local result, err = git_submodule.init(nil)
      assert.is_nil(result)
      eq({ 'reponame is required' }, err)
    end)

    it('should pass submodule init args', function()
      mock_execute_result = {}
      git_submodule.init('/repo')
      eq('/repo', captured_reponame)
      eq({ 'submodule', 'init' }, captured_args)
    end)

    it('should pass --all option', function()
      mock_execute_result = {}
      git_submodule.init('/repo', nil, { all = true })
      eq({ 'submodule', 'init', '--all' }, captured_args)
    end)

    it('should pass a string path', function()
      mock_execute_result = {}
      git_submodule.init('/repo', 'lib/sub')
      eq({ 'submodule', 'init', 'lib/sub' }, captured_args)
    end)

    it('should pass a table of paths', function()
      mock_execute_result = {}
      git_submodule.init('/repo', { 'lib/sub1', 'lib/sub2' })
      eq({ 'submodule', 'init', 'lib/sub1', 'lib/sub2' }, captured_args)
    end)
  end)

  describe('deinit()', function()
    it('should error when reponame is nil', function()
      local result, err = git_submodule.deinit(nil)
      assert.is_nil(result)
      eq({ 'reponame is required' }, err)
    end)

    it('should pass submodule deinit args', function()
      mock_execute_result = {}
      git_submodule.deinit('/repo')
      eq({ 'submodule', 'deinit' }, captured_args)
    end)

    it('should pass force option', function()
      mock_execute_result = {}
      git_submodule.deinit('/repo', nil, { force = true })
      eq({ 'submodule', 'deinit', '-f' }, captured_args)
    end)

    it('should pass force option via f alias', function()
      mock_execute_result = {}
      git_submodule.deinit('/repo', nil, { f = true })
      eq({ 'submodule', 'deinit', '-f' }, captured_args)
    end)

    it('should pass --all option', function()
      mock_execute_result = {}
      git_submodule.deinit('/repo', nil, { all = true })
      eq({ 'submodule', 'deinit', '--all' }, captured_args)
    end)

    it('should pass string path', function()
      mock_execute_result = {}
      git_submodule.deinit('/repo', 'lib/sub')
      eq({ 'submodule', 'deinit', 'lib/sub' }, captured_args)
    end)

    it('should pass table of paths', function()
      mock_execute_result = {}
      git_submodule.deinit('/repo', { 'lib/sub1', 'lib/sub2' })
      eq({ 'submodule', 'deinit', 'lib/sub1', 'lib/sub2' }, captured_args)
    end)

    it('should pass force and paths together', function()
      mock_execute_result = {}
      git_submodule.deinit('/repo', { 'lib/sub1' }, { force = true, all = true })
      eq({ 'submodule', 'deinit', '-f', '--all', 'lib/sub1' }, captured_args)
    end)
  end)

  describe('update()', function()
    it('should error when reponame is nil', function()
      local result, err = git_submodule.update(nil)
      assert.is_nil(result)
      eq({ 'reponame is required' }, err)
    end)

    it('should pass submodule update args', function()
      mock_execute_result = {}
      git_submodule.update('/repo')
      eq({ 'submodule', 'update' }, captured_args)
    end)

    it('should pass --init option', function()
      mock_execute_result = {}
      git_submodule.update('/repo', nil, { init = true })
      eq({ 'submodule', 'update', '--init' }, captured_args)
    end)

    it('should pass --recursive option', function()
      mock_execute_result = {}
      git_submodule.update('/repo', nil, { recursive = true })
      eq({ 'submodule', 'update', '--recursive' }, captured_args)
    end)

    it('should pass --force option', function()
      mock_execute_result = {}
      git_submodule.update('/repo', nil, { force = true })
      eq({ 'submodule', 'update', '-f' }, captured_args)
    end)

    it('should pass --force option via f alias', function()
      mock_execute_result = {}
      git_submodule.update('/repo', nil, { f = true })
      eq({ 'submodule', 'update', '-f' }, captured_args)
    end)

    it('should pass --checkout option', function()
      mock_execute_result = {}
      git_submodule.update('/repo', nil, { checkout = true })
      eq({ 'submodule', 'update', '--checkout' }, captured_args)
    end)

    it('should pass --rebase option', function()
      mock_execute_result = {}
      git_submodule.update('/repo', nil, { rebase = true })
      eq({ 'submodule', 'update', '--rebase' }, captured_args)
    end)

    it('should pass --merge option', function()
      mock_execute_result = {}
      git_submodule.update('/repo', nil, { merge = true })
      eq({ 'submodule', 'update', '--merge' }, captured_args)
    end)

    it('should pass --remote option', function()
      mock_execute_result = {}
      git_submodule.update('/repo', nil, { remote = true })
      eq({ 'submodule', 'update', '--remote' }, captured_args)
    end)

    it('should pass depth option', function()
      mock_execute_result = {}
      git_submodule.update('/repo', nil, { depth = 3 })
      eq({ 'submodule', 'update', '--depth', '3' }, captured_args)
    end)

    it('should pass jobs option', function()
      mock_execute_result = {}
      git_submodule.update('/repo', nil, { jobs = 4 })
      eq({ 'submodule', 'update', '-j', '4' }, captured_args)
    end)

    it('should pass jobs option via j alias', function()
      mock_execute_result = {}
      git_submodule.update('/repo', nil, { j = 8 })
      eq({ 'submodule', 'update', '-j', '8' }, captured_args)
    end)

    it('should pass paths as string', function()
      mock_execute_result = {}
      git_submodule.update('/repo', 'lib/sub')
      eq({ 'submodule', 'update', 'lib/sub' }, captured_args)
    end)

    it('should pass paths as table', function()
      mock_execute_result = {}
      git_submodule.update('/repo', { 'lib/sub1', 'lib/sub2' })
      eq({ 'submodule', 'update', 'lib/sub1', 'lib/sub2' }, captured_args)
    end)

    it('should pass all options together', function()
      mock_execute_result = {}
      git_submodule.update('/repo', { 'lib/sub' }, {
        init = true,
        recursive = true,
        force = true,
        checkout = true,
        rebase = true,
        merge = true,
        remote = true,
        depth = 2,
        jobs = 4,
      })
      eq({
        'submodule',
        'update',
        '--init',
        '--recursive',
        '-f',
        '--checkout',
        '--rebase',
        '--merge',
        '--remote',
        '--depth',
        '2',
        '-j',
        '4',
        'lib/sub',
      }, captured_args)
    end)
  end)

  describe('sync()', function()
    it('should error when reponame is nil', function()
      local result, err = git_submodule.sync(nil)
      assert.is_nil(result)
      eq({ 'reponame is required' }, err)
    end)

    it('should pass submodule sync args', function()
      mock_execute_result = {}
      git_submodule.sync('/repo')
      eq({ 'submodule', 'sync' }, captured_args)
    end)

    it('should pass --recursive option', function()
      mock_execute_result = {}
      git_submodule.sync('/repo', nil, { recursive = true })
      eq({ 'submodule', 'sync', '--recursive' }, captured_args)
    end)

    it('should pass string path', function()
      mock_execute_result = {}
      git_submodule.sync('/repo', 'lib/sub')
      eq({ 'submodule', 'sync', 'lib/sub' }, captured_args)
    end)

    it('should pass table of paths', function()
      mock_execute_result = {}
      git_submodule.sync('/repo', { 'lib/sub1', 'lib/sub2' })
      eq({ 'submodule', 'sync', 'lib/sub1', 'lib/sub2' }, captured_args)
    end)
  end)

  describe('foreach()', function()
    it('should error when reponame is nil', function()
      local result, err = git_submodule.foreach(nil, 'git pull')
      assert.is_nil(result)
      eq({ 'reponame is required' }, err)
    end)

    it('should error when command is nil', function()
      local result, err = git_submodule.foreach('/repo', nil)
      assert.is_nil(result)
      eq({ 'command is required' }, err)
    end)

    it('should pass submodule foreach with command', function()
      mock_execute_result = {}
      git_submodule.foreach('/repo', 'git pull')
      eq({ 'submodule', 'foreach', 'git pull' }, captured_args)
    end)

    it('should pass --recursive option', function()
      mock_execute_result = {}
      git_submodule.foreach('/repo', 'git pull', { recursive = true })
      eq({ 'submodule', 'foreach', '--recursive', 'git pull' }, captured_args)
    end)

    it('should pass -q option via quiet', function()
      mock_execute_result = {}
      git_submodule.foreach('/repo', 'git status', { quiet = true })
      eq({ 'submodule', 'foreach', '-q', 'git status' }, captured_args)
    end)

    it('should pass -q option via q alias', function()
      mock_execute_result = {}
      git_submodule.foreach('/repo', 'git status', { q = true })
      eq({ 'submodule', 'foreach', '-q', 'git status' }, captured_args)
    end)

    it('should pass recursive and quiet together', function()
      mock_execute_result = {}
      git_submodule.foreach('/repo', 'git fetch', { recursive = true, quiet = true })
      eq({ 'submodule', 'foreach', '--recursive', '-q', 'git fetch' }, captured_args)
    end)
  end)

  describe('set_branch()', function()
    it('should error when reponame is nil', function()
      local result, err = git_submodule.set_branch(nil, 'main', 'lib/sub')
      assert.is_nil(result)
      eq({ 'reponame is required' }, err)
    end)

    it('should error when path is nil', function()
      local result, err = git_submodule.set_branch('/repo', 'main', nil)
      assert.is_nil(result)
      eq({ 'path is required' }, err)
    end)

    it('should error when neither branch nor default option is provided', function()
      local result, err = git_submodule.set_branch('/repo', nil, 'lib/sub')
      assert.is_nil(result)
      eq({ 'branch is required unless using default option' }, err)
    end)

    it('should pass branch with -b', function()
      mock_execute_result = {}
      git_submodule.set_branch('/repo', 'develop', 'lib/sub')
      eq({ 'submodule', 'set-branch', '-b', 'develop', 'lib/sub' }, captured_args)
    end)

    it('should pass default with -d via default option', function()
      mock_execute_result = {}
      git_submodule.set_branch('/repo', nil, 'lib/sub', { default = true })
      eq({ 'submodule', 'set-branch', '-d', 'lib/sub' }, captured_args)
    end)

    it('should pass default with -d via d alias', function()
      mock_execute_result = {}
      git_submodule.set_branch('/repo', nil, 'lib/sub', { d = true })
      eq({ 'submodule', 'set-branch', '-d', 'lib/sub' }, captured_args)
    end)

    it('should prefer default over branch when both provided', function()
      mock_execute_result = {}
      git_submodule.set_branch('/repo', 'develop', 'lib/sub', { default = true })
      -- default takes priority per the source code if-elseif chain
      eq({ 'submodule', 'set-branch', '-d', 'lib/sub' }, captured_args)
    end)
  end)

  describe('set_url()', function()
    it('should error when reponame is nil', function()
      local result, err = git_submodule.set_url(nil, 'lib/sub', 'https://new.url')
      assert.is_nil(result)
      eq({ 'reponame is required' }, err)
    end)

    it('should error when path is nil', function()
      local result, err = git_submodule.set_url('/repo', nil, 'https://new.url')
      assert.is_nil(result)
      eq({ 'path is required' }, err)
    end)

    it('should error when url is nil', function()
      local result, err = git_submodule.set_url('/repo', 'lib/sub', nil)
      assert.is_nil(result)
      eq({ 'url is required' }, err)
    end)

    it('should pass submodule set-url path and url', function()
      mock_execute_result = {}
      git_submodule.set_url('/repo', 'lib/sub', 'https://new.example.com/repo.git')
      eq('/repo', captured_reponame)
      eq({
        'submodule',
        'set-url',
        'lib/sub',
        'https://new.example.com/repo.git',
      }, captured_args)
    end)
  end)

  describe('absorbgitdirs()', function()
    it('should error when reponame is nil', function()
      local result, err = git_submodule.absorbgitdirs(nil)
      assert.is_nil(result)
      eq({ 'reponame is required' }, err)
    end)

    it('should pass submodule absorbgitdirs args', function()
      mock_execute_result = {}
      git_submodule.absorbgitdirs('/repo')
      eq('/repo', captured_reponame)
      eq({ 'submodule', 'absorbgitdirs' }, captured_args)
    end)
  end)

  describe('summary()', function()
    it('should error when reponame is nil', function()
      local result, err = git_submodule.summary(nil)
      assert.is_nil(result)
      eq({ 'reponame is required' }, err)
    end)

    it('should pass submodule summary args', function()
      mock_execute_result = {}
      git_submodule.summary('/repo')
      eq({ 'submodule', 'summary' }, captured_args)
    end)

    it('should pass --cached option', function()
      mock_execute_result = {}
      git_submodule.summary('/repo', { cached = true })
      eq({ 'submodule', 'summary', '--cached' }, captured_args)
    end)

    it('should pass --files option', function()
      mock_execute_result = {}
      git_submodule.summary('/repo', { files = true })
      eq({ 'submodule', 'summary', '--files' }, captured_args)
    end)

    it('should pass --summary-limit option', function()
      mock_execute_result = {}
      git_submodule.summary('/repo', { summary_limit = 10 })
      eq({ 'submodule', 'summary', '--summary-limit', '10' }, captured_args)
    end)

    it('should pass commit option', function()
      mock_execute_result = {}
      git_submodule.summary('/repo', { commit = 'HEAD~5' })
      eq({ 'submodule', 'summary', 'HEAD~5' }, captured_args)
    end)

    it('should pass all options together', function()
      mock_execute_result = {}
      git_submodule.summary('/repo', {
        cached = true,
        files = true,
        summary_limit = 5,
        commit = 'abc123',
      })
      eq({
        'submodule',
        'summary',
        '--cached',
        '--files',
        '--summary-limit',
        '5',
        'abc123',
      }, captured_args)
    end)
  end)
end)
