#' Resolve Multiple Classification Results to a Single Choice
#'
#' @description
#' Selects a single vegetation type classification when multiple expert system
#' rules have been triggered. Uses a priority-based resolution strategy to
#' determine the most appropriate classification outcome.
#'
#' @details
#' This function implements a conflict resolution mechanism for cases where a
#' vegetation plot satisfies the criteria of multiple classification rules
#' simultaneously. The resolution strategy prioritizes classifications according
#' to a predefined priority hierarchy:
#'
#' - If no classifications match: returns `"?"`
#' - If exactly one classification matches: returns that classification
#' - If multiple match: selects the one with the highest priority (lowest
#'   priority level in the hierarchy)
#' - If multiple classifications share the highest priority: returns `"+"` to
#'   indicate ambiguity
#'
#' The priority hierarchy is examined from highest to lowest level, selecting
#' the first (highest-priority) classification that appears uniquely at its
#' level. This ensures deterministic, consistent classification outcomes.
#'
#' @param type_short_names character vector of matched classification short names
#'   (e.g., vegetation type abbreviations) from triggered expert system rules.
#'
#' @param vegtype.priority factor with ordered priority levels defining the
#'   hierarchy for resolving classification conflicts. Lower priority levels
#'   (earlier in the factor levels) take precedence.
#'
#' @param vegtype.formula.names.short character vector of all known vegetation
#'   type short names in the expert system, in the same order as the priority
#'   values in `vegtype.priority`.
#'
#' @return character scalar representing the chosen classification:
#'   - A vegetation type short name if a single highest-priority match is found
#'   - `"?"` if no classifications are provided
#'   - `"+"` if multiple classifications share the highest priority level
#'
#' @keywords internal
#'
#' @examples
#' # No matches
#' .resy_classify_choice(character(), c(1, 2, 3), c("T1", "T2", "T3"))
#'
#' # Single match
#' .resy_classify_choice("T1", c(1, 2, 3), c("T1", "T2", "T3"))
#'
#' # Multiple matches with clear priority
#' .resy_classify_choice(
#'   c("T2", "T3"),
#'   factor(c(1, 2, 3), levels = c(1, 2, 3)),
#'   c("T1", "T2", "T3")
#' )
#'
#' # Multiple matches with conflicting priorities
#' .resy_classify_choice(
#'   c("T1", "T2"),
#'   factor(c(1, 1, 3), levels = c(1, 3)),
#'   c("T1", "T2", "T3")
#' )
#'
#' @keywords internal
.resy_classify_choice <- function(
    type_short_names, vegtype.priority, vegtype.formula.names.short
) {
  
  if (length(type_short_names) == 0) return("?")
  if (length(type_short_names) == 1) return(type_short_names)
  
  p <- vegtype.priority[fastmatch::fmatch(
    type_short_names, vegtype.formula.names.short
  )]
  # If multiple, pick the unique highest-priority one; else '+'
  for (lev in rev(levels(p))) {
    
    if (sum(p == lev, na.rm = TRUE) == 1) return(type_short_names[p == lev][1])
    
  }
  
  return("+")
  
}
