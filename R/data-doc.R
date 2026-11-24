#' Coastal vegetation of the Bohn map with a 500 m buffer (EPSG:25832)
#'
#' Polygons of the coastal vegetation (formation P) of the Map of the Natural
#' Vegetation of Europe (Bohn et al.), buffered by 500 m, in EPSG:25832. The
#' dataset holds the list `bohn`; `attributes$DUNE` marks dune polygons.
#' Used to set `Dunes_Bohn` in [resy_harmonize_eunis()].
#'
#' @format A plain list for 367 polygon features: `rings` holds two-column
#'   coordinate matrices, `feature`, `part` and `ring` identify each ring,
#'   `ring_bbox` and `bbox` hold bounding boxes, `attributes` holds the feature
#'   table, and `crs` is the EPSG code. Ring 1 is the shell; later rings are holes.
#' @source Bohn, U. et al.: Map of the Natural Vegetation of Europe.
#' @usage data(dunes_bohn_500mbuffer_epsg25832)
#' @name dunes_bohn_500mbuffer_epsg25832
#' @aliases bohn
#' @docType data
#' @keywords internal
NULL

#' Regional seas around Europe (EPSG:25832)
#'
#' The regional seas around Europe (Marine Strategy Framework Directive regions)
#' in EPSG:25832. The dataset holds the list `co`; `attributes$COAST_EEA`
#' gives the coast code of each sea (for example `MED_COAST`). Used to set
#' `Coast_EEA` in [resy_harmonize_eunis()].
#'
#' @format A plain coordinate list with 5 multiline features. See
#'   [dunes_bohn_500mbuffer_epsg25832] for the ring and attribute fields.
#'   `segments`, `segment_bbox` and `segment_feature` index the line segments.
#' @source European Environment Agency: Regional seas around Europe.
#' @usage data(coastline_regions_epsg25832)
#' @name coastline_regions_epsg25832
#' @aliases co
#' @docType data
#' @keywords internal
NULL

#' Ecoregions of Europe (EPSG:25832)
#'
#' The terrestrial ecoregions of Europe from the RESOLVE Ecoregions 2017 map, in
#' EPSG:25832. Used to set `Ecoreg` (column `ECO_ID`) in
#' [resy_harmonize_eunis()].
#'
#' @format A plain coordinate list with 159 polygon features. See
#'   [dunes_bohn_500mbuffer_epsg25832] for the ring and attribute fields.
#' @source Dinerstein, E. et al. (2017): An ecoregion-based approach to
#'   protecting half the terrestrial realm. BioScience 67. Licence CC-BY 4.0.
#' @usage data(ecoregions2017_epsg25832)
#' @name ecoregions2017_epsg25832
#' @docType data
#' @keywords internal
NULL

#' European countries at high resolution (EPSG:25832)
#'
#' Country boundaries (NUTS level 0, columns `NUTS_ID` and `NUTS_NAME`) at the
#' 1:1 million scale, in EPSG:25832. Used to set `Country` in
#' [resy_harmonize_eunis()].
#'
#' @format A plain coordinate list with 37 polygon features. See
#'   [dunes_bohn_500mbuffer_epsg25832] for the ring and attribute fields.
#'   `land` holds simplified EPSG:3857 outlines for map export.
#' @source Eurostat GISCO: NUTS boundaries.
#' @usage data(europe_resolution_1_epsg25832)
#' @name europe_resolution_1_epsg25832
#' @docType data
#' @keywords internal
NULL

#' European countries at low resolution (EPSG:25832)
#'
#' Country boundaries (NUTS level 0, columns `NUTS_ID` and `NUTS_NAME`) at the
#' 1:60 million scale, in EPSG:25832, for maps.
#'
#' @format A plain coordinate list with 37 polygon features. See
#'   [dunes_bohn_500mbuffer_epsg25832] for the ring and attribute fields.
#'   `land` holds simplified EPSG:3857 outlines for map export.
#' @source Eurostat GISCO: NUTS boundaries.
#' @usage data(europe_resolution_60_epsg25832)
#' @name europe_resolution_60_epsg25832
#' @docType data
#' @keywords internal
NULL
