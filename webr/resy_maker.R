# R functions behind the RESY Maker (vignettes/articles/maker.Rmd), sourced
# after resy_page.R, whose helpers read the data and classify. The page edits an
# expert system as JSON; these functions open an existing system as JSON, test
# the system being edited on a set of plots, and write it as a .txt file.

.maker <- new.env()

# ---- Opening an expert system ------------------------------------------------

# Writes an expert system to `out` in the JSON format: a scheme shipped with
# RESY (in `version`, or its newest version), or an uploaded .json/.txt file.
resy_maker_open <- function(out, scheme = NULL, version = NULL, path = NULL) {
  src <- path
  if (is.null(src)) {
    if (is.null(version)) {
      root <- system.file("extdata", "classifications", scheme, package = "RESY")
      version <- sort(list.dirs(root, full.names = FALSE, recursive = FALSE), decreasing = TRUE)[1]
    }
    src <- resy_expert_path(scheme, version)
  }
  if (RESY:::.resy_is_json(src)) {
    writeBin(RESY:::.resy_read_raw(src), out)
    return(invisible(out))
  }
  model <- .maker_from_txt(src)
  model$metadata <- list(
    scheme = scheme %||% sub("\\.txt(\\.xz)?$", "", basename(src), ignore.case = TRUE),
    version = version %||% "",
    description = ""
  )
  json <- function(x) enc2utf8(as.character(jsonlite::toJSON(x, auto_unbox = TRUE)))
  con <- file(out, open = "wb")
  on.exit(close(con))
  writeBin(charToRaw(paste0(
    '{"metadata":', json(model$metadata),
    ',"synonyms":', .maker_json_lists(model$synonyms),
    ',"groups":', .maker_json_lists(model$groups),
    ',"rules":', json(model$rules), "}"
  )), con)
  invisible(out)
}

# Character vectors as JSON strings. A string without a character that JSON
# escapes is only quoted; the others go through jsonlite one by one.
.maker_json_strings <- function(x) {
  x <- enc2utf8(x)
  out <- paste0('"', x, '"')
  escaped <- grepl('[\\\\"[:cntrl:]]', x)
  out[escaped] <- vapply(x[escaped], function(s) as.character(jsonlite::toJSON(s, auto_unbox = TRUE)),
                         character(1))
  out
}

# A named list of character vectors as a JSON object of arrays. The object of
# the species names has tens of thousands of keys, which jsonlite writes one
# element at a time; here all strings are quoted in one pass.
.maker_json_lists <- function(x) {
  of <- factor(rep(seq_along(x), lengths(x)), levels = seq_along(x))
  arrays <- vapply(split(.maker_json_strings(unlist(x, use.names = FALSE)), of),
                   paste, character(1), collapse = ",")
  paste0("{", paste0(.maker_json_strings(names(x)), ":[", arrays, "]", collapse = ","), "}")
}

# The sections of a .txt expert file as the lists of the JSON format, with the
# formulas as they are written in the file.
.maker_from_txt <- function(path) {
  tree <- resy_read_expert(path)
  entries <- function(n) RESY:::.resy_section_by_number(tree, n)$entries %||% list()
  aggs <- entries(1L)
  groups <- Filter(function(g) !is.na(g$prefix), entries(2L))
  rules <- Filter(function(r) !is.na(r$priority) && grepl("<", r$expression, fixed = TRUE), entries(3L))
  # A JSON object holds each name once: the entries of a species or group that
  # the file lists twice are put together.
  by_name <- function(values, names) {
    lapply(split(values, factor(names, levels = unique(names))),
           function(v) unique(as.character(unlist(v, use.names = FALSE))))
  }
  list(
    synonyms = by_name(lapply(aggs, function(a) a$synonyms),
                       vapply(aggs, function(a) a$canonical, character(1))),
    groups = by_name(lapply(groups, function(g) g$members),
                     vapply(groups, function(g) paste(g$prefix, g$name), character(1))),
    rules = lapply(rules, function(r) list(
      priority = r$priority, code = r$code, description = r$description,
      expression = gsub("\\s*\n\\s*", " ", r$expression)
    ))
  )
}

# ---- Test data ------------------------------------------------------------------

