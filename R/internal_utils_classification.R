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