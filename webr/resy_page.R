# R functions behind the RESY App. The page streams the data files and hands
# them over in batches of whole plots, as tab-separated files with fixed column
# names; these functions classify each batch and return JSON.

suppressPackageStartupMessages({
  library(RESY)
})

.page <- new.env()

.page_json <- function(x) jsonlite::toJSON(x, auto_unbox = TRUE, na = "null", dataframe = "rows")

# Code and name of every type in a parsed expert system, from the Section 3
# header lines ("FB    Beech-fir montane forest").
.page_type_names <- function(parsed) {
  full <- trimws(parsed$vegtype.formula.names)
  data.frame(code = parsed$vegtype.formula.names.short,
             name = trimws(sub("^\\S+", "", full)),
             stringsAsFactors = FALSE)
}

# Header columns the expert system reads through $$C and $$N conditions.
.page_header_cols <- function(parsed) {
  conds <- parsed$conditions[startsWith(parsed$conditions, "$$C") |
                               startsWith(parsed$conditions, "$$N")]
  sort(unique(trimws(substring(conds, 4L))))
}

# Header columns that resy_harmonize_eunis() derives from the plot position.
# A system reading any of them gets the EUNIS-ESy site step before classifying.
.page_eunis_site_cols <- c("Coast_EEA", "Dunes_Bohn", "Ecoreg", "Ecoreg_name",
                           "Country_ID", "DEG_LON", "DEG_LAT")

# Selects the expert system later runs use: a scheme shipped with the package
# ("EUNIS", "Apennine-test") or an uploaded .json/.txt file. Returns a summary
# of the system and the names of its types.
resy_page_set_expert <- function(scheme = "EUNIS", path = NULL) {
  t0 <- Sys.time()
  parsed <- if (is.null(path)) resy_load_expert(scheme = scheme) else tryCatch(
    resy_load_expert(expertfile = path),
    error = function(e) stop("RESY could not read ", basename(path), " as an expert system (",
                             conditionMessage(e), ").", call. = FALSE)
  )
  header_cols <- .page_header_cols(parsed)
  eunis <- any(header_cols %in% .page_eunis_site_cols)
  names <- .page_type_names(parsed)
  # A code with several rules has one description per rule ("... trees 1",
  # "... trees 2"); the EUNIS names table gives the type's own name.
  names <- names[!duplicated(names$code), ]
  if (eunis) {
    eunis_names <- resy_eunis_names()[c("code", "name")]
    names <- rbind(eunis_names, names[!names$code %in% eunis_names$code, ])
  }
  .page$system <- list(
    scheme = if (is.null(path)) scheme else basename(path),
    parsed = parsed,
    eunis = eunis,
    names = names
  )
  .page$taxa <- character()
  derived <- if (eunis) intersect(header_cols, .page_eunis_site_cols) else character()
  .page_json(list(
    scheme = .page$system$scheme,
    eunis = eunis,
    n_types = length(unique(parsed$vegtype.formula.names.short)),
    n_species = length(parsed$aggs),
    header_cols = I(header_cols),
    derived_cols = I(derived),
    names = names,
    levels = if (eunis) names[nchar(names$code) == 1L, ] else names,
    seconds = round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 2)
  ))
}

# Species names as the expert system knows them. Each distinct name is cleaned
# and checked once per expert system; later batches reuse the result.
.page_taxa <- function(raw) {
  new <- setdiff(unique(raw), names(.page$taxa))
  if (length(new)) {
    cleaned <- resy_clean_names(new)
    checked <- as.data.frame(resy_check_taxonomy(data.frame(scientificName = unique(cleaned)),
                                                 .page$system$parsed, col = "scientificName"))
    known <- checked$TaxonName[match(cleaned, checked$scientificName)]
    .page$taxa <- c(.page$taxa, stats::setNames(known, new))
  }
  unname(.page$taxa[raw])
}

.page_read <- function(path) {
  data.table::fread(path, sep = "\t", quote = "", colClasses = "character",
                    na.strings = "", encoding = "UTF-8", data.table = FALSE)
}

