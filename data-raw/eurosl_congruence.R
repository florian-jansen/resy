# Check ESy expert systems for congruence with the EuroSL taxonomic backbone.
#
# Step 1: every Section 1 aggregation must name one EuroSL tree node and every
#         member must resolve to that node (as a synonym) or to a node below it.
# Step 2: every Section 2 species-group member must resolve to an accepted
#         EuroSL name.
#
# Names are resolved with vegdata::taxname.match(); the tree comes from the
# parent links of vegdata::tax("all"). The backbone is read from a local EuroSL
# sqlite until https://eurosl.infinitenature.org is updated.
#
# Usage: Rscript --no-init-file data-raw/eurosl_congruence.R [EuroSL.sqlite] [outdir]

suppressMessages({
  pkgload::load_all(quiet = TRUE)
  library(data.table)
})

args <- commandArgs(trailingOnly = TRUE)
db <- if (length(args) >= 1) args[1] else
  "/home/jansen/aGitRepos/reflists/EuroSL/results/EuroSL.sqlite"
outdir <- if (length(args) >= 2) args[2] else "data-raw/eurosl-congruence"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

root <- "inst/extdata/classifications"
systems <- c(
  "EUNIS-2025-10-03"         = file.path(root, "EUNIS/2025-10-03/expert.txt.xz"),
  "Apennine-test-2026-06-27" = file.path(root, "Apennine-test/2026-06-27/expert.json")
)
# Names are matched with RESY's concept-aware backbone matching
# (.resy_backbone_match(), R/resy_backbone.R): no "simplify", no "aggregate as
# species", broad names only on aggregate-level nodes, cf./aff./? and auct.
# never matched.

# ---- backbone -----------------------------------------------------------------

bbk <- .resy_backbone_get("EuroSL", db)
sp <- bbk$list
strict_re <- .resy_strict_re

acc <- sp[SYNONYM == FALSE]
concept_of <- setNames(sp$TaxonConceptID, sp$TaxonUsageID)
cname <- setNames(acc$TaxonName, acc$TaxonConceptID)
crank <- setNames(acc$taxonRank, acc$TaxonConceptID)
parent <- setNames(acc$parentTaxonConceptID, acc$TaxonConceptID)

# Ancestor table: column k holds the k-th ancestor of each accepted concept.
anc <- list(unname(parent[acc$TaxonConceptID]))
repeat {
  nxt <- unname(parent[anc[[length(anc)]]])
  if (all(is.na(nxt))) break
  anc[[length(anc) + 1L]] <- nxt
}
anc <- setNames(as.data.table(anc), paste0("a", seq_along(anc)))
anc[, cid := acc$TaxonConceptID]
anc_long <- melt(anc, id.vars = "cid", value.name = "anc", na.rm = TRUE)[, .(cid, anc)]
setkey(anc_long, cid, anc)
n_desc <- anc_long[, .N, by = anc]
is_below <- function(c, g) !is.na(anc_long[.(c, g), on = .(cid, anc), mult = "first", which = TRUE])
label <- function(c) ifelse(is.na(c), "", sprintf("%s [%s, %s]", cname[c], crank[c], c))
infrageneric_stop <- c("GAT", "SGE", "FAM", "SFA", "ORD", "KLA", "UKL", "ROOT")

# ---- expert systems -----------------------------------------------------------

read_txt <- function(path) {
  x <- readLines(xzfile(path, encoding = "UTF-8"), warn = FALSE)
  sec <- function(n) {
    from <- grep(sprintf("^SECTION %d: (?!End)", n), x, perl = TRUE)
    to <- grep(sprintf("^SECTION %d: End", n), x)
    if (!length(from)) character() else x[(from + 1L):(to - 1L)]
  }
  s1 <- sec(1)
  blk <- cumsum(!nzchar(trimws(s1)))
  keep <- nzchar(trimws(s1))
  nm <- trimws(sub("\\s+(-\\s+\\d+|\\d+)\\s*$", "", s1[keep]))
  b <- split(nm, blk[keep])
  aggs <- rbindlist(lapply(b, function(v)
    data.table(group = v[1], member = v[-1])[, member := as.character(member)]), fill = TRUE)
  aggs <- unique(rbind(aggs, data.table(group = vapply(b, `[`, "", 1), member = NA_character_)))
  s2 <- sec(2)
  gh <- startsWith(s2, "#")
  gname <- cumsum(gh)
  groups <- data.table(group = s2[gh][gname[!gh & nzchar(trimws(s2))]],
                       member = trimws(s2[!gh & nzchar(trimws(s2))]))
  list(aggs = aggs, groups = groups)
}

read_json <- function(path) {
  d <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  aggs <- rbindlist(lapply(names(d$synonyms), function(g)
    data.table(group = g, member = c(NA_character_, unlist(d$synonyms[[g]])))))
  groups <- rbindlist(lapply(names(d$groups), function(g)
    data.table(group = g, member = unlist(d$groups[[g]]))))
  list(aggs = aggs, groups = groups)
}

