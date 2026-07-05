utils::globalVariables(c(
  # data.table specials used inside .resy_solve_membership
  ".", "y",
  ".SD", "plot.group.non.C",
  "Cover_Perc", "TaxonName",
  "PlotObservationID",
  "ind", "values",
  "priority_rank", "plot_id", "type",
  # dplyr tidy-eval column names in check_country
  "NUTS_ID", "NUTS_NAME", "Country"
))
