# ---- JSON expert-system schema ----------------------------------------------
# Shared by the JSON parser (.resy_parse_json) and the JSON validator.

.resy_json_required  <- c("synonyms", "groups", "rules")
.resy_json_rule_keys <- c("priority", "code", "description", "expression")

# Required keys a rule lacks. Keys starting with "_" (e.g. "_comment") are
# comments and never count as data.
.resy_json_missing_rule_keys <- function(rule) {
  setdiff(.resy_json_rule_keys, names(rule)[!startsWith(names(rule), "_")])
}

# The Section 3 header line of a rule, as in a .txt expert file: priority, 10
# spaces, the code padded to 5 characters, a space, the description.
.resy_rule_header <- function(priority, code, description) {
  sprintf("%s%10s%-5s %s", as.character(priority), "", as.character(code),
          as.character(description))
}

# A JSON object of arrays as a named list of character vectors.
.resy_json_chr_list <- function(x) {
  lapply(x, function(v) {
    if (is.null(v) || length(v) == 0L) character(0L)
    else as.character(unlist(v, use.names = FALSE))
  })
}

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
#'     solver prefix such as `"### "`, `"##D "`...) to an array of canonical
#'     member species.}
#'   \item{`rules`}{Array of objects, each with `priority` (character 0-9 or
#'     letter), `code` (string), `description` (string), and `expression`
#'     (string using the formula syntax, e.g.
#'     `"<#TC Beech-forest-trees GR 15>"`). Keys starting with `_`
#'     (e.g. `"_comment"`) are silently ignored.}
#' }
#'
#' @param path Path to a `.json` expert-system file.
#' @return A list of class `resy_parsed_expert`, identical in structure to the
#'   output of [resy_load_expert()].
#' @noRd
.resy_parse_json <- function(path) {
  if (!file.exists(path))
    stop("File not found: ", path)

  x <- jsonlite::read_json(path, simplifyVector = FALSE)

  missing <- setdiff(.resy_json_required, names(x))
  if (length(missing))
    stop("JSON expert file is missing required keys: ",
         paste(missing, collapse = ", "))

  # synonyms -> aggs: canonical name -> character vector of aliases
  if (!is.list(x$synonyms))
    stop("'synonyms' must be a JSON object (key: array pairs).")
  aggs <- .resy_json_chr_list(x$synonyms)

  # groups -> solver groups; keys already carry the solver prefix (e.g. "### ")
  if (!is.list(x$groups))
    stop("'groups' must be a JSON object (key: array pairs).")
  groups <- .resy_json_chr_list(x$groups)

  # rules -> named formula strings; keys starting with "_" are ignored
  rules <- x$rules
  if (!is.list(rules) || length(rules) == 0L)
    stop("'rules' must be a non-empty JSON array of rule objects.")

  for (i in seq_along(rules)) {
    missing_keys <- .resy_json_missing_rule_keys(rules[[i]])
    if (length(missing_keys))
      stop("Rule ", i, " is missing required keys: ",
           paste(missing_keys, collapse = ", "))
  }

  membership.formula.names <- .resy_rule_header(
    vapply(rules, function(r) as.character(r[["priority"]]), character(1L)),
    vapply(rules, `[[`, character(1L), "code"),
    vapply(rules, `[[`, character(1L), "description")
  )
  membership.formulas <- as.character(vapply(rules, `[[`, character(1L), "expression"))

  raw <- .resy_transform_formulas(aggs, groups, membership.formulas, membership.formula.names)
  .resy_build_parsed(raw)
}
