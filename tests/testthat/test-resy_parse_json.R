# resy_parse_json() reads a structured JSON expert system into the internal
# resy_parsed_expert object. These tests cover its input contract: the required
# top-level keys and per-rule keys, coercion of the synonyms/groups objects, and
# the convention that rule keys beginning with "_" (comments) are ignored. The
# short-code extraction that follows is covered in test-resy_parse_esy.R.

write_expert_json <- function(...) {
  tmp <- tempfile(fileext = ".json")
  jsonlite::write_json(list(...), tmp, auto_unbox = TRUE)
  tmp
}

minimal_rules <- function() {
  list(list(priority = "5", code = "AB", description = "A type",
            expression = "<### G1>"))
}

test_that("a minimal valid JSON parses to a resy_parsed_expert", {
  tmp <- write_expert_json(
    metadata = list(scheme = "t", version = "0"),
    synonyms = setNames(list(), character(0)),
    groups   = list(`### G1` = list("Sp1", "Sp2")),
    rules    = minimal_rules()
  )
  on.exit(unlink(tmp))
  parsed <- RESY:::resy_parse_json(tmp)
  expect_s3_class(parsed, "resy_parsed_expert")
  expect_equal(parsed$vegtype.formula.names.short, "AB")
})

test_that("a missing top-level key is reported", {
  tmp <- write_expert_json(
    synonyms = setNames(list(), character(0)),
    groups   = list(`### G1` = list("Sp1"))
    # rules missing
  )
  on.exit(unlink(tmp))
  expect_error(RESY:::resy_parse_json(tmp), "missing required keys")
})

test_that("a rule missing a required key is reported with its index", {
  tmp <- write_expert_json(
    synonyms = setNames(list(), character(0)),
    groups   = list(`### G1` = list("Sp1")),
    rules    = list(list(priority = "5", code = "AB", description = "d"))
    # expression missing
  )
  on.exit(unlink(tmp))
  expect_error(RESY:::resy_parse_json(tmp), "Rule 1 is missing")
})

test_that("an empty rules array is rejected", {
  tmp <- write_expert_json(
    synonyms = setNames(list(), character(0)),
    groups   = list(`### G1` = list("Sp1")),
    rules    = list()
  )
  on.exit(unlink(tmp))
  expect_error(RESY:::resy_parse_json(tmp), "non-empty")
})

test_that("keys beginning with '_' are treated as comments, not data", {
  tmp <- write_expert_json(
    metadata = list(scheme = "t", version = "0"),
    synonyms = setNames(list(), character(0)),
    groups   = list(`### G1` = list("Sp1")),
    rules    = list(list(`_comment` = "ignore me", priority = "5",
                         code = "AB", description = "d",
                         expression = "<### G1>"))
  )
  on.exit(unlink(tmp))
  parsed <- RESY:::resy_parse_json(tmp)
  expect_s3_class(parsed, "resy_parsed_expert")
  expect_equal(parsed$vegtype.formula.names.short, "AB")
})

test_that("synonyms map canonical names to their alias vectors", {
  tmp <- write_expert_json(
    metadata = list(scheme = "t", version = "0"),
    synonyms = list(`Achillea millefolium agg.` =
                      list("Achillea millefolium", "Achillea pratensis")),
    groups   = list(`### G1` = list("Sp1")),
    rules    = minimal_rules()
  )
  on.exit(unlink(tmp))
  parsed <- RESY:::resy_parse_json(tmp)
  expect_equal(parsed$aggs[["Achillea millefolium agg."]],
               c("Achillea millefolium", "Achillea pratensis"))
})

test_that("a nonexistent path errors", {
  expect_error(RESY:::resy_parse_json(tempfile(fileext = ".json")),
               "File not found")
})
