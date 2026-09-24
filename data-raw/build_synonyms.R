# Build the shipped ESy synonym table and record what it was built from.
#
# Run from the package root:  Rscript data-raw/build_synonyms.R
#
# The table maps alternate species names to the canonical names of the EUNIS-ESy
# expert system. It is harvested from the synonym rows of six taxify backbones
# (Euro+Med, WFO, GBIF, COL, ITIS, NCBI) and anchored on the expert vocabulary,
# so a name the expert already uses is never remapped.
#
# Reproducing a build: install the taxify release named in
# inst/extdata/esy_synonyms_build.csv, run taxify::taxify_restore() on
# data-raw/esy_synonyms_taxify_lock.json to install the backbone versions listed
# there, then run this script. The same backbones, expert file, and script give
# the same table.
#
# Outputs
#   inst/extdata/esy_synonyms.csv.xz         synonym, esy_canonical, source,
#                                            accepted_in
#   inst/extdata/esy_synonyms_backbones.csv  backbone versions and content ids
#   inst/extdata/esy_synonyms_build.csv      build date, tool versions, counts
#   data-raw/esy_synonyms_taxify_lock.json   taxify lockfile
#   data-raw/esy_synonyms_build_log.csv      pair count after each filter

suppressMessages({
  devtools::load_all(".", quiet = TRUE)
  library(taxify)
  library(vectra)
})

BACKBONES  <- c("euromed", "wfo", "gbif", "col", "itis", "ncbi")
EXPERT     <- list(scheme = "EUNIS", version = "2025-10-03")
TAXIFY_VER <- "0.5.5"

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

# ---- Inputs ------------------------------------------------------------------

lock_before <- taxify_lock(verbose = FALSE)

expert_file <- resy_expert_path(EXPERT$scheme, EXPERT$version, "json")
expert      <- resy_load_expert(expertfile = expert_file)
expert_vocab <- unique(norm(c(names(expert$aggs),
                              unlist(expert$aggs, use.names = FALSE))))
esy_canonical <- resy_canonical_species()

# ---- Harvest -----------------------------------------------------------------

backbone_table <- function(bb) taxify:::backbone_path(bb, verbose = FALSE)

harvest <- function(bb) {
  syn <- vectra::tbl(backbone_table(bb)) |>
    vectra::filter(is_synonym == TRUE) |>
    vectra::select(canonical_name, accepted_name, authorship) |>
    vectra::collect()
  data.frame(
    synonym       = norm(syn$canonical_name),
    esy_canonical = norm(syn$accepted_name),
    backbone      = bb,
    authorship    = author_key(syn$authorship),
    stringsAsFactors = FALSE
  )
}

pairs <- do.call(rbind, lapply(BACKBONES, harvest))
log_n <- data.frame(step = "harvested synonym rows", n = nrow(pairs))
note  <- function(step, x) {
  log_n <<- rbind(log_n, data.frame(step = step, n = nrow(x)))
  x
}

# ---- Filters -----------------------------------------------------------------

# Keep rows whose accepted name is an ESy canonical. Synonyms are binomials
# (genus and species epithet): bare genera, infraspecific names, and hybrid
# formulas are outside the table. Empty names and self-maps are dropped.
is_binomial <- lengths(strsplit(pairs$synonym, " ", fixed = TRUE)) == 2L
pairs <- pairs[pairs$esy_canonical %in% esy_canonical & is_binomial &
                 !is.na(pairs$synonym) & nzchar(pairs$synonym) &
                 pairs$synonym != pairs$esy_canonical, ]
syn_author <- unique(pairs)
pairs <- note("accepted name is an ESy canonical; binomial synonyms; no self-maps",
              unique(pairs[c("synonym", "esy_canonical", "backbone")]))

# A synonym pointing at more than one canonical across backbones is resolved by
# Euro+Med, the authority the expert system follows: its single answer is kept,
# otherwise the synonym is dropped.
n_targets <- tapply(pairs$esy_canonical, pairs$synonym,
                    function(x) length(unique(x)))
ambiguous <- names(n_targets)[n_targets > 1L]
em <- pairs[pairs$backbone == "euromed" & pairs$synonym %in% ambiguous, ]
em_targets <- tapply(em$esy_canonical, em$synonym, function(x) unique(x))
em_single  <- em_targets[lengths(em_targets) == 1L]
em_answer  <- vapply(em_single, `[`, "", 1L)
is_amb  <- pairs$synonym %in% ambiguous
answer  <- em_answer[pairs$synonym]
keep_em <- is_amb & !is.na(answer) & pairs$esy_canonical == answer
pairs <- note("cross-backbone ambiguity resolved by Euro+Med", pairs[!is_amb | keep_em, ])

# A synonym string the expert system itself uses (an ESy canonical or any name in
# its aggregation vocabulary) is never remapped.
pairs <- note("synonym is not an expert-vocabulary name",
              pairs[!pairs$synonym %in% union(esy_canonical, expert_vocab), ])

# A synonym that Euro+Med accepts as a species is kept only when its target is the
# same Euro+Med concept (an orthographic or gender variant). Distinct concepts
# are separate species, and a target outside Euro+Med cannot be checked.
em_all <- vectra::tbl(backbone_table("euromed")) |>
  vectra::select(taxon_id, canonical_name, taxon_rank, is_synonym, accepted_taxon_id) |>
  vectra::collect()
em_all$name    <- norm(em_all$canonical_name)
em_all$concept <- ifelse(em_all$is_synonym, em_all$accepted_taxon_id, em_all$taxon_id)

accepted_species <- em_all[!em_all$is_synonym & em_all$taxon_rank == "SPECIES", ]
concepts_by_name <- split(em_all$concept, em_all$name)
concept_of <- function(nm) {
  vapply(nm, function(n) {
    id <- unique(concepts_by_name[[n]])
    if (length(id) == 1L) as.character(id) else NA_character_
  }, character(1), USE.NAMES = FALSE)
}

