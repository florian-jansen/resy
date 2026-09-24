library(testthat)

# Helper to create JSON files for testing
make_json <- function(...) {
  tmp <- tempfile(fileext = ".json")
  jsonlite::write_json(list(...), tmp, auto_unbox = TRUE)
  tmp
}

# ---- JSON Validator: Valid files pass ----------------------------------------

test_that("resy_validate_esy_json: valid minimal JSON passes", {
  tmp <- make_json(
    synonyms = list(),
    groups   = list(`### G` = list("Sp1")),
    rules    = list(
      list(priority = "5", code = "AB", description = "Test",
           expression = "<### G GR 10>")
    )
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_true(result$ok)
  expect_length(result$errors, 0L)
  expect_equal(result$meta$groups_defined, 1L)
  expect_equal(result$meta$vegtypes_defined, 1L)
})

test_that("resy_validate_esy_json: multiple groups and rules pass", {
  tmp <- make_json(
    synonyms = list(),
    groups   = list(
      `### Forest` = list("Sp1", "Sp2"),
      `#TC Beech` = list("Fagus"),
      `#SC Oak` = list("Quercus")
    ),
    rules    = list(
      list(priority = "1", code = "BF", description = "Beech forest",
           expression = "(<### Forest> AND <#TC Beech>)"),
      list(priority = "2", code = "OF", description = "Oak forest",
           expression = "(<### Forest> AND <#SC Oak>)")
    )
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_true(result$ok)
  expect_equal(result$meta$groups_defined, 3L)
  expect_equal(result$meta$vegtypes_defined, 2L)
})

test_that("resy_validate_esy_json: metadata is optional", {
  tmp <- make_json(
    synonyms = list(),
    groups   = list(`### G` = list("Sp1")),
    rules    = list(
      list(priority = "5", code = "AB", description = "d", expression = "<### G>")
    )
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_true(result$ok)
  expect_true(any(grepl("metadata", result$warnings)))
})

# ---- JSON Validator: Structural errors ------

test_that("resy_validate_esy_json: missing required top-level key → error", {
  tmp <- make_json(
    synonyms = list(),
    groups   = list(),
    # rules intentionally missing
    metadata = list(scheme = "test", version = "0")
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("rules", result$errors)))
})

test_that("resy_validate_esy_json: empty rules array → error", {
  tmp <- make_json(
    synonyms = list(),
    groups   = list(`### G` = list("Sp1")),
    rules    = list()
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("rules", result$errors)))
})

test_that("resy_validate_esy_json: rule missing required key → error", {
  tmp <- make_json(
    synonyms = list(),
    groups   = list(`### G` = list("Sp1")),
    rules    = list(
      list(priority = "5", code = "AB", description = "Test")
      # expression missing
    )
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("expression", result$errors)))
})

test_that("resy_validate_esy_json: empty code → error", {
  tmp <- make_json(
    synonyms = list(),
    groups   = list(`### G` = list("Sp1")),
    rules    = list(
      list(priority = "5", code = "", description = "d", expression = "<### G>")
    )
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("Empty code", result$errors)))
})

test_that("resy_validate_esy_json: invalid priority character → error", {
  tmp <- make_json(
    synonyms = list(),
    groups   = list(`### G` = list("Sp1")),
    rules    = list(
      list(priority = "55", code = "AB", description = "d",
           expression = "<### G>")
    )
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("priority", result$errors)))
})

test_that("resy_validate_esy_json: code with whitespace → error", {
  tmp <- make_json(
    synonyms = list(),
    groups   = list(`### G` = list("Sp1")),
    rules    = list(
      list(priority = "5", code = "A B", description = "d",
           expression = "<### G>")
    )
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("whitespace", result$errors)))
})

test_that("resy_validate_esy_json: empty expression → error", {
  tmp <- make_json(
    synonyms = list(),
    groups   = list(`### G` = list("Sp1")),
    rules    = list(
      list(priority = "5", code = "AB", description = "d", expression = "")
    )
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("expression", result$errors)))
})