# Sites as the header table for the classifier. For a system that reads the
# EUNIS-ESy site columns this adds ecoregion, country, and optionally coast and
# dune flags from the plot position. Plots without a position get these columns
# as missing values, whichever other plots share their batch.
.page_sites <- function(si, coast_dunes, coast_buffer) {
  for (col in setdiff(names(si), c("PlotObservationID", "Country"))) {
    si[[col]] <- utils::type.convert(si[[col]], as.is = TRUE)
  }
  if (!.page$system$eunis) return(si)
  si$Longitude <- suppressWarnings(as.numeric(si$Longitude))
  si$Latitude <- suppressWarnings(as.numeric(si$Latitude))
  placed <- !is.na(si$Longitude) & !is.na(si$Latitude)
  out <- if (!any(placed)) si else {
    h <- resy_harmonize_eunis(
      data = sf::st_as_sf(si[placed, ], coords = c("Longitude", "Latitude"), crs = 4326),
      run_coast_dunes = isTRUE(coast_dunes), coast_buffer = coast_buffer, verbose = FALSE
    )
    as.data.frame(data.table::rbindlist(list(as.data.frame(h$sites), si[!placed, ]), fill = TRUE))
  }
  derived <- .page_eunis_site_cols
  if (!isTRUE(coast_dunes)) derived <- setdiff(derived, c("Coast_EEA", "Dunes_Bohn"))
  for (col in setdiff(derived, names(out))) out[[col]] <- NA
  out
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
    res <- .page_classify(species_tsv, sites_tsv, coast_dunes, coast_buffer)
    cand <- res$candidates
    list(
      id = names(res$result.classification),
      code = unname(res$result.classification),
      candidates = unname(vapply(split(cand$type, factor(cand$plot_id, levels = names(res$result.classification))),
                                 paste, character(1), collapse = " ")),
      n_obs = nrow(res$obs),
      unmatched = sum(is.na(res$obs$TaxonName))
    )
  },
  warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w))
    invokeRestart("muffleWarning")
  },
  message = function(m) invokeRestart("muffleMessage"))
  out$warnings <- I(unique(warnings))
  rm(res, cand)
  invisible(gc())
  out$heap <- .page_heap()
  .page_json(out)
}

.page_classify <- function(species_tsv, sites_tsv, coast_dunes, coast_buffer) {
  sp <- .page_read(species_tsv)
  obs <- data.frame(PlotObservationID = sp$PlotObservationID,
                    TaxonName = .page_taxa(sp$name),
                    Cover_Perc = suppressWarnings(as.numeric(sp$cover)))
  sites <- .page_sites(.page_read(sites_tsv), coast_dunes, coast_buffer)
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
  res <- suppressWarnings(suppressMessages(.page_classify(species_tsv, sites_tsv, coast_dunes, coast_buffer)))
  .page_json(suppressWarnings(RESY:::.resy_plot_evidence(res, plot_id, type = type)))
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
  if (is.null(.page$land[[layer]])) {
    .page$land[[layer]] <- sf::st_geometry(sf::st_transform(RESY:::.resy_gis(layer), 3857))
  }
  pad <- 2 / scale
  unit <- c(xmin = ox / scale - pad, xmax = (ox + w) / scale + pad,
            ymin = oy / scale - pad, ymax = (oy + h) / scale + pad)
  box <- sf::st_bbox(c(xmin = (unit[["xmin"]] - 0.5) * earth, xmax = (unit[["xmax"]] - 0.5) * earth,
                       ymin = (0.5 - unit[["ymax"]]) * earth, ymax = (0.5 - unit[["ymin"]]) * earth),
                     crs = sf::st_crs(3857))
  g <- suppressWarnings(sf::st_crop(.page$land[[layer]], box))
  g <- sf::st_simplify(g, dTolerance = metres_per_pixel / 2)
  g <- g[!sf::st_is_empty(g)]
  if (!length(g)) return(.page_json(list(paths = I(character()))))
  g <- suppressWarnings(sf::st_cast(sf::st_collection_extract(g, "POLYGON"), "MULTIPOLYGON"))
  xy <- sf::st_coordinates(g)
  px <- round((xy[, "X"] / earth + 0.5) * scale - ox, 1)
  py <- round((0.5 - xy[, "Y"] / earth) * scale - oy, 1)
  ring <- paste(xy[, "L1"], xy[, "L2"], xy[, "L3"])
  feature <- xy[, "L3"]
  rings <- vapply(split(paste(px, py, sep = ","), factor(ring, levels = unique(ring))),
                  function(p) paste0("M", p[1], "L", paste(p[-1], collapse = " "), "Z"), character(1))
  owner <- feature[!duplicated(ring)]
  .page_json(list(paths = I(unname(vapply(split(rings, owner), paste, character(1), collapse = "")))))
}

# The example files shipped with RESY.
resy_page_examples <- function() {
  c(species = system.file("extdata", "data_example_species.csv", package = "RESY"),
    sites = system.file("extdata", "data_example_sites.csv", package = "RESY"))
}
