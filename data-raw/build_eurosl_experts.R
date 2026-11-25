# Build the EuroSL-backbone versions of the EUNIS and Apennine-test expert
# systems from their releases with Section 1 (species aggregation):
#
# * Section 1 is replaced by the declaration of the taxonomic backbone;
# * species named in Section 2 (species groups) and Section 3 (single-species
#   conditions, EXCEPT parts) get their accepted EuroSL name where the name
#   resolves to a EuroSL concept without doubt (synonyms, spelling variants,
#   aggr. -> agg., accepted genus); duplicates in a group are dropped;
# * names that do not resolve are kept as they are and reported;
# * obvious errors of the release are corrected (see "Corrections" below).
#
# Run from the package root: Rscript --no-init-file data-raw/build_eurosl_experts.R
# Uses the local EuroSL file below until https://eurosl.infinitenature.org is
# updated.

suppressMessages(pkgload::load_all(quiet = TRUE))
library(data.table)

eurosl <- "/home/jansen/aGitRepos/reflists/EuroSL/results/EuroSL.sqlite"
options(resy.backbone = eurosl)
bb <- .resy_backbone_get("EuroSL")
version <- bb$version
backbone <- list(name = "EuroSL", url = "https://eurosl.infinitenature.org",
                 version = version)
root <- "inst/extdata/classifications"
report_dir <- "data-raw/eurosl-congruence"
dir.create(report_dir, showWarnings = FALSE)

# Accepted EuroSL name for each name that resolves to a concept; the report of
# all names the expert system uses.
rename_map <- function(parsed, system) {
  ref <- .resy_expert_used(parsed)
  m <- .resy_backbone_match(ref, bb)
  m[, used_in := fifelse(name %in% trimws(unlist(parsed$groups)), "Section 2", "Section 3")]
  m[, action := fcase(
    !is.na(concept) & accepted != name, "renamed",
    !is.na(concept), "unchanged",
    default = "kept, not in backbone")]
  # renames an expert should look at
  words <- function(x) lengths(strsplit(x, " "))
  m[, review := fcase(
    action != "renamed", NA_character_,
    match == "fuzzy", "spelling corrected by fuzzy matching",
    match == "accepted genus", "moved to the accepted genus",
    words(name) != words(accepted), "rank or extent differs",
    default = NA_character_)]
  fwrite(cbind(system = system, m[order(action, name)]),
         file.path(report_dir, paste0(system, "_names_used.tsv")), sep = "\t")
  m <- m[action == "renamed"]
  stats::setNames(m$accepted, m$name)
}

# Rename the species of one membership expression ("<...>" without brackets):
# bare sides are single species; in "A EXCEPT B" the parts of B that are no
# group are species. Group references (with a code) are never touched.
rename_expression <- function(x, map, group_names) {
  ops <- "\\s+(GR|GE|EQ)\\s+"
  sides <- strsplit(x, ops, perl = TRUE)[[1L]]
  opers <- regmatches(x, gregexpr(ops, x, perl = TRUE))[[1L]]
  sides <- vapply(sides, function(s) {
    t <- trimws(s)
    if (!grepl("^[#$]", t) && !grepl("^NON ", t) && t %in% names(map))
      return(sub(t, map[[t]], s, fixed = TRUE))
    if (grepl(" EXCEPT ", s, fixed = TRUE)) {
      p <- strsplit(s, " EXCEPT ", fixed = TRUE)[[1L]]
      b <- strsplit(p[2L], "|", fixed = TRUE)[[1L]]
      b <- vapply(b, function(e) {
        te <- trimws(e)
        if (!grepl("^[#$]", te) && !te %in% group_names && te %in% names(map))
          sub(te, map[[te]], e, fixed = TRUE) else e
      }, "", USE.NAMES = FALSE)
      return(paste(p[1L], paste(b, collapse = "|"), sep = " EXCEPT "))
    }
    s
  }, "", USE.NAMES = FALSE)
  paste0(c(rbind(sides, c(opers, ""))), collapse = "")
}

