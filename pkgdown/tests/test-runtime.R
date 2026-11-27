pkgload::load_all(".", quiet = TRUE)
data.table::setDTthreads(1)
source("pkgdown/assets/webr/resy_page.R")
source("pkgdown/assets/webr/resy_maker.R")

testthat::test_that("site cache checks all input values and options and joins by plot ID", {
  info <- jsonlite::read_json("pkgdown/assets/webr/bundle.json", simplifyVector = TRUE)
  image <- info$images$resy
  con <- gzfile(file.path("pkgdown/assets/webr", image$file), "rb")
  bytes <- readBin(con, "raw", image$metadata$remote_package_size)
  close(con)
  entry <- image$metadata$files[endsWith(image$metadata$files$filename, "/example-sites.rds"), ]
  .page$example_sites <- unserialize(memDecompress(bytes[seq.int(entry$start + 1L, entry$end)], "xz"))
  input <- .page$example_sites$input
  testthat::expect_equal(nrow(input), 200L)
  invisible(resy_page_set_expert("EUNIS"))
  cached <- suppressWarnings(.page_sites(input, TRUE, 5000))
  saved <- .page$example_sites
  .page$example_sites <- modifyList(saved, list(coast_buffer = -1))
  calculated <- suppressWarnings(.page_sites(input, TRUE, 5000))
  .page$example_sites <- saved
  testthat::expect_identical(cached, calculated)
  reverse <- input[rev(seq_len(nrow(input))), ]
  reordered <- suppressWarnings(.page_sites(reverse, TRUE, 5000))
  testthat::expect_identical(reordered$PlotObservationID, reverse$PlotObservationID)
  testthat::expect_identical(reordered$Ecoreg, cached$Ecoreg[match(reverse$PlotObservationID, cached$PlotObservationID)])
  input$Longitude[1] <- input$Longitude[1] + .01
  testthat::expect_null(.page_cached_sites(input, TRUE, 5000))
  testthat::expect_null(.page_cached_sites(saved$input, FALSE, 5000))
  testthat::expect_null(.page_cached_sites(saved$input, TRUE, 1000))
  testthat::expect_null(.page_cached_sites(saved$input[1:3, ], TRUE, 5000))
})

testthat::test_that("rule and group edits invalidate exactly the affected taxonomy names", {
  model <- list(metadata = list(scheme = "test"),
                synonyms = list(`Fagus sylvatica` = "Fagus sylvatica L."),
                groups = list(`### Trees` = "Abies alba"),
                rules = list(list(priority = "1", code = "A", description = "Trees",
                                  expression = "<#TC Trees GR 10>")))
  use <- function(x) .page_use_system(RESY:::.resy_parsed_from_json(x), "test")
  raw <- c("Fagus sylvatica", "Abies alba", "Planta inventa")
  use(model)
  testthat::expect_identical(.page_taxa(raw), c("Fagus sylvatica", "Abies alba", NA_character_))
  kept <- .page$taxa
  model$rules[[1]]$expression <- "<#TC Trees GR 30>"
  use(model)
  testthat::expect_identical(.page$taxa, kept)
  model$groups[[1]] <- "Planta inventa"
  use(model)
  testthat::expect_identical(names(.page$taxa), "Fagus sylvatica")
  testthat::expect_identical(.page_taxa(raw), c("Fagus sylvatica", NA_character_, "Planta inventa"))
  model$rules[[1]]$expression <- "<Abies alba GR 10>"
  use(model)
  testthat::expect_identical(.page_taxa(raw), c("Fagus sylvatica", "Abies alba", "Planta inventa"))
  model$synonyms <- list(`Fagus orientalis` = "Fagus sylvatica")
  use(model)
  testthat::expect_length(.page$taxa, 0L)
  testthat::expect_identical(.page_taxa(raw), c("Fagus orientalis", "Abies alba", "Planta inventa"))
})

testthat::test_that("target-only taxonomy agrees with the complete vocabulary mapping", {
  for (scheme in c("Apennine-test", "EUNIS")) {
    parsed <- resy_load_expert(scheme = scheme)
    testthat::expect_identical(RESY:::.resy_expert_names(parsed, mapping = FALSE)$targets,
                              RESY:::.resy_expert_names(parsed)$targets)
  }
})

testthat::test_that("Maker parsing changes with rules and synonyms", {
  path <- tempfile(fileext = ".json")
  model <- list(metadata = list(scheme = "test"), groups = list(`### Trees` = "Abies alba"),
                rules = list(list(priority = "1", code = "A", description = "Trees",
                                  expression = "<#TC Trees GR 10>")))
  .maker$synonyms <- list(`Abies alba` = list("Abies alba Mill."))
  .maker$parsed <- NULL
  jsonlite::write_json(model, path, auto_unbox = TRUE)
  first <- .maker_system(path)$parsed
  testthat::expect_identical(.maker_system(path)$parsed, first)
  model$rules[[1]]$expression <- "<#TC Trees GR 30>"
  jsonlite::write_json(model, path, auto_unbox = TRUE)
  testthat::expect_match(.maker_system(path)$parsed$vegtype.formulas, "GR 30", fixed = TRUE)
  syn <- tempfile(fileext = ".json")
  jsonlite::write_json(list(`Abies alba` = list("Abies pectinata")), syn)
  resy_maker_synonyms(syn)
  testthat::expect_identical(.maker_system(path)$parsed$aggs[[1]], "Abies pectinata")
  unlink(c(path, syn))
})

testthat::test_that("systems with a backbone match names along the prepared EuroSL", {
  testthat::skip_if_not_installed("vegdata")
  bb <- RESY:::.resy_backbone_get("EuroSL",
                                  system.file("extdata", "eurosl_example.csv.xz", package = "RESY"))
  path <- tempfile(fileext = ".rds")
  saveRDS(RESY:::.resy_backbone_prepare(bb), path)
  resy_page_backbone(path)
  out <- jsonlite::fromJSON(resy_page_set_expert("Apennine-test"))
  testthat::expect_identical(out$backbone, "EuroSL")
  testthat::expect_identical(.page_taxa(c("Fagus sylvatica L.", "Abies pectinata", "Planta inventa")),
                             c("Fagus sylvatica", "Abies alba", NA))
  json <- tempfile(fileext = ".json")
  resy_maker_open(json, scheme = "Apennine-test")
  testthat::expect_identical(jsonlite::read_json(json)$backbone$name, "EuroSL")
  txt <- tempfile(fileext = ".txt")
  resy_maker_write_txt(json, txt)
  testthat::expect_identical(resy_load_expert(expertfile = txt)$backbone$name, "EuroSL")
  unlink(c(path, json, txt))
})

testthat::test_that("a folder of whole backbones is read by backbone name", {
  dir <- tempfile()
  dir.create(dir)
  file.create(file.path(dir, c("EuroSL.rds", "GermanSL.rds")))
  resy_page_backbone(dir)
  testthat::expect_identical(.page_full_backbone("GermanSL"), file.path(dir, "GermanSL.rds"))
  testthat::expect_identical(.page_full_backbone("EuroSL"), file.path(dir, "EuroSL.rds"))
  testthat::expect_null(.page_full_backbone("Other"))
  resy_page_backbone(file.path(dir, "EuroSL.rds"))
  testthat::expect_identical(.page_full_backbone("EuroSL"), file.path(dir, "EuroSL.rds"))
  testthat::expect_null(.page_full_backbone("GermanSL"))
  .page$full_backbone <- NULL
  unlink(dir, recursive = TRUE)
})
