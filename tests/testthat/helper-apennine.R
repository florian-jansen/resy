# The Apennine-test example classified once per test run, shared by the tests
# of resy_eval_plot() and resy_compare_types(), and a builder for small expert
# systems written as JSON.

eval_plot_data <- function() {
  sp <- utils::read.csv(
    system.file("extdata", "data_example_species.csv", package = "RESY"),
    stringsAsFactors = FALSE
  )
  names(sp)[names(sp) == "scientificName"] <- "TaxonName"
  sp
}

apennine_result <- local({
  res <- NULL
  function() {
    if (is.null(res)) {
      sp <- eval_plot_data()
      header <- as.data.frame(unique(sp["PlotObservationID"]))
      res <<- suppressMessages(
        resy_classify(sp, header, scheme = "Apennine-test", mc = 1L)
      )
    }
    res
  }
})

# A JSON expert system with one rule per row of `rules` (columns code,
# priority, expression; the description is the code), written to a temporary
# file whose path is returned.
tiny_expert <- function(rules, species = "Fagus sylvatica", groups = list()) {
  rules$description <- rules$code
  path <- tempfile(fileext = ".json")
  synonyms <- stats::setNames(rep(list(list()), length(species)), species)
  jsonlite::write_json(list(metadata = list(scheme = "test", version = "1"),
                            groups = groups, synonyms = synonyms, rules = rules),
                       path, auto_unbox = TRUE)
  path
}
