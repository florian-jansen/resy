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

test_that("read_synonyms anchors the shipped layer and validates the schema", {
  syn <- resy_read_synonyms()
  expect_true(all(RESY:::.RESY_SYNONYM_COLUMNS %in% names(syn)))
  expect_gt(nrow(syn), 60000L)

  expect_error(resy_read_synonyms(data.frame(x = 1)), "missing required column")
  expect_error(resy_read_synonyms(123), "must be NULL")
  expect_error(resy_read_synonyms("no_such_file.csv.xz"), "file not found")
})

test_that("the shipped layer matches its recorded build", {
  build <- utils::read.csv(
    system.file("extdata", "esy_synonym_layer_build.csv", package = "RESY"),
    stringsAsFactors = FALSE
  )
  backbones <- utils::read.csv(
    system.file("extdata", "esy_synonym_layer_backbones.csv", package = "RESY"),
    stringsAsFactors = FALSE
  )
  layer <- RESY:::.resy_synonym_layer()

  expect_equal(build$n_pairs, nrow(layer))
  expect_equal(build$n_synonyms, length(unique(layer$synonym)))
  expect_equal(build$n_targets, length(unique(layer$target)))
  expect_equal(build$n_sc_drop, sum(layer$sc_drop))
  expect_equal(build$n_accepted_in, sum(!is.na(layer$accepted_in)))
  expect_false(anyDuplicated(layer[c("synonym", "target")]) > 0L)
  expect_true(all(unlist(strsplit(layer$source, ";", fixed = TRUE)) %in%
                    backbones$backbone))
  expect_true(all(unlist(strsplit(layer$accepted_in[!is.na(layer$accepted_in)], ";",
                                  fixed = TRUE)) %in% backbones$backbone))
  expect_true(all(nzchar(backbones$version) & nzchar(backbones$content_id)))
  expect_true(!is.na(as.Date(build$built)))
})

test_that("the table anchored on EUNIS 2025-10-03 keeps its recorded content", {
  expert <- resy_expert_path("EUNIS", "2025-10-03", "json", mustWork = FALSE)
  skip_if(is.na(expert) || !file.exists(expert), "EUNIS expert not installed")
  parsed <- resy_load_expert(expertfile = expert)
  syn <- resy_read_synonyms(expert = parsed)
  nm <- RESY:::.resy_expert_names(parsed)

  expect_false(anyDuplicated(syn$synonym) > 0L)
  expect_true(all(syn$esy_canonical %in% nm$targets))
  expect_false(any(syn$synonym %in% nm$vocab))
  expect_identical(resy_read_synonyms(expert = parsed), syn)

  f <- tempfile(fileext = ".csv")
  con <- file(f, "wb")
  utils::write.csv(syn, con, row.names = FALSE, na = "", eol = "\n")
  close(con)
  expect_equal(nrow(syn), 67018L)
  expect_equal(unname(tools::md5sum(f)), "b36fd67b891b40927914bea9c6145135")
})

mini_expert <- function() {
  list(
    aggs = list(`Genus alpha aggr.` = c("Genus alpha", "Genus alpha var. x"),
                `Genus beta` = "Genus betoides"),
    groups = list(`### Group-one` = c("Genus beta", "Genus gamma"),
                  `$$C Country` = "Austria"),
    groups.names = c("Group-one", "Country"),
    conditions = c("### Group-one", "Genus delta", "#TC Group-one EXCEPT Genus epsilon",
                   "$$C Country")
  )
}

mini_layer <- function() {
  data.frame(
    synonym = c("Syn one", "Syn two", "Syn two", "Syn three", "Syn three",
                "Genus betoides", "Syn four", "Syn five", "Syn six", "Syn six"),
    target  = c("Genus gamma", "Genus beta", "Genus delta", "Genus beta", "Genus alpha",
                "Genus gamma", "Genus epsilon", "Genus alpha", "Genus beta",
                "Genus betoides"),
    source  = c("wfo", "euromed;wfo", "gbif", "wfo", "gbif", "wfo", "wfo", "wfo",
                "wfo", "gbif"),
    accepted_in = NA_character_,
    sc_drop = c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE),
    stringsAsFactors = FALSE
  )
}

test_that("expert names hold the evaluated names and the whole vocabulary", {
  nm <- RESY:::.resy_expert_names(mini_expert())
  expect_setequal(nm$targets, c("Genus alpha aggr.", "Genus beta", "Genus gamma",
                                "Genus delta", "Genus epsilon"))
  expect_setequal(nm$vocab, c(nm$targets, "Genus alpha", "Genus alpha var. x",
                              "Genus betoides"))
  expect_false("Austria" %in% nm$vocab)
  expect_equal(unname(nm$evaluated_as[c("Genus alpha", "Genus betoides", "Genus gamma")]),
               c("Genus alpha aggr.", "Genus beta", "Genus gamma"))
})

