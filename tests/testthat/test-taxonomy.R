# Taxonomy name resolution: map plot species names to canonical ESy names via
# exact match then a synonym fallback. Recovery-style -- known names must recover
# known canonical names; unmatched and ambiguous names must stay NA, never a
# best guess.

mini_syn <- function() {
  data.frame(
    synonym       = c("Old name", "Older name"),
    esy_canonical = c("Genus species", "Genus species"),
    source        = c("test", "test"),
    stringsAsFactors = FALSE
  )
}
mini_canon <- function() data.frame(esy_canonical = c("Genus species", "Other taxon"))

test_that("read_synonyms loads the shipped table and validates the schema", {
  syn <- resy_read_synonyms()
  expect_true(all(RESY:::.RESY_SYNONYM_COLUMNS %in% names(syn)))
  expect_gt(nrow(syn), 40000L)

  expect_error(resy_read_synonyms(data.frame(x = 1)), "missing required column")
  expect_error(resy_read_synonyms(123), "must be NULL")
  expect_error(resy_read_synonyms("no_such_file.csv.xz"), "file not found")
})

test_that("resolve recovers canonical names exactly and via synonym fallback", {
  obs <- data.frame(
    TaxonName = c("Genus species", " Old name ", "Older name", "Other taxon"),
    stringsAsFactors = FALSE
  )
  res <- resy_resolve_taxa(obs, "TaxonName",
                           synonyms = mini_syn(), canonical = mini_canon())
  expect_equal(res$canonical,
               c("Genus species", "Genus species", "Genus species", "Other taxon"))
  expect_equal(res$taxon_confidence,
               c("exact", "synonym", "synonym", "exact"))
})

test_that("unmatched input stays NA and flagged, never substituted", {
  res <- resy_resolve_taxa(data.frame(TaxonName = "Notareal speciesxyz"),
                           "TaxonName", synonyms = mini_syn(),
                           canonical = mini_canon())
  expect_true(is.na(res$canonical[1]))
  expect_equal(res$taxon_confidence[1], "unresolved")
})

test_that("ambiguous synonyms resolve to nothing (no silent pick)", {
  amb <- data.frame(synonym = c("Shared syn", "Shared syn"),
                    esy_canonical = c("Genus species", "Other taxon"),
                    source = "test", stringsAsFactors = FALSE)
  res <- resy_resolve_taxa(data.frame(TaxonName = "Shared syn"), "TaxonName",
                           synonyms = amb, canonical = mini_canon())
  expect_true(is.na(res$canonical[1]))
  expect_equal(res$taxon_confidence[1], "unresolved")
})

test_that("resolver validates its arguments", {
  expect_error(resy_resolve_taxa(list(), "TaxonName"), "must be a data frame")
  expect_error(resy_resolve_taxa(data.frame(a = 1), "TaxonName"),
               "not found in `obs`")
})

test_that("canonical_species returns the sorted unique canonical names", {
  sp <- resy_canonical_species(mini_canon())
  expect_equal(sp, c("Genus species", "Other taxon"))
  expect_gt(length(resy_canonical_species()), 19000L)
})

test_that("summarize_taxa counts resolution and lists unresolved inputs", {
  obs <- data.frame(
    TaxonName = c("Genus species", "Old name", "Notareal sp", "Stillfake"),
    stringsAsFactors = FALSE
  )
  res <- resy_resolve_taxa(obs, "TaxonName",
                           synonyms = mini_syn(), canonical = mini_canon())
  s <- resy_summarize_taxa(res, species_col = "TaxonName")
  expect_equal(s$n, 4L)
  expect_equal(s$resolved, 2L)
  expect_equal(s$unresolved, 2L)
  expect_setequal(s$unresolved_taxa, c("Notareal sp", "Stillfake"))
  expect_equal(sum(s$by_confidence$n), 4L)
  expect_equal(sum(s$by_confidence$prop), 1)
  expect_error(resy_summarize_taxa(data.frame(x = 1)), "taxon_confidence")
})

test_that("classify by = 'name' never corrupts names the expert already knows", {
  expert <- resy_expert_path("EUNIS", "2025-10-03", "json", mustWork = FALSE)
  skip_if(is.na(expert) || !file.exists(expert), "EUNIS expert not installed")
  sp_path <- system.file("extdata", "data_example_species.csv", package = "RESY")
  si_path <- system.file("extdata", "data_example_sites.csv", package = "RESY")
  skip_if(!nzchar(sp_path) || !nzchar(si_path), "example data not installed")

  sp <- utils::read.csv(sp_path, stringsAsFactors = FALSE)
  header <- utils::read.csv(si_path, stringsAsFactors = FALSE)
  obs <- data.frame(PlotObservationID = sp$PlotObservationID,
                    TaxonName = resy_clean_names(sp$species),
                    Cover_Perc = sp$cover, stringsAsFactors = FALSE)

  parsed <- resy_load_expert(expertfile = expert)
  vocab <- unique(c(names(parsed$aggs), unlist(parsed$aggs, use.names = FALSE)))

  # No-corruption invariant: any name the expert already knows resolves to itself
  # (exact), never remapped.
  res <- resy_resolve_taxa(obs, "TaxonName", canonical = vocab)
  known <- res$TaxonName %in% vocab
  expect_gt(sum(known), 0L)
  expect_true(all(res$canonical[known] == res$TaxonName[known]))
  expect_true(all(res$taxon_confidence[known] == "exact"))

  # Causality: by = "name" changes the classification only on plots where a name
  # was actually resolved; every other plot is byte-identical to the canonical path.
  remapped <- unique(as.character(
    res$PlotObservationID[res$taxon_confidence == "synonym"]))
  base <- resy_classify(obs, header, expertfile = expert)
  vianame <- resy_classify(obs, header, expertfile = expert,
                           species_col = "TaxonName", by = "name")
  b <- base$result.classification; v <- vianame$result.classification
  keep <- setdiff(names(b), remapped)
  expect_equal(b[keep], v[keep])

  expect_null(base$taxon_resolution)
  expect_type(vianame$taxon_resolution, "list")
  expect_equal(vianame$taxon_resolution$n, nrow(obs))
})
