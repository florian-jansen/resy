# resy_aggregate_taxa() rewrites obs$TaxonName to the expert system's
# aggregation level: a member species is replaced by its aggregate name, an
# aggregate name is kept, and a species the mapping does not mention is left
# untouched. Getting this wrong silently mis-counts species per group in the
# solver, so the mapping must be exact and order-preserving.

make_obs <- function(taxa) {
  data.table::data.table(
    PlotObservationID = seq_along(taxa),
    TaxonName         = taxa,
    Cover_Perc        = 10
  )
}

test_that("member species are replaced by their aggregate name", {
  aggs <- list(`Achillea millefolium agg.` =
                 c("Achillea millefolium", "Achillea pratensis"))
  obs  <- make_obs(c("Achillea millefolium", "Achillea pratensis"))
  out  <- RESY:::resy_aggregate_taxa(obs, aggs)
  expect_equal(out$TaxonName,
               c("Achillea millefolium agg.", "Achillea millefolium agg."))
})

test_that("an aggregate name is kept as itself", {
  aggs <- list(`Achillea millefolium agg.` = c("Achillea millefolium"))
  obs  <- make_obs("Achillea millefolium agg.")
  out  <- RESY:::resy_aggregate_taxa(obs, aggs)
  expect_equal(out$TaxonName, "Achillea millefolium agg.")
})

test_that("species outside the mapping are left untouched", {
  aggs <- list(`Achillea millefolium agg.` = c("Achillea millefolium"))
  obs  <- make_obs(c("Achillea millefolium", "Fagus sylvatica"))
  out  <- RESY:::resy_aggregate_taxa(obs, aggs)
  expect_equal(out$TaxonName,
               c("Achillea millefolium agg.", "Fagus sylvatica"))
})

test_that("a data.frame input is coerced to data.table without losing rows", {
  aggs <- list(`Grp` = c("Sp1", "Sp2"))
  obs  <- data.frame(
    PlotObservationID = 1:3,
    TaxonName         = c("Sp1", "Sp2", "Sp3"),
    Cover_Perc        = 10,
    stringsAsFactors  = FALSE
  )
  out <- RESY:::resy_aggregate_taxa(obs, aggs)
  expect_s3_class(out, "data.table")
  expect_equal(nrow(out), 3L)
  expect_equal(out$TaxonName, c("Grp", "Grp", "Sp3"))
})

test_that("aggregation is idempotent", {
  aggs <- list(`Achillea millefolium agg.` =
                 c("Achillea millefolium", "Achillea pratensis"))
  obs  <- make_obs(c("Achillea millefolium", "Achillea pratensis"))
  once  <- RESY:::resy_aggregate_taxa(obs, aggs)
  twice <- RESY:::resy_aggregate_taxa(once, aggs)
  expect_equal(twice$TaxonName, once$TaxonName)
})
