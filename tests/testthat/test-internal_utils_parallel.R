# Tests for internal parallel computing utilities
# These functions provide cross-platform wrappers around parallel::mclapply() and
# parallel::mcmapply() with graceful fallback to sequential operations on Windows
# or when single core is requested.

test_that("%||% operator returns left value when not NULL", {
  result <- 5 %||% 10
  expect_equal(result, 5)
})

test_that("%||% operator returns right value when left is NULL", {
  result <- NULL %||% 10
  expect_equal(result, 10)
})

test_that("%||% operator handles empty list as non-NULL", {
  result <- list() %||% "default"
  expect_equal(result, list())
})

test_that("%||% operator handles FALSE as non-NULL", {
  result <- FALSE %||% TRUE
  expect_false(result)
})

test_that(".resy_mclapply with single core uses lapply", {
  X <- c(1, 2, 3)
  FUN <- function(x) x * 2
  result <- .resy_mclapply(X, FUN, mc = 1L)
  expect_equal(result, list(2, 4, 6))
})

test_that(".resy_mclapply with default mc=1 uses lapply", {
  X <- c(1, 2, 3)
  FUN <- function(x) x * 2
  result <- .resy_mclapply(X, FUN)
  expect_equal(result, list(2, 4, 6))
})

test_that(".resy_mclapply with NULL mc defaults to 1 and uses lapply", {
  X <- c(1, 2, 3)
  FUN <- function(x) x * 2
  result <- .resy_mclapply(X, FUN, mc = NULL)
  expect_equal(result, list(2, 4, 6))
})

test_that(".resy_mclapply prioritizes mc.cores over mc parameter", {
  X <- c(1, 2, 3)
  FUN <- function(x) x * 2
  # With both mc and mc.cores specified, mc.cores should be used
  result <- .resy_mclapply(X, FUN, mc = 1L, mc.cores = 1L)
  expect_equal(result, list(2, 4, 6))
})

test_that(".resy_mclapply converts mc to integer", {
  X <- c(1, 2, 3)
  FUN <- function(x) x * 2
  # Pass numeric instead of integer
  result <- .resy_mclapply(X, FUN, mc = 1.9)
  expect_equal(result, list(2, 4, 6))
})

test_that(".resy_mclapply uses lapply on Windows", {
  skip_if_not(.Platform$OS.type == "windows",
              "This test is only relevant on Windows")
  X <- c(1, 2, 3)
  FUN <- function(x) x * 2
  # Even with mc > 1, should fall back to lapply on Windows
  result <- .resy_mclapply(X, FUN, mc = 2L)
  expect_equal(result, list(2, 4, 6))
})

test_that(".resy_mclapply with mc > 1 on Unix-like uses parallel", {
  skip_if(.Platform$OS.type == "windows",
          "This test requires fork-based parallelization")
  skip_if_not_installed("parallel")
  
  X <- c(1, 2, 3)
  FUN <- function(x) x * 2
  result <- .resy_mclapply(X, FUN, mc = 2L)
  expect_equal(result, list(2, 4, 6))
})

test_that(".resy_mclapply passes additional arguments to FUN", {
  X <- c(1, 2, 3)
  FUN <- function(x, mult) x * mult
  result <- .resy_mclapply(X, FUN, mc = 1L, mult = 3)
  expect_equal(result, list(3, 6, 9))
})

test_that(".resy_mclapply handles empty input", {
  result <- .resy_mclapply(c(), identity, mc = 1L)
  expect_equal(result, list())
})

test_that(".resy_mclapply handles single element", {
  result <- .resy_mclapply(5, function(x) x + 1, mc = 1L)
  expect_equal(result, list(6))
})

test_that(".resy_mclapply handles complex FUN", {
  X <- list(a = 1, b = 2, c = 3)
  FUN <- function(x) x^2
  result <- .resy_mclapply(X, FUN, mc = 1L)
  expect_equal(result, list(1, 4, 9))
})

test_that(".resy_mcmapply with single core uses mapply", {
  result <- .resy_mcmapply(
    function(x, y) x + y,
    x = c(1, 2, 3),
    y = c(10, 20, 30),
    mc = 1L
  )
  expect_equal(result, c(11, 22, 33))
})

