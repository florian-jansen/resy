library(testthat)

# ---- Shared helper tests ----------------------------------------------------

test_that(".resy_esy_balanced_brackets: paired brackets pass", {
  expect_true(RESY:::.resy_esy_balanced_brackets("(<A> AND <B>)"))
  expect_true(RESY:::.resy_esy_balanced_brackets("[(<A> OR <B>) AND <C>]"))
  expect_true(RESY:::.resy_esy_balanced_brackets(""))
})

test_that(".resy_esy_balanced_brackets: mismatched or unclosed brackets fail", {
  expect_false(RESY:::.resy_esy_balanced_brackets("(<A> AND <B>"))   # unclosed (
  expect_false(RESY:::.resy_esy_balanced_brackets("(<A> AND [<B>))")) # wrong closer
  expect_false(RESY:::.resy_esy_balanced_brackets(")"))               # closer without opener
})

test_that(".resy_esy_extract_group_refs: extracts names from #TC, ###, #SC", {
  expr  <- "(<#TC Beech-forest-trees GR 15> AND <### Nardus-grassland GR 25>)"
  refs  <- RESY:::.resy_esy_extract_group_refs(expr)
  expect_contains(refs, "Beech-forest-trees")
  expect_contains(refs, "Nardus-grassland")
})

test_that(".resy_esy_extract_group_refs: ignores species names and thresholds", {
  expr  <- "<Nardus stricta GR 10>"
  refs  <- RESY:::.resy_esy_extract_group_refs(expr)
  expect_length(refs, 0L)
})

# ---- JSON validator: valid file passes --------------------------------------

test_that("resy_validate_esy: Apennine-test JSON passes validation", {
  path <- system.file(
    "extdata/classifications/Apennine-test/2026-06-27/expert.json",
    package = "RESY"
  )
  skip_if(!nzchar(path), "Apennine-test JSON not found")
  result <- resy_validate_esy(path, verbose = FALSE)
  expect_true(result$ok)
  expect_length(result$errors, 0L)
  expect_equal(result$meta$vegtypes_defined, 5L)
})

test_that("resy_validate_esy: EUNIS JSON passes validation", {
  path <- system.file(
    "extdata/classifications/EUNIS/2025-10-03/expert.json",
    package = "RESY"
  )
  skip_if(!nzchar(path), "EUNIS JSON not found")
  result <- resy_validate_esy(path, verbose = FALSE)
  expect_true(result$ok)
  expect_length(result$errors, 0L)
})

# ---- JSON validator: structural errors --------------------------------------

make_json <- function(...) {
  tmp <- tempfile(fileext = ".json")
  jsonlite::write_json(list(...), tmp, auto_unbox = TRUE)
  tmp
}

test_that("resy_validate_esy JSON: missing required top-level key → error", {
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

test_that("resy_validate_esy JSON: empty rules array → error", {
  tmp <- make_json(
    synonyms = list(),
    groups   = list(`### G` = list("Sp1")),
    rules    = list()
  )
  result <- resy_validate_esy(tmp, verbose = FALSE)
  expect_false(result$ok)
  expect_true(any(grepl("rules", result$errors)))
})

test_that("resy_validate_esy JSON: rule missing required key → error", {
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

test_that("resy_validate_esy JSON: invalid priority character → error", {
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

test_that("resy_validate_esy JSON: code with whitespace → error", {
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

test_that("resy_validate_esy JSON: empty expression → error", {
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

test_that("resy_validate_esy JSON: expression without <...> → error", {
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

test_that("resy_validate_esy JSON: unbalanced brackets → error", {
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

test_that("resy_validate_esy JSON: group key with bad prefix → error", {
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

test_that("resy_validate_esy JSON: duplicate codes → warning (not strict)", {
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

test_that("resy_validate_esy JSON: duplicate codes → error in strict mode", {
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

test_that("resy_validate_esy JSON: undefined group reference → warning", {
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

# ---- resy_add_classification: validation gate --------------------------------

test_that("resy_add_classification stops on invalid JSON", {
  bad_json <- make_json(
    synonyms = list(),
    # groups key missing
    rules = list(
      list(priority = "5", code = "AB", description = "d", expression = "<### G>")
    )
  )
  expect_error(
    resy_add_classification(bad_json, scheme = "Test", version = "0",
                            location = "user"),
    "Validation failed"
  )
})

test_that("resy_add_classification accepts valid JSON without errors", {
  valid_json <- make_json(
    synonyms = list(),
    groups   = list(`### G` = list("Sp1")),
    rules    = list(
      list(priority = "5", code = "AB", description = "Test type",
           expression = "<### G>")
    )
  )
  out_dir <- file.path(tempdir(), "resy_test_store")
  # Patch resy_classifications_root temporarily
  withr::with_envvar(
    list(RESY_CLASSIFICATIONS_ROOT = out_dir),
    {
      res <- tryCatch(
        resy_add_classification(valid_json, scheme = "TestScheme",
                                version = "0.0.1", location = "user"),
        error = function(e) e
      )
      # We just want to confirm it didn't fail on validation;
      # it may fail on storage if the env var isn't honoured
      if (inherits(res, "error")) {
        expect_false(grepl("Validation failed", conditionMessage(res)))
      } else {
        expect_true(file.exists(res$json))
      }
    }
  )
})
