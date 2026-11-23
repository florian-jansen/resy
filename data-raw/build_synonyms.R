# Build the shipped synonym layer and record what it was built from.
#
# Run from the package root:  Rscript data-raw/build_synonyms.R
#
# The layer holds the synonym pairs of six taxify backbones (Euro+Med, WFO, GBIF,
# COL, ITIS, NCBI) and does not depend on any expert system. resy_read_synonyms()
# anchors it on the expert system in use when the synonyms are needed, so each
# release of an expert system gets its own synonym table from the same layer.
#
# Reproducing a build: install the taxify release named in
# inst/extdata/esy_synonym_layer_build.csv, run taxify::taxify_restore() on
# data-raw/esy_synonym_layer_taxify_lock.json to install the backbone versions listed
# there, then run this script. The same backbones and script give the same layer.
#
# Outputs
#   inst/extdata/esy_synonym_layer.csv.xz    synonym, target, source,
#                                            accepted_in, sc_drop
#   inst/extdata/esy_synonym_layer_backbones.csv  backbone versions, content ids, and
#                                            synonym counts per backbone
#   inst/extdata/esy_synonym_layer_build.csv      build date, tool versions, counts
#   data-raw/esy_synonym_layer_taxify_lock.json   taxify lockfile
#   data-raw/esy_synonym_layer_build_log.csv      pair count after each step

suppressMessages({
  devtools::load_all(".", quiet = TRUE)
  library(taxify)
  library(vectra)
  library(data.table)
})

BACKBONES  <- c("euromed", "wfo", "gbif", "col", "itis", "ncbi")
TAXIFY_VER <- "0.7.1"

stopifnot(as.character(utils::packageVersion("taxify")) == TAXIFY_VER)

norm <- function(x) gsub("\\s+", " ", trimws(x))

# Authorship reduced to lower-case letters and digits, so that spacing and
# punctuation differences between backbones do not separate the same author.
author_key <- function(x) tolower(gsub("[^A-Za-z0-9]", "", ifelse(is.na(x), "", x)))

# Files are written with LF line endings on every platform.
write_lf <- function(x, path) {
  con <- file(path, "wb")
  on.exit(close(con))
  utils::write.csv(x, con, row.names = FALSE, na = "", eol = "\n")
}
lf_only <- function(path) {
  bytes <- readBin(path, "raw", file.size(path))
  writeBin(bytes[bytes != as.raw(13L)], path)
}

lock_before <- taxify_lock(verbose = FALSE)
backbone_table <- function(bb) taxify:::backbone_path(bb, verbose = FALSE)

# ---- Harvest -----------------------------------------------------------------

harvest <- function(bb) {
  syn <- vectra::tbl(backbone_table(bb)) |>
    vectra::filter(is_synonym == TRUE) |>
    vectra::select(canonical_name, accepted_name, authorship) |>
    vectra::collect()
  data.table(synonym = norm(syn$canonical_name), target = norm(syn$accepted_name),
             backbone = bb, authorship = author_key(syn$authorship))
}
pairs <- rbindlist(lapply(BACKBONES, harvest))
synonym_rows <- table(factor(pairs$backbone, levels = BACKBONES))
log_n <- data.frame(step = "harvested synonym rows", n = nrow(pairs))
note  <- function(step, x) {
  log_n <<- rbind(log_n, data.frame(step = step, n = nrow(x)))
  invisible(x)
}

# Synonyms are binomials (genus and species epithet): bare genera, infraspecific
# names, and hybrid formulas are outside the layer. Empty names and self-maps
# are dropped.
is_binomial <- lengths(strsplit(pairs$synonym, " ", fixed = TRUE)) == 2L
pairs <- pairs[is_binomial & !is.na(synonym) & nzchar(synonym) &
                 !is.na(target) & nzchar(target) & synonym != target]
note("binomial synonyms; no self-maps", unique(pairs[, .(synonym, target, backbone)]))

# Targets are Euro+Med names, the taxonomy of the EUNIS expert system, and the
# names that the expert systems shipped with RESY evaluate.
em_all <- as.data.table(vectra::tbl(backbone_table("euromed")) |>
  vectra::select(taxon_id, canonical_name, taxon_rank, is_synonym, accepted_taxon_id) |>
  vectra::collect())
em_all[, name := norm(canonical_name)]
em_all[, concept := as.character(ifelse(is_synonym, accepted_taxon_id, taxon_id))]

shipped <- resy_available_classifications()
expert_targets <- unique(unlist(lapply(seq_len(nrow(shipped)), function(i) {
  e <- resy_load_expert(expertfile = resy_expert_path(shipped$scheme[i],
                                                      shipped$version[i], "json"))
  .resy_expert_names(e)$targets
})))
pairs <- pairs[target %chin% union(em_all$name, expert_targets)]
note("target is a Euro+Med name or a name a shipped expert system evaluates",
     unique(pairs[, .(synonym, target, backbone)]))

# ---- Layer -------------------------------------------------------------------

layer <- pairs[, .(source = paste(sort(unique(backbone)), collapse = ";")),
               by = .(synonym, target)]