# ---- checks -------------------------------------------------------------------

resolve <- function(names) {
  r <- .resy_backbone_match(names, bbk)
  # candidate concept of a name with an unclear level, for the hint
  cand <- unname(concept_of[r$usage])
  hint <- fifelse(r$issue %in% "level_unclear",
                  fifelse(is.na(cand),
                          paste("species node would be",
                                label(concept_of[sp$TaxonUsageID[match(
                                  trimws(sub(strict_re, " ", r$name)), sp$TaxonName)]])),
                          paste("candidate", label(cand))), NA_character_)
  data.table(Name = r$name, TaxonUsageID = r$usage, cid = r$concept, match = r$match,
             synonym = r$usage %in% sp$TaxonUsageID[sp$SYNONYM],
             issue = fifelse(r$issue %in% "not_found", NA_character_, r$issue),
             hint = hint)
}

check_step1 <- function(aggs, sys) {
  r <- resolve(c(aggs$group, aggs$member))
  g <- unique(aggs[, .(group)])
  g[r, on = .(group = Name), `:=`(g_cid = i.cid, g_match = i.match,
                                  g_syn = i.synonym, g_issue = i.issue, g_hint = i.hint)]
  g[, status := fcase(
    g_issue %in% "level_unclear", "group_level_unclear",
    g_issue %in% "misapplied_name", "group_misapplied_name",
    g_issue %in% "uncertain_determination", "group_uncertain_determination",
    is.na(g_cid), "group_not_found",
    g_match != "exact", "group_name_needs_cleaning",
    g_syn, "group_is_synonym",
    default = "ok")]
  g[, suggestion := fcase(
    status == "group_level_unclear",
    paste0("decide taxon level (", g_hint, ")"),
    status == "group_misapplied_name", "misapplied name: needs a concept in EuroSL (auct.)",
    status == "group_uncertain_determination", "cf./aff./? taxa are ignored: drop the aggregation",
    status == "group_not_found", "add name to EuroSL or rename group",
    status %in% c("group_name_needs_cleaning", "group_is_synonym"),
    paste("rename group to", label(g_cid)),
    default = "")]
  g[, eurosl_node := label(g_cid)]
  g[n_desc, on = .(g_cid = anc), eurosl_descendants := i.N]
  # several ESy aggregations collapsing onto one EuroSL node
  g[!is.na(g_cid), same_node := {
    if (.N > 1) vapply(group, function(x) paste(setdiff(group, x), collapse = ", "), "") else ""
  }, by = g_cid]
  g[status == "ok" & nzchar(same_node), status := "duplicate_node"]
  # ESy aggregation nested below another (infrageneric) ESy aggregation
  nodes <- unique(na.omit(g$g_cid))
  nest <- anc_long[cid %in% nodes & anc %in% nodes & !crank[anc] %in% infrageneric_stop]
  nest <- nest[, .(nested_in = paste(g$group[match(anc, g$g_cid)], collapse = ", ")), by = cid]
  g[nest, on = .(g_cid = cid), nested_in := i.nested_in]

  m <- aggs[!is.na(member)]
  m[g, on = "group", g_cid := i.g_cid]
  m[r, on = .(member = Name), `:=`(m_cid = i.cid, m_match = i.match,
                                   m_issue = i.issue, m_hint = i.hint)]
  m[, rel := fcase(
    !is.na(m_issue), m_issue,
    is.na(m_cid), "none",
    is.na(g_cid), "group_unresolved",
    m_cid == g_cid, "same",
    default = NA_character_)]
  m[is.na(rel), rel := fifelse(is_below(m_cid, g_cid), "below",
                        fifelse(is_below(g_cid, m_cid), "above", "other"))]
  m[, status := fcase(
    rel == "level_unclear", "member_level_unclear",
    rel == "misapplied_name", "member_misapplied_name",
    rel == "uncertain_determination", "member_uncertain_determination",
    rel == "none", "member_not_found",
    rel == "group_unresolved", "group_unresolved",
    rel %in% c("same", "below") & m_match != "exact", "ok_after_cleaning",
    rel %in% c("same", "below"), "ok",
    rel == "above", "member_broader_than_group",
    default = "member_elsewhere")]
  # member hangs directly on the genus that also holds the group node: EuroSL
  # lacks the infrageneric placement, the expert file is not wrong
  m[status == "member_elsewhere", m_parent := unname(parent[m_cid])]
  m[status == "member_elsewhere" & crank[m_parent] %in% "GAT" & is_below(g_cid, m_parent),
    status := "eurosl_placement_missing"]
  m[, eurosl_match := label(m_cid)]
  m[, suggestion := fcase(
    status == "member_level_unclear", paste0("decide taxon level (", m_hint, ")"),
    status == "member_misapplied_name", "misapplied name: needs a concept in EuroSL (auct.)",
    status == "member_uncertain_determination", "cf./aff./? taxa are ignored: drop member",
    status == "member_not_found", "not in EuroSL: drop member, or add name to EuroSL",
    status == "ok_after_cleaning",
    "field-name variant; drop from expert file, handled by dataset name matching",
    status == "member_broader_than_group",
    "member is broader; drop it, or move the aggregation up to that node",
    status == "eurosl_placement_missing",
    paste("EuroSL: place", eurosl_match, "below", label(g_cid), "(now directly under the genus)"),
    status == "member_elsewhere", paste("EuroSL places it under", eurosl_match,
                                        "- drop or move to that aggregation"),
    default = "")]
  list(groups = cbind(system = sys, g[, .(group, status, eurosl_node, matched_via = g_match,
                                          eurosl_descendants, same_node, nested_in, suggestion)]),
       members = cbind(system = sys, m[status != "ok", .(group, member, status,
                                                         matched_via = m_match, eurosl_match,
                                                         suggestion)]))
}

