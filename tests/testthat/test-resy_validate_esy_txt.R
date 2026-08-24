library(testthat)

# Helper to create TXT files for testing
make_txt <- function(sec1 = "", sec2 = "", sec3 = "") {
  tmp <- tempfile(fileext = ".txt")
  content <- paste(
    "SECTION 1: Description",
    sec1,
    "",
    "SECTION 2: Groups",
    sec2,
    "",
    "SECTION 3: Types",
    sec3,
    sep = "\n"
  )
  writeLines(content, tmp, useBytes = TRUE)
  tmp
}

# ---- TXT Validator: Valid files pass ----------------------------------------

test_that("resy_validate_esy_txt: minimal valid TXT passes", {
  tmp <- make_txt(
    sec1 = "Test classification",
    sec2 = "### TestGroup\n  Sp1\n  Sp2",
    sec3 = "0         AB   <### TestGroup GR 10>"
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_true(result$ok)
  expect_length(result$errors, 0L)
  expect_equal(result$meta$groups_defined, 1L)
  expect_equal(result$meta$vegtypes_defined, 1L)
})

test_that("resy_validate_esy_txt: multiple sections and groups pass", {
  tmp <- make_txt(
    sec1 = "Forest classification system\nAuthor: Test",
    sec2 = "### Deciduous\n  Fagus\n  Quercus\n### Coniferous\n  Picea\n  Abies",
    sec3 = "0         AB   Forest <### Deciduous GR 20>\n1         CD   Conifer <### Coniferous GE 15>"
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_true(result$ok)
  expect_equal(result$meta$groups_defined, 2L)
  expect_equal(result$meta$vegtypes_defined, 2L)
})

test_that("resy_validate_esy_txt: priority can be 0-9, A-Z, a-z", {
  tmp <- make_txt(
    sec1 = "Test",
    sec2 = "### G\n  Sp1",
    sec3 = "0         AB   <### G>\n9         CD   <### G>\nA         EF   <### G>\nZ         GH   <### G>\na         IJ   <### G>\nz         KL   <### G>"
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_true(result$ok)
  expect_equal(result$meta$vegtypes_defined, 6L)
})

test_that("resy_validate_esy_txt: complex formulas with AND/OR/NOT pass", {
  tmp <- make_txt(
    sec1 = "Test",
    sec2 = "### A\n  Sp1\n### B\n  Sp2",
    sec3 = "0         AB   (<### A GR 10> AND <### B GE 5>)\n1         CD   (<### A> OR <### B>)\n2         EF   NOT <### A>"
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_true(result$ok)
  expect_equal(result$meta$vegtypes_defined, 3L)
})

# ---- TXT Validator: Structural errors ----------------------------------------

test_that("resy_validate_esy_txt: missing SECTION 1 header → error", {
  tmp <- make_txt(
    sec1 = "",
    sec2 = "### G\n  Sp1",
    sec3 = "0         AB   <### G>"
  )
  # Manually create without SECTION 1
  content <- "SECTION 2: Groups\n### G\n  Sp1\n\nSECTION 3: Types\n0         AB   <### G>"
  writeLines(content, tmp, useBytes = TRUE)
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("SECTION 1", result$errors)))
})

test_that("resy_validate_esy_txt: missing SECTION 2 header → error", {
  tmp <- tempfile(fileext = ".txt")
  content <- "SECTION 1: Description\nTest\n\nSECTION 3: Types\n0         AB   <### G>"
  writeLines(content, tmp, useBytes = TRUE)
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("SECTION 2", result$errors)))
})

test_that("resy_validate_esy_txt: missing SECTION 3 header → error", {
  tmp <- tempfile(fileext = ".txt")
  content <- "SECTION 1: Description\nTest\n\nSECTION 2: Groups\n### G\n  Sp1"
  writeLines(content, tmp, useBytes = TRUE)
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("SECTION 3", result$errors)))
})

test_that("resy_validate_esy_txt: sections not in order → error", {
  tmp <- tempfile(fileext = ".txt")
  content <- "SECTION 2: Groups\n### G\n  Sp1\n\nSECTION 1: Description\nTest\n\nSECTION 3: Types\n0         AB   <### G>"
  writeLines(content, tmp, useBytes = TRUE)
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("not in the correct order", result$errors)))
})

test_that("resy_validate_esy_txt: empty vegetation type code → error", {
  tmp <- make_txt(
    sec1 = "Test",
    sec2 = "### G\n  Sp1",
    sec3 = "0                  <### G>"  # code missing (only spaces)
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("Empty vegetation type code", result$errors)))
})

test_that("resy_validate_esy_txt: missing formula for type → warning (not strict)", {
  tmp <- make_txt(
    sec1 = "Test",
    sec2 = "### G\n  Sp1",
    sec3 = "0         AB   # No formula on next line"
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_true(result$ok)  # warning, not error
  expect_true(any(grepl("Missing formula", result$warnings)))
})

test_that("resy_validate_esy_txt: relational operator outside <...> → error", {
  tmp <- make_txt(
    sec1 = "Test",
    sec2 = "### G\n  Sp1",
    sec3 = "0         AB   > GR 10 <### G>"
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("relational operator outside", result$errors)))
})

