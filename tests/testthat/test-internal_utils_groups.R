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
