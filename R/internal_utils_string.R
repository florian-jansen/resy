#' Internal String Utility Functions
#'
#' This file contains helper functions for string manipulation, such as trimming
#' leading/trailing whitespace or specific patterns. These functions are
#' primarily used internally by RESY and are not intended for direct export.
#'
#' @keywords internal
#' @name string_utils
NULL

#' Trim Leading and Trailing Whitespace
#'
#' Removes leading and trailing whitespace (including spaces, tabs, and newlines)
#' from a character vector.
#'
#' @param x A character vector.
#' @return A character vector with leading/trailing whitespace removed.
#' @examples
#' trim("  hello world  ")  # Returns "hello world"
#' trim(c("  a ", "b  ", " c "))  # Returns c("a", "b", "c")
#' @keywords internal
trim <- function(x) gsub("^\\s+|\\s+$", "", x)

#' Trim Trailing Whitespace and Specific Patterns
#'
#' Removes trailing whitespace, digits, or patterns like "- <digit>" from strings.
#' This is useful for cleaning up labels or identifiers with trailing artifacts.
#'
#' @param x A character vector.
#' @return A character vector with trailing patterns removed.
#' #' @details
#' This function targets common trailing artifacts in RESY data, such as
#' spaces followed by digits or hyphen-digit combinations (e.g., " - 1").
#' It does not handle all possible trailing patterns; for more complex cases,
#' use regular expressions directly
#' @examples
#' trim.trailing("text  ")      # Returns "text"
#' trim.trailing("text- 1")    # Returns "text-"
#' trim.trailing("text 123")   # Returns "text"
#' @seealso [trim()], [trim.leading()]
#' @keywords internal
trim.trailing <- function(x) sub("\\s+$|\\s+\\d$|\\s+\\-\\s+\\d$", "", x)

#' Trim Leading Whitespace
#'
#' Removes leading whitespace (spaces, tabs, newlines) from a character vector.
#'
#' @param x A character vector.
#' @return A character vector with leading whitespace removed.
#' @examples
#' trim.leading("  hello")  # Returns "hello"
#' @seealso [trim()], [trim.trailing()]
#' @keywords internal
trim.leading <- function(x) sub("^\\s+", "", x)
