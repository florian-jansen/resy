#' What changed between two expert systems
#'
#' @description
#' `r lifecycle::badge("experimental")`
#' Compares two expert systems, for example two releases of EUNIS-ESy, and
#' lists every aggregate, species group and type that was added, removed or
#' changed. Systems are compared after parsing, so a `.txt` and a `.json`
#' file can be compared with each other and differences in layout or line
#' endings do not count as changes.
#'
#' @param from,to The two expert systems: a `resy_parsed_expert` from
#'   [resy_load_expert()], the path of an expert file, or a version of
#'   `scheme` available to [resy_load_expert()] (see
#'   [resy_available_classifications()]).
#' @param scheme Scheme of `from` and `to` when they are given as versions.
#'
#' @return A data frame of class `resy_expert_diff`, one row per change, with
#'   columns
#'   \describe{
#'     \item{`section`}{`"aggregate"` (Section 1 aggregation of taxa),
#'       `"group"` (Section 2 species group) or `"type"` (Section 3
#'       definition).}
#'     \item{`key`}{Aggregate name, group name or type code.}
#'     \item{`change`}{`"added"`, `"removed"` or `"changed"`.}
#'     \item{`what`}{For a changed aggregate or group, the members that were
#'       added (`+`) and removed (`-`); for a changed type, which of
#'       `priority`, `name` and `formula` changed.}
#'     \item{`from`, `to`}{For a type, the definition (priority, name and
#'       formula) in each system; `NA` where the type is absent. For an
#'       aggregate or group, the number of members.}
#'   }
#'   `print()` shows the number of changes per section; `summary()` lists
#'   the changed keys.
#' @seealso [resy_load_expert()], [resy_available_classifications()]
#' @examples
#' \donttest{
#' d <- resy_diff_expert("2020-06-08", "2021-06-01")
#' d
#' summary(d)
#' subset(d, section == "type" & change == "added")
#' }
#' @export
resy_diff_expert <- function(from, to, scheme = "EUNIS") {
  a <- .resy_as_parsed(from, scheme)
  b <- .resy_as_parsed(to, scheme)

  out <- rbind(
    .resy_diff_members("aggregate", .resy_member_sets(a$aggs), .resy_member_sets(b$aggs)),
    .resy_diff_members("group", .resy_member_sets(a$groups, strip = "^#+\\s*"),
                       .resy_member_sets(b$groups, strip = "^#+\\s*")),
    .resy_diff_types(.resy_type_table(a), .resy_type_table(b))
  )
  rownames(out) <- NULL
  structure(out, class = c("resy_expert_diff", "data.frame"),
            from = .resy_source_label(a), to = .resy_source_label(b))
}

#' @export
print.resy_expert_diff <- function(x, ...) {
  cat("Changes from ", attr(x, "from"), " to ", attr(x, "to"), ":\n", sep = "")
  if (!nrow(x)) {
    cat("  none\n")
    return(invisible(x))
  }
  print(.resy_diff_counts(x), row.names = FALSE)
  invisible(x)
}

#' @export
`[.resy_expert_diff` <- function(x, ...) {
  out <- NextMethod()
  if (!is.data.frame(out)) return(out)
  if (!all(c("section", "key", "change") %in% names(out)))
    return(structure(out, class = "data.frame"))
  attr(out, "from") <- attr(x, "from")
  attr(out, "to")   <- attr(x, "to")
  class(out) <- class(x)
  out
}

#' @export
summary.resy_expert_diff <- function(object, ...) {
  structure(list(counts = .resy_diff_counts(object),
                 keys = split(object$key, list(object$section, object$change), drop = TRUE),
                 from = attr(object, "from"), to = attr(object, "to")),
            class = "summary.resy_expert_diff")
}

#' @export
print.summary.resy_expert_diff <- function(x, max = 30L, ...) {
  cat("Changes from ", x$from, " to ", x$to, ":\n", sep = "")
  print(x$counts, row.names = FALSE)
  for (nm in names(x$keys)) {
    k <- x$keys[[nm]]
    cat("\n", sub("\\.", " ", nm), " (", length(k), "):\n", sep = "")
    shown <- utils::head(k, max)
    cat(strwrap(paste(shown, collapse = ", "), indent = 2, exdent = 2), sep = "\n")
    if (length(k) > max) cat("  ... and ", length(k) - max, " more\n", sep = "")
  }
  invisible(x)
}

# ---- helpers ----------------------------------------------------------------

# A parsed expert from a parsed object, a classification result, a file path or
# a version of `scheme`.
.resy_as_parsed <- function(x, scheme) {
  if (inherits(x, "resy_parsed_expert")) return(x)
  if (inherits(x, "resy_result")) return(x$parsed)
  if (!is.character(x) || length(x) != 1L || is.na(x))
    stop("Each expert system must be a resy_parsed_expert, a resy_result, a file path or a version string.",
         call. = FALSE)
  if (file.exists(x)) return(resy_load_expert(expertfile = x))
  resy_load_expert(scheme = scheme, version = x)
}

