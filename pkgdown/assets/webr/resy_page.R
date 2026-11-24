# R functions behind the RESY App. The page streams the data files and hands
# them over in batches of whole plots, as tab-separated files with fixed column
# names; these functions classify each batch and return JSON.

suppressPackageStartupMessages({
  library(RESY)
})

.page <- new.env()

.page_json <- function(x, ...) jsonlite::toJSON(x, auto_unbox = TRUE, na = "null", dataframe = "rows", ...)

# Code and name of every type in a parsed expert system, from the Section 3
# header lines ("FB    Beech-fir montane forest"). A code with several rules has
# one description per rule ("... trees 1", "... trees 2"); the type's name is
# the words they share.
.page_type_names <- function(parsed) {
  code <- parsed$vegtype.formula.names.short
  name <- trimws(sub("^\\S+", "", trimws(parsed$vegtype.formula.names)))
  by_code <- split(name, factor(code, levels = unique(code)))
  data.frame(code = names(by_code),
             name = vapply(by_code, .page_shared_words, character(1)),
             stringsAsFactors = FALSE, row.names = NULL)
}

.page_shared_words <- function(x) {
  words <- strsplit(x, " ", fixed = TRUE)
  first <- words[[1]]
  k <- 0L
  while (k < min(lengths(words)) &&
         all(vapply(words, function(w) w[k + 1L] == first[k + 1L], logical(1)))) k <- k + 1L
  if (k == 0L) x[1] else paste(first[seq_len(k)], collapse = " ")
}

# Header columns the expert system reads through $$C and $$N conditions.
.page_header_cols <- function(parsed, kinds = c("$$C", "$$N")) {
  conds <- parsed$conditions[substr(parsed$conditions, 1L, 3L) %in% kinds]
  sort(unique(trimws(substring(conds, 4L))))
}

# Header columns that resy_harmonize_eunis() derives from the plot position.
# A system reading any of them gets the EUNIS-ESy site step before classifying.
.page_eunis_site_cols <- c("Coast_EEA", "Dunes_Bohn", "Ecoreg", "Ecoreg_name",
                           "Country_ID", "DEG_LON", "DEG_LAT")

# Selects the expert system later runs use: a scheme shipped with the package
# ("EUNIS", "Apennine-test") in a given version (NULL: the newest), or an
# uploaded .json/.txt file. Returns a summary of the system, the release it
# rests on and the names of its types.
resy_page_set_expert <- function(scheme = "EUNIS", version = NULL, path = NULL) {
  t0 <- Sys.time()
  # A system read before in this session is kept, so choosing it again does not
  # parse its file again. A file is known by its content.
  key <- if (is.null(path)) paste(scheme, version %||% "", sep = ":") else
    paste("file", unname(tools::md5sum(path)), sep = ":")
  kept <- .page$read[[key]]
  if (is.null(kept)) {
    parsed <- if (is.null(path)) resy_load_expert(scheme = scheme, version = version) else tryCatch(
      resy_load_expert(expertfile = path),
      error = function(e) stop("RESY could not read ", basename(path), " as an expert system (",
                               conditionMessage(e), ").", call. = FALSE)
    )
    kept <- list(parsed = parsed, provenance = resy_provenance(parsed))
    .page$read[[key]] <- kept
  }
  parsed <- kept$parsed
  prov <- kept$provenance
  sys <- .page_use_system(parsed, if (is.null(path)) scheme else basename(path))
  .page_json(list(
    scheme = sys$scheme,
    release_scheme = prov$scheme,
    version = prov$version,
    doi = prov$release_doi,
    identical_to_release = prov$identical_to_release,
    eunis = sys$eunis,
    n_types = length(unique(parsed$vegtype.formula.names.short)),
    n_species = length(parsed$aggs),
    header_cols = I(sys$header_cols),
    derived_cols = I(sys$derived_cols),
    names = sys$names,
    levels = if (sys$eunis) sys$names[nchar(sys$names$code) == 1L, ] else sys$names,
    seconds = round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 2)
  ))
}

