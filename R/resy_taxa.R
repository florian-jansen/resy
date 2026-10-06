# A resy_taxa table holds taxon names with the result of matching them against a
# reference vocabulary: resy_check_taxonomy() gives one row per distinct name,
# resy_resolve_taxa() one row per observation. Both carry a logical `matched`
# column; `name_col` names the column with the names as submitted and `columns`
# describes the taxonomy columns shown by print().
.resy_taxa <- function(df, input_col, name_col, columns, reference) {
  attr(df, "input_col") <- input_col
  attr(df, "name_col")  <- name_col
  attr(df, "columns")   <- columns
  attr(df, "reference") <- reference
  class(df) <- c("resy_taxa", "data.frame")
  df
}

.resy_taxa_attrs <- c("input_col", "name_col", "columns", "reference")

.resy_is_taxa <- function(x) {
  is.data.frame(x) && all(c(attr(x, "name_col"), "matched") %in% names(x))
}

#' @export
`[.resy_taxa` <- function(x, ...) {
  out <- NextMethod()
  if (!is.data.frame(out)) return(out)
  for (a in .resy_taxa_attrs) attr(out, a) <- attr(x, a)
  if (.resy_is_taxa(out)) return(out)
  for (a in .resy_taxa_attrs) attr(out, a) <- NULL
  class(out) <- setdiff(class(out), "resy_taxa")
  out
}

#' @export
print.resy_taxa <- function(x, n = 10L, ...) {
  if (!.resy_is_taxa(x)) return(NextMethod())
  s <- summary(x)
  counts <- if (s$n_records == s$n) {
    sprintf("%d name(s)", s$n)
  } else {
    sprintf("%d record(s) with %d distinct name(s)", s$n_records, s$n)
  }
  cat(sprintf("<resy_taxa> %s from column `%s` %s\n",
              counts, attr(x, "input_col"), attr(x, "reference")))
  columns <- attr(x, "columns")
  cols <- intersect(names(columns), names(x))
  w <- max(nchar(cols))
  cat(sprintf("  %-*s  %s\n", w, cols, columns[cols]), sep = "")
  others <- setdiff(names(x), cols)
  if (length(others)) {
    cat(sprintf("  (%d other column(s) not shown: %s)\n", length(others),
                paste(others, collapse = ", ")))
  }
  cat(sprintf("%d matched (%s), %d unmatched",
              s$matched, .resy_pct(s$matched, s$n), s$unmatched))
  cat(if (s$unmatched > 0L) "; summary() lists them\n\n" else "\n\n")
  shown <- as.data.frame(unclass(x)[cols], stringsAsFactors = FALSE)
  print(utils::head(shown, n), ...)
  if (nrow(shown) > n) cat(sprintf("# ... %d more row(s)\n", nrow(shown) - n))
  invisible(x)
}

#' @export
summary.resy_taxa <- function(object, ...) {
  if (!.resy_is_taxa(object)) {
    stop("summary.resy_taxa: `object` needs the columns `",
         attr(object, "name_col"), "` and `matched`.", call. = FALSE)
  }
  m <- as.logical(object$matched)
  taxa <- as.character(object[[attr(object, "name_col")]])
  first <- !is.na(taxa) & !duplicated(taxa)
  by_confidence <- NULL
  if ("taxon_confidence" %in% names(object)) {
    conf <- as.character(object$taxon_confidence)
    by_confidence <- as.data.frame(table(confidence = conf),
                                   stringsAsFactors = FALSE)
    names(by_confidence) <- c("confidence", "n")
    by_confidence$prop <- by_confidence$n / length(conf)
  }
  structure(
    list(
      n               = sum(first),
      matched         = sum(m[first]),
      unmatched       = sum(!m[first]),
      unmatched_names = sort(taxa[first & !m]),
      n_records       = length(m),
      records_matched = sum(m),
      by_confidence   = by_confidence
    ),
    class = "summary.resy_taxa"
  )
}

#' @export
print.summary.resy_taxa <- function(x, ...) {
  cat(sprintf("%d names checked: %d matched (%s), %d not matched (%s).\n",
              x$n, x$matched, .resy_pct(x$matched, x$n),
              x$unmatched, .resy_pct(x$unmatched, x$n)))
  if (x$n_records != x$n) {
    cat(sprintf("%d of %d records matched (%s).\n", x$records_matched,
                x$n_records, .resy_pct(x$records_matched, x$n_records)))
  }
  if (!is.null(x$by_confidence) && nrow(x$by_confidence) > 0L) {
    cat("\nRecords by match type:\n")
    bc <- x$by_confidence
    w <- max(nchar(bc$confidence))
    cat(sprintf("  %-*s  %*d  (%s)\n", w, bc$confidence, max(nchar(bc$n)), bc$n,
                vapply(bc$n, .resy_pct, character(1), n = x$n_records)), sep = "")
  }
  if (x$unmatched > 0L) {
    cat("\nNot matched:\n")
    kinds <- .resy_name_kind(x$unmatched_names)
    labels <- c(genus = "genus only", infraspecific = "below species level",
                species = "species")
    for (k in names(labels)) {
      nm <- x$unmatched_names[kinds == k]
      if (!length(nm)) next
      if (k == "genus") nm <- sub("\\s+spp?\\.?$", "", nm)
      cat(.resy_pack_names(sprintf("  %s (%d): ", labels[[k]], length(nm)), nm,
                           width = getOption("width"), exdent = 4L), sep = "\n")
    }
  }
  invisible(x)
}

# Lines of comma-separated names after `lead`, filled up to `width` characters
# without breaking a name across lines; continuation lines are indented by
# `exdent` spaces.
.resy_pack_names <- function(lead, names, width, exdent) {
  lines <- character()
  current <- lead
  fresh <- TRUE
  for (i in seq_along(names)) {
    item <- if (i < length(names)) paste0(names[i], ",") else names[i]
    candidate <- if (fresh) paste0(current, item) else paste(current, item)
    if (!fresh && nchar(candidate) > width) {
      lines <- c(lines, current)
      current <- paste0(strrep(" ", exdent), item)
    } else {
      current <- candidate
    }
    fresh <- FALSE
  }
  c(lines, current)
}

# What a taxon name names: a genus only ("Carex sp.", "Carex"), a taxon below
# species level ("Festuca rubra subsp. commutata", "... var. ..."), or a species.
.resy_name_kind <- function(names) {
  words <- lengths(strsplit(trimws(names), "\\s+"))
  genus <- words == 1L | grepl("\\s+spp?\\.?$", names)
  infra <- grepl("\\s(subsp|ssp|var|subvar|f|nothosubsp)\\.\\s", names)
  ifelse(genus, "genus", ifelse(infra, "infraspecific", "species"))
}

.resy_pct <- function(k, n) {
  if (n == 0L) "0%" else sprintf("%.1f%%", 100 * k / n)
}
