#' Add a new classification to the RESY store
#'
#' @description
#' Validates and copies an ESy expert file (`.txt`, `.json`, or either
#' xz-compressed) into the RESY classification store so that it becomes
#' available to [resy_load_expert()] and [resy_classify()].
#'
#' Without `file`, the published release `scheme`/`version` is downloaded
#' from the source listed in the RESY release registry (Zenodo for EUNIS-ESy),
#' checked against its SHA-256 checksum and stored. The registry is read from
#' the RESY repository on GitHub, so a release published after this version of
#' RESY can be added without updating the package. Downloading requires the
#' [getaca](https://CRAN.R-project.org/package=getaca) package.
#'
#' A file you supply is validated with [resy_validate_esy()] before anything
#' is written; a downloaded release is checked against its published checksum
#' instead.
#' If validation fails the function stops with a message that lists every error
#' found, so you can fix the file and try again. Pass `validate = FALSE` to skip
#' validation (not recommended).
#'
#' @param file Path to an ESy expert file (`.txt`, `.json`, `.txt.xz` or
#'   `.json.xz`), or `NULL` to download the published release
#'   `scheme`/`version`.
#' @param scheme Scheme name to store under (e.g. `"MyClassification"`).
#'   With `file = NULL`, the scheme of the published release (e.g. `"EUNIS"`).
#' @param version Version string to store under (e.g. `"2026-07-05"`). With
#'   `file = NULL`, the version of the published release; `NULL` takes the
#'   newest one.
#' @param location Where to store: `"user"` (default, recommended) or
#'   `"package"` (requires a writable library).
#' @param overwrite Logical; overwrite an existing classification. Defaults to
#'   `FALSE`.
#' @param validate Logical; run [resy_validate_esy()] on `file` before
#'   storing. Defaults to `TRUE`. Set to `FALSE` only if you are certain the
#'   file is valid. Not used for a downloaded release.
#'
#' @details
#' The file is stored as `<root>/<scheme>/<version>/expert.txt`,
#' `expert.txt.xz`, `expert.json` or `expert.json.xz`, where `<root>` is
#' `tools::R_user_dir("RESY", "data")` for `location = "user"`. A text file is
#' stored unchanged, together with a `metadata.json` sidecar recording the
#' scheme, version, source path and time of storage. Replacing a
#' classification with `overwrite = TRUE` removes the files of the previous
#' one, so a `.txt` never sits beside a stale `.json` that
#' [resy_load_expert()] would read first.
#'
#' @return Invisibly, a named list with the paths of the files written:
#'   \describe{
#'     \item{`txt`}{Path to the stored text file, or `NULL` for JSON input.}
#'     \item{`json`}{Path to the stored JSON file, or `NULL` for text input.}
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
#'
#' \dontrun{
#' # Download a published EUNIS-ESy release from Zenodo into the user store.
#' resy_add_classification(scheme = "EUNIS", version = "2025-10-03")
#' }
#' @export
resy_add_classification <- function(file      = NULL,
                                    scheme,
                                    version   = NULL,
                                    location  = c("user", "package"),
                                    overwrite = FALSE,
                                    validate  = TRUE) {
  location <- match.arg(location)

  if (!is.character(scheme) || length(scheme) != 1L || !nzchar(scheme))
    stop("`scheme` must be a non-empty string.", call. = FALSE)

  if (is.null(file)) {
    got      <- .resy_fetch_release(scheme, version)
    file     <- got$file
    version  <- got$version
    validate <- FALSE
  }

  if (!is.character(file) || length(file) != 1L || is.na(file))
    stop("`file` must be a single file path.", call. = FALSE)
  if (!file.exists(file))
    stop("File not found: ", file, call. = FALSE)

  is_json <- .resy_is_json(file)
  if (!is_json && !.resy_is_txt(file))
    stop("File must be a .txt, .json, .txt.xz or .json.xz expert file; got: ",
         basename(file), call. = FALSE)
  is_xz <- .resy_is_xz(file)

  if (!is.character(version) || length(version) != 1L || !nzchar(version))
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
    pkg_root <- .resy_classifications_root("package")
    if (file.access(pkg_root, 2L) != 0L)
      stop("The package classification directory is not writable. ",
           "Use location = 'user' instead.", call. = FALSE)
  }

  out_dir <- file.path(
    .resy_classifications_root(location, create = TRUE), scheme, version
  )
  if (!dir.exists(out_dir))
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  all_files <- file.path(out_dir, unlist(.resy_expert_files, use.names = FALSE))
  candidates <- .resy_expert_files[[if (is_json) "json" else "txt"]]
  out_file  <- file.path(out_dir, candidates[if (is_xz) 2L else 1L])
  out_meta  <- file.path(out_dir, "metadata.json")

  if (!overwrite && any(file.exists(all_files)))
    stop("Classification '", scheme, "/", version, "' already exists at:\n  ",
         out_dir, "\nSet overwrite = TRUE to replace it.", call. = FALSE)

  unlink(c(all_files, out_meta))

  ok <- file.copy(file, out_file, overwrite = TRUE)
  if (!isTRUE(ok)) stop("Failed to copy file to: ", out_file, call. = FALSE)

  if (is_json) return(invisible(list(txt = NULL, json = out_file)))

  metadata <- list(
    scheme      = scheme,
    version     = version,
    source_file = normalizePath(file, winslash = "/", mustWork = FALSE),
    created_utc = format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ")
  )
  jsonlite::write_json(metadata, out_meta, auto_unbox = TRUE, pretty = TRUE)
  invisible(list(txt = out_file, json = NULL))
}

# Download a published release through the RESY getaca registry
# (inst/getaca/registry.rds, built from classifications/releases.csv by
# data-raw/build_registry.R). The "current" policy consults the remote copy of
# the registry on GitHub, so releases published after this RESY version are
# found. getaca checks the SHA-256 checksum and caches the file. Returns the
# cached file and the resolved version.
.resy_fetch_release <- function(scheme, version = NULL) {
  if (!requireNamespace("getaca", quietly = TRUE))
    stop("Downloading a published release requires the getaca package: ",
         "install.packages(\"getaca\").", call. = FALSE)
  res <- getaca::resolve_resource(scheme, package = "RESY", policy = "current",
                                  version = version)
  v <- res$record$version
  message("Downloading ", scheme, " ", v, " (doi:", res$record$doi, ").")
  path <- getaca::getaca(scheme, package = "RESY", version = v,
                         policy = "current")
  list(file = path, version = v)
}
