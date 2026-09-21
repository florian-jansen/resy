# resy_eval_type() prints the definition of one vegetation type from the expert
# system of a classification result: full name, formula as written, compiled
# formula, and the membership conditions it uses. The tests classify the example
# plots once with Apennine-test and pin the printed parts for a type with two
# conditions, that a code and its index print the same, and the undefined case.

eval_type_result <- local({
  res <- NULL
  function() {
    if (is.null(res)) {
      sp <- utils::read.csv(
        system.file("extdata", "data_example_species.csv", package = "RESY"),
        stringsAsFactors = FALSE
      )
      names(sp)[names(sp) == "species"] <- "TaxonName"
      names(sp)[names(sp) == "cover"]   <- "Cover_Perc"
      header <- as.data.frame(unique(sp["PlotObservationID"]))
      res <<- suppressMessages(
        resy_classify(sp, header, scheme = "Apennine-test", mc = 1L)
      )
    }
    res
  }
})

test_that("a type code prints its name, formulas and membership conditions", {
  out <- capture.output(resy_eval_type(eval_type_result(), "FB"))
  out <- paste(out, collapse = "\n")

  expect_match(out, "FB    Beech-fir montane forest", fixed = TRUE)
  expect_match(out, "(<#TC Beech-forest-trees GR 15> AND <#TC Beech-forest-herbs GR 10>)",
               fixed = TRUE)
  expect_match(out, "(col2 & col3)", fixed = TRUE)
  expect_match(out, "#TC Beech-forest-trees GR 15", fixed = TRUE)
  expect_match(out, "#TC Beech-forest-herbs GR 10", fixed = TRUE)
})

test_that("the conditions table lists exactly the columns in the formula", {
  out <- capture.output(resy_eval_type(eval_type_result(), "FB"))
  rows <- grep("^[0-9]+ ", out, value = TRUE)
  expect_equal(sub(" .*", "", rows), c("2", "3"))
})

test_that("a numeric index prints the same as its code", {
  res   <- eval_type_result()
  codes <- res$parsed$vegtype.formula.names.short
  for (i in seq_along(codes)) {
    expect_identical(
      capture.output(resy_eval_type(res, i)),
      capture.output(resy_eval_type(res, codes[[i]]))
    )
  }
})

test_that("the return value is invisible NULL", {
  res <- eval_type_result()
  capture.output(val <- expect_invisible(resy_eval_type(res, "F")))
  expect_null(val)
})

test_that("an undefined code prints a notice and returns NULL", {
  res <- eval_type_result()
  expect_output(val <- resy_eval_type(res, "ZZ"), "^Type not defined\\.$")
  expect_null(val)
})

test_that("a non-result input is rejected", {
  expect_error(resy_eval_type(list(), "F"), "resy_result")
})
