# resy_classifications_root() resolves where expert systems are stored: the
# read-only package location (shipped classifications) and a per-user writable
# location (user-added classifications). The package root must point at the
# installed extdata tree; the user root must be creatable on demand.

test_that("package root points at the installed classifications tree", {
  root <- RESY:::resy_classifications_root("package")
  expect_true(nzchar(root))
  expect_true(dir.exists(root))
  # EUNIS ships with the package, so it must live under this root.
  expect_true(dir.exists(file.path(root, "EUNIS")))
})

test_that("user root sits under the per-user data directory", {
  root <- RESY:::resy_classifications_root("user")
  expect_true(nzchar(root))
  expect_match(root, "classifications$")
  expect_match(root, "RESY")
})

test_that("create = TRUE materialises the user root", {
  fake_home <- file.path(tempdir(), "resy_root_test")
  unlink(fake_home, recursive = TRUE)
  withr::with_envvar(
    list(R_USER_DATA_DIR = fake_home),
    {
      root <- RESY:::resy_classifications_root("user", create = TRUE)
      expect_true(dir.exists(root))
    }
  )
  unlink(fake_home, recursive = TRUE)
})

test_that("create = FALSE does not create the user root", {
  fake_home <- file.path(tempdir(), "resy_root_nocreate")
  unlink(fake_home, recursive = TRUE)
  withr::with_envvar(
    list(R_USER_DATA_DIR = fake_home),
    {
      root <- RESY:::resy_classifications_root("user", create = FALSE)
      expect_false(dir.exists(root))
    }
  )
  unlink(fake_home, recursive = TRUE)
})

test_that("location is matched by match.arg", {
  expect_error(RESY:::resy_classifications_root("elsewhere"), "should be one of")
})