rename_formulas <- function(x, map, group_names) {
  m <- gregexpr("<[^<>]*>", x, perl = TRUE)
  regmatches(x, m) <- lapply(regmatches(x, m), function(tok) vapply(tok, function(t)
    paste0("<", rename_expression(substr(t, 2L, nchar(t) - 1L), map, group_names), ">"),
    "", USE.NAMES = FALSE))
  x
}

# ---- EUNIS (text file) ----------------------------------------------------------

src <- file.path(root, "EUNIS/2025-10-03/expert.txt.xz")
lines <- readLines(xzfile(src, encoding = "UTF-8"), warn = FALSE, encoding = "UTF-8")
# Corrections of the release: a missing space turned "GR 05" into part of a
# group name that does not exist (type P2N).
lines <- gsub("<#TC Cliff-ferns GR05>", "<#TC Cliff-ferns GR 05>", lines, fixed = TRUE)
parsed <- .resy_build_parsed(.resy_parse_expert_lines(lines))
map <- rename_map(parsed, "EUNIS-2025-10-03")
group_names <- parsed$groups.names

at <- function(re) grep(re, lines)
s1 <- at("^SECTION 1: "); s2 <- at("^SECTION 2: "); s3 <- at("^SECTION 3: ")

# Section 2: rename members, drop members a group already lists
sec2 <- lines[(s2[1L] + 1L):(s2[2L] - 1L)]
is_member <- grepl("^\\s", sec2) & nzchar(trimws(sec2))
nm <- trimws(sec2)
ren <- is_member & nm %in% names(map)
sec2[ren] <- paste0(sub("^(\\s*).*$", "\\1", sec2[ren]), map[nm[ren]])
block <- cumsum(!is_member & nzchar(trimws(sec2)))
dup <- is_member & duplicated(paste(block, trimws(sec2)))
sec2 <- sec2[!dup]

# Section 3: single-species conditions
sec3 <- lines[(s3[1L] + 1L):(s3[2L] - 1L)]
sec3 <- rename_formulas(sec3, map, group_names)

out <- c(
  if (s1[1L] > 1L) lines[seq_len(s1[1L] - 1L)],
  "SECTION 1: Taxonomic backbone",
  .resy_backbone_line(backbone),
  "SECTION 1: End",
  lines[(s1[2L] + 1L):s2[1L]], sec2, lines[s2[2L]:s3[1L]], sec3,
  lines[s3[2L]:length(lines)]
)
dir <- file.path(root, "EUNIS/2025-10-03-EuroSL")
dir.create(dir, showWarnings = FALSE, recursive = TRUE)
con <- xzfile(file.path(dir, "expert.txt.xz"), "wb", compression = 9)
writeLines(enc2utf8(out), con, sep = "\r\n", useBytes = TRUE)
close(con)
message("EUNIS: ", length(map), " names renamed, ", sum(dup), " duplicate group members dropped")

# ---- Apennine-test (JSON) -------------------------------------------------------

src <- file.path(root, "Apennine-test/2026-06-27/expert.json")
x <- jsonlite::read_json(src, simplifyVector = FALSE)
parsed <- .resy_parse_json(src)
map <- rename_map(parsed, "Apennine-test-2026-06-27")
x$groups <- lapply(x$groups, function(g) {
  g <- unlist(g)
  g[g %in% names(map)] <- map[g[g %in% names(map)]]
  as.list(unique(g))
})
x$rules <- lapply(x$rules, function(r) {
  r$expression <- rename_formulas(r$expression, map, parsed$groups.names)
  r
})
x$synonyms <- NULL
x$metadata$version <- "2026-06-27-EuroSL"
x <- c(x["metadata"], list(backbone = backbone), x[c("groups", "rules")])
dir <- file.path(root, "Apennine-test/2026-06-27-EuroSL")
dir.create(dir, showWarnings = FALSE, recursive = TRUE)
jsonlite::write_json(x, file.path(dir, "expert.json"), auto_unbox = TRUE, pretty = TRUE)
message("Apennine-test: ", length(map), " names renamed")