test_that("anchoring keeps unambiguous pairs and never picks between targets", {
  nm <- RESY:::.resy_expert_names(mini_expert())
  out <- RESY:::.resy_anchor_synonyms(mini_layer(), nm)
  got <- stats::setNames(out$esy_canonical, out$synonym)

  expect_equal(got[["Syn one"]], "Genus gamma")
  # Two evaluated targets: Euro+Med's single answer is kept.
  expect_equal(got[["Syn two"]], "Genus beta")
  # Two evaluated targets, one through an aggregate member, no Euro+Med answer.
  expect_false("Syn three" %in% out$synonym)
  # A name the expert system uses is never remapped.
  expect_false("Genus betoides" %in% out$synonym)
  # A Euro+Med species of another concept is dropped.
  expect_false("Syn four" %in% out$synonym)
  # A target that is only an aggregate member is not a canonical name.
  expect_false("Syn five" %in% out$synonym)
  # Targets evaluated as the same name are not ambiguous.
  expect_equal(got[["Syn six"]], "Genus beta")
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
               "`obs` has no column `TaxonName`", fixed = TRUE)
})

test_that("canonical_species returns the sorted unique canonical names", {
  sp <- resy_canonical_species(mini_canon())
  expect_equal(sp, c("Genus species", "Other taxon"))
  expect_gt(length(resy_canonical_species()), 19000L)
  expect_equal(resy_canonical_species(expert = mini_expert()),
               sort(RESY:::.resy_expert_names(mini_expert())$targets))
})

test_that("resolve returns a resy_taxa table whose summary counts names and records", {
  obs <- data.frame(
    PlotObservationID = c("p1", "p1", "p2", "p2", "p3"),
    TaxonName = c("Genus species", "Old name", "Notareal sp", "Stillfake",
                  "Genus species"),
    stringsAsFactors = FALSE
  )
  res <- resy_resolve_taxa(obs, "TaxonName",
                           synonyms = mini_syn(), canonical = mini_canon())
  expect_s3_class(res, c("resy_taxa", "data.frame"))
  expect_equal(res$matched, c(TRUE, TRUE, FALSE, FALSE, TRUE))
  
  s <- summary(res)
  expect_s3_class(s, "summary.resy_taxa")
  expect_equal(c(s$n, s$matched, s$unmatched), c(4L, 2L, 2L))
  expect_equal(c(s$n_records, s$records_matched), c(5L, 3L))
  expect_equal(s$unmatched_names, c("Notareal sp", "Stillfake"))
  expect_equal(sum(s$by_confidence$n), 5L)
  expect_equal(sum(s$by_confidence$prop), 1)
  
  out <- capture.output(print(s))
  expect_true("4 names checked: 2 matched (50.0%), 2 not matched (50.0%)." %in% out)
  expect_true("3 of 5 records matched (60.0%)." %in% out)
  expect_true(any(grepl("^  exact +2  \\(40\\.0%\\)$", out)))
})

test_that("printing a resolved table shows its taxonomy columns and names the rest", {
  obs <- data.frame(PlotObservationID = c("p1", "p2"),
                    TaxonName = c("Genus species", "Genus species"),
                    stringsAsFactors = FALSE)
  res <- resy_resolve_taxa(obs, "TaxonName",
                           synonyms = mini_syn(), canonical = mini_canon())
  expect_output(print(res), "2 record(s) with 1 distinct name(s) from column `TaxonName` resolved against 2 reference names",
                fixed = TRUE)
  expect_output(print(res), "(1 other column(s) not shown: PlotObservationID)",
                fixed = TRUE)
})

test_that("dropping a defining column turns a resy_taxa table into a data frame", {
  res <- resy_resolve_taxa(data.frame(TaxonName = "Genus species"), "TaxonName",
                           synonyms = mini_syn(), canonical = mini_canon())
  kept <- res[c("TaxonName", "matched")]
  expect_s3_class(kept, "resy_taxa")
  expect_equal(attr(kept, "name_col"), "TaxonName")
  plain <- res[c("TaxonName", "canonical")]
  expect_false(inherits(plain, "resy_taxa"))
  expect_null(attr(plain, "name_col"))
})

test_that("classify with resolve_taxa = TRUE resolves and never corrupts known names", {
  expert <- resy_expert_path("EUNIS", "2025-10-03", "json", mustWork = FALSE)
  skip_if(is.na(expert) || !file.exists(expert), "EUNIS expert not installed")
  sp_path <- system.file(
    "extdata", "data_example_species.csv", package = "RESY"
    )
  si_path <- system.file("extdata", "data_example_sites.csv", package = "RESY")
  skip_if(!nzchar(sp_path) || !nzchar(si_path), "example data not installed")
  
  sp <- utils::read.csv(sp_path, stringsAsFactors = FALSE)
  header <- utils::read.csv(si_path, stringsAsFactors = FALSE)
  obs <- data.frame(
    PlotObservationID = sp$PlotObservationID,
    TaxonName = resy_clean_names(sp$scientificName),
    Cover_Perc = sp$Cover_Perc,
    stringsAsFactors = FALSE
  )
  
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
  cl <- suppressMessages(suppressWarnings(
    resy_classify(obs, header, expertfile = expert, resolve_taxa = TRUE)
    ))
  expect_s3_class(cl$taxon_resolution, "summary.resy_taxa")
  expect_equal(cl$taxon_resolution$n_records, nrow(obs))
  
  # Consistency: the in-classifier resolution matches an explicit pre-resolution
  # followed by an agnostic classify (idempotent).
  obs_pre <- obs
  obs_pre$TaxonName <- ifelse(
    is.na(res$canonical), obs$TaxonName, res$canonical
    )
  cl_pre <- suppressMessages(suppressWarnings(
    resy_classify(obs_pre, header, expertfile = expert)
    ))
  expect_equal(cl$result.classification, cl_pre$result.classification)
})
