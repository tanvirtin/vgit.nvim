local fs = require('vgit.core.fs')
local Object = require('vgit.core.Object')
local gitcli = require('vgit.git.git2.gitcli')

local Patch = Object:extend()

function Patch:constructor(filename, hunk)
  local header = hunk.header

  if hunk.type == 'add' then
    local previous, _ = hunk:parse_header(header)
    header = string.format('@@ -%s,%s +%s,%s @@', previous[1], previous[2], previous[1] + 1, #hunk.diff)
  end

  local patch = {
    string.format('diff --git a/%s b/%s', filename, filename),
    'index 000000..000000',
    string.format('--- a/%s', filename),
    string.format('+++ a/%s', filename),
    header,
  }

  for i = 1, #hunk.diff do
    patch[#patch + 1] = hunk.diff[i]
  end

  return patch
end

local stager = {}

function stager.stage(reponame, filename)
  if not reponame then return nil, { 'reponame is required' } end

  return gitcli.run({
    '-C',
    reponame,
    '--no-pager',
    'add',
    '--',
    filename or '.',
  })
end

function stager.unstage(reponame, filename)
  if not reponame then return nil, { 'reponame is required' } end

  return gitcli.run({
    '-C',
    reponame,
    'reset',
    '-q',
    'HEAD',
    '--',
    filename or '.',
  })
end

function stager.stage_hunk(reponame, filename, hunk)
  if not reponame then return nil, { 'reponame is required' } end
  if not filename then return nil, { 'filename is required' } end
  if not hunk then return nil, { 'hunk is required' } end

  local patch = Patch(filename, hunk)
  local patch_filename = fs.tmpname()

  fs.write_file(patch_filename, patch)

  local _, err = gitcli.run({
    '-C',
    reponame,
    '--no-pager',
    'apply',
    '--cached',
    '--whitespace=nowarn',
    '--unidiff-zero',
    patch_filename,
  })

  fs.remove_file(patch_filename)

  return nil, err
end

function stager.unstage_hunk(reponame, filename, hunk)
  if not reponame then return nil, { 'reponame is required' } end
  if not filename then return nil, { 'filename is required' } end
  if not hunk then return nil, { 'hunk is required' } end

  local patch = Patch(filename, hunk)
  local patch_filename = fs.tmpname()

  fs.write_file(patch_filename, patch)

  local _, err = gitcli.run({
      '-C',
      reponame,
      '--no-pager',
      'apply',
      '--reverse',
      '--cached',
      '--whitespace=nowarn',
      '--unidiff-zero',
      patch_filename,
  })

  fs.remove_file(patch_filename)

  return nil, err
end

return stager
