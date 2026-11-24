# Parsed expert systems loaded during the tests are cached in the session's
# temporary directory, never in the user's cache directory.
withr::local_options(
  RESY.cache_dir = file.path(tempdir(), "resy-test-cache"),
  .local_envir = teardown_env()
)
