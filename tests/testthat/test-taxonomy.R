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

test_that("the shipped table matches its recorded build", {
  build <- utils::read.csv(
    system.file("extdata", "esy_synonyms_build.csv", package = "RESY"),
    stringsAsFactors = FALSE
  )
  backbones <- utils::read.csv(
    system.file("extdata", "esy_synonyms_backbones.csv", package = "RESY"),
    stringsAsFactors = FALSE
  )
  syn <- resy_read_synonyms()

  expect_equal(build$n_pairs, nrow(syn))
  expect_equal(build$n_canonicals, length(unique(syn$esy_canonical)))
  expect_true(all(unlist(strsplit(syn$source, ";", fixed = TRUE)) %in%
                    backbones$backbone))
  expect_true(all(nzchar(backbones$version) & nzchar(backbones$content_id)))
  expect_true(!is.na(as.Date(build$built)))

  expect_true("accepted_in" %in% names(syn))
  expect_equal(build$n_accepted_in, sum(!is.na(syn$accepted_in)))
  expect_true(all(unlist(strsplit(syn$accepted_in[!is.na(syn$accepted_in)], ";",
                                  fixed = TRUE)) %in% backbones$backbone))
})

test_that("read_synonyms keeps the optional accepted_in column when present", {
  syn <- mini_syn()
  expect_false("accepted_in" %in% names(resy_read_synonyms(syn)))

  syn$accepted_in <- c("wfo", NA)
  out <- resy_read_synonyms(syn)
  expect_equal(names(out), c("synonym", "esy_canonical", "source", "accepted_in"))
  expect_equal(out$accepted_in, c("wfo", NA))
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

test_that("author citations are removed for matching when the name does not match as given", {
  obs <- data.frame(
    TaxonName = c("Genus species L.", "Old name (L.) Schult.", "Other taxon",
                  "Notareal sp. Smith", NA),
    stringsAsFactors = FALSE
  )
  res <- resy_resolve_taxa(obs, "TaxonName",
                           synonyms = mini_syn(), canonical = mini_canon())
  expect_equal(res$canonical,
               c("Genus species", "Genus species", "Other taxon", NA, NA))
  expect_equal(res$taxon_confidence,
               c("cleaned_exact", "cleaned_synonym", "exact",
                 "unresolved", "unresolved"))
  expect_equal(res$TaxonName, obs$TaxonName)
})

test_that("a name that matches as given is not cleaned", {
  res <- resy_resolve_taxa(data.frame(TaxonName = "Genus species L."),
                           "TaxonName", synonyms = mini_syn(),
                           canonical = data.frame(esy_canonical = "Genus species L."))
  expect_equal(res$canonical, "Genus species L.")
  expect_equal(res$taxon_confidence, "exact")
})

test_that("cleaning does not merge distinct names", {
  res <- resy_resolve_taxa(data.frame(TaxonName = "Taraxacum sect. Arctica"),
                           "TaxonName", synonyms = mini_syn(),
                           canonical = data.frame(esy_canonical = "Taraxacum sect. Alpina"))
  expect_true(is.na(res$canonical))
  expect_equal(res$taxon_confidence, "unresolved")
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

test_that("classify with resolve_taxa = TRUE resolves and never corrupts known names", {
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

  # With resolve_taxa = TRUE the classifier resolves names and reports what it did.
  cl <- resy_classify(obs, header, expertfile = expert, resolve_taxa = TRUE)
  expect_type(cl$taxon_resolution, "list")
  expect_equal(cl$taxon_resolution$n, nrow(obs))

  # Consistency: the in-classifier resolution matches an explicit pre-resolution
  # followed by an agnostic classify (idempotent).
  obs_pre <- obs
  obs_pre$TaxonName <- ifelse(is.na(res$canonical), obs$TaxonName, res$canonical)
  cl_pre <- resy_classify(obs_pre, header, expertfile = expert)
  expect_equal(cl$result.classification, cl_pre$result.classification)
})
