# Builds inst/getaca/registry.rds, the getaca registry of published
# expert-system releases, from inst/extdata/classifications/releases.csv.
#
# resy_add_classification(scheme = , version = ) downloads a release through
# this registry under getaca's "current" policy, which reads the copy on
# GitHub (`remote` below). A new release is published to every installed RESY
# by adding its row to releases.csv, running this script and pushing both
# files to main. Published rows are never edited: getaca refuses a remote
# registry that changes the bytes a published version names.
#
# Run from the package root: Rscript data-raw/build_registry.R

library(getaca)

rel <- utils::read.csv("inst/extdata/classifications/releases.csv",
                       colClasses = "character", stringsAsFactors = FALSE)

resources <- lapply(seq_len(nrow(rel)), function(i) {
  r <- rel[i, ]
  resource(
    name        = r$scheme,
    version     = r$version,
    urls        = r$url,
    sha256      = r$sha256,
    size        = as.numeric(r$size),
    license     = toupper(r$licence),
    description = sprintf("%s expert system, release %s", r$scheme, r$version),
    doi         = r$doi,
    file        = r$file
  )
})

newest <- tapply(rel$version, rel$scheme, function(v) sort(v, decreasing = TRUE)[1L])

reg <- registry(
  package   = "RESY",
  resources = resources,
  remote    = "https://raw.githubusercontent.com/florian-jansen/resy/main/inst/getaca/registry.rds",
  current   = newest
)

# `created` is set to the newest release date, so rebuilding an unchanged
# table reproduces the file byte for byte.
registry_write(reg, "inst/getaca/registry.rds",
               created = as.POSIXct(max(rel$version), tz = "UTC"))