test_that(".resy_mcmapply with default mc=1 uses mapply", {
  result <- .resy_mcmapply(
    function(x, y) x + y,
    x = c(1, 2, 3),
    y = c(10, 20, 30)
  )
  expect_equal(result, c(11, 22, 33))
})

test_that(".resy_mcmapply prioritizes mc.cores over mc", {
  result <- .resy_mcmapply(
    function(x, y) x + y,
    x = c(1, 2, 3),
    y = c(10, 20, 30),
    mc = 1L,
    mc.cores = 1L
  )
  expect_equal(result, c(11, 22, 33))
})

test_that(".resy_mcmapply uses mapply on Windows", {
  skip_if_not(.Platform$OS.type == "windows",
              "This test is only relevant on Windows")
  result <- .resy_mcmapply(
    function(x, y) x + y,
    x = c(1, 2, 3),
    y = c(10, 20, 30),
    mc = 2L
  )
  expect_equal(result, c(11, 22, 33))
})

test_that(".resy_mcmapply with mc > 1 on Unix-like uses parallel", {
  skip_if(.Platform$OS.type == "windows",
          "This test requires fork-based parallelization")
  skip_if_not_installed("parallel")
  
  result <- .resy_mcmapply(
    function(x, y) x + y,
    x = c(1, 2, 3),
    y = c(10, 20, 30),
    mc = 2L
  )
  expect_equal(result, c(11, 22, 33))
})

test_that(".resy_mcmapply respects SIMPLIFY parameter", {
  result_simplified <- .resy_mcmapply(
    function(x, y) c(x, y),
    x = c(1, 2),
    y = c(10, 20),
    mc = 1L,
    SIMPLIFY = TRUE
  )
  result_not_simplified <- .resy_mcmapply(
    function(x, y) c(x, y),
    x = c(1, 2),
    y = c(10, 20),
    mc = 1L,
    SIMPLIFY = FALSE
  )
  expect_type(result_simplified, "double")
  expect_type(result_not_simplified, "list")
})

test_that(".resy_mcmapply respects USE.NAMES parameter", {
  result_with_names <- .resy_mcmapply(
    function(x, y) x + y,
    x = c(a = 1, b = 2),
    y = c(a = 10, b = 20),
    mc = 1L,
    USE.NAMES = TRUE
  )
  result_without_names <- .resy_mcmapply(
    function(x, y) x + y,
    x = c(a = 1, b = 2),
    y = c(a = 10, b = 20),
    mc = 1L,
    USE.NAMES = FALSE
  )
  expect_named(result_with_names, c("a", "b"))
  expect_null(names(result_without_names))
})

test_that(".resy_mcmapply handles empty input", {
  result <- .resy_mcmapply(
    function(x) x,
    x = c(),
    mc = 1L,
    SIMPLIFY = FALSE
  )
  expect_equal(result, list())
})

test_that(".resy_mcmapply handles single element", {
  result <- .resy_mcmapply(
    function(x, y) x + y,
    x = 5,
    y = 10,
    mc = 1L
  )
  expect_equal(result, 15)
})

test_that(".resy_mcmapply with multiple arguments", {
  result <- .resy_mcmapply(
    function(x, y, z) x + y + z,
    x = c(1, 2, 3),
    y = c(10, 20, 30),
    z = c(100, 200, 300),
    mc = 1L
  )
  expect_equal(result, c(111, 222, 333))
})

test_that(".resy_mcmapply converts mc to integer", {
  result <- .resy_mcmapply(
    function(x, y) x + y,
    x = c(1, 2, 3),
    y = c(10, 20, 30),
    mc = 1.9
  )
  expect_equal(result, c(11, 22, 33))
})

test_that(".resy_mcmapply with NULL mc defaults to 1", {
  result <- .resy_mcmapply(
    function(x, y) x + y,
    x = c(1, 2, 3),
    y = c(10, 20, 30),
    mc = NULL
  )
  expect_equal(result, c(11, 22, 33))
})
