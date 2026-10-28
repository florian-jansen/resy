# Column names RESY reads, and the other names accepted for each of them, in
# order of preference. Darwin Core terms (https://dwc.tdwg.org/terms/) are
# accepted for the columns that have one: eventID for the plot, scientificName
# for the species, decimalLongitude/decimalLatitude for the coordinates and
# country for the country name.
.resy_column_aliases <- list(
  PlotObservationID = c("PlotID", "eventID"),
  TaxonName         = "scientificName",
  Longitude         = "decimalLongitude",
  Latitude          = "decimalLatitude",
  Country           = "country"
)

# Columns computed from Darwin Core terms that do not map one to one: cover from
# organismQuantity with its organismQuantityType, altitude from the elevation
# range.
.resy_column_derived <- list(
  Cover_Perc     = function(data) .resy_dwc_cover(data),
  `Altitude (m)` = function(data) .resy_dwc_elevation(data)
)

# Names accepted for `column`, the RESY name first.
.resy_column_names <- function(column) {
  c(column, .resy_column_aliases[[column]])
}

# First name accepted for `column` that `data` has, or NULL.
.resy_find_column <- function(data, column) {
  hit <- intersect(.resy_column_names(column), names(data))
  if (length(hit)) hit[1] else NULL
}

# Value of `column` taken from an accepted name or derived from Darwin Core
# terms, or NULL when `data` has neither.
.resy_column_value <- function(data, column) {
  derive <- .resy_column_derived[[column]]
  if (!is.null(derive)) return(derive(data))
  hit <- .resy_find_column(data, column)
  if (is.null(hit)) NULL else data[[hit]]
}

# Adds each of `columns` that `data` lacks under its RESY name, from an accepted
# name or from Darwin Core terms. Columns already present are left unchanged.
.resy_adopt_columns <- function(data, columns) {
  for (col in setdiff(columns, names(data))) {
    value <- .resy_column_value(data, col)
    if (is.null(value)) next
    if (data.table::is.data.table(data)) {
      data <- data.table::copy(data)
      data.table::set(data, j = col, value = value)
    } else {
      data[[col]] <- value
    }
  }
  data
}

# Name of the species column of `obs`: `species_col` when given, otherwise the
# first accepted name for TaxonName that `obs` has. `arg` names the argument in
# the error message.
.resy_species_col <- function(obs, species_col = NULL, arg = "species_col") {
  if (!is.null(species_col)) {
    if (!species_col %in% names(obs))
      stop("`obs` has no column `", species_col, "`. Name the column holding ",
           "the species names with `", arg, "`.", call. = FALSE)
    return(species_col)
  }
  col <- .resy_find_column(obs, "TaxonName")
  if (is.null(col))
    stop("`obs` has no species column. Use one of ",
         paste0("`", .resy_column_names("TaxonName"), "`", collapse = ", "),
         ", or name the column with `", arg, "`.", call. = FALSE)
  col
}

# Cover in percent from Darwin Core organismQuantity. Only a percent cover can
# be used, so every organismQuantityType has to name one ("% cover",
# "percent cover").
.resy_dwc_cover <- function(data) {
  if (!all(c("organismQuantity", "organismQuantityType") %in% names(data)))
    return(NULL)
  type <- as.character(data$organismQuantityType)
  percent <- grepl("cover", type, ignore.case = TRUE) &
    grepl("%|percent", type, ignore.case = TRUE)
  other <- unique(type[!percent & !is.na(type)])
  if (length(other))
    stop("`Cover_Perc` can be taken from `organismQuantity` only when ",
         "`organismQuantityType` is a percent cover such as \"% cover\". ",
         "Found: ", paste0("\"", other, "\"", collapse = ", "), ".",
         call. = FALSE)
  as.numeric(data$organismQuantity)
}

# Altitude in metres from Darwin Core minimumElevationInMeters and
# maximumElevationInMeters. A plot with a range gets its midpoint; a plot with
# one of the two gets that value.
.resy_dwc_elevation <- function(data) {
  lo <- data[["minimumElevationInMeters"]]
  hi <- data[["maximumElevationInMeters"]]
  if (is.null(lo) && is.null(hi)) return(NULL)
  lo <- as.numeric(if (is.null(lo)) hi else lo)
  hi <- as.numeric(if (is.null(hi)) lo else hi)
  ranged <- sum(!is.na(lo) & !is.na(hi) & lo != hi)
  if (ranged)
    warning(ranged, " plot(s) have an elevation range; `Altitude (m)` is the ",
            "midpoint of minimumElevationInMeters and maximumElevationInMeters.",
            call. = FALSE)
  ifelse(is.na(lo), hi, ifelse(is.na(hi), lo, (lo + hi) / 2))
}
