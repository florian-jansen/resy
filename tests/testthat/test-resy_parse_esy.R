library(testthat)

# ---------------------------------------------------------------------------
# Tests for Expert System (ESy) parsing
#
# Covers the rules described in Tichý et al., Appendix S1:
#   Section 3 header format:
#     char 1     : priority digit/letter
#     chars 2-11 : 10 spaces (distance E)
#     chars 12+  : code (variable length) followed by space and description
# ---------------------------------------------------------------------------

# ---- .resy_parse_definition_header -----------------------------------------

test_that(".resy_parse_definition_header: 5-char code (canonical format)", {
  # "VAA01 Lemnetum trisulcae" starting at char 12
  h <- "5          VAA01 Lemnetum trisulcae"
  r <- RESY:::.resy_parse_definition_header(h)
  expect_equal(r$priority,    "5")
  expect_equal(r$code,        "VAA01")
  expect_equal(r$description, "Lemnetum trisulcae")
})

test_that(".resy_parse_definition_header: 2-char code (Apennine-test style)", {
  h <- "5          BF Beech-fir montane forest"
  r <- RESY:::.resy_parse_definition_header(h)
  expect_equal(r$priority,    "5")
  expect_equal(r$code,        "BF")
  expect_equal(r$description, "Beech-fir montane forest")
})

test_that(".resy_parse_definition_header: 2-char code padded to 5 chars", {
  # Code padded with trailing spaces to 5 chars (strict spec-compliant txt)
  h <- "5          BF    Beech-fir montane forest"
  r <- RESY:::.resy_parse_definition_header(h)
  expect_equal(r$priority,    "5")
  expect_equal(r$code,        "BF")
  expect_equal(r$description, "Beech-fir montane forest")
})

test_that(".resy_parse_definition_header: letter priority level", {
  h <- "A          R5560 Nardus acidic grassland"
  r <- RESY:::.resy_parse_definition_header(h)
  expect_equal(r$priority, "A")
  expect_equal(r$code,     "R5560")
})

test_that(".resy_parse_definition_header: disabled line (---) returns NA", {
  h <- "---5          BF Beech-fir montane forest"
  r <- RESY:::.resy_parse_definition_header(h)
  expect_true(is.na(r$priority))
  expect_true(is.na(r$code))
})

# ---- .resy_build_parsed via resy_load_expert (JSON path) -------------------

test_that("JSON parser: vegtype.formula.names.short correct for short codes", {
  path <- system.file(
    "extdata/classifications/Apennine-test/2026-06-27/expert.json",
    package = "RESY"
  )
  skip_if(!nzchar(path), "Apennine-test JSON not found")

  parsed <- RESY:::resy_parse_json(path)

  # All short codes should be the raw code, not code+description prefix
  expect_true(all(nchar(parsed$vegtype.formula.names.short) <= 5))
  expect_contains(parsed$vegtype.formula.names.short, "BF")
  expect_contains(parsed$vegtype.formula.names.short, "NG")
  expect_contains(parsed$vegtype.formula.names.short, "SM")

  # None should contain a space (which would indicate description bled in)
  expect_false(any(grepl(" ", parsed$vegtype.formula.names.short)))
})

test_that("JSON parser: vegtype.formula.names contains full description", {
  path <- system.file(
    "extdata/classifications/Apennine-test/2026-06-27/expert.json",
    package = "RESY"
  )
  skip_if(!nzchar(path), "Apennine-test JSON not found")

  parsed <- RESY:::resy_parse_json(path)

  bf_name <- parsed$vegtype.formula.names[
    parsed$vegtype.formula.names.short == "BF"
  ]
  expect_true(grepl("Beech", bf_name))
})

test_that("JSON parser: formula name format round-trips priority correctly", {
  path <- system.file(
    "extdata/classifications/Apennine-test/2026-06-27/expert.json",
    package = "RESY"
  )
  skip_if(!nzchar(path), "Apennine-test JSON not found")

  parsed <- RESY:::resy_parse_json(path)
  prio   <- as.character(parsed$vegtype.priority)

  # BF and NG have priority 5, SM has priority 3
  bf_prio <- prio[parsed$vegtype.formula.names.short == "BF"]
  sm_prio <- prio[parsed$vegtype.formula.names.short == "SM"]
  expect_equal(bf_prio, "5")
  expect_equal(sm_prio, "3")
})

# ---- vegtype.formula.names.short extraction in .resy_build_parsed ----------

test_that(".resy_build_parsed: short code extracted for various lengths", {
  # Test through the full parse pipeline with a minimal in-memory JSON
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))

  jsonlite::write_json(
    list(
      metadata = list(scheme = "test", version = "0"),
      synonyms = setNames(list(), character(0)),
      groups   = list(`### G1` = list("Sp1", "Sp2")),
      rules    = list(
        list(priority = "5", code = "AB",    description = "Two char",
             expression = "<### G1>"),
        list(priority = "5", code = "ABCDE", description = "Five char",
             expression = "<### G1>"),
        list(priority = "5", code = "A",     description = "One char",
             expression = "<### G1>")
      )
    ),
    tmp, auto_unbox = TRUE
  )

  parsed <- RESY:::resy_parse_json(tmp)
  short  <- parsed$vegtype.formula.names.short

  expect_equal(short[1L], "AB")
  expect_equal(short[2L], "ABCDE")
  expect_equal(short[3L], "A")
  expect_false(any(grepl(" ", short)))
})