test_that("resy_validate_esy_txt: undefined group reference → warning", {
  tmp <- make_txt(
    sec1 = "Test",
    sec2 = "### Defined\n  Sp1",
    sec3 = "0         AB   <### Defined GR 10> AND <### Undefined GR 5>"
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_true(result$ok)
  expect_true(any(grepl("Undefined", result$warnings)))
})

test_that("resy_validate_esy_txt: empty group name in SECTION 2 → error", {
  tmp <- make_txt(
    sec1 = "Test",
    sec2 = "###\n  Sp1",  # empty group name
    sec3 = "0         AB   <### G>"
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("Empty group name", result$errors)))
})

test_that("resy_validate_esy_txt: duplicate vegetation codes → warning", {
  tmp <- make_txt(
    sec1 = "Test",
    sec2 = "### G\n  Sp1",
    sec3 = "0         AB   <### G>\n1         AB   <### G>"
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_true(result$ok)  # warning, not error
  expect_true(any(grepl("Duplicate", result$warnings)))
})

test_that("resy_validate_esy_txt: duplicate codes → error in strict mode", {
  tmp <- make_txt(
    sec1 = "Test",
    sec2 = "### G\n  Sp1",
    sec3 = "0         AB   <### G>\n1         AB   <### G>"
  )
  result <- resy_validate_esy(tmp, strict = TRUE, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("Duplicate", result$errors)))
})

# ---- TXT Validator: Formula validation ----------------------------------------

test_that("resy_validate_esy_txt: formula without <...> → error", {
  tmp <- make_txt(
    sec1 = "Test",
    sec2 = "### G\n  Sp1",
    sec3 = "0         AB   Sp1 GR 10"  # no <...> brackets
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("membership condition", result$errors)))
})

test_that("resy_validate_esy_txt: unbalanced brackets → error", {
  tmp <- make_txt(
    sec1 = "Test",
    sec2 = "### G\n  Sp1",
    sec3 = "0         AB   (<### G GR 10> AND <### G GE 5>"  # missing )
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("Unbalanced bracket", result$errors)))
})

test_that("resy_validate_esy_txt: dangling AND at end → error", {
  tmp <- make_txt(
    sec1 = "Test",
    sec2 = "### G\n  Sp1",
    sec3 = "0         AB   <### G> AND"
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("Dangling logical operator", result$errors)))
})

test_that("resy_validate_esy_txt: dangling OR at start → error", {
  tmp <- make_txt(
    sec1 = "Test",
    sec2 = "### G\n  Sp1",
    sec3 = "0         AB   OR <### G>"
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("Dangling logical operator", result$errors)))
})

test_that("resy_validate_esy_txt: legacy UP operator → warning", {
  tmp <- make_txt(
    sec1 = "Test",
    sec2 = "### G\n  Sp1",
    sec3 = "0         AB   <### G UP 10>"
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_true(result$ok)  # warning, not error by default
  expect_true(any(grepl("UP", result$warnings)))
})

test_that("resy_validate_esy_txt: legacy UP operator → error in strict mode", {
  tmp <- make_txt(
    sec1 = "Test",
    sec2 = "### G\n  Sp1",
    sec3 = "0         AB   <### G UP 10>"
  )
  result <- resy_validate_esy(tmp, strict = TRUE, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("UP", result$errors)))
})

# ---- TXT Validator: Tab detection ----

test_that("resy_validate_esy_txt: tab characters detected → warning", {
  tmp <- tempfile(fileext = ".txt")
  content <- "SECTION 1: Description\nTest\n\nSECTION 2: Groups\n### G\tExtraStuff\n  Sp1\n\nSECTION 3: Types\n0         AB   <### G>"
  writeLines(content, tmp, useBytes = TRUE)
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_true(result$ok)
  expect_true(any(grepl("Tab character", result$warnings)))
  expect_true(result$meta$tabs_present)
})

# ---- TXT Validator: Disabled types (---) ----

test_that("resy_validate_esy_txt: disabled types (---) are skipped", {
  tmp <- make_txt(
    sec1 = "Test",
    sec2 = "### G\n  Sp1",
    sec3 = "0         AB   <### G>\n---  0         CD   <### G>"  # disabled type
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_true(result$ok)
  expect_equal(result$meta$vegtypes_defined, 1L)  # only AB, not CD
})

# ---- TXT Validator: Multi-line formulas ----

test_that("resy_validate_esy_txt: formulas spanning multiple lines pass", {
  tmp <- make_txt(
    sec1 = "Test",
    sec2 = "### G1\n  Sp1\n### G2\n  Sp2",
    sec3 = "0         AB   (<### G1 GR 10>\n  AND\n  <### G2 GE 5>)"
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_true(result$ok)
  expect_equal(result$meta$vegtypes_defined, 1L)
})