.resy_source_label <- function(p) {
  s <- p$source
  if (is.null(s)) return("expert system")
  if (!is.na(s$scheme) && !is.na(s$version)) paste0(s$scheme, " ", s$version, " (", s$file, ")")
  else s$file
}

# Named list of sorted unique member sets; a name declared twice is merged.
.resy_member_sets <- function(x, strip = NULL) {
  nm <- names(x)
  if (!is.null(strip)) nm <- sub(strip, "", nm)
  nm <- trimws(nm)
  lapply(split(unlist(x, use.names = FALSE), rep(nm, lengths(x))),
         function(m) sort(unique(trimws(m))))
}

.resy_diff_members <- function(section, a, b) {
  added   <- setdiff(names(b), names(a))
  removed <- setdiff(names(a), names(b))
  common  <- intersect(names(a), names(b))
  changed <- common[!vapply(common, function(k) identical(a[[k]], b[[k]]), logical(1))]
  what <- vapply(changed, function(k) {
    plus  <- setdiff(b[[k]], a[[k]])
    minus <- setdiff(a[[k]], b[[k]])
    paste(c(if (length(plus)) paste0("+", plus), if (length(minus)) paste0("-", minus)),
          collapse = "; ")
  }, character(1))
  n <- function(s, k) if (length(k)) as.character(lengths(s[k])) else character()
  data.frame(
    section = rep(section, length(added) + length(removed) + length(changed)),
    key     = c(sort(added), sort(removed), sort(changed)),
    change  = rep(c("added", "removed", "changed"),
                  c(length(added), length(removed), length(changed))),
    what    = c(rep(NA_character_, length(added) + length(removed)),
                unname(what[order(changed)])),
    from    = c(rep(NA_character_, length(added)), n(a, sort(removed)), n(a, sort(changed))),
    to      = c(n(b, sort(added)), rep(NA_character_, length(removed)), n(b, sort(changed))),
    stringsAsFactors = FALSE
  )
}

# One row per type: key (code, made unique when a code is declared twice),
# priority, name and formula with whitespace normalised.
.resy_type_table <- function(p) {
  code <- p$vegtype.formula.names.short
  name <- trimws(substring(p$vegtype.formula.names, nchar(code) + 1L))
  data.frame(
    key      = make.unique(code, sep = "#"),
    priority = as.character(p$vegtype.priority),
    name     = name,
    formula  = gsub("\\s+", " ", trimws(unname(p$vegtype.formulas))),
    stringsAsFactors = FALSE
  )
}

.resy_diff_types <- function(a, b) {
  added   <- setdiff(b$key, a$key)
  removed <- setdiff(a$key, b$key)
  m <- merge(a, b, by = "key", suffixes = c(".a", ".b"))
  fields <- c("priority", "name", "formula")
  diffs <- vapply(fields, function(f) m[[paste0(f, ".a")]] != m[[paste0(f, ".b")]],
                  logical(nrow(m)))
  if (!is.matrix(diffs)) diffs <- matrix(diffs, ncol = length(fields), dimnames = list(NULL, fields))
  ch <- m[rowSums(diffs) > 0, , drop = FALSE]
  what <- apply(diffs[rowSums(diffs) > 0, , drop = FALSE], 1L,
                function(r) paste(fields[r], collapse = ", "))
  def <- function(t, keys, sfx = "") {
    if (!length(keys)) return(character())
    i <- match(keys, t$key)
    paste0(t[[paste0("priority", sfx)]][i], " | ", t[[paste0("name", sfx)]][i], " | ",
           t[[paste0("formula", sfx)]][i])
  }
  data.frame(
    section = rep("type", length(added) + length(removed) + nrow(ch)),
    key     = c(added, removed, ch$key),
    change  = rep(c("added", "removed", "changed"), c(length(added), length(removed), nrow(ch))),
    what    = c(rep(NA_character_, length(added) + length(removed)), unname(what)),
    from    = c(rep(NA_character_, length(added)), def(a, removed), def(ch, ch$key, ".a")),
    to      = c(def(b, added), rep(NA_character_, length(removed)), def(ch, ch$key, ".b")),
    stringsAsFactors = FALSE
  )
}

.resy_diff_counts <- function(x) {
  sec <- factor(x$section, levels = c("aggregate", "group", "type"))
  chg <- factor(x$change, levels = c("added", "removed", "changed"))
  tab <- table(sec, chg)
  data.frame(section = rownames(tab), added = tab[, "added"], removed = tab[, "removed"],
             changed = tab[, "changed"], row.names = NULL, stringsAsFactors = FALSE)
}