reviewed <- pairs$synonym %in% accepted_species$name
rv <- pairs[reviewed, ]
same_concept <- concept_of(rv$synonym) == concept_of(rv$esy_canonical)
drop_key <- paste(rv$synonym, rv$esy_canonical)[is.na(same_concept) | !same_concept]
pairs <- note("Euro+Med accepted species kept only as same-concept variants",
              pairs[!paste(pairs$synonym, pairs$esy_canonical) %in% drop_key, ])

# ---- Assemble ----------------------------------------------------------------

src <- tapply(pairs$backbone, paste(pairs$synonym, pairs$esy_canonical, sep = "\t"),
              function(b) paste(sort(unique(b)), collapse = ";"))
key <- strsplit(names(src), "\t", fixed = TRUE)
table_out <- data.frame(
  synonym       = vapply(key, `[`, "", 1L),
  esy_canonical = vapply(key, `[`, "", 2L),
  source        = unname(src),
  stringsAsFactors = FALSE
)
table_out <- table_out[order(table_out$esy_canonical, table_out$synonym,
                             method = "radix"), ]
rownames(table_out) <- NULL

# ---- Backbones that accept the synonym ---------------------------------------

# Backbones that list the synonym string as an accepted name, under the same
# author as the synonym rows supporting the pair. An accepted name with a
# different author is a homonym and is not counted.
same_author <- function(a, b) {
  a != "" & b != "" & (a == b | startsWith(a, b) | startsWith(b, a))
}
accepted <- do.call(rbind, lapply(BACKBONES, function(bb) {
  a <- vectra::tbl(backbone_table(bb)) |>
    vectra::filter(is_synonym == FALSE) |>
    vectra::select(canonical_name, authorship) |>
    vectra::collect()
  a <- data.frame(backbone = bb, synonym = norm(a$canonical_name),
                  author = author_key(a$authorship), stringsAsFactors = FALSE)
  a[a$synonym %in% table_out$synonym, ]
}))
accepted_by <- split(accepted[c("backbone", "author")], accepted$synonym)

pair_key <- function(synonym, canonical) paste(synonym, canonical, sep = "\t")
support <- syn_author[pair_key(syn_author$synonym, syn_author$esy_canonical) %in%
                        pair_key(table_out$synonym, table_out$esy_canonical), ]
support_by <- split(support$authorship, pair_key(support$synonym, support$esy_canonical))

table_out$accepted_in <- vapply(seq_len(nrow(table_out)), function(i) {
  a <- accepted_by[[table_out$synonym[i]]]
  if (is.null(a)) return("")
  s <- unique(support_by[[pair_key(table_out$synonym[i], table_out$esy_canonical[i])]])
  hit <- vapply(a$author, function(x) any(same_author(x, s)), NA)
  paste(sort(unique(a$backbone[hit])), collapse = ";")
}, "")

stopifnot(
  !anyNA(table_out),
  !anyDuplicated(table_out$synonym),
  all(table_out$esy_canonical %in% esy_canonical),
  !any(table_out$synonym %in% expert_vocab)
)

# ---- Write -------------------------------------------------------------------

# The backbones read during the harvest must be the ones locked at the start.
lock_after <- taxify_lock(file = "data-raw/esy_synonyms_taxify_lock.json",
                          verbose = FALSE)
lf_only("data-raw/esy_synonyms_taxify_lock.json")
lock_cols <- function(l) vapply(l$backbones, function(b) paste(b$name, b$content_id), "")
stopifnot(identical(sort(lock_cols(lock_before)), sort(lock_cols(lock_after))))

con <- xzfile("inst/extdata/esy_synonyms.csv.xz", "wb", compression = 9)
utils::write.csv(table_out, con, row.names = FALSE, na = "", eol = "\n")
close(con)

used <- Filter(function(b) b$name %in% BACKBONES, lock_after$backbones)
manifest <- tryCatch(list_backbones(verbose = FALSE), error = function(e) NULL)
source_date <- function(nm) {
  if (is.null(manifest)) return(NA_character_)
  as.character(manifest$source_date[match(nm, manifest$name)])
}
backbones_out <- data.frame(
  backbone      = vapply(used, function(b) b$name, ""),
  version       = vapply(used, function(b) b$version, ""),
  upstream_date = vapply(used, function(b) source_date(b$name), ""),
  downloaded    = vapply(used, function(b) b$downloaded_at, ""),
  content_id    = vapply(used, function(b) b$content_id, ""),
  stringsAsFactors = FALSE
)
backbones_out <- backbones_out[match(BACKBONES, backbones_out$backbone), ]
write_lf(backbones_out, "inst/extdata/esy_synonyms_backbones.csv")

build_out <- data.frame(
  built           = as.character(Sys.Date()),
  taxify_version  = TAXIFY_VER,
  taxify_commit   = utils::packageDescription("taxify")$RemoteSha,
  expert_system   = EXPERT$scheme,
  expert_version  = EXPERT$version,
  expert_md5      = unname(tools::md5sum(expert_file)),
  n_pairs         = nrow(table_out),
  n_canonicals    = length(unique(table_out$esy_canonical)),
  n_accepted_in   = sum(nzchar(table_out$accepted_in)),
  r_version       = as.character(getRversion()),
  stringsAsFactors = FALSE
)
write_lf(build_out, "inst/extdata/esy_synonyms_build.csv")
write_lf(log_n, "data-raw/esy_synonyms_build_log.csv")

print(log_n, row.names = FALSE)
print(build_out, row.names = FALSE)
print(backbones_out, row.names = FALSE)
