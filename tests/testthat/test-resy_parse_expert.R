# The text parser reads the canonical three-section .txt expert file into the
# same intermediate list the JSON parser produces, which .resy_build_parsed then
# turns into a resy_parsed_expert. These tests drive parse.classification.expert.vector
# on an in-memory file so no fixture is needed, and check the two things that
# silently corrupt a classification if wrong: which species land in which
# aggregation/group, and that an unknown group prefix is rejected rather than
# mis-parsed.

mini_expert <- c(
  "SECTION 1: Species aggregation",
  "Achillea millefolium agg.",
  "     Achillea millefolium",
  "     Achillea pratensis",
  "SECTION 1: End",
  "SECTION 2: Species groups",
  "### Grassland-herbs",
  "     Nardus stricta",
  "     Achillea millefolium agg.",
  "### Forest-trees",
  "     Fagus sylvatica",
  "     Abies alba",
  "",
  "SECTION 2: End",
  "SECTION 3: Group definitions",
  "5          GR Grassland",
  "<### Grassland-herbs GR 0>",
  "2          FO Forest",
  "<### Forest-trees GR 0>",
  "SECTION 3: End"
)

test_that("section 1 aggregations map an aggregate to its members", {
  raw <- RESY:::parse.classification.expert.vector(mini_expert)
  expect_equal(
    raw$aggs[["Achillea millefolium agg."]],
    c("Achillea millefolium", "Achillea pratensis")
  )
})

test_that("section 2 groups keep their prefix and members", {
  raw <- RESY:::parse.classification.expert.vector(mini_expert)
  expect_setequal(names(raw$groups), c("### Grassland-herbs", "### Forest-trees"))
  expect_equal(raw$groups[["### Grassland-herbs"]],
               c("Nardus stricta", "Achillea millefolium agg."))
  expect_equal(raw$groups[["### Forest-trees"]],
               c("Fagus sylvatica", "Abies alba"))
})

test_that("section 3 yields formulas and their priorities", {
  raw <- RESY:::parse.classification.expert.vector(mini_expert)
  expect_length(raw$formulas, 2L)
  expect_equal(as.character(raw$membership.priority), c("5", "2"))
})

test_that(".resy_build_parsed extracts the short codes", {
  parsed <- RESY:::.resy_build_parsed(
    RESY:::parse.classification.expert.vector(mini_expert)
  )
  expect_s3_class(parsed, "resy_parsed_expert")
  expect_equal(parsed$vegtype.formula.names.short, c("GR", "FO"))
})

test_that("an unknown group prefix is rejected", {
  bad <- mini_expert
  bad[7] <- "@@@ Grassland-herbs"   # not a recognised prefix
  expect_error(
    RESY:::parse.classification.expert.vector(bad),
    "known group prefixes"
  )
})
