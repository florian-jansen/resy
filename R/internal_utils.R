# Whitespace trimming. .resy_trim_trailing also drops a trailing aggregation
# code ("  0", "  -  0") from a Section 1 line.
.resy_trim_trailing <- function(x) sub("\\s+$|\\s+\\d$|\\s+\\-\\s+\\d$", "", x)
.resy_trim_leading <- function(x) sub("^\\s+", "", x)
.resy_trim <- function(x) gsub("^\\s+|\\s+$", "", x)

# Prefixes that open a Section 2 group: species groups (###), differential
# groups (##D, ##Q, ##C) and header variables (categorical $$C, numeric $$N).
.resy_group_prefixes <- c("###", "##D", "##Q", "##C", "$$C", "$$N")

# Group name of a Section 2 group key: the text after the prefix and its space.
.resy_group_name <- function(key) substr(key, 5, nchar(key))

# Line numbers of the "SECTION <n>" markers (opener and "SECTION <n>: End").
.resy_section_rows <- function(lines, n) {
  which(grepl(paste0("^\\s*SECTION\\s+", n, "\\b"), lines, ignore.case = TRUE, perl = TRUE))
}

#' @keywords internal
.total_cover <- function(x) round((1 - prod(1 - x/100)) * 100, 10)

#' @keywords internal
.resy_mclapply <- function(X, FUN, ..., mc = 1L, mc.cores = NULL) {
  if (!is.null(mc.cores)) mc <- mc.cores

  mc <- as.integer(mc %||% 1L)
  if (mc <= 1L) return(lapply(X, FUN, ...))
  # parallel::mclapply is not available on Windows
  if (.Platform$OS.type == "windows") return(lapply(X, FUN, ...))
  parallel::mclapply(X, FUN, ..., mc.cores = mc)
}

#' @keywords internal
.resy_mcmapply <- function(FUN, ..., mc = 1L, mc.cores = NULL, SIMPLIFY = TRUE, USE.NAMES = TRUE) {
  if (!is.null(mc.cores)) mc <- mc.cores
  mc <- as.integer(mc %||% 1L)
  if (mc <= 1L || .Platform$OS.type == "windows") {
    return(mapply(FUN, ..., SIMPLIFY = SIMPLIFY, USE.NAMES = USE.NAMES))
  }
  parallel::mcmapply(FUN, ..., mc.cores = mc, SIMPLIFY = SIMPLIFY, USE.NAMES = USE.NAMES)
}

`%||%` <- function(a, b) if (!is.null(a)) a else b

#' @keywords internal
.resy_classify_choice <- function(type_short_names, vegtype.priority, vegtype.formula.names.short) {
  if (length(type_short_names) == 0) return("?")
  if (length(type_short_names) == 1) return(type_short_names)

  p <- vegtype.priority[fastmatch::fmatch(type_short_names, vegtype.formula.names.short)]
  # If multiple, pick the unique highest-priority one; else '+'
  for (lev in rev(levels(p))) {
    if (sum(p == lev, na.rm = TRUE) == 1) return(type_short_names[p == lev][1])
  }
  return("+")
}

.resy_guess_id_col <- function(obs, header) {
  candidates <- c("PlotObservationID", "PlotID")
  for (nm in candidates) {
    if (nm %in% names(obs) && nm %in% names(header)) return(nm)
  }
  return(NULL)
}

# Standardize plot id to PlotObservationID internally.
# Returns list(obs=..., header=..., id_col_used=...)
.resy_standardize_plot_id <- function(obs, header, id_col = NULL) {
  if (!is.null(id_col)) {
    if (!(id_col %in% names(obs))) stop("id_col '", id_col, "' not found in obs.")
    if (!(id_col %in% names(header))) stop("id_col '", id_col, "' not found in header.")
    id_used <- id_col
  } else {
    id_used <- .resy_guess_id_col(obs, header)
    if (is.null(id_used)) {
      stop(
        "No plot id column found in both obs and header. ",
        "Please provide id_col, or include one of: PlotObservationID, PlotID."
      )
    }
  }
  # Create/overwrite PlotObservationID used by internal logic
  obs[, PlotObservationID := as.character(get(id_used))]
  header$PlotObservationID <- as.character(header[[id_used]])
  list(obs = obs, header = header, id_col_used = id_used)
}
