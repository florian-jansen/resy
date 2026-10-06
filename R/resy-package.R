#' RESY: rule-based expert classification of vegetation plots
#'
#' @description
#' RESY assigns vegetation plots to vegetation or habitat types with formalised
#' expert systems: rule sets that combine indicator species groups, species
#' covers and plot header data (for example ecoregion, country or coast) into
#' membership formulas. The EUNIS-ESy expert system for European EUNIS habitat
#' types (Chytrý et al. 2020) ships with the package, and any other system in
#' the ESy `.txt` or `.json` format can be added.
#'
#' @section Workflow:
#' \enumerate{
#'   \item Pick an expert system: [resy_available_classifications()] lists the
#'     shipped ones, [resy_add_classification()] stores your own, and
#'     [resy_load_expert()] loads one.
#'   \item Prepare the plot data: [resy_check_taxonomy()] checks species names
#'     against the expert system, [resy_resolve_taxa()] harmonises names from
#'     other taxonomic backbones, and [resy_harmonize_eunis()] adds the header
#'     columns EUNIS-ESy needs.
#'   \item Classify with [resy_classify()].
#'   \item Inspect the result: [resy_candidates()] lists the candidate types per
#'     plot, [resy_eval_plot()] shows why a plot matched, and [resy_expert_tree()] shows the type hierarchy.
#' }
#'
#' @references
#' Chytrý M, Tichý L, Hennekens SM et al. (2020) EUNIS Habitat
#' Classification: expert system, characteristic species combinations and
#' distribution maps of European habitats. *Applied Vegetation Science* 23,
#' 648-675. \doi{10.1111/avsc.12519}
#'
#' @examples
#' resy_available_classifications()[, c("scheme", "version")]
#'
#' parsed <- resy_load_expert(scheme = "Apennine-test")
#' parsed$vegtype.formula.names
#'
#' @import data.table
#' @importFrom fastmatch fmatch
#' @importFrom stringi stri_replace_all_fixed
#' @importFrom utils head read.csv stack
"_PACKAGE"
