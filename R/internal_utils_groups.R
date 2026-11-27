#' Internal Group Parsing Utilities
#'
#' @description
#' Provides helper constants and functions for identifying section-2 group
#' markers used in RESY expert-system definitions. This file centralizes the
#' prefixes and parsing rules for species groups, differential groups, and
#' header variables.
#'
#' @details
#' RESY expert-system definitions use structured Section 2 group labels with
#' prefixes such as `###`, `##D`, `##Q`, `##C`, `$$C`, and `$$N`. These helpers
#' make it easier to:
#'
#' - recognize valid group markers,
#' - extract the group name from a prefixed key,
#' - locate the line numbers of `SECTION <n>` markers in parsed text.
#'
#' @keywords internal
#' @name group_utils
NULL
#'
#' Recognized Section 2 Group Prefixes
#'
#' Character vector containing the valid prefixes that open Section 2 groups,
#' including species groups, differential groups, and header variables.
#'
#' @return A character vector of recognized Section 2 group prefixes.
#' @keywords internal
#' @noRd
.resy_group_prefixes <- c("###", "##D", "##Q", "##C", "$$C", "$$N")
#'
#' Extract the Group Name from a Section 2 Key
#'
#' @description
#' Removes the prefix and the following space from a Section 2 group key and
#' returns the remaining group name.
#'
#' @param key character scalar representing a group key such as `"### Forest"` or
#'   `"##D Wet meadow"`.
#'
#' @return character scalar with the group name only.
#'
#' @keywords internal
#' @noRd
.resy_group_name <- function(key) substr(key, 5, nchar(key))
#'
#' Locate the Rows of Section Markers
#'
#' @description
#' Finds the line numbers in a character vector that match the `SECTION <n>`
#' opener or closing marker.
#'
#' @param lines character vector containing the lines of a parsed expert-system
#'   document.
#'
#' @param n integer section number to search for, e.g. `2` for `SECTION 2`.
#'
#' @return integer vector of matching line numbers.
#'
#' @keywords internal
#' @noRd
.resy_section_rows <- function(lines, n) {
  which(grepl(paste0("^\\s*SECTION\\s+", n, "\\b"), lines, ignore.case = TRUE, perl = TRUE))
}
#'
#' Groups Named in Groups
#'
#' @description
#' A member of a Section 2 group may be another group, written with its prefix
#' (`"### Wet-meadows"`), so that a group is built from other groups (a group
#' of site indicators from several species groups). `.resy_expand_group_refs()`
#' replaces each such member by the species of the group it names, recursively;
#' `.resy_group_ref_problems()`
#' names references to undefined groups and groups that contain themselves.
#'
#' @param groups Named list of Section 2 groups (keys with prefix) and their
#'   members.
#' @return The groups with species only, or a character vector of problems.
#' @keywords internal
#' @noRd
.resy_group_ref_prefixes <- c("###", "##D", "##Q", "##C")
.resy_is_group_ref <- function(x)
  substr(x, 1L, 3L) %in% .resy_group_ref_prefixes & substr(x, 4L, 4L) == " "
.resy_group_key <- function(x) gsub("\\s+", " ", trimws(x))

.resy_group_ref_problems <- function(groups) {
  keys <- .resy_group_key(names(groups))
  refs <- lapply(groups, function(m) .resy_group_key(m[.resy_is_group_ref(m)]))
  names(refs) <- keys
  problems <- character()
  for (k in keys) for (r in setdiff(refs[[k]], keys))
    problems <- c(problems, sprintf('Group "%s" names group "%s", which is not defined', k, r))
  # A group that reaches itself through its references.
  reach <- function(k, seen) {
    for (r in intersect(refs[[k]], keys)) {
      if (r %in% seen) return(TRUE)
      if (reach(r, c(seen, r))) return(TRUE)
    }
    FALSE
  }
  for (k in keys[lengths(refs[keys]) > 0L]) if (reach(k, k))
    problems <- c(problems, sprintf('Group "%s" contains itself through the groups it names', k))
  problems
}

.resy_expand_group_refs <- function(groups) {
  is_ref <- lapply(groups, .resy_is_group_ref)
  if (!any(unlist(is_ref, use.names = FALSE))) return(groups)
  problems <- .resy_group_ref_problems(groups)
  if (length(problems)) stop(paste(problems, collapse = "; "), call. = FALSE)
  keys <- .resy_group_key(names(groups))
  done <- list()
  expand <- function(i) {
    if (!is.null(done[[keys[i]]])) return(done[[keys[i]]])
    m <- groups[[i]]
    r <- is_ref[[i]]
    out <- unique(c(m[!r], unlist(lapply(match(.resy_group_key(m[r]), keys), expand),
                                 use.names = FALSE)))
    done[[keys[i]]] <<- out
    out
  }
  out <- lapply(seq_along(groups), expand)
  names(out) <- names(groups)
  out
}
