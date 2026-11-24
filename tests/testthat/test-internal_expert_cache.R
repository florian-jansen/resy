# resy_load_expert() keeps each parsed system as an RDS file in a cache
# directory and restores it on the next load of the same file. The tests check
# that a second load returns the same object without rewriting the entry, that
# changing the file replaces its entry, that the entries of a deleted file are
# removed, that an unreadable entry is parsed again, and that nothing is cached when the cache is off or RESY is not an
# installed build. The build stamp is set by hand, since the tests may run on a
# development load.

local_cache <- function(build = "test-build", env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  withr::local_options(RESY.cache_dir = dir, RESY.cache = TRUE, .local_envir = env)
  state <- RESY:::.resy_cache_state
  old <- state$build
  state$build <- build
  withr::defer(state$build <- old, envir = env)
  dir
}

local_expert_copy <- function(env = parent.frame()) {
  path <- file.path(withr::local_tempdir(.local_envir = env), "expert.txt")
  file.copy(system.file("extdata", "example_mini_expert_file.txt", package = "RESY"), path)
  path
}

test_that("a second load restores the cached object without rewriting it", {
  dir <- local_cache()
  path <- local_expert_copy()

  first <- resy_load_expert(expertfile = path)
  entry <- list.files(dir, "[.]rds$", full.names = TRUE)
  expect_length(entry, 1L)
  expect_identical(readRDS(entry), first)

  stamp <- file.info(entry)$mtime
  second <- resy_load_expert(expertfile = path)
  expect_identical(second, first)
  expect_identical(file.info(entry)$mtime, stamp)
})

test_that("a changed file gets a new entry that replaces the old one", {
  dir <- local_cache()
  path <- local_expert_copy()

  resy_load_expert(expertfile = path)
  before <- list.files(dir, "[.]rds$")
  cat("\n", file = path, append = TRUE)
  resy_load_expert(expertfile = path)
  after <- list.files(dir, "[.]rds$")

  expect_length(after, 1L)
  expect_false(identical(after, before))
  expect_identical(substr(after, 1L, 17L), substr(before, 1L, 17L))
})

test_that("an unreadable entry is parsed again and replaced", {
  dir <- local_cache()
  path <- local_expert_copy()

  first <- resy_load_expert(expertfile = path)
  entry <- list.files(dir, "[.]rds$", full.names = TRUE)
  writeLines("not an RDS file", entry)

  expect_identical(resy_load_expert(expertfile = path), first)
  expect_identical(readRDS(entry), first)
})

test_that("the entries of a deleted file are removed at the next write", {
  dir <- local_cache()
  gone <- local_expert_copy()
  kept <- local_expert_copy()

  resy_load_expert(expertfile = gone)
  unlink(gone)
  resy_load_expert(expertfile = kept)

  expect_length(list.files(dir, "[.]rds$"), 1L)
  expect_identical(readLines(list.files(dir, "[.]path$", full.names = TRUE)),
                   normalizePath(kept, winslash = "/"))
})

test_that("nothing is cached when the cache is off", {
  dir <- local_cache()
  withr::local_options(RESY.cache = FALSE)
  resy_load_expert(expertfile = local_expert_copy())
  expect_length(list.files(dir), 0L)
})

test_that("nothing is cached without an installed build of RESY", {
  dir <- local_cache(build = NA_character_)
  resy_load_expert(expertfile = local_expert_copy())
  expect_length(list.files(dir), 0L)
})
