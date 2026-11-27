library(testthat)

# ---- .resy_group_prefixes -----------------------------------------------------

test_that(".resy_group_prefixes contains all supported Section 2 group markers", {
  expected <- c("###", "##D", "##Q", "##C", "$$C", "$$N")

  expect_type(RESY:::.resy_group_prefixes, "character")
  expect_equal(RESY:::.resy_group_prefixes, expected)
})

# ---- .resy_group_name ---------------------------------------------------------

test_that(".resy_group_name strips the prefix and following space", {
  expect_equal(RESY:::.resy_group_name("### Forest"), "Forest")
  expect_equal(RESY:::.resy_group_name("##D Wet meadow"), "Wet meadow")
  expect_equal(RESY:::.resy_group_name("##Q Species A"), "Species A")
  expect_equal(RESY:::.resy_group_name("$$N Climate"), "Climate")
})

# ---- .resy_section_rows -------------------------------------------------------

test_that(".resy_section_rows finds all SECTION n opener rows with optional spacing", {
  lines <- c(
    "SECTION 1",
    "  SECTION 2", 
    "not a match",
    "SECTION 2 legend",
    "section 3",
    "  section 2 text",
    "SECTION 10"
  )

  expect_equal(RESY:::.resy_section_rows(lines, 2), c(2, 4, 6))
})

test_that(".resy_section_rows is case-insensitive and ignores other section numbers", {
  lines <- c(
    "section 2",
    "SECTION 3",
    "  Section 2 start",
    "SECTION 20",
    "heading"
  )

  expect_equal(RESY:::.resy_section_rows(lines, 2), c(1, 3))
})

# A group may name other groups (with their prefix); they stand for their
# species, also through several levels.
test_that("groups named in groups are expanded to their species", {
  groups <- list(`### A` = c("Sp1", "Sp2"),
                 `### B` = c("Sp3"),
                 `##D +01 AB` = c("### A", "### B", "Sp4"),
                 `##D +01 C` = c("##D +01 AB", "Sp2"))
  out <- RESY:::.resy_expand_group_refs(groups)
  expect_identical(out[["##D +01 AB"]], c("Sp4", "Sp1", "Sp2", "Sp3"))
  expect_setequal(out[["##D +01 C"]], c("Sp1", "Sp2", "Sp3", "Sp4"))
  expect_identical(out[["### A"]], groups[["### A"]])
  # without references nothing changes
  expect_identical(RESY:::.resy_expand_group_refs(groups[1:2]), groups[1:2])
})

test_that("undefined groups and cycles are reported", {
  expect_match(RESY:::.resy_group_ref_problems(list(`### A` = c("### X"))),
               '"### X", which is not defined')
  cyc <- list(`### A` = c("### B"), `### B` = c("### A", "Sp1"))
  expect_length(RESY:::.resy_group_ref_problems(cyc), 2L)
  expect_error(RESY:::.resy_expand_group_refs(cyc), "contains itself")
})

test_that("JSON and text files resolve groups named in groups alike", {
  json <- tempfile(fileext = ".json")
  jsonlite::write_json(list(
    metadata = list(scheme = "t", version = "0"),
    synonyms = setNames(list(), character(0)),
    groups = list(`### A` = list("Sp1", "Sp2"), `### B` = list("Sp3"),
                  `##D +01 AB` = list("### A", "### B"), `##D +01 C` = list("Sp4")),
    rules = list(list(priority = "5", code = "X", description = "X",
                      expression = "<##Q +01 AB>"))), json, auto_unbox = TRUE)
  on.exit(unlink(json))
  parsed <- RESY:::.resy_parse_json(json)
  expect_identical(parsed$groups[["##D +01 AB"]], c("Sp1", "Sp2", "Sp3"))
  expect_true(resy_validate_esy(json, verbose = FALSE)$ok)

  txt <- tempfile(fileext = ".txt")
  writeLines(c("SECTION 1: Start", "SECTION 1: End", "SECTION 2: Start",
               "### A", "   Sp1", "   Sp2", "### B", "   Sp3",
               "##D +01 AB", "   ### A", "   ### B", "##D +01 C", "   Sp4",
               "SECTION 2: End", "SECTION 3: Start",
               "5          X     X", "<##Q +01 AB>", "SECTION 3: End"), txt)
  on.exit(unlink(txt), add = TRUE)
  expect_identical(resy_load_expert(expertfile = txt)$groups[["##D +01 AB"]],
                   c("Sp1", "Sp2", "Sp3"))
  expect_true(resy_validate_esy(txt, verbose = FALSE)$ok)

  bad <- tempfile(fileext = ".json")
  x <- jsonlite::read_json(json)
  x$groups[["##D +01 AB"]] <- list("### A", "### Z")
  jsonlite::write_json(x, bad, auto_unbox = TRUE)
  on.exit(unlink(bad), add = TRUE)
  v <- resy_validate_esy(bad, verbose = FALSE)
  expect_false(v$ok)
  expect_match(paste(v$errors, collapse = " "), "### Z")
})
