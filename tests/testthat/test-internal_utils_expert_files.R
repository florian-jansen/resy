# Expert files may be stored as plain JSON or as xz-compressed JSON
# (`expert.json.xz`, used for the bundled EUNIS system to keep the package
# small). Both must be found, recognised as JSON and parsed identically.

apennine_json_path <- function() {
  system.file("extdata", "classifications", "Apennine-test", "2026-06-27",
              "expert.json", package = "RESY")
}

xz_copy <- function(src, dir) {
  out <- file.path(dir, "expert.json.xz")
  con <- xzfile(out, "wb", compression = 9)
  writeBin(readBin(src, "raw", file.size(src)), con)
  close(con)
  out
}

test_that(".resy_is_json recognises plain and xz-compressed JSON only", {
  expect_true(RESY:::.resy_is_json("a/expert.json"))
  expect_true(RESY:::.resy_is_json("a/expert.json.xz"))
  expect_true(RESY:::.resy_is_json("a/EXPERT.JSON.XZ"))
  expect_false(RESY:::.resy_is_json("a/expert.txt"))
  expect_false(RESY:::.resy_is_json("a/expert.xz"))
})

test_that(".resy_find_expert_file prefers plain JSON and falls back to .json.xz", {
  dir <- withr::local_tempdir()
  expect_true(is.na(RESY:::.resy_find_expert_file(dir, "json")))

  xz <- xz_copy(apennine_json_path(), dir)
  expect_equal(RESY:::.resy_find_expert_file(dir, "json"), xz)

  plain <- file.path(dir, "expert.json")
  file.copy(apennine_json_path(), plain)
  expect_equal(RESY:::.resy_find_expert_file(dir, "json"), plain)
})

test_that("an xz-compressed expert file parses identically to the plain one", {
  dir <- withr::local_tempdir()
  xz <- xz_copy(apennine_json_path(), dir)
  expect_identical(
    without_source(resy_load_expert(expertfile = xz)),
    without_source(resy_load_expert(expertfile = apennine_json_path()))
  )
})

test_that("the bundled EUNIS system is shipped compressed and loads", {
  p <- resy_expert_path("EUNIS", "2025-10-03")
  expect_match(basename(p), "^expert\\.txt\\.xz$")
  parsed <- resy_load_expert(scheme = "EUNIS", version = "2025-10-03",
                             location = "package")
  expect_gt(length(parsed$vegtype.formula.names), 100L)
})

test_that("resy_add_classification stores a .json.xz file byte-identical", {
  withr::local_envvar(R_USER_DATA_DIR = withr::local_tempdir())
  xz <- xz_copy(apennine_json_path(), withr::local_tempdir())
  out <- resy_add_classification(xz, scheme = "XzScheme", version = "1.0")
  expect_equal(basename(out$json), "expert.json.xz")
  expect_identical(unname(tools::md5sum(out$json)), unname(tools::md5sum(xz)))
  expect_identical(
    without_source(resy_load_expert(scheme = "XzScheme", version = "1.0")),
    without_source(resy_load_expert(expertfile = apennine_json_path()))
  )
})
