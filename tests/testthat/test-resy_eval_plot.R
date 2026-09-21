# resy_eval_plot() explains the classification of one plot in words. The tests
# check that it reads the plot's own row of the solver results when the header
# is in a different order from the observations, that conditions are stated with
# the plot's value, the required value and the species behind them, that the
# lower levels a plot did not reach are listed, and that rules read with the
# solver's and/or/not structure. The condition helpers are checked on a
# hand-built set of groups so each resolution rule is visible.

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

eval_plot_text <- function(...) {
  paste(capture.output(resy_eval_plot(...)), collapse = "\n")
}

classified_as <- function(res, p) {
  out <- capture.output(suppressWarnings(resy_eval_plot(res, p, lower = FALSE)))
  if (any(grepl("^No type's rule holds", out))) return("?")
  if (any(grepl("^Not classified: several types", out))) return("+")
  sub("^Classified as (\\S+) .*$", "\\1", grep("^Classified as ", out, value = TRUE))
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

test_that("the species list shows species and cover only, largest cover first", {
  out <- capture.output(resy_eval_plot(apennine_result(), "AN57", lower = FALSE))
  i <- match("Plot AN57: 10 species", out)
  expect_false(is.na(i))
  expect_match(out[i + 1], "^ species +cover")
  expect_match(out[i + 2], "Fagus sylvatica +62.5")
  expect_false(any(grepl("group_names|PlotObservationID", out)))
})

test_that("the classification is stated in words with the type's name", {
  out <- eval_plot_text(apennine_result(), "AN57", lower = FALSE)
  expect_match(out, "Types whose rule holds: F (priority 2)", fixed = TRUE)
  expect_match(out, "Classified as F (Forest).", fixed = TRUE)
})

test_that("a lower level not reached is explained condition by condition", {
  out <- eval_plot_text(apennine_result(), "AN57")

  expect_match(out, "Why not a lower level of F:", fixed = TRUE)
  expect_match(out, "FB    Beech-fir montane forest: rule not met", fixed = TRUE)
  expect_match(out, "Rule: [1] and [2]", fixed = TRUE)
  expect_match(out, "[1] met      total cover of Beech-forest-trees is 62.7%, needs more than 15%",
               fixed = TRUE)
  expect_match(out, "[2] not met  total cover of Beech-forest-herbs is 0.6%, needs more than 10%",
               fixed = TRUE)
  expect_match(out, "Oxalis acetosella 0.5, Prenanthes purpurea 0.1", fixed = TRUE)
})

test_that("a condition under not that is met is marked as excluding", {
  out <- eval_plot_text(apennine_result(), "AN57", lower = FALSE, type = "N")

  expect_match(out, "Rule: ([1] or [2]) and not [3]", fixed = TRUE)
  expect_match(out, "[3] excludes total cover of Beech-forest-trees", fixed = TRUE)
})

test_that("a plot at a type without lower levels says so", {
  res <- apennine_result()
  p <- names(res$result.classification)[res$result.classification == "FB"][1]
  expect_output(resy_eval_plot(res, p), "FB has no lower levels.", fixed = TRUE)
})

test_that("an unclassified plot is shown against the top-level types", {
  res <- apennine_result()
  p <- names(res$result.classification)[res$result.classification == "?"][1]
  out <- eval_plot_text(res, p)
  expect_match(out, "No type's rule holds, so the plot is not classified.", fixed = TRUE)
  expect_match(out, "Top-level types not reached: 2 types, closest first", fixed = TRUE)
  expect_match(out, "Closest, in full", fixed = TRUE)
})

test_that("lower = FALSE leaves the lower levels out", {
  out <- capture.output(resy_eval_plot(apennine_result(), "AN57", lower = FALSE))
  expect_false(any(grepl("lower level", out, fixed = TRUE)))
  expect_equal(out[2], "Classified as F (Forest).")
  expect_equal(length(out), match("Plot AN57: 10 species", out) + 1 + 10)
})

test_that("an undefined type code is reported", {
  expect_output(resy_eval_plot(apennine_result(), "AN57", lower = FALSE, type = "ZZ"),
                "Type ZZ is not defined.", fixed = TRUE)
})

test_that("rules read with the solver's and/or/not structure", {
  expect_equal(.resy_rule_words("(col2 & col3)")$text, "[1] and [2]")
  r <- .resy_rule_words("(col4 | col5) &! col2")
  expect_equal(r$text, "([1] or [2]) and not [3]")
  expect_equal(r$cols, c(4L, 5L, 2L))
  expect_equal(r$negated, 2L)
  expect_equal(.resy_rule_words("(col1 &! col4 | col5) & col9")$text,
               "([1] and not [2] or [3]) and [4]")
})

test_that("conditions are put in words", {
  w <- function(x) .resy_condition_words(x)$words
  expect_equal(w("#TC Trees"), "total cover of Trees")
  expect_equal(w("#TC Trees EXCEPT #TC Picea"), "total cover of Trees not counting Picea")
  expect_equal(w("##Q +12 Grassland-species"), "sum of square-root covers of Grassland-species")
  expect_equal(w("#03 Coastal-saltmarsh-specialists"),
               "at least 3 species of Coastal-saltmarsh-specialists")
  expect_equal(w("### +01 Arable-weeds"), "number of species of Arable-weeds")
  expect_equal(w("#SC Trees EXCEPT Fagus sylvatica"),
               "highest cover of a single species of Trees not counting Fagus sylvatica")
  expect_equal(w("#T$"), "total cover of all species")
  expect_equal(w("$25"), "25% of the total cover")
  expect_equal(w("$$N DEG_LAT"), "DEG_LAT")
  expect_equal(w("Fagus sylvatica"), "cover of Fagus sylvatica")
  expect_equal(.resy_condition_words("#TC Trees")$unit, "%")
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
