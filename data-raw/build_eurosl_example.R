# Build inst/extdata/eurosl_example.csv.xz: the part of EuroSL that the bundled
# example plots and the default EUNIS and Apennine-test expert systems need, so
# that examples, vignettes and tests run without a EuroSL installation.
#
# Kept: every name (accepted and synonyms) of the concepts the example species
# resolve to, of the concepts the two expert systems name, and of all their
# ancestors. Without the expert systems' concepts, their names could match
# a similar name by fuzzy matching.
# Classifying the example plots with the extract gives the same result as with
# the full EuroSL (checked at the end).
#
# Run from the package root: Rscript --no-init-file data-raw/build_eurosl_example.R

suppressMessages(pkgload::load_all(quiet = TRUE))

eurosl <- "/home/jansen/aGitRepos/reflists/EuroSL/results/EuroSL.sqlite"
out <- "inst/extdata/eurosl_example.csv.xz"

con <- DBI::dbConnect(RSQLite::SQLite(), eurosl)
full <- DBI::dbReadTable(con, "EuroSL")
DBI::dbDisconnect(con)
bb <- .resy_backbone_build("EuroSL", full)

species <- utils::read.csv(system.file("extdata", "data_example_species.csv", package = "RESY"))
used <- unlist(lapply(c("Apennine-test", "EUNIS"), function(scheme)
  .resy_expert_used(resy_load_expert(scheme = scheme))))
names <- unique(c(species$scientificName, used))
concepts <- stats::na.omit(.resy_backbone_match(names, bb)$concept)
keep <- unique(.resy_backbone_ancestors(concepts, bb$parent)$ancestor)

cols <- c("TaxonUsageID", "TaxonName", "NameAuthor", "status", "TaxonConceptID",
          "TaxonRank", "parentTaxonID", "EditStatus")
ext <- full[full$TaxonConceptID %in% keep, cols]
ext <- ext[order(ext$TaxonName), ]
con <- xzfile(out, "wb", compression = 9)
utils::write.csv(ext, con, row.names = FALSE, na = "", fileEncoding = "UTF-8")
close(con)
message(nrow(ext), " names of ", length(keep), " concepts written to ", out,
        " (", round(file.size(out) / 1024), " KB)")

# ---- same classification as with the full backbone -----------------------------

header <- data.frame(PlotObservationID = unique(species$PlotObservationID))
classify <- function(source, scheme) {
  options(resy.backbone = source)
  suppressWarnings(suppressMessages(
    resy_classify(species, header, scheme = scheme, species_col = "scientificName",
                  mc = 1L)))
}
for (scheme in c("Apennine-test", "EUNIS")) {
  a <- classify(eurosl, scheme)
  b <- classify(out, scheme)
  same_types <- identical(a$result.classification, b$result.classification)
  cols <- c("scientificName", "TaxonName", "status", "importance")
  same <- function(x, y) all((x == y) %in% TRUE | (is.na(x) & is.na(y)))
  same_names <- nrow(a$taxon_resolution) == nrow(b$taxon_resolution) &&
    all(vapply(cols, function(k) same(a$taxon_resolution[[k]], b$taxon_resolution[[k]]),
               logical(1)))
  message(scheme, ": same types ", same_types, ", same name matching ", same_names)
  if (!same_types || !same_names) stop("The extract does not reproduce the full backbone.")
}
