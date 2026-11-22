utils::globalVariables(c(
  # data.table columns used inside the solver and resy_candidates()
  ".SD", "Cover_Perc", "TaxonName", "PlotObservationID",
  "priority_rank", "plot_id", "type",
  ".N", "k", "row", "plot", "t", "q", "v",
  # dplyr column in .resy_assign_country()
  "Country"
))
