local ffi = require('ffi')
local event = require('vgit.core.event')
local libgit2_setting = require('vgit.settings.libgit2')

local libgit2 = {
  cli = {},
  initialized = false,
}

function libgit2.cdefine()
  if libgit2.initialized then return nil, { 'already initialized' } end

  ffi.cdef([[
    typedef uint64_t git_object_size_t;

    typedef struct git_oid {
      unsigned char id[20];
    } git_oid;

    typedef struct git_index git_index;
    typedef struct git_object git_object;
    typedef struct git_repository git_repository;

    typedef struct {
      int32_t seconds;
      uint32_t nanoseconds;
    } git_index_time;

    typedef struct git_index_entry {
      git_index_time ctime;
      git_index_time mtime;

      uint32_t dev;
      uint32_t ino;
      uint32_t mode;
      uint32_t uid;
      uint32_t gid;
      uint32_t file_size;

      git_oid id;

      uint16_t flags;
      uint16_t flags_extended;

      const char *path;
    } git_index_entry;
    const git_index_entry *git_index_get_bypath(git_index *index, const char *path, int stage);

    typedef struct git_error {
      char *message;
      int klass;
    } git_error;
    const git_error *git_error_last(void);

    typedef enum {
      GIT_OBJECT_ANY = -2,
      GIT_OBJECT_INVALID = -1,
      GIT_OBJECT_COMMIT = 1,
      GIT_OBJECT_TREE = 2,
      GIT_OBJECT_BLOB = 3,
      GIT_OBJECT_TAG = 4,
      GIT_OBJECT_OFS_DELTA = 6,
      GIT_OBJECT_REF_DELTA = 7
    } git_object_t;

    typedef struct {
      char   *ptr;
      size_t  asize;
      size_t  size;
    } git_buf;

    typedef struct git_tree git_tree;
    typedef struct git_commit git_commit;
    typedef struct git_tree_entry git_tree_entry;
    typedef struct git_blob git_blob;

    void git_index_free(git_index *index);
    void git_repository_free(git_repository *repo);

    int git_libgit2_init();
    int git_libgit2_shutdown();

    int git_repository_open(git_repository **out, const char *path);
    int git_repository_index(git_index **out, git_repository *repo);

    int git_repository_discover(git_buf *out, const char *start_path, int across_fs, const char *ceiling_dirs);
    int git_repository_open_ext(git_repository **out, const char *path, unsigned int flags, const char *ceiling_dirs);
    const char *git_repository_workdir(git_repository *repo);
    int git_repository_is_bare(git_repository *repo);
    int git_ignore_path_is_ignored(int *ignored, git_repository *repo, const char *path);

    int git_revparse_single(git_object **out, git_repository *repo, const char *spec);

    git_object_t git_object_type(const git_object *obj);
    void git_object_free(git_object *object);
    void git_buf_free(git_buf *buffer);

    int git_commit_tree(git_tree **tree_out, const git_commit *commit);
    void git_tree_free(git_tree *tree);

    const git_oid * git_tree_entry_id(const git_tree_entry *entry);
    int git_tree_entry_bypath(git_tree_entry **out, const git_tree *root, const char *path);
    void git_tree_entry_free(git_tree_entry *entry);
  ]])

  return true
end

function libgit2.is_enabled()
  return libgit2_setting:get('enabled') == true
end

function libgit2.error(msg)
  local err_msg = msg or 'libgit2 operation failed'

  local err = libgit2.cli.git_error_last()
  if err ~= nil then err_msg = ffi.string(err.message) end

  return nil, { err_msg }
end

function libgit2.shutdown()
  if not libgit2.initialized then return nil, { 'not initialized' } end

  local ret = libgit2.cli.git_libgit2_shutdown()
  if ret < 0 then return libgit2.error() end

  if ret == 0 then libgit2.initialized = false end

  return true
end

function libgit2.register(path)
  if not libgit2.is_enabled() then return false end

  path = path or libgit2_setting:get('path')
  if not path then return nil, { 'path is required' } end

  if libgit2.initialized then return nil, { 'already initialized' } end
  if vim.fn.filereadable(path) == 0 then return nil, { 'libgit2.dylib not found at: ' .. path } end

  libgit2.cli = ffi.load(path, true)
  libgit2.cdefine()

  local ret = libgit2.cli.git_libgit2_init()
  if ret < 0 then return libgit2.error() end

  libgit2.initialized = true
  event.on('VimLeavePre', libgit2.shutdown)

  return true
end

return libgit2
