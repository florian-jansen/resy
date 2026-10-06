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
#' @keywords internal
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
.resy_section_rows <- function(lines, n) {
  which(grepl(paste0("^\\s*SECTION\\s+", n, "\\b"), lines, ignore.case = TRUE, perl = TRUE))
}