# Reads the plots the system is tested on: `species_tsv` with the columns
# PlotObservationID, name and cover, `sites_tsv` with PlotObservationID and the
# site columns. Returns the species of the plots under their cleaned names, each
# with the number of plots it occurs in and the names it is written as.
resy_maker_set_data <- function(species_tsv, sites_tsv) {
  sp <- .page_read(species_tsv)
  sp <- sp[!is.na(sp$name) & !is.na(sp$PlotObservationID), , drop = FALSE]
  .maker$all <- list(sp = sp, si = .page_read(sites_tsv))
  resy_maker_region()
  .page$taxa <- character()
  raw <- unique(sp$name)
  clean <- resy_clean_names(raw)
  ok <- !is.na(clean) & nzchar(clean)
  raw <- raw[ok]
  clean <- clean[ok]
  variants <- split(raw, clean)
  of_record <- clean[match(sp$name, raw)]
  plots <- tapply(sp$PlotObservationID, of_record, function(p) length(unique(p)))
  .page_json(list(
    n_plots = length(unique(sp$PlotObservationID)),
    n_records = nrow(sp),
    species = unname(Map(function(name, v) list(name = name, plots = as.integer(plots[[name]]),
                                                variants = I(setdiff(v, name))),
                         names(variants), variants))
  ))
}

# Limits the test to the plots of the test data whose IDs are in the JSON array
# at `path`; without `path` the test takes all plots again.
resy_maker_region <- function(path = NULL) {
  all <- .maker$all
  keep <- if (is.null(path)) NULL else unlist(jsonlite::read_json(path), use.names = FALSE)
  within <- function(d) if (is.null(keep)) d else d[d$PlotObservationID %in% keep, , drop = FALSE]
  .maker$sp <- within(all$sp)
  .maker$si <- within(all$si)
  .maker$sites <- NULL
  .maker$res <- NULL
  invisible(NULL)
}

# The site columns a rule can read: numeric ones with their range, the others
# with their values.
.maker_columns <- function(sites) {
  cols <- setdiff(names(sites), "PlotObservationID")
  out <- lapply(cols, function(col) {
    v <- sites[[col]]
    if (is.list(v)) return(NULL)
    if (is.numeric(v)) {
      v <- v[!is.na(v)]
      return(list(name = col, type = "number",
                  min = if (length(v)) min(v) else NA, max = if (length(v)) max(v) else NA))
    }
    u <- sort(unique(as.character(v[!is.na(v)])))
    list(name = col, type = "category", values = I(utils::head(u, 200L)))
  })
  Filter(Negate(is.null), out)
}

# ---- Testing the system being edited -----------------------------------------------

# The species list of the system, read when it changes; a test reads the groups
# and rules only.
resy_maker_synonyms <- function(path) {
  .maker$synonyms <- jsonlite::read_json(path, simplifyVector = FALSE)
  .maker$parsed <- NULL
  invisible(length(.maker$synonyms))
}

# The parsed system belongs to the complete rules document and the current
# synonym table. Site preparation and classification share that object.
.maker_system <- function(path) {
  document <- readBin(path, "raw", file.size(path))
  if (!is.null(.maker$parsed) && identical(document, .maker$document)) return(.maker$parsed)
  x <- RESY:::.resy_raw_json(document)
  x$synonyms <- .maker$synonyms %||% list()
  groups <- RESY:::.resy_json_chr_list(x$groups)
  parsed <- if (length(x$rules)) RESY:::.resy_parsed_from_json(x) else
    structure(list(aggs = RESY:::.resy_json_chr_list(x$synonyms), groups = groups,
                    groups.names = RESY:::.resy_group_name(names(groups)), conditions = character()),
               class = "resy_parsed_expert")
  .maker$document <- document
  .maker$parsed <- list(x = x, groups = groups, parsed = parsed)
  .maker$parsed
}

resy_maker_needs_geography <- function(path, coast_dunes = TRUE, coast_buffer = 5000) {
  system <- tryCatch(.maker_system(path), error = function(e) NULL)
  if (is.null(system) || is.null(.maker$si)) return(FALSE)
  eunis <- any(.page_header_cols(system$parsed) %in% .page_eunis_site_cols)
  eunis && is.null(.page_cached_sites(.page_site_input(.maker$si), coast_dunes, coast_buffer))
}

