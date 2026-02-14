local GitQueryBuilder = require('vgit.git.GitQueryBuilder')

local eq = assert.are.same

describe('GitQueryBuilder:', function()
  describe('constructor', function()
    it('should error when repository is nil', function()
      assert.has_error(function()
        GitQueryBuilder(nil)
      end, 'GitQueryBuilder: repository path (string) is required')
    end)

    it('should error when repository is not a string', function()
      assert.has_error(function()
        GitQueryBuilder(123)
      end, 'GitQueryBuilder: repository path (string) is required')
    end)

    it('should error when repository is empty string', function()
      assert.has_error(function()
        GitQueryBuilder('')
      end)
    end)

    it('should error when repository is whitespace only', function()
      assert.has_error(function()
        GitQueryBuilder('   ')
      end)
    end)

    it('should create builder with valid repository', function()
      local builder = GitQueryBuilder('/my/repo')
      assert.is_not_nil(builder)
    end)
  end)

  describe('to_args', function()
    it('should start with -C and repository path', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:raw_arg('status')
      local args = builder:to_args()
      assert.are.equal('-C', args[1])
      assert.are.equal('/my/repo', args[2])
    end)
  end)

  describe('to_command', function()
    it('should produce a git command string', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:raw_arg('status')
      local cmd = builder:to_command()
      assert.are.equal('git -C /my/repo status', cmd)
    end)
  end)

  describe('log', function()
    it('should set up log command args', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:log()
      local args = builder:to_args()
      assert.are.equal('-C', args[1])
      assert.are.equal('/my/repo', args[2])
      assert.are.equal('--no-pager', args[3])
      assert.are.equal('log', args[4])
      assert.are.equal('--color=never', args[5])
    end)

    it('should error on duplicate command', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:log()
      assert.has_error(function()
        builder:show()
      end)
    end)
  end)

  describe('show', function()
    it('should set up show command args', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:show()
      local args = builder:to_args()
      assert.are.equal('show', args[3])
      assert.are.equal('--color=never', args[4])
    end)

    it('should accept a ref argument', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:show('HEAD~1')
      local args = builder:to_args()
      assert.are.equal('show', args[3])
      assert.are.equal('HEAD~1', args[4])
      assert.are.equal('--color=never', args[5])
    end)
  end)

  describe('status', function()
    it('should set up status command args', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:status()
      local args = builder:to_args()
      assert.are.equal('--no-pager', args[3])
      assert.are.equal('status', args[4])
      assert.are.equal('-u', args[5])
      assert.are.equal('-s', args[6])
      assert.are.equal('--ignore-submodules', args[7])
    end)
  end)

  describe('diff_tree', function()
    it('should set up diff-tree command args', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:diff_tree()
      local args = builder:to_args()
      assert.are.equal('--no-pager', args[3])
      assert.are.equal('diff-tree', args[4])
      assert.are.equal('--no-commit-id', args[5])
      assert.are.equal('--name-status', args[6])
      assert.are.equal('-r', args[7])
    end)
  end)

  describe('blame', function()
    it('should set up blame command args', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:blame()
      local args = builder:to_args()
      assert.are.equal('blame', args[3])
    end)
  end)

  describe('stash', function()
    it('should set up stash command args', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:stash()
      local args = builder:to_args()
      assert.are.equal('--no-pager', args[3])
      assert.are.equal('stash', args[4])
    end)
  end)

  describe('_prevent_duplicate_command', function()
    it('should error when calling two command methods', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:log()
      assert.has_error(function()
        builder:status()
      end)
    end)

    it('should error with descriptive message', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:blame()
      local ok, err = pcall(function()
        builder:stash()
      end)
      assert.is_false(ok)
      assert.truthy(err:match('Already using "blame"'))
    end)
  end)

  describe('pretty', function()
    it('should append pretty format arg', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:log()
      builder:pretty('%H|%an|%s')
      local args = builder:to_args()
      local found = false
      for _, arg in ipairs(args) do
        if arg == '--pretty=format:%H|%an|%s' then found = true end
      end
      assert.is_true(found)
    end)

    it('should error when no command set', function()
      local builder = GitQueryBuilder('/my/repo')
      assert.has_error(function()
        builder:pretty('%H')
      end)
    end)

    it('should error on empty format string', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:log()
      assert.has_error(function()
        builder:pretty('')
      end)
    end)
  end)

  describe('paginate', function()
    it('should append count and skip args for log', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:log()
      builder:paginate(10, 5)
      local args = builder:to_args()
      local has_n = false
      local has_skip = false
      for i, arg in ipairs(args) do
        if arg == '-n' and args[i + 1] == '10' then has_n = true end
        if arg == '--skip=5' then has_skip = true end
      end
      assert.is_true(has_n)
      assert.is_true(has_skip)
    end)

    it('should work for stash command', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:stash()
      builder:paginate(3)
      local args = builder:to_args()
      local has_n = false
      for i, arg in ipairs(args) do
        if arg == '-n' and args[i + 1] == '3' then has_n = true end
      end
      assert.is_true(has_n)
    end)

    it('should error for non-paginatable commands', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:status()
      assert.has_error(function()
        builder:paginate(10)
      end)
    end)

    it('should error on negative count', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:log()
      assert.has_error(function()
        builder:paginate(-1)
      end)
    end)

    it('should error on duplicate pagination', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:log()
      builder:paginate(5)
      assert.has_error(function()
        builder:paginate(10)
      end)
    end)

    it('should skip offset arg when offset is 0', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:log()
      builder:paginate(5, 0)
      local args = builder:to_args()
      for _, arg in ipairs(args) do
        assert.is_false(arg:match('skip') ~= nil)
      end
    end)
  end)

  describe('file', function()
    it('should append -- separator and filename', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:log()
      builder:file('src/main.lua')
      local args = builder:to_args()
      local found_sep = false
      local found_file = false
      for i, arg in ipairs(args) do
        if arg == '--' then
          found_sep = true
          if args[i + 1] == 'src/main.lua' then found_file = true end
        end
      end
      assert.is_true(found_sep)
      assert.is_true(found_file)
    end)

    it('should error for non-file commands', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:stash()
      assert.has_error(function()
        builder:file('test.lua')
      end)
    end)

    it('should error on duplicate file call', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:log()
      builder:file('a.lua')
      assert.has_error(function()
        builder:file('b.lua')
      end)
    end)

    it('should support file for blame command', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:blame()
      builder:file('test.lua')
      local args = builder:to_args()
      local found = false
      for _, arg in ipairs(args) do
        if arg == 'test.lua' then found = true end
      end
      assert.is_true(found)
    end)

    it('should be a no-op when filename is nil', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:log()
      builder:file(nil)
      local args = builder:to_args()
      for _, arg in ipairs(args) do
        assert.are_not.equal('--', arg)
      end
    end)
  end)

  describe('refs', function()
    it('should append ref arguments', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:show()
      builder:refs('HEAD', 'main')
      local args = builder:to_args()
      local found_head = false
      local found_main = false
      for _, arg in ipairs(args) do
        if arg == 'HEAD' then found_head = true end
        if arg == 'main' then found_main = true end
      end
      assert.is_true(found_head)
      assert.is_true(found_main)
    end)

    it('should error for non-ref commands', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:log()
      assert.has_error(function()
        builder:refs('HEAD')
      end)
    end)

    it('should error when no refs provided', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:diff_tree()
      assert.has_error(function()
        builder:refs()
      end)
    end)

    it('should validate each ref is a string', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:diff_tree()
      assert.has_error(function()
        builder:refs(123)
      end)
    end)
  end)

  describe('no_patch', function()
    it('should append --no-patch for show command', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:show()
      builder:no_patch()
      local args = builder:to_args()
      local found = false
      for _, arg in ipairs(args) do
        if arg == '--no-patch' then found = true end
      end
      assert.is_true(found)
    end)

    it('should error for non-show commands', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:log()
      assert.has_error(function()
        builder:no_patch()
      end)
    end)
  end)

  describe('subcommand', function()
    it('should append valid stash subcommand', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:stash()
      builder:subcommand('list')
      local args = builder:to_args()
      local found = false
      for _, arg in ipairs(args) do
        if arg == 'list' then found = true end
      end
      assert.is_true(found)
    end)

    it('should error for invalid stash subcommand', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:stash()
      assert.has_error(function()
        builder:subcommand('invalid')
      end)
    end)

    it('should error for non-stash commands', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:log()
      assert.has_error(function()
        builder:subcommand('list')
      end)
    end)

    it('should accept all valid stash subcommands', function()
      local valid = { 'list', 'show', 'drop', 'pop', 'apply', 'branch', 'clear', 'create', 'store' }
      for _, subcmd in ipairs(valid) do
        local builder = GitQueryBuilder('/my/repo')
        builder:stash()
        assert.has_no.errors(function()
          builder:subcommand(subcmd)
        end)
      end
    end)
  end)

  describe('option', function()
    it('should append --key=value when value is provided', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:log()
      builder:option('format', 'oneline')
      local args = builder:to_args()
      local found = false
      for _, arg in ipairs(args) do
        if arg == '--format=oneline' then found = true end
      end
      assert.is_true(found)
    end)

    it('should append --key when value is nil', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:log()
      builder:option('oneline')
      local args = builder:to_args()
      local found = false
      for _, arg in ipairs(args) do
        if arg == '--oneline' then found = true end
      end
      assert.is_true(found)
    end)

    it('should accept numeric values', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:log()
      builder:option('max-count', 5)
      local args = builder:to_args()
      local found = false
      for _, arg in ipairs(args) do
        if arg == '--max-count=5' then found = true end
      end
      assert.is_true(found)
    end)

    it('should error on non-string/number value', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:log()
      assert.has_error(function()
        builder:option('key', true)
      end)
    end)
  end)

  describe('raw_arg', function()
    it('should append a single raw argument', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:raw_arg('rev-parse')
      builder:raw_arg('HEAD')
      local args = builder:to_args()
      assert.are.equal('rev-parse', args[3])
      assert.are.equal('HEAD', args[4])
    end)

    it('should auto-set command to raw', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:raw_arg('rev-parse')
      -- Should not error since command is set
      assert.has_no.errors(function()
        builder:raw_arg('--abbrev-ref')
      end)
    end)

    it('should be a no-op when arg is nil', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:raw_arg(nil)
      local args = builder:to_args()
      assert.are.equal(2, #args) -- only -C and repo
    end)

    it('should error on empty string', function()
      local builder = GitQueryBuilder('/my/repo')
      assert.has_error(function()
        builder:raw_arg('')
      end)
    end)
  end)

  describe('raw_args', function()
    it('should append multiple raw arguments', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:raw_args('rev-parse', '--abbrev-ref', 'HEAD')
      local args = builder:to_args()
      assert.are.equal('rev-parse', args[3])
      assert.are.equal('--abbrev-ref', args[4])
      assert.are.equal('HEAD', args[5])
    end)

    it('should error when no arguments provided', function()
      local builder = GitQueryBuilder('/my/repo')
      assert.has_error(function()
        builder:raw_args()
      end)
    end)

    it('should accept numeric arguments', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:raw_args('log', '-n', 5)
      local args = builder:to_args()
      assert.are.equal('5', args[5])
    end)

    it('should error on non-string/number arguments', function()
      local builder = GitQueryBuilder('/my/repo')
      assert.has_error(function()
        builder:raw_args('log', true)
      end)
    end)
  end)

  describe('_validate_query', function()
    it('should error when blame is missing file', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:blame()
      assert.has_error(function()
        builder:execute()
      end)
    end)

    it('should error when diff-tree is missing refs', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:diff_tree()
      assert.has_error(function()
        builder:execute()
      end)
    end)

    it('should skip validation for raw commands', function()
      local builder = GitQueryBuilder('/my/repo')
      builder:raw_arg('rev-parse')
      -- execute would call gitcli.run which is async, so we test _validate_query directly
      assert.has_no.errors(function()
        builder:_validate_query()
      end)
    end)
  end)

  describe('_validate_string', function()
    it('should error on non-string', function()
      local builder = GitQueryBuilder('/my/repo')
      assert.has_error(function()
        builder:_validate_string(123, 'test_field')
      end)
    end)

    it('should error on empty string', function()
      local builder = GitQueryBuilder('/my/repo')
      assert.has_error(function()
        builder:_validate_string('', 'test_field')
      end)
    end)

    it('should error on whitespace-only string', function()
      local builder = GitQueryBuilder('/my/repo')
      assert.has_error(function()
        builder:_validate_string('   ', 'test_field')
      end)
    end)

    it('should accept valid strings', function()
      local builder = GitQueryBuilder('/my/repo')
      assert.has_no.errors(function()
        builder:_validate_string('hello', 'test_field')
      end)
    end)
  end)

  describe('_validate_number', function()
    it('should error on non-number', function()
      local builder = GitQueryBuilder('/my/repo')
      assert.has_error(function()
        builder:_validate_number('abc', 'test_field')
      end)
    end)

    it('should error when below minimum', function()
      local builder = GitQueryBuilder('/my/repo')
      assert.has_error(function()
        builder:_validate_number(-1, 'test_field', 0)
      end)
    end)

    it('should accept valid number at minimum', function()
      local builder = GitQueryBuilder('/my/repo')
      assert.has_no.errors(function()
        builder:_validate_number(0, 'test_field', 0)
      end)
    end)

    it('should accept valid number without minimum', function()
      local builder = GitQueryBuilder('/my/repo')
      assert.has_no.errors(function()
        builder:_validate_number(-5, 'test_field')
      end)
    end)
  end)

  describe('chain composition', function()
    it('should support fluent chaining for log with pagination and file', function()
      local builder = GitQueryBuilder('/my/repo')
        :log()
        :paginate(5, 10)
        :file('src/main.lua')
      local args = builder:to_args()

      -- Should contain: -C, /my/repo, --no-pager, log, --color=never, -n, 5, --skip=10, --, src/main.lua
      assert.are.equal('-C', args[1])
      assert.are.equal('/my/repo', args[2])
      local cmd = builder:to_command()
      assert.truthy(cmd:match('log'))
      assert.truthy(cmd:match('%-n 5'))
      assert.truthy(cmd:match('%-%-skip=10'))
      assert.truthy(cmd:match('src/main%.lua'))
    end)

    it('should support fluent chaining for show with ref and no-patch', function()
      local builder = GitQueryBuilder('/my/repo')
        :show('abc123')
        :no_patch()
      local args = builder:to_args()
      local has_show = false
      local has_ref = false
      local has_no_patch = false
      for _, arg in ipairs(args) do
        if arg == 'show' then has_show = true end
        if arg == 'abc123' then has_ref = true end
        if arg == '--no-patch' then has_no_patch = true end
      end
      assert.is_true(has_show)
      assert.is_true(has_ref)
      assert.is_true(has_no_patch)
    end)

    it('should support chaining for stash with subcommand and pagination', function()
      local builder = GitQueryBuilder('/my/repo')
        :stash()
        :subcommand('list')
        :paginate(3)
      local cmd = builder:to_command()
      assert.truthy(cmd:match('stash'))
      assert.truthy(cmd:match('list'))
      assert.truthy(cmd:match('%-n 3'))
    end)

    it('should support diff-tree with refs', function()
      local builder = GitQueryBuilder('/my/repo')
        :diff_tree()
        :refs('HEAD')
      local cmd = builder:to_command()
      assert.truthy(cmd:match('diff%-tree'))
      assert.truthy(cmd:match('HEAD'))
    end)
  end)
end)