# Makes a parsed expert system the one later runs use, and returns it with the
# header columns it reads, those RESY derives from the plot position, and the
# names of its types.
.page_use_system <- function(parsed, scheme) {
  .page_use_taxonomy(parsed)
  header_cols <- .page_header_cols(parsed)
  eunis <- any(header_cols %in% .page_eunis_site_cols)
  names <- .page_type_names(parsed)
  # A type keeps the name its expert system gives it; the EUNIS names table
  # names the habitat groups the system does not define as types.
  if (eunis) {
    eunis_names <- resy_eunis_names()[c("code", "name")]
    names <- rbind(names, eunis_names[!eunis_names$code %in% names$code, ])
  }
  .page$system <- list(
    scheme = scheme,
    parsed = parsed,
    eunis = eunis,
    names = names,
    header_cols = header_cols,
    derived_cols = if (eunis) intersect(header_cols, .page_eunis_site_cols) else character()
  )
  .page$system
}

# Rule edits can change species named directly in conditions or groups. Only
# those names lose their matches while the aggregation table stays identical.
.page_use_taxonomy <- function(parsed) {
  old <- .page$system$parsed
  if (!identical(old$aggs, parsed$aggs)) {
    .page$taxa <- character()
  } else if (length(.page$taxa)) {
    before <- RESY:::.resy_expert_used(old)
    after <- RESY:::.resy_expert_used(parsed)
    changed <- union(setdiff(before, after), setdiff(after, before))
    if (length(changed)) {
      raw <- names(.page$taxa)
      .page$taxa <- .page$taxa[!resy_clean_names(raw) %in% changed]
    }
  }
}

# Species names as the expert system knows them. A name the system lists as
# written (a species or one of its synonyms, author included) is taken as it
# is; only the other names are cleaned and checked again. Each distinct name is
# checked once per expert system; later batches reuse the result.
.page_taxa <- function(raw) {
  new <- setdiff(unique(raw), names(.page$taxa))
  if (length(new)) {
    known <- .page_check_taxa(new)
    open <- is.na(known)
    if (any(open)) known[open] <- .page_check_taxa(resy_clean_names(new[open]))
    .page$taxa <- c(.page$taxa, stats::setNames(known, new))
  }
  unname(.page$taxa[raw])
}
.page_check_taxa <- function(names) {
  checked <- as.data.frame(resy_check_taxonomy(data.frame(scientificName = unique(names)),
                                               .page$system$parsed, col = "scientificName"))
  checked$TaxonName[match(names, checked$scientificName)]
}

# Numbers written with a decimal point or a decimal comma ("60.5", "60,5"), as
# covers and coordinates come; anything else is NA. Same rule as fieldNumber()
# in resy_files.js.
.page_number <- function(x) {
  x <- trimws(x)
  comma <- grepl("^[-+]?[0-9]*,[0-9]+$", x)
  x[comma] <- sub(",", ".", x[comma], fixed = TRUE)
  suppressWarnings(as.numeric(x))
}

.page_read <- function(path) {
  data.table::fread(path, sep = "\t", quote = "", colClasses = "character",
                    na.strings = "", encoding = "UTF-8", data.table = FALSE)
}

.page_read_batch <- function(path) {
  data <- .page_read(path)
  data$PlotObservationID <- utils::URLdecode(data$PlotObservationID)
  data
}

# Sites as the header table for the classifier. For a system that reads the
# EUNIS-ESy site columns this adds ecoregion, country, and optionally coast and
# dune flags from the plot position. Plots without a position get these columns
# as missing values, whichever other plots share their batch.
.page_site_input <- function(si) {
  for (col in setdiff(names(si), c("PlotObservationID", "Country"))) {
    si[[col]] <- utils::type.convert(si[[col]], as.is = TRUE)
  }
  si
}

# Cached rows are selected by plot ID and used only when every input column
# and option agrees with the inputs used to derive those rows.
.page_cached_sites <- function(si, coast_dunes, coast_buffer) {
  if (is.null(.page$example_sites)) {
    path <- system.file("extdata", "example-sites.rds", package = "RESY")
    if (!nzchar(path)) return(NULL)
    .page$example_sites <- readRDS(path)
  }
  cached <- .page$example_sites
  if (!identical(coast_dunes, cached$coast_dunes) ||
      !identical(as.numeric(coast_buffer), as.numeric(cached$coast_buffer)) ||
      nrow(si) != nrow(cached$input) ||
      !setequal(names(si), names(cached$input)) || anyDuplicated(si$PlotObservationID)) return(NULL)
  at <- match(si$PlotObservationID, cached$input$PlotObservationID)
  if (anyNA(at)) return(NULL)
  same <- vapply(names(si), function(col) identical(si[[col]], cached$input[[col]][at]), logical(1))
  if (!all(same)) return(NULL)
  rows <- match(cached$sites$PlotObservationID, si$PlotObservationID)
  selected <- which(!is.na(rows))
  selected <- selected[order(rows[selected])]
  list(sites = cached$sites[selected, , drop = FALSE], warnings = cached$warnings)
}

