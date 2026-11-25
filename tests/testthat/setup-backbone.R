# Expert systems with a taxonomic backbone read the part of EuroSL that ships
# with RESY.
withr::local_options(
  resy.backbone = system.file("extdata", "eurosl_example.csv.xz", package = "RESY"),
  .local_envir = teardown_env()
)
