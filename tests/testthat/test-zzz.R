# zzz.R only registers the non-standard-evaluation column names used inside the
# data.table pipelines (Cover_Perc, TaxonName, ind, values, ...) via
# utils::globalVariables(), so R CMD check does not flag them as undefined
# globals. There is no runtime behaviour to assert directly; instead this is a
# plumbing check that the pipelines relying on those names run without a
# "no visible binding" error, which is what the registration guards against.

test_that("data.table NSE pipelines relying on registered globals run", {
  aggs <- list(`Grp` = c("Sp1", "Sp2"))
  obs  <- data.table::data.table(
    PlotObservationID = 1:2,
    TaxonName         = c("Sp1", "Sp3"),
    Cover_Perc        = c(10, 20)
  )
  # resy_aggregate_taxa uses the `ind`/`values` NSE columns registered in zzz.R.
  expect_silent(out <- RESY:::resy_aggregate_taxa(obs, aggs))
  expect_equal(out$TaxonName, c("Grp", "Sp3"))
})

test_that("the package namespace loads and exposes its front-door verbs", {
  for (fn in c("resy_classify", "resy_expert_path", "resy_load_expert")) {
    expect_true(is.function(getExportedValue("RESY", fn)))
  }
})