# Classifies the test plots with the system in `rules_json` (metadata, groups
# and rules of the JSON format, its species list being the one last given to
# resy_maker_synonyms()). Returns the warnings of the classification and, per
# rule, the number of plots in which the rule and each of its conditions hold
# and the number of plots assigned to its type; per group the number of plots
# with one of its species; the type of each plot; the species names of the plots
# that the system does not know. A file without rules gives the group and
# species counts only. What RESY's validation says about the file is read with
# resy_maker_notes(): in webR it takes longer than the classification.
resy_maker_test <- function(rules_json, coast_dunes = TRUE, coast_buffer = 5000) {
  t0 <- Sys.time()
  out <- list(ok = FALSE, errors = character(), warnings = character())
  done <- function(out) {
    out$errors <- I(unique(out$errors))
    out$warnings <- I(.page_notes(out$warnings))
    out$seconds <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 2)
    .page_json(out)
  }

  prepared <- tryCatch(.maker_system(rules_json), error = function(e) e)
  if (inherits(prepared, "error")) {
    out$errors <- c(out$errors, conditionMessage(prepared))
    return(done(out))
  }
  x <- prepared$x
  groups <- prepared$groups
  parsed <- prepared$parsed

  if (is.null(.maker$sp)) return(done(out))
  sys <- if (length(x$rules)) .page_use_system(parsed, x$metadata$scheme %||% "draft") else {
    .page_use_taxonomy(parsed)
    .page$system <- list(scheme = "draft", parsed = parsed, eunis = FALSE, names = NULL,
                         header_cols = character(), derived_cols = character())
    .page$system
  }
  site_options <- list(eunis = sys$eunis, coast_dunes = coast_dunes, coast_buffer = coast_buffer)
  if (is.null(.maker$sites) || !identical(.maker$site_options, site_options)) {
    .maker$sites <- .page_sites(.maker$si, coast_dunes, coast_buffer)
    .maker$site_options <- site_options
  }
  out$columns <- .maker_columns(.maker$sites)
  out$eunis <- sys$eunis
  out$derived_cols <- I(sys$derived_cols)

  sp <- .maker$sp
  taxon <- .page_taxa(sp$name)
  unknown <- sort(table(sp$name[is.na(taxon)]), decreasing = TRUE)
  out$n_records <- nrow(sp)
  out$n_unmatched <- sum(is.na(taxon))
  out$unmatched <- unname(Map(function(name, n) list(name = name, records = n),
                              names(utils::head(unknown, 50L)), as.integer(utils::head(unknown, 50L))))
  out$n_unmatched_names <- length(unknown)
  plot_of <- sp$PlotObservationID
  .maker$group_plots <- lapply(groups, function(m) unique(plot_of[taxon %in% trimws(m)]))
  out$groups <- as.list(lengths(.maker$group_plots))
  out$n_plots <- length(unique(plot_of))
  if (!length(x$rules)) {
    .maker$res <- NULL
    out$ok <- TRUE
    return(done(out))
  }

  warnings <- character()
  res <- tryCatch(withCallingHandlers(
    .page_run(sp, .maker$sites),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    },
    message = function(m) invokeRestart("muffleMessage")
  ), error = function(e) e)
  if (inherits(res, "error")) {
    out$errors <- c(out$errors, conditionMessage(res))
    return(done(out))
  }
  .maker$res <- res
  out$warnings <- c(out$warnings, warnings)

  type <- res$result.classification
  n <- length(type)
  count <- function(v) sum(as.logical(v)[seq_len(n)], na.rm = TRUE)
  codes <- parsed$vegtype.formula.names.short
  assigned <- table(factor(type, levels = unique(codes)))
  expressions <- .maker_rule_expressions(parsed$vegtype.formulas)
  out$rules <- unname(Map(function(code, holds, e) list(
    code = code,
    holds = count(holds),
    assigned = as.integer(assigned[[code]]),
    conds = I(unname(vapply(res$logi1[match(e, parsed$membership.expressions)], count, integer(1))))
  ), codes, res$logi2, expressions))
  cand <- res$candidates
  out$plots <- list(
    id = I(names(type)),
    code = I(unname(type)),
    candidates = I(unname(vapply(split(cand$type, factor(cand$plot_id, levels = names(type))),
                                 paste, character(1), collapse = " ")))
  )
  out$ok <- TRUE
  done(out)
}

# What RESY's validation says about the system in `rules_json`, the file of the
# last test.
resy_maker_notes <- function(rules_json) {
  checked <- resy_validate_esy(rules_json, verbose = FALSE)
  .page_json(list(errors = I(checked$errors), warnings = I(.page_notes(checked$warnings))))
}

# The conditions of each rule in the order they are written in it.
.maker_rule_expressions <- function(formulas) {
  regmatches(formulas, gregexpr("(?<=<)[^<>]+(?=>)", formulas, perl = TRUE))
}

# The plots of the last test in which rule number `i` of the tested system
# holds and in which each of its conditions holds, as positions in the plot
# order of the test, counted from 0. A condition whose left side is a measure
# of the plot (the cover of a group, a number of species, a site value) also
# gives `value`, that measure in every plot.
resy_maker_rule_plots <- function(i) {
  res <- .maker$res
  parsed <- res$parsed
  n <- length(res$result.classification)
  at <- function(v) I(which(as.logical(v)[seq_len(n)]) - 1L)
  e <- .maker_rule_expressions(parsed$vegtype.formulas[[i]])[[1]]
  sides <- RESY:::.resy_expression_sides(e)
  left <- sides$token[sides$is_side & !duplicated(sides$expr)]
  col <- match(left, parsed$conditions)
  .page_json(list(
    holds = at(res$logi2[[i]]),
    conds = unname(Map(function(k, j) {
      out <- list(plots = at(res$logi1[[k]]))
      if (!is.na(j)) out$value <- I(as.numeric(res$plot.cond[[j]])[seq_len(n)])
      out
    }, match(e, parsed$membership.expressions), col))
  ), digits = NA)
}