check_step2 <- function(groups, sys) {
  r <- resolve(groups$member)
  groups[r, on = .(member = Name), `:=`(cid = i.cid, mt = i.match, syn = i.synonym,
                                        issue = i.issue,
                                        hint = i.hint)]
  groups[, status := fcase(
    !is.na(issue), issue,
    is.na(cid), "not_found",
    mt != "exact", "needs_cleaning",
    syn, "synonym",
    default = "ok")]
  groups[, suggestion := fifelse(status %in% c("needs_cleaning", "synonym"),
                                 paste("use", label(cid)),
                                 fcase(status == "not_found", "not in EuroSL",
                                       status == "level_unclear",
                                       paste0("decide taxon level (", hint, ")"),
                                       status == "uncertain_determination",
                                       "cf./aff./? taxa are ignored: drop member",
                                       status == "misapplied_name",
                                       "misapplied name: needs a concept in EuroSL (auct.)",
                                       default = ""))]
  cbind(system = sys, groups[status != "ok", .(group, member, status, matched_via = mt,
                                               suggestion)])
}

# Species names an expert system uses in Sections 2 and 3, as RESY reads them.
used_names <- function(path) {
  parsed <- if (grepl("\\.json$", path)) .resy_parse_json(path) else
    .resy_build_parsed(.resy_parse_expert_lines(
      readLines(xzfile(path, encoding = "UTF-8"), warn = FALSE, encoding = "UTF-8")))
  .resy_expert_used(parsed)
}

# ---- run ----------------------------------------------------------------------

summary <- character()
for (sys in names(systems)) {
  path <- systems[[sys]]
  e <- if (grepl("\\.json$", path)) read_json(path) else read_txt(path)
  s1 <- check_step1(e$aggs, sys)
  # A Section 1 mismatch matters only where the aggregation is used: as a
  # member of a species group or as a species in a Section 3 condition.
  used <- used_names(path)
  # Only concept mismatches are important; field-name variants (spelling,
  # cf./aff./?, strings unknown to the backbone) lose just that spelling.
  concept_status <- c("member_elsewhere", "member_broader_than_group",
                      "eurosl_placement_missing", "member_level_unclear",
                      "member_misapplied_name", "group_unresolved")
  s1$groups[, importance := fifelse(group %in% used & status != "ok" &
                                      status != "group_uncertain_determination",
                                    "important", "unimportant")]
  s1$members[, importance := fifelse(group %in% used & status %in% concept_status,
                                     "important", "unimportant")]
  setorder(s1$groups, importance, status, group)
  setorder(s1$members, importance, status, group)
  s2 <- check_step2(e$groups, sys)
  fwrite(s1$groups[status != "ok" | !is.na(nested_in)],
         file.path(outdir, paste0(sys, "_step1_groups.tsv")), sep = "\t")
  fwrite(s1$members, file.path(outdir, paste0(sys, "_step1_members.tsv")), sep = "\t")
  fwrite(s2, file.path(outdir, paste0(sys, "_step2_species_groups.tsv")), sep = "\t")
  tab <- function(x) paste(sprintf("%s: %d", names(x), x), collapse = ", ")
  summary <- c(summary, sprintf(
    "## %s\nSection 1: %d aggregations, %d members\n  groups:  %s\n  nested inside another aggregation: %d\n  members: %s\nSection 2: %d groups, %d member entries\n  issues:  %s\n",
    sys, nrow(s1$groups), sum(!is.na(e$aggs$member)),
    tab(table(s1$groups$status)), sum(!is.na(s1$groups$nested_in)),
    paste(tab(table(s1$members$status)), "\n  of these used in Sections 2/3 (important):",
          sum(s1$members$importance == "important"), "members,",
          sum(s1$groups$importance == "important" & s1$groups$status != "ok"), "groups"),
    uniqueN(e$groups$group), nrow(e$groups), tab(table(s2$status))))
}
writeLines(summary, file.path(outdir, "summary.txt"))
cat(summary, sep = "\n")