resy_page_sites_cached <- function(path, coast_dunes = TRUE, coast_buffer = 5000) {
  .page_check_buffer(coast_dunes, coast_buffer)
  !.page$system$eunis || !is.null(.page_cached_sites(.page_site_input(.page_read_batch(path)), coast_dunes, coast_buffer))
}

.page_check_buffer <- function(coast_dunes, coast_buffer) {
  if (.page$system$eunis && isTRUE(coast_dunes) &&
      (!is.numeric(coast_buffer) || length(coast_buffer) != 1L ||
       !is.finite(coast_buffer) || coast_buffer < 1))
    stop("Enter a coast buffer of at least 1 metre.", call. = FALSE)
}

.page_sites <- function(si, coast_dunes, coast_buffer) {
  si <- .page_site_input(si)
  if (!.page$system$eunis) return(si)
  cached <- .page_cached_sites(si, coast_dunes, coast_buffer)
  if (!is.null(cached)) {
    for (w in cached$warnings) warning(w, call. = FALSE)
    return(cached$sites)
  }
  si$Longitude <- .page_number(si$Longitude)
  si$Latitude <- .page_number(si$Latitude)
  placed <- !is.na(si$Longitude) & !is.na(si$Latitude)
  out <- if (!any(placed)) si else {
    h <- resy_harmonize_eunis(
      data = si[placed, ], source_crs = 4326,
      run_coast_dunes = isTRUE(coast_dunes), coast_buffer = coast_buffer, verbose = FALSE
    )
    as.data.frame(data.table::rbindlist(list(as.data.frame(h$sites), si[!placed, ]), fill = TRUE))
  }
  derived <- .page_eunis_site_cols
  if (!isTRUE(coast_dunes)) derived <- setdiff(derived, c("Coast_EEA", "Dunes_Bohn"))
  for (col in setdiff(derived, names(out))) out[[col]] <- NA
  out
}

# The warnings of RESY's validation and classification, worded for the pages:
# they name the argument `header` of resy_classify(), which the pages call the
# sites file. A missing altitude column is reported by the EUNIS-ESy site step
# and again among the missing columns; the two become one note. A warning with
# other words is passed on as it is.
.page_notes <- function(w) {
  w <- sub("^`header` is missing columns used by the expert system: (.*)\\. Rules using these columns are evaluated with a value of 0\\.$",
           "Rules read site columns that the sites file does not have: \\1. A condition on such a column is evaluated with the value 0.", w)
  w <- sub("^Header columns used by the expert system have missing values: ",
           "Site columns read by rules have missing values: ", w)
  w <- sub("^Undefined group\\(s\\) in [a-z]+ for (.*): ", "\\1 names a group that is not defined: ", w)
  w <- sub("^Duplicate vegetation type code\\(s\\): ", "Several rules have the same type code: ", w)
  altitude <- startsWith(w, '"Altitude (m)" is missing.')
  columns <- startsWith(w, "Rules read site columns that the sites file does not have: ") &
    grepl("Altitude (m)", w, fixed = TRUE)
  if (any(altitude) && any(columns)) {
    w[columns] <- paste(w[columns], 'The article "Get altitude data" shows how to add the altitude.')
    w <- w[!altitude]
  }
  w <- sub("^([a-z])", "\\U\\1", w, perl = TRUE)
  unique(w)
}

# Size of the session's memory in bytes. WebAssembly memory only grows, so this
# is the most the session has needed so far; NA outside webR.
.page_heap <- function() {
  if (!requireNamespace("webr", quietly = TRUE)) return(NA_real_)
  webr::eval_js("typeof wasmMemory !== 'undefined' ? wasmMemory.buffer.byteLength : Module.HEAPU8.length")
}

