# resy-package.R holds the package help page and the namespace-wide imports
# (data.table, fastmatch::fmatch, stringi::stri_replace_all_fixed, and the utils
# helpers). The engine calls these without a namespace prefix, so they must be
# reachable from the package namespace; the help page must name the package and
# point at the front-door verbs its workflow section describes.

test_that("the namespace-wide imports resolve inside the package", {
  ns <- asNamespace("RESY")
  for (fn in c("fmatch", "stri_replace_all_fixed", "head", "read.csv", "stack",
               "data.table", "setDT", ":=", "fread")) {
    expect_true(exists(fn, envir = ns, inherits = TRUE), info = fn)
  }
  expect_identical(get("fmatch", envir = ns), fastmatch::fmatch)
  expect_identical(get("stri_replace_all_fixed", envir = ns),
                   stringi::stri_replace_all_fixed)
})

test_that("the package help page exists and names the package", {
  # Source tree (devtools::test) first, installed help (R CMD check) otherwise.
  rd_file <- test_path("..", "..", "man", "RESY-package.Rd")
  rd <- if (file.exists(rd_file)) {
    list(`RESY-package.Rd` = tools::parse_Rd(rd_file))
  } else {
    tools::Rd_db("RESY")
  }
  expect_true("RESY-package.Rd" %in% names(rd))

  aliases <- unlist(lapply(rd[["RESY-package.Rd"]], function(x)
    if (identical(attr(x, "Rd_tag"), "\\alias")) as.character(x)))
  expect_true(all(c("RESY", "RESY-package") %in% aliases))
})

test_that("every function the help page links to is exported", {
  links <- c("resy_available_classifications", "resy_add_classification",
             "resy_load_expert", "resy_check_taxonomy", "resy_resolve_taxa",
             "resy_harmonize_eunis", "resy_classify", "resy_candidates",
             "resy_eval_plot", "resy_eval_type", "resy_expert_tree")
  expect_true(all(links %in% getNamespaceExports("RESY")))
})
