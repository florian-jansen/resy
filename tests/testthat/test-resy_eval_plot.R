# resy_eval_plot() prints the evidence for one plot. The tests check that it
# reads the plot's own row of the solver results when the header is in a
# different order from the observations, and that the conditions of a type name
# the plot's taxa responsible for them. The condition helpers are checked on a
# hand-built set of groups so each resolution rule is visible.

eval_plot_data <- function() {
  sp <- utils::read.csv(
    system.file("extdata", "data_example_species.csv", package = "RESY"),
    stringsAsFactors = FALSE
  )
  names(sp)[names(sp) == "species"] <- "TaxonName"
  names(sp)[names(sp) == "cover"]   <- "Cover_Perc"
  sp
}

classified_as <- function(res, p) {
  out <- capture.output(suppressWarnings(resy_eval_plot(res, p)))
  trimws(sub("Classified as:", "", grep("^Classified as:", out, value = TRUE)))
}

test_that("a header in a different order from obs reports each plot's own types", {
  sp <- eval_plot_data()
  header <- as.data.frame(unique(sp["PlotObservationID"]))
  header <- header[rev(seq_len(nrow(header))), , drop = FALSE]
  res <- suppressMessages(
    resy_classify(sp, header, scheme = "Apennine-test", mc = 1L)
  )
  expect_false(identical(as.character(res$header$PlotObservationID),
                         names(res$types)))

  plots <- names(res$result.classification)
  got <- vapply(plots, function(p) classified_as(res, p), character(1))
  expect_equal(unname(got), unname(res$result.classification))
})

test_that("type conditions name the plot's taxa responsible for them", {
  sp <- eval_plot_data()
  header <- as.data.frame(unique(sp["PlotObservationID"]))
  res <- suppressMessages(
    resy_classify(sp, header, scheme = "Apennine-test", mc = 1L)
  )
  out <- paste(capture.output(resy_eval_plot(res, "AN57", type = "F")),
               collapse = "\n")

  expect_match(out, "F     Forest", fixed = TRUE)
  expect_match(out, "<#TC Beech-forest-trees GR 10>", fixed = TRUE)
  expect_match(out, "Abies alba | Fagus sylvatica", fixed = TRUE)
})

toy_groups <- list(c("Fagus sylvatica", "Abies alba"),
                   c("Picea abies", "Abies alba"))
toy_names <- c("Trees", "+12 Conifers")

test_that("a condition resolves to the taxa of the groups it names", {
  taxa <- function(x) .resy_condition_taxa(x, toy_groups, toy_names)

  expect_setequal(taxa("#TC Trees"), c("Fagus sylvatica", "Abies alba"))
  expect_setequal(taxa("##Q +12 Conifers"), c("Picea abies", "Abies alba"))
  expect_setequal(taxa("NON ##Q +12 Conifers"), c("Picea abies", "Abies alba"))
  expect_setequal(taxa("#02 Trees|#02 +12 Conifers"),
                  c("Fagus sylvatica", "Abies alba", "Picea abies"))
  expect_setequal(taxa("#TC Trees EXCEPT #TC Abies alba"), "Fagus sylvatica")
  expect_equal(taxa("Nardus stricta"), "Nardus stricta")
  expect_length(taxa("$$C Country"), 0L)
  expect_length(taxa("#T$"), 0L)
})

test_that("an expression's conditions are found longest first", {
  conds <- c("#TC Trees", "#TC Trees EXCEPT #TC Abies alba", "#TC Abies alba")
  expect_equal(
    .resy_expression_conditions("<#TC Trees EXCEPT #TC Abies alba GR 20>", conds),
    "#TC Trees EXCEPT #TC Abies alba"
  )
  expect_setequal(
    .resy_expression_conditions("<#TC Trees GR #TC Abies alba>", conds),
    c("#TC Trees", "#TC Abies alba")
  )
})
