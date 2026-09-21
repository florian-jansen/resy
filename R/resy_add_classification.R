#' Add a new classification to the RESY store
#'
#' @description
#' Validates and copies an ESy expert file (`.txt` or `.json`) into the RESY
#' classification store so that it becomes available to [resy_load_expert()] and
#' [resy_classify()].
#'
#' The file is validated with [resy_validate_esy()] before anything is written.
#' If validation fails the function stops with a message that lists every error
#' found, so you can fix the file and try again. Pass `validate = FALSE` to skip
#' validation (not recommended).
#'
#' @param file Path to an ESy expert file (`.txt` or `.json`).
#' @param scheme Scheme name to store under (e.g. `"MyClassification"`).
#' @param version Version string to store under (e.g. `"2026-07-05"`).
#' @param location Where to store: `"user"` (default, recommended) or
#'   `"package"` (requires a writable library).
#' @param overwrite Logical; overwrite an existing classification. Defaults to
#'   `FALSE`.
#' @param validate Logical; run [resy_validate_esy()] before storing. Defaults
#'   to `TRUE`. Set to `FALSE` only if you are certain the file is valid.
#'
#' @details
#' The file is stored as `<root>/<scheme>/<version>/expert.txt` or
#' `expert.json`, where `<root>` is `tools::R_user_dir("RESY", "data")` for
#' `location = "user"`. A `.txt` file is stored unchanged, together with a
#' `metadata.json` sidecar recording the scheme, version, source path and
#' time of storage. Replacing a classification with `overwrite = TRUE` removes
#' the files of the previous one, so a `.txt` never sits beside a stale
#' `.json` that [resy_load_expert()] would read first.
#'
#' @return Invisibly, a named list with the paths of the files written:
#'   \describe{
#'     \item{`txt`}{Path to the stored `.txt` file, or `NULL` for JSON input.}
#'     \item{`json`}{Path to the stored `.json` file, or `NULL` for `.txt`
#'       input.}
#'   }
#' @seealso [resy_validate_esy()], [resy_load_expert()],
#'   [resy_available_classifications()]
#' @examples
#' # Store the bundled Apennine-test system under a new name. The store is
#' # redirected to a temporary directory here; by default it lives in
#' # tools::R_user_dir("RESY", "data").
#' old <- Sys.getenv("R_USER_DATA_DIR")
#' Sys.setenv(R_USER_DATA_DIR = tempfile("resy_store"))
#'
#' src   <- resy_expert_path("Apennine-test", "2026-06-27")
#' paths <- resy_add_classification(src, scheme = "MyApennine",
#'                                  version = "2026-09-21")
#' basename(paths$json)
#'
#' # The stored system is now found by scheme and version.
#' parsed <- resy_load_expert(scheme = "MyApennine", version = "2026-09-21")
#' parsed$vegtype.formula.names.short
#'
#' Sys.setenv(R_USER_DATA_DIR = old)
#' @export
resy_add_classification <- function(file,
                                    scheme,
                                    version,
                                    location  = c("user", "package"),
                                    overwrite = FALSE,
                                    validate  = TRUE) {
  location <- match.arg(location)

  if (!is.character(file) || length(file) != 1L || is.na(file))
    stop("`file` must be a single file path.", call. = FALSE)
  if (!file.exists(file))
    stop("File not found: ", file, call. = FALSE)

  ext <- tolower(tools::file_ext(file))
  if (!ext %in% c("txt", "json"))
    stop("File must be a .txt or .json expert file; got extension: .", ext,
         call. = FALSE)

  if (!is.character(scheme)  || !nzchar(scheme))
    stop("`scheme` must be a non-empty string.", call. = FALSE)
  if (!is.character(version) || !nzchar(version))
    stop("`version` must be a non-empty string.", call. = FALSE)

  # --- Validate ---------------------------------------------------------------
  if (isTRUE(validate)) {
    result <- resy_validate_esy(file, strict = FALSE, verbose = FALSE)
    if (!result$ok) {
      stop(
        "Validation failed for '", basename(file), "' \u2014 ",
        length(result$errors), " error(s) found:\n",
        paste0("  \u2022 ", result$errors, collapse = "\n"),
        if (length(result$warnings))
          paste0("\nWarnings:\n", paste0("  \u2022 ", result$warnings, collapse = "\n"))
        else "",
        "\nFix the error(s) above and try again, or pass validate = FALSE to skip.",
        call. = FALSE
      )
    }
    if (length(result$warnings)) {
      message("Validation warnings for '", basename(file), "':\n",
              paste0("  \u2022 ", result$warnings, collapse = "\n"))
    }
  }

  # --- Resolve output location ------------------------------------------------
  if (location == "package") {
    pkg_root <- resy_classifications_root("package")
    if (file.access(pkg_root, 2L) != 0L)
      stop("The package classification directory is not writable. ",
           "Use location = 'user' instead.", call. = FALSE)
  }

  out_dir <- file.path(
    resy_classifications_root(location, create = TRUE), scheme, version
  )
  if (!dir.exists(out_dir))
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  out_txt  <- file.path(out_dir, "expert.txt")
  out_json <- file.path(out_dir, "expert.json")
  out_meta <- file.path(out_dir, "metadata.json")

  if (!overwrite && (file.exists(out_txt) || file.exists(out_json)))
    stop("Classification '", scheme, "/", version, "' already exists at:\n  ",
         out_dir, "\nSet overwrite = TRUE to replace it.", call. = FALSE)

  unlink(c(out_txt, out_json, out_meta))

  if (ext == "txt") {
    ok <- file.copy(file, out_txt, overwrite = TRUE)
    if (!isTRUE(ok)) stop("Failed to copy file to: ", out_txt, call. = FALSE)

    metadata <- list(
      scheme      = scheme,
      version     = version,
      source_file = normalizePath(file, winslash = "/", mustWork = FALSE),
      created_utc = format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ")
    )
    jsonlite::write_json(metadata, out_meta, auto_unbox = TRUE, pretty = TRUE)
    return(invisible(list(txt = out_txt, json = NULL)))
  }

  ok <- file.copy(file, out_json, overwrite = TRUE)
  if (!isTRUE(ok)) stop("Failed to copy file to: ", out_json, call. = FALSE)
  invisible(list(txt = NULL, json = out_json))
}