# A synonym that Euro+Med accepts as a species is a variant of its target only
# when both are the same Euro+Med concept (an orthographic or gender variant).
# Distinct concepts are separate species, and a target outside Euro+Med cannot
# be checked; such pairs are flagged and dropped when the layer is anchored.
one_concept <- em_all[, .(concept = if (uniqueN(concept) == 1L) concept[1] else NA_character_),
                      by = name]
accepted_species <- unique(em_all[!is_synonym & taxon_rank == "SPECIES", name])
layer[, c_syn := one_concept$concept[match(synonym, one_concept$name)]]
layer[, c_tgt := one_concept$concept[match(target, one_concept$name)]]
layer[, sc_drop := synonym %chin% accepted_species &
          (is.na(c_syn) | is.na(c_tgt) | c_syn != c_tgt)]
layer[, c("c_syn", "c_tgt") := NULL]

# Backbones that list the synonym string as an accepted name, under the same
# author as the synonym rows supporting the pair. An accepted name with a
# different author is a homonym and is not counted.
accepted <- rbindlist(lapply(BACKBONES, function(bb) {
  a <- vectra::tbl(backbone_table(bb)) |>
    vectra::filter(is_synonym == FALSE) |>
    vectra::select(canonical_name, authorship) |>
    vectra::collect()
  a <- data.table(backbone = bb, synonym = norm(a$canonical_name),
                  author = author_key(a$authorship))
  unique(a[synonym %chin% layer$synonym])
}))
support <- unique(pairs[, .(synonym, target, authorship)])
both <- support[accepted, on = "synonym", allow.cartesian = TRUE, nomatch = NULL]
both <- both[author != "" & authorship != "" &
               (author == authorship | startsWith(author, authorship) |
                  startsWith(authorship, author))]
acc <- both[, .(accepted_in = paste(sort(unique(backbone)), collapse = ";")),
            by = .(synonym, target)]
layer[acc, accepted_in := i.accepted_in, on = c("synonym", "target")]
layer[is.na(accepted_in), accepted_in := ""]

layer_out <- layer[, .(synonym, target, source, accepted_in, sc_drop = as.integer(sc_drop))]
setorder(layer_out, target, synonym)
note("layer pairs", layer_out)

stopifnot(
  !anyNA(layer_out),
  !anyDuplicated(layer_out[, .(synonym, target)]),
  all(unlist(strsplit(layer_out$source, ";", fixed = TRUE)) %in% BACKBONES)
)

# ---- Write -------------------------------------------------------------------

# The backbones read during the harvest must be the ones locked at the start.
lock_after <- taxify_lock(file = "data-raw/esy_synonym_layer_taxify_lock.json",
                          verbose = FALSE)
lf_only("data-raw/esy_synonym_layer_taxify_lock.json")
lock_cols <- function(l) vapply(l$backbones, function(b) paste(b$name, b$content_id), "")
stopifnot(identical(sort(lock_cols(lock_before)), sort(lock_cols(lock_after))))

con <- xzfile("inst/extdata/esy_synonym_layer.csv.xz", "wb", compression = 9)
utils::write.csv(layer_out, con, row.names = FALSE, na = "", eol = "\n")
close(con)

used <- Filter(function(b) b$name %in% BACKBONES, lock_after$backbones)
manifest <- tryCatch(list_backbones(verbose = FALSE), error = function(e) NULL)
source_date <- function(nm) {
  if (is.null(manifest)) return(NA_character_)
  as.character(manifest$source_date[match(nm, manifest$name)])
}
layer_by_backbone <- table(factor(unlist(strsplit(layer_out$source, ";", fixed = TRUE)),
                                  levels = BACKBONES))
backbones_out <- data.frame(
  backbone      = vapply(used, function(b) b$name, ""),
  version       = vapply(used, function(b) b$version, ""),
  upstream_date = vapply(used, function(b) source_date(b$name), ""),
  downloaded    = vapply(used, function(b) b$downloaded_at, ""),
  content_id    = vapply(used, function(b) b$content_id, ""),
  stringsAsFactors = FALSE
)
backbones_out <- backbones_out[match(BACKBONES, backbones_out$backbone), ]
backbones_out$synonym_rows <- as.integer(synonym_rows[backbones_out$backbone])
backbones_out$layer_pairs  <- as.integer(layer_by_backbone[backbones_out$backbone])
write_lf(backbones_out, "inst/extdata/esy_synonym_layer_backbones.csv")

build_out <- data.frame(
  built          = as.character(Sys.Date()),
  taxify_version = TAXIFY_VER,
  taxify_commit  = utils::packageDescription("taxify")$RemoteSha %||% NA_character_,
  n_pairs        = nrow(layer_out),
  n_synonyms     = uniqueN(layer_out$synonym),
  n_targets      = uniqueN(layer_out$target),
  n_accepted_in  = sum(nzchar(layer_out$accepted_in)),
  n_sc_drop      = sum(layer_out$sc_drop),
  r_version      = as.character(getRversion()),
  stringsAsFactors = FALSE
)
write_lf(build_out, "inst/extdata/esy_synonym_layer_build.csv")
write_lf(log_n, "data-raw/esy_synonym_layer_build_log.csv")

print(log_n, row.names = FALSE)
print(build_out, row.names = FALSE)
print(backbones_out, row.names = FALSE)
