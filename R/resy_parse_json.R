#' Parse a structured JSON expert-system file
#'
#' @description
#' Reads a structured JSON expert-system definition file into the internal
#' `resy_parsed_expert` format consumed by [resy_classify()].
#'
#' The JSON file must have the following top-level keys:
#' \describe{
#'   \item{`metadata`}{Object with `scheme` and `version` (both strings).
#'     Optional: `description`, `source_file`.}
#'   \item{`synonyms`}{Object mapping each canonical name (key) to an array of
#'     accepted spelling variants / author-cited synonyms (value). An empty
#'     array means the canonical name has no known aliases.}
#'   \item{`groups`}{Object mapping each species-group name (key, including its
#'     solver prefix such as `"### "`, `"##D "`…) to an array of canonical
#'     member species.}
#'   \item{`rules`}{Array of objects, each with `priority` (character 0–9 or
#'     letter), `code` (string), `description` (string), and `expression`
#'     (string using the formula syntax, e.g.
#'     `"<#TC Beech-forest-trees GR 15>"`). Keys starting with `_`
#'     (e.g. `"_comment"`) are silently ignored.}
#' }
#'
#' @param path Path to a `.json` expert-system file.
#' @return A list of class `resy_parsed_expert`, identical in structure to the
#'   output of [resy_load_expert()].
#' @seealso [resy_load_expert()]
#' @keywords internal
resy_parse_json <- function(path) {
  if (!requireNamespace("jsonlite", quietly = TRUE))
    stop("Package 'jsonlite' is required to read JSON expert files.")
  if (!file.exists(path))
    stop("File not found: ", path)

  x <- jsonlite::read_json(path, simplifyVector = FALSE)

  required <- c("synonyms", "groups", "rules")
  missing  <- setdiff(required, names(x))
  if (length(missing))
    stop("JSON expert file is missing required keys: ",
         paste(missing, collapse = ", "))

  # synonyms → aggs: canonical name → character vector of aliases
  if (!is.list(x$synonyms))
    stop("'synonyms' must be a JSON object (key: array pairs).")
  aggs <- lapply(x$synonyms, function(v) {
    if (is.null(v) || length(v) == 0L) character(0L)
    else as.character(unlist(v, use.names = FALSE))
  })

  # groups → solver groups; keys already carry the solver prefix (e.g. "### ")
  if (!is.list(x$groups))
    stop("'groups' must be a JSON object (key: array pairs).")
  groups <- lapply(x$groups, function(v) {
    if (is.null(v) || length(v) == 0L) character(0L)
    else as.character(unlist(v, use.names = FALSE))
  })

  # rules → named formula strings; keys starting with "_" are ignored
  rules <- x$rules
  if (!is.list(rules) || length(rules) == 0L)
    stop("'rules' must be a non-empty JSON array of rule objects.")

  required_rule_keys <- c("priority", "code", "description", "expression")
  for (i in seq_along(rules)) {
    data_keys    <- names(rules[[i]])[!startsWith(names(rules[[i]]), "_")]
    missing_keys <- setdiff(required_rule_keys, data_keys)
    if (length(missing_keys))
      stop("Rule ", i, " is missing required keys: ",
           paste(missing_keys, collapse = ", "))
  }

  # Formula name format expected by the solver:
  #   char 1     : priority digit/letter
  #   chars 2-11 : 10 spaces (padding)
  #   chars 12-16: code (left-justified, space-padded to exactly 5 chars)
  #   chars 17+  : full name / description
  # The code is always padded to 5 characters so that column-position extraction
  # in .resy_build_parsed() works correctly regardless of the actual code length.
  membership.formula.names <- sprintf(
    "%s%10s%-5s %s",
    as.character(vapply(rules, function(r) as.character(r[["priority"]]), character(1L))),
    "",
    as.character(vapply(rules, `[[`, character(1L), "code")),
    as.character(vapply(rules, `[[`, character(1L), "description"))
  )
  membership.formulas <- as.character(vapply(rules, `[[`, character(1L), "expression"))

  raw <- .resy_transform_formulas(aggs, groups, membership.formulas, membership.formula.names)
  .resy_build_parsed(raw)
}
