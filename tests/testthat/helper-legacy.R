# The deprecated synonym-layer functions are still tested; testthat turns
# lifecycle warnings on in every test, so tests of them silence the
# deprecation (which test-deprecated.R checks).
local_legacy <- function(env = parent.frame()) {
  withr::local_options(lifecycle_verbosity = "quiet", .local_envir = env)
}
