# Functions and arguments of the name matching through the synonym layer are
# deprecated in favour of the taxonomic backbone.

test_that("synonym-layer functions are deprecated", {
  lifecycle::expect_deprecated(resy_read_synonyms(data.frame(
    synonym = "A b", esy_canonical = "A c", source = "x")))
  lifecycle::expect_deprecated(resy_canonical_species(data.frame(esy_canonical = "A b")))
  lifecycle::expect_deprecated(
    resy_resolve_taxa(data.frame(TaxonName = "A b"),
                      synonyms = data.frame(synonym = "A b", esy_canonical = "A c",
                                            source = "x"),
                      canonical = c("A c", "D e")))
  lifecycle::expect_deprecated(resy_clean_names("Fagus sylvatica L."))
})

test_that("taxonomy arguments of resy_classify and resy_harmonize_eunis are deprecated", {
  sp <- data.frame(PlotObservationID = "p1", TaxonName = "Fagus sylvatica", Cover_Perc = 50)
  header <- data.frame(PlotObservationID = "p1")
  lifecycle::expect_deprecated(suppressMessages(
    resy_classify(sp, header, scheme = "Apennine-test", version = "2026-06-27",
                  resolve_taxa = FALSE, mc = 1L)))
  plots <- data.frame(PlotObservationID = "s1", Longitude = 8.15, Latitude = 53.55)
  # the site warnings of the example are muffled, the deprecation is not
  only_deprecation <- function(expr) withCallingHandlers(expr, warning = function(w) {
    if (!inherits(w, "lifecycle_warning_deprecated")) invokeRestart("muffleWarning")
  })
  lifecycle::expect_deprecated(only_deprecation(
    resy_harmonize_eunis(plots, source_crs = 4326, run_taxonomy = FALSE, verbose = FALSE)))
})
