# resy_check_taxonomy() matches the taxon names of a plot table against the
# canonical names and synonyms in Section 1 of an expert system, offline. The
# tests use a hand-built expert with one aggregate so each mapping rule is
# visible, then check the bundled example data against the Apennine-test system.
# Unmatched names must stay NA: the check never substitutes a best guess.

toy_expert <- function() {
  structure(
    list(aggs = list(
      `Achillea millefolium agg.` = c("Achillea millefolium",
                                      "Achillea pratensis"),
      `Fagus sylvatica`           = "Fagus sylvatica L.",
      `Abies alba`                = character(0)
    )),
    class = "resy_parsed_expert"
  )
}

test_that("canonical names map to themselves and synonyms to their canonical", {
  obs <- data.frame(TaxonName = c("Achillea millefolium agg.",
                                  "Achillea pratensis",
                                  "Fagus sylvatica L.",
                                  "Abies alba"))
  out <- resy_check_taxonomy(obs, toy_expert())

  expect_s3_class(out, c("resy_taxa", "data.frame"))
  expect_named(out, c("scientificName", "TaxonName", "matched"))
  expect_true(all(out$matched))
  expect_equal(out$TaxonName, c("Achillea millefolium agg.",
                                "Achillea millefolium agg.",
                                "Fagus sylvatica",
                                "Abies alba"))
})

test_that("unknown names are flagged and keep canonical NA", {
  obs <- data.frame(TaxonName = c("Fagus sylvatica", "Planta inventa",
                                  "fagus sylvatica"))
  out <- resy_check_taxonomy(obs, toy_expert())

  expect_equal(out$matched, c(TRUE, FALSE, FALSE))
  expect_equal(out$TaxonName, c("Fagus sylvatica", NA, NA))
})

test_that("one row per distinct name, in order of first appearance, NA dropped", {
  obs <- data.frame(TaxonName = c("Abies alba", NA, "Fagus sylvatica",
                                  "Abies alba", "Fagus sylvatica"))
  out <- resy_check_taxonomy(obs, toy_expert())
  expect_equal(out$scientificName, c("Abies alba", "Fagus sylvatica"))
})

test_that("factor and data.table input give the same result as a data.frame", {
  names <- c("Achillea pratensis", "Planta inventa")
  ref <- resy_check_taxonomy(data.frame(TaxonName = names), toy_expert())

  fac <- data.frame(TaxonName = factor(names))
  expect_identical(resy_check_taxonomy(fac, toy_expert()), ref)

  dt <- data.table::data.table(TaxonName = names)
  expect_identical(resy_check_taxonomy(dt, toy_expert()), ref)
})

test_that("col selects the column holding the names", {
  obs <- data.frame(species = c("Achillea pratensis"), TaxonName = "Planta inventa")
  out <- resy_check_taxonomy(obs, toy_expert(), col = "species")
  expect_equal(out$scientificName, "Achillea pratensis")
  expect_equal(out$TaxonName, "Achillea millefolium agg.")
})

test_that("invalid input is rejected", {
  obs <- data.frame(TaxonName = "Abies alba")
  expect_error(resy_check_taxonomy(obs, list(aggs = list())),
               "resy_parsed_expert")
  expect_error(resy_check_taxonomy(obs, toy_expert(), col = "species"),
               "Column 'species' not found")
})

test_that("every species of the example data is known to Apennine-test", {
  sp <- utils::read.csv(
    system.file("extdata", "data_example_species.csv", package = "RESY"),
    stringsAsFactors = FALSE
  )
  parsed <- resy_load_expert(scheme = "Apennine-test")
  out <- resy_check_taxonomy(sp, parsed, col = "species")

  expect_equal(nrow(out), length(unique(sp$species)))
  expect_true(all(out$matched))
  expect_true(all(out$TaxonName %in% names(parsed$aggs)))
})

test_that("summary counts matches and lists unmatched names", {
  obs <- data.frame(TaxonName = c("Fagus sylvatica", "Planta inventa",
                                  "Abies alba", "Herba ignota"))
  s <- summary(resy_check_taxonomy(obs, toy_expert()))

  expect_s3_class(s, "summary.resy_taxa")
  expect_equal(c(s$n, s$matched, s$unmatched), c(4L, 2L, 2L))
  expect_equal(s$unmatched_names, c("Herba ignota", "Planta inventa"))
  expect_output(print(s), "2 matched (50.0%), 2 unmatched", fixed = TRUE)
})

test_that("summary is computed from the rows, so it follows subsetting", {
  obs <- data.frame(TaxonName = c("Fagus sylvatica", "Planta inventa"))
  out <- resy_check_taxonomy(obs, toy_expert())
  sub <- out[out$matched, ]

  expect_s3_class(sub, "resy_taxa")
  expect_equal(summary(sub)$unmatched, 0L)
})

test_that("print shows the column meanings, the counts and the rows", {
  obs <- data.frame(species = c("Fagus sylvatica", "Planta inventa"))
  out <- resy_check_taxonomy(obs, toy_expert(), col = "species")

  expect_output(print(out), "from column `species` checked against 3")
  expect_output(print(out), "scientificName  name as submitted")
  expect_output(print(out), "1 matched (50.0%), 1 unmatched; summary() lists them",
                fixed = TRUE)
  expect_output(print(out), "Planta inventa")
  expect_invisible(print(out))
})

test_that("print truncates long tables", {
  obs <- data.frame(TaxonName = paste("Planta", seq_len(12)))
  expect_output(print(resy_check_taxonomy(obs, toy_expert())),
                "# ... 2 more row(s)", fixed = TRUE)
})