# The plots of the last test with a species of the group `key`, as positions in
# its plot order, counted from 0.
resy_maker_group_plots <- function(key) {
  ids <- names(.maker$res$result.classification)
  at <- match(.maker$group_plots[[key]], ids)
  .page_json(I(sort(at[!is.na(at)]) - 1L))
}

# Why a plot of the last test is classified as it is (see resy_page_explain()).
resy_maker_explain <- function(plot_id, type = character()) {
  .page_json(.page_name_unknown(
    suppressWarnings(RESY:::.resy_plot_evidence(.maker$res, plot_id, type = type)), .maker$sp))
}

# ---- Export ---------------------------------------------------------------------------

# What RESY's validation says about a complete JSON expert file, and the error
# if RESY cannot read it.
resy_maker_check <- function(json_path) {
  checked <- resy_validate_esy(json_path, verbose = FALSE)
  loaded <- tryCatch({ resy_load_expert(expertfile = json_path); NULL },
                     error = function(e) conditionMessage(e))
  errors <- unique(c(checked$errors, loaded))
  .page_json(list(ok = !length(errors), errors = I(errors), warnings = I(.page_notes(checked$warnings))))
}

# Writes the JSON expert file `json_path` in the .txt format to `out` (a path
# ending in .txt), in the layout of the EUNIS-ESy releases. The file written is
# read back, and it is an error if RESY does not read the same species,
# groups, types and formulas from it as from the JSON file.
resy_maker_write_txt <- function(json_path, out) {
  x <- jsonlite::read_json(json_path, simplifyVector = FALSE)
  synonyms <- RESY:::.resy_json_chr_list(x$synonyms)
  groups <- RESY:::.resy_json_chr_list(x$groups)
  priority <- vapply(x$rules, function(r) as.character(r$priority), character(1))
  if (any(!priority %in% as.character(0:9)))
    stop("The .txt format takes the priorities 0 to 9 only; found ",
         paste(unique(priority[!priority %in% as.character(0:9)]), collapse = ", "), ".", call. = FALSE)
  s1 <- unlist(Map(function(name, syn) c(sprintf("%-57s -  0", name),
                                         if (length(syn)) sprintf("     %-55s 0", syn), ""),
                   names(synonyms), synonyms), use.names = FALSE)
  s2 <- unlist(Map(function(key, m) c(key, paste0("     ", m), ""), names(groups), groups),
               use.names = FALSE)
  s3 <- unlist(lapply(x$rules, function(r) c(
    RESY:::.resy_rule_header(r$priority, r$code, r$description), as.character(r$expression), ""
  )), use.names = FALSE)
  lines <- c("SECTION 1: Species aggregation", "", s1, "SECTION 1: End",
             "SECTION 2: Species groups", "", s2, "SECTION 2: End",
             "SECTION 3: Group definitions", "", s3, "SECTION 3: End", "",
             "SECTION 4: Similarity", "", "SECTION 4: End")
  bad <- grepl("---|\t|\n", lines)
  if (any(bad))
    stop("The .txt format cannot hold a tab, a line break or '---' in a name: ",
         paste(utils::head(trimws(lines[bad]), 3L), collapse = "; "), ".", call. = FALSE)
  con <- file(out, open = "wb")
  writeBin(charToRaw(enc2utf8(paste0(paste(lines, collapse = "\r\n"), "\r\n"))), con)
  close(con)

  a <- resy_load_expert(expertfile = json_path)
  b <- resy_load_expert(expertfile = out)
  parts <- c(species = identical(a$aggs, b$aggs),
             groups = identical(a$groups, b$groups),
             types = identical(a$vegtype.formula.names, b$vegtype.formula.names),
             priorities = identical(as.character(a$vegtype.priority), as.character(b$vegtype.priority)),
             formulas = identical(unname(a$vegtype.formulas), unname(b$vegtype.formulas)))
  if (!all(parts))
    stop("RESY does not read the same ", paste(names(parts)[!parts], collapse = ", "),
         " from the .txt file as from the JSON file, so the .txt file was not kept.", call. = FALSE)
  invisible(out)
}