# Classifies one batch of plots. `species_tsv` has the columns
# PlotObservationID, name and cover; `sites_tsv` has PlotObservationID and the
# site columns. Returns per plot its type and its candidate types (highest
# priority first), the warnings RESY gave and the session's memory size. The
# memory of the batch is freed before the next one, which keeps R from
# claiming more WebAssembly memory batch after batch.
resy_page_batch <- function(species_tsv, sites_tsv, coast_dunes = TRUE, coast_buffer = 5000) {
  warnings <- character()
  out <- withCallingHandlers({
    .page_check_buffer(coast_dunes, coast_buffer)
    sp <- .page_read_batch(species_tsv)
    if ("organismQuantityType" %in% names(sp)) {
      unit <- sp$organismQuantityType
      unit[is.na(unit) & !is.na(sp$cover)] <- "(missing)"
      RESY:::.resy_dwc_cover(data.frame(organismQuantity = 0, organismQuantityType = unit))
    }
    raw_sites <- .page_read_batch(sites_tsv)
    sites <- .page_sites(raw_sites, coast_dunes, coast_buffer)
    res <- .page_run(sp, sites)
    types <- .page_plot_types(res)
    c(types, list(n_obs = nrow(res$obs), unmatched = sum(is.na(res$obs$TaxonName)),
                  sites = .page_site_counts(types$id, raw_sites, res$header)))
  },
  warning = function(w) {
    msg <- conditionMessage(w)
    if (!any(startsWith(msg, .page_counted_site_warnings))) warnings <<- c(warnings, msg)
    invokeRestart("muffleWarning")
  },
  message = function(m) invokeRestart("muffleMessage"))
  out$warnings <- I(.page_notes(warnings))
  rm(res)
  invisible(gc())
  out$heap <- .page_heap()
  .page_json(out)
}

.page_counted_site_warnings <- c(
  "`header` is missing columns used by the expert system: ",
  "Header columns used by the expert system have missing values: ",
  "No site falls inside the ",
  '\"Ecoreg\" is missing for some plots because they fall outside the ',
  '\"Country\" is missing for some plots because they fall outside the '
)

.page_site_counts <- function(ids, raw, sites) {
  at <- match(ids, sites$PlotObservationID)
  input <- match(ids, raw$PlotObservationID)
  present <- intersect(.page$system$header_cols, names(sites))
  numeric <- .page_header_cols(.page$system$parsed, "$$N")
  missing <- vapply(numeric, function(col) {
    if (!col %in% present) return(length(ids))
    sum(is.na(suppressWarnings(as.numeric(sites[[col]][at]))))
  }, integer(1))
  maps <- data.frame(column = character(), located = integer(), matched = integer())
  if (.page$system$eunis) {
    located <- is.finite(.page_number(raw$Longitude[input])) &
      is.finite(.page_number(raw$Latitude[input]))
    for (col in setdiff(c("Ecoreg", "Country"), names(raw))) {
      matched <- if (col %in% names(sites)) sum(!is.na(sites[[col]][at[located]])) else 0L
      maps[nrow(maps) + 1L, ] <- list(col, sum(located), matched)
    }
  }
  list(matched = sum(!is.na(input)), absent = sum(is.na(input)), present = I(present),
       missing = data.frame(column = names(missing), n = unname(missing)), maps = maps)
}

# Per plot of a classification `res`: its id, its type and its candidate types
# (highest priority first, separated by spaces), as arrays in JSON whatever the
# number of plots.
.page_plot_types <- function(res) {
  type <- res$result.classification
  cand <- res$candidates
  list(
    id = I(names(type)),
    code = I(unname(type)),
    candidates = I(unname(vapply(split(cand$type, factor(cand$plot_id, levels = names(type))),
                                 paste, character(1), collapse = " ")))
  )
}

# Classifies the species records `sp` (columns PlotObservationID, name, cover)
# of plots whose header table is `sites`, with the expert system in use.
.page_run <- function(sp, sites) {
  cover <- .page_number(sp$cover)
  if (any(is.na(cover) & !is.na(sp$cover))) warning("Some species records have a cover that is not a number.", call. = FALSE)
  obs <- data.frame(PlotObservationID = sp$PlotObservationID,
                    TaxonName = .page_taxa(sp$name),
                    Cover_Perc = cover)
  utils::capture.output(
    res <- resy_classify(obs = obs, header = sites, expert = .page$system$parsed, mc = 1L)
  )
  res
}