test_that("resy_validate_esy_json: expression without <...> → error", {
  tmp <- make_json(
    synonyms = list(),
    groups   = list(`### G` = list("Sp1")),
    rules    = list(
      list(priority = "5", code = "AB", description = "d",
           expression = "Sp1 GR 10")
    )
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("membership condition", result$errors)))
})

test_that("resy_validate_esy_json: unbalanced brackets → error", {
  tmp <- make_json(
    synonyms = list(),
    groups   = list(`### G` = list("Sp1")),
    rules    = list(
      list(priority = "5", code = "AB", description = "d",
           expression = "(<### G GR 10> AND <### G GE 05>")
    )
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("bracket", result$errors)))
})

test_that("resy_validate_esy_json: group key with bad prefix → error", {
  tmp <- make_json(
    synonyms = list(),
    groups   = list(`BAD Grp` = list("Sp1")),
    rules    = list(
      list(priority = "5", code = "AB", description = "d",
           expression = "<### Grp GR 10>")
    )
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("recognised prefix", result$errors)))
})

test_that("resy_validate_esy_json: empty group name → error", {
  tmp <- make_json(
    synonyms = list(),
    groups   = list(`### ` = list("Sp1")),
    rules    = list(
      list(priority = "5", code = "AB", description = "d",
           expression = "<### G>")
    )
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("Empty group name", result$errors)))
})

# ---- JSON Validator: Warnings ------------------------------------------------

test_that("resy_validate_esy_json: duplicate codes → warning (not strict)", {
  tmp <- make_json(
    synonyms = list(),
    groups   = list(`### G` = list("Sp1")),
    rules    = list(
      list(priority = "5", code = "AB", description = "d1", expression = "<### G>"),
      list(priority = "5", code = "AB", description = "d2", expression = "<### G>")
    )
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_true(result$ok)   # warning, not error
  expect_true(any(grepl("Duplicate", result$warnings)))
})

test_that("resy_validate_esy_json: duplicate codes → error in strict mode", {
  tmp <- make_json(
    synonyms = list(),
    groups   = list(`### G` = list("Sp1")),
    rules    = list(
      list(priority = "5", code = "AB", description = "d1", expression = "<### G>"),
      list(priority = "5", code = "AB", description = "d2", expression = "<### G>")
    )
  )
  result <- resy_validate_esy(tmp, strict = TRUE, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("Duplicate", result$errors)))
})

test_that("resy_validate_esy_json: undefined group reference → warning", {
  tmp <- make_json(
    synonyms = list(),
    groups   = list(`### G1` = list("Sp1")),
    rules    = list(
      list(priority = "5", code = "AB", description = "d",
           expression = "<### G1> AND <### G_UNDEFINED GR 10>")
    )
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_true(result$ok)
  expect_true(any(grepl("G_UNDEFINED", result$warnings)))
})

test_that("resy_validate_esy_json: empty description → warning (not strict)", {
  tmp <- make_json(
    synonyms = list(),
    groups   = list(`### G` = list("Sp1")),
    rules    = list(
      list(priority = "5", code = "AB", description = "", expression = "<### G>")
    )
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_true(result$ok)
  expect_true(any(grepl("description", result$warnings)))
})

test_that("resy_validate_esy_json: empty description → error in strict mode", {
  tmp <- make_json(
    synonyms = list(),
    groups   = list(`### G` = list("Sp1")),
    rules    = list(
      list(priority = "5", code = "AB", description = "", expression = "<### G>")
    )
  )
  result <- resy_validate_esy(tmp, strict = TRUE, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("description", result$errors)))
})

test_that("resy_validate_esy_json: missing metadata fields → warning", {
  tmp <- make_json(
    synonyms = list(),
    groups   = list(`### G` = list("Sp1")),
    rules    = list(
      list(priority = "5", code = "AB", description = "d", expression = "<### G>")
    ),
    metadata = list(description = "test")
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_true(result$ok)
  expect_true(any(grepl("scheme", result$warnings)) || any(grepl("version", result$warnings)))
})
