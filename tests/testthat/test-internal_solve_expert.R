# The membership solver resolves each condition to the set of taxa it covers.
# These helpers are the resolution primitives:
#   .resy_membership_parts       splits "A|B" combinations and strips a prefix
#   .resy_group_taxa_union       union of members of the referenced groups
#   .resy_group_taxa_or_species  same, but a token that is not a group name is
#                                treated as a single species
# A wrong split or a missed prefix silently changes which species a rule sees,
# so these are pinned directly. A small end-to-end solve guards the assembly.

groups       <- list(`### GrpA` = c("Sp1", "Sp2"), `### GrpB` = c("Sp2", "Sp3"))
groups.names <- substr(names(groups), 5, nchar(names(groups)))

# ---- .resy_membership_parts -------------------------------------------------

test_that(".resy_membership_parts splits on the | combine operator", {
  expect_equal(RESY:::.resy_membership_parts("GrpA|GrpB"), c("GrpA", "GrpB"))
})

test_that(".resy_membership_parts strips a leading condition prefix", {
  expect_equal(RESY:::.resy_membership_parts("#TC GrpA", prefix = "#TC"), "GrpA")
})

test_that(".resy_membership_parts drops empty parts", {
  expect_length(RESY:::.resy_membership_parts(""), 0L)
  expect_equal(RESY:::.resy_membership_parts("GrpA||GrpB"), c("GrpA", "GrpB"))
})

# ---- .resy_group_taxa_union -------------------------------------------------

test_that(".resy_group_taxa_union returns the members of a single group", {
  expect_equal(
    RESY:::.resy_group_taxa_union("GrpA", groups, groups.names),
    c("Sp1", "Sp2")
  )
})

test_that(".resy_group_taxa_union unions combined groups without duplicates", {
  expect_equal(
    RESY:::.resy_group_taxa_union("GrpA|GrpB", groups, groups.names),
    c("Sp1", "Sp2", "Sp3")
  )
})

test_that(".resy_group_taxa_union returns empty for an unknown group", {
  expect_length(
    RESY:::.resy_group_taxa_union("Nope", groups, groups.names), 0L
  )
})

# ---- .resy_group_taxa_or_species --------------------------------------------

test_that(".resy_group_taxa_or_species keeps a non-group token as a species", {
  expect_equal(
    RESY:::.resy_group_taxa_or_species("GrpA|Sp9", groups, groups.names),
    c("Sp1", "Sp2", "Sp9")
  )
})

# ---- end-to-end: the solver assembles a classification ----------------------

test_that(".resy_solve_membership classifies a plot from a parsed expert", {
  expert <- c(
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
  parsed <- RESY:::.resy_build_parsed(
    RESY:::parse.classification.expert.vector(expert)
  )

  obs <- data.table::data.table(
    PlotObservationID = c("p1", "p1", "p2"),
    TaxonName         = c("Nardus stricta", "Nardus stricta", "Fagus sylvatica"),
    Cover_Perc        = c(20, 20, 40)
  )
  header    <- data.frame(PlotObservationID = c("p1", "p2"))
  plot.cond <- RESY:::resy_init_plot_conditions(obs, parsed$conditions)

  res <- suppressMessages(
    RESY:::.resy_solve_membership(obs, header, parsed, plot.cond, mc = 1L)
  )

  expect_type(res$result.classification, "character")
  expect_equal(res$result.classification[["p1"]], "GR")
  expect_equal(res$result.classification[["p2"]], "FO")
})
