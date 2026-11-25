# Published EUNIS-ESy releases: the shipped files, the release table, the
# getaca registry built from it, provenance and the version diff.

releases <- function() {
  utils::read.csv(system.file("extdata", "classifications", "releases.csv", package = "RESY"),
                  colClasses = "character")
}

test_that("every published release is shipped", {
  avail <- resy_available_classifications()
  shipped <- avail$version[avail$scheme == "EUNIS"]
  expect_true(all(releases()$version %in% shipped))
  # further versions are derived from a release and use a taxonomic backbone
  for (v in setdiff(shipped, releases()$version))
    expect_false(is.null(resy_load_expert(scheme = "EUNIS", version = v)$backbone))
})

test_that("the shipped .txt.xz releases decompress to the published bytes", {
  rel <- releases()
  for (v in rel$version[rel$scheme == "EUNIS"]) {
    p <- resy_expert_path("EUNIS", v)
    expect_match(basename(p), "^expert\\.txt\\.xz$")
    expect_identical(RESY:::.resy_content_md5(p), rel$md5[rel$version == v])
  }
})

test_that("resy_read_expert() and resy_write_expert() round-trip an xz-compressed release", {
  p <- resy_expert_path("EUNIS", "2021-06-01", format = "txt")
  out <- withr::local_tempfile(fileext = ".txt")
  resy_write_expert(resy_read_expert(p), out)
  expect_identical(unname(tools::md5sum(out)), RESY:::.resy_content_md5(p))
})

test_that("the getaca registry declares the releases of the release table", {
  reg <- readRDS(system.file("getaca", "registry.rds", package = "RESY"))
  rel <- releases()
  expect_identical(reg$package, "RESY")
  got <- vapply(reg$resources, function(r) paste(r$name, r$version, r$sha256, r$file), "")
  expect_setequal(got, paste(rel$scheme, rel$version, rel$sha256, rel$file))
  expect_identical(unname(reg$current[["EUNIS"]]), max(rel$version))
})

test_that("resy_provenance() reports the release a parsed system rests on", {
  p <- resy_provenance(resy_load_expert(scheme = "EUNIS", version = "2021-06-01"))
  expect_identical(p$scheme, "EUNIS")
  expect_identical(p$version, "2021-06-01")
  expect_identical(p$release_doi, "10.5281/zenodo.4812736")
  expect_true(p$identical_to_release)
  expect_true(is.na(p$synonym_layer_built))

  p <- resy_provenance(resy_load_expert(scheme = "EUNIS", version = "2025-10-03"))
  expect_identical(p$release_doi, "10.5281/zenodo.16895007")
  expect_true(p$identical_to_release)
})

test_that("a file outside the store is identified by its content", {
  dir <- withr::local_tempdir()
  copy <- file.path(dir, "anything.txt")
  writeBin(RESY:::.resy_read_raw(resy_expert_path("EUNIS", "2020-06-08", format = "txt")), copy)
  p <- resy_provenance(resy_load_expert(expertfile = copy))
  expect_identical(p$version, "2020-06-08")
  expect_true(p$identical_to_release)

  own <- file.path(withr::local_tempdir(), "expert.json")
  file.copy(resy_expert_path("Apennine-test", "2026-06-27"), own)
  p <- resy_provenance(resy_load_expert(expertfile = own))
  expect_true(is.na(p$scheme))
  expect_true(is.na(p$version))
  expect_true(is.na(p$identical_to_release))
})

test_that("a downloaded release is stored without validation", {
  withr::local_envvar(R_USER_DATA_DIR = withr::local_tempdir())
  src <- resy_expert_path("EUNIS", "2020-06-08", format = "txt")
  local_mocked_bindings(
    .resy_fetch_release = function(scheme, version = NULL) list(file = src, version = "2020-06-08"),
    resy_validate_esy = function(...) stop("validation must not run for a download")
  )
  out <- resy_add_classification(scheme = "EUNIS", version = "2020-06-08")
  expect_identical(basename(out$txt), "expert.txt.xz")
  p <- resy_provenance(resy_load_expert(scheme = "EUNIS", version = "2020-06-08",
                                        location = "user"))
  expect_true(p$identical_to_release)
})

test_that("resy_classify() reports the release and synonym layer it used", {
  species <- utils::read.csv(system.file("extdata", "data_example_species.csv", package = "RESY"))
  header <- as.data.frame(unique(species["PlotObservationID"]))
  res <- suppressWarnings(resy_classify(species, header, scheme = "EUNIS", version = "2021-06-01",
                                        species_col = "scientificName", resolve_taxa = TRUE,
                                        mc = 1))
  p <- resy_provenance(res)
  expect_identical(p$version, "2021-06-01")
  expect_false(is.na(p$synonym_layer_built))
  expect_identical(res$version, "2021-06-01")
})

test_that("resy_diff_expert() lists the changes between two releases", {
  d <- resy_diff_expert("2020-06-08", "2021-06-01")
  expect_s3_class(d, "resy_expert_diff")
  counts <- table(factor(d$section, c("aggregate", "group", "type")),
                  factor(d$change, c("added", "removed", "changed")))
  expect_equal(unname(counts["type", ]), c(41, 28, 15))
  expect_equal(unname(counts["group", ]), c(34, 31, 47))
  expect_equal(unname(counts["aggregate", ]), c(180, 18, 214))

  types <- subset(d, section == "type" & change == "added")
  expect_s3_class(types, "resy_expert_diff")
  expect_true(all(is.na(types$from)) && !anyNA(types$to))
  expect_s3_class(d[, c("key", "what")], "data.frame")
  expect_false(inherits(d[, c("key", "what")], "resy_expert_diff"))

  expect_lte(length(capture.output(print(d))), length(capture.output(print(summary(d)))))
})

test_that("an expert system does not differ from itself", {
  e <- resy_load_expert(scheme = "Apennine-test", version = "2026-06-27")
  expect_identical(nrow(resy_diff_expert(e, e)), 0L)
})

test_that("a code filling the code field is read without the description", {
  parsed <- resy_load_expert(scheme = "EUNIS", version = "2025-10-03")
  short <- parsed$vegtype.formula.names.short
  expect_true(all(c("N15", "N15!", "N15!!", "T1C!!", "T1D!!") %in% short))
  expect_false(any(grepl("!![A-Za-z]", short)))
  expect_true("N15!! Atlantic and Baltic coastal dune grassland (grey dune)" %in%
                parsed$vegtype.formula.names)
})

test_that("an aggregate declared twice keeps the members of both declarations", {
  parsed <- resy_load_expert(scheme = "EUNIS", version = "2025-10-03")
  members <- unlist(parsed$aggs[names(parsed$aggs) == "Mentha longifolia"])
  expect_true(all(c("Mentha acuminata", "Mentha Xlongifolia_X_spicata") %in% members))
  checked <- resy_check_taxonomy(data.frame(TaxonName = "Mentha acuminata"), parsed)
  expect_identical(checked$TaxonName, "Mentha longifolia")
})