# Why one plot is classified as it is: what resy_eval_plot() prints, as data,
# for a batch holding only that plot. `type` adds the rules of further types in
# full.
resy_page_explain <- function(species_tsv, sites_tsv, plot_id, coast_dunes = TRUE, coast_buffer = 5000,
                              type = character()) {
  .page_check_buffer(coast_dunes, coast_buffer)
  sp <- .page_read_batch(species_tsv)
  res <- suppressWarnings(suppressMessages(
    .page_run(sp, .page_sites(.page_read_batch(sites_tsv), coast_dunes, coast_buffer))))
  .page_json(.page_name_unknown(suppressWarnings(RESY:::.resy_plot_evidence(res, plot_id, type = type)), sp))
}

# The species table of the evidence `ev` has no name for the records of the
# plot whose name the expert system does not know; they take no part in the
# classification. Here they get the name written in the species records `sp`
# and are marked `unknown`.
.page_name_unknown <- function(ev, sp) {
  rec <- as.data.frame(sp)
  rec <- rec[as.character(rec$PlotObservationID) == ev$id, , drop = FALSE]
  rec <- rec[is.na(.page_taxa(rec$name)), , drop = FALSE]
  known <- ev$species[!is.na(ev$species$species), , drop = FALSE]
  known$unknown <- rep(FALSE, nrow(known))
  other <- data.frame(species = as.character(rec$name),
                      cover = suppressWarnings(as.numeric(rec$cover)),
                      unknown = rep(TRUE, nrow(rec)), stringsAsFactors = FALSE)
  all <- rbind(known, other)
  ev$species <- all[order(-all$cover, all$species), , drop = FALSE]
  ev
}

# Country outlines inside the map view, as SVG path data in screen pixels, for
# the map download. The outlines are the Eurostat GISCO NUTS boundaries RESY
# uses to find the country of a plot: the 1:60 million layer for a view of the
# continent, the 1:1 million layer closer in, simplified to half a pixel. The
# view is given as the page draws it: `scale` pixels per unit of Web Mercator
# scaled to [0, 1] (x east, y south), `ox`, `oy` the pixel position of the
# view's corner and `w`, `h` its size. Each country is one path; holes are
# kept as rings of the same path.
resy_page_land <- function(scale, ox, oy, w, h) {
  earth <- 2 * pi * 6378137
  metres_per_pixel <- earth / scale
  layer <- if (metres_per_pixel > 5000) "europe_resolution_60_epsg25832" else "europe_resolution_1_epsg25832"
  land <- RESY:::.resy_gis(layer)$land
  pad <- 2 / scale
  unit <- c(xmin = ox / scale - pad, xmax = (ox + w) / scale + pad,
            ymin = oy / scale - pad, ymax = (oy + h) / scale + pad)
  box <- c((unit[["xmin"]] - .5) * earth, (.5 - unit[["ymax"]]) * earth,
           (unit[["xmax"]] - .5) * earth, (.5 - unit[["ymin"]]) * earth)
  b <- land$ring_bbox
  keep <- which(b[, 1] <= box[3] & b[, 3] >= box[1] & b[, 2] <= box[4] & b[, 4] >= box[2])
  rings <- vapply(keep, function(i) {
    xy <- RESY:::.resy_simplify_line(land$rings[[i]] * land$unit, metres_per_pixel / 2)
    px <- round((xy[, 1] / earth + .5) * scale - ox, 1)
    py <- round((.5 - xy[, 2] / earth) * scale - oy, 1)
    p <- paste(px, py, sep = ',')
    paste0('M', p[1L], 'L', paste(p[-1L], collapse = ' '), 'Z')
  }, character(1))
  .page_json(list(paths = I(unname(vapply(split(rings, land$feature[keep]), paste, character(1), collapse = '')))))
}

# The example files shipped with RESY.
resy_page_examples <- function() {
  c(species = system.file("extdata", "data_example_species.csv", package = "RESY"),
    sites = system.file("extdata", "data_example_sites.csv", package = "RESY"))
}
