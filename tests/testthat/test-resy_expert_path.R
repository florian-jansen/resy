# resy_expert_path() resolves a bundled expert-system file from scheme/version.
# It must return a real, existing path for a shipped classification, honour the
# json/txt format switch, and fail loudly (or return NA) when the file is absent,
# so a mistyped scheme is caught at the call site rather than downstream.

test_that("resy_expert_path returns an existing file of the requested format", {
  p <- resy_expert_path("Apennine-test", "2026-06-27", format = "json")
  expect_true(file.exists(p))
  expect_match(p, "expert\\.json(\\.xz)?$")
  p <- resy_expert_path("EUNIS", "2025-10-03", format = "txt")
  expect_true(file.exists(p))
  expect_match(p, "EUNIS")
  expect_true(is.na(resy_expert_path("EUNIS", "2025-10-03", format = "json", mustWork = FALSE)))
})

test_that("resy_expert_path defaults to the file the classification is stored in", {
  expect_equal(resy_expert_path("EUNIS", "2025-10-03"),
               resy_expert_path("EUNIS", "2025-10-03", format = "txt"))
  expect_equal(resy_expert_path("Apennine-test", "2026-06-27"),
               resy_expert_path("Apennine-test", "2026-06-27", format = "json"))
})

test_that("resy_expert_path errors on a missing file when mustWork = TRUE", {
  expect_error(
    resy_expert_path("NoSuchScheme", "1900-01-01"),
    "Expert file not found"
  )
})

test_that("resy_expert_path returns NA on a missing file when mustWork = FALSE", {
  p <- resy_expert_path("NoSuchScheme", "1900-01-01", mustWork = FALSE)
  expect_true(is.na(p))
})

test_that("resy_expert_path rejects an unknown format", {
  expect_error(
    resy_expert_path("EUNIS", "2025-10-03", format = "rds"),
    "should be one of"
  )
})
