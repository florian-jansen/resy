# resy_classify() is the front door: load an expert system, resolve names,
# evaluate the membership formulas, and return one classification per plot.
# These tests run the minimal Apennine-test scheme on the bundled example data
# and pin the result's shape, the value set (defined codes plus the "?" no-match
# marker), the per-plot candidate table, and determinism. They also pin the
# no-silent-substitution floor: an unknown species is classified as unknown,
# never a best guess.

example_obs <- function() {
  sp <- utils::read.csv(
    system.file("extdata", "data_example_species.csv", package = "RESY"),
    stringsAsFactors = FALSE
  )
  names(sp)[names(sp) == "species"] <- "TaxonName"
  names(sp)[names(sp) == "cover"]   <- "Cover_Perc"
  sp
}

test_that("resy_classify returns one classification per plot as a resy_result", {
  obs    <- example_obs()
  header <- as.data.frame(unique(obs["PlotObservationID"]))

  res <- suppressMessages(
    resy_classify(obs, header, scheme = "Apennine-test", mc = 1L)
  )

  expect_s3_class(res, "resy_result")
  cls <- res$result.classification
  expect_type(cls, "character")
  expect_equal(length(cls), nrow(header))
  expect_setequal(names(cls), as.character(header$PlotObservationID))
})

test_that("every classification is a defined code or the no-match marker", {
  obs    <- example_obs()
  header <- as.data.frame(unique(obs["PlotObservationID"]))

  res <- suppressMessages(
    resy_classify(obs, header, scheme = "Apennine-test", mc = 1L)
  )
  codes <- res$parsed$vegtype.formula.names.short
  expect_true(all(res$result.classification %in% c(codes, "?")))
})

test_that("the candidate table lists priorities per plot", {
  obs    <- example_obs()
  header <- as.data.frame(unique(obs["PlotObservationID"]))

  res <- suppressMessages(
    resy_classify(obs, header, scheme = "Apennine-test", mc = 1L)
  )
  cand <- res$candidates
  expect_s3_class(cand, "data.table")
  expect_named(cand, c("plot_id", "type", "priority", "priority_rank"),
               ignore.order = TRUE)
  expect_type(cand$priority_rank, "integer")
  expect_true(all(cand$plot_id %in% as.character(header$PlotObservationID)))
})

test_that("classification is deterministic", {
  obs    <- example_obs()
  header <- as.data.frame(unique(obs["PlotObservationID"]))

  r1 <- suppressMessages(resy_classify(obs, header, scheme = "Apennine-test", mc = 1L))
  r2 <- suppressMessages(resy_classify(obs, header, scheme = "Apennine-test", mc = 1L))
  expect_identical(r1$result.classification, r2$result.classification)
})

test_that("resy_classify reports taxon resolution and never guesses unknowns", {
  obs <- data.table::data.table(
    PlotObservationID = c("p1", "p1", "p2"),
    TaxonName         = c("Fagus sylvatica",
                          "Xxx nonexistentus",   # not in any backbone
                          "Yyy alsoinvented"),
    Cover_Perc        = c(40, 5, 30)
  )
  header <- data.frame(PlotObservationID = c("p1", "p2"))

  res <- suppressMessages(
    resy_classify(obs, header, scheme = "Apennine-test", mc = 1L)
  )
  tr <- res$taxon_resolution
  expect_type(tr, "list")
  expect_true(all(c("n", "resolved", "unresolved") %in% names(tr)))

  # The invented names are not silently remapped: they survive verbatim in the
  # observations passed to the solver.
  expect_true(all(c("Xxx nonexistentus", "Yyy alsoinvented") %in%
                    res$obs$TaxonName))
  # A plot whose only taxa are unknown cannot match any type.
  expect_equal(unname(res$result.classification[["p2"]]), "?")
})
