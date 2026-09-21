# resy_add_classification() validates an expert file and copies it into the
# per-user classification store, where resy_load_expert() and resy_classify()
# find it by scheme and version. Every test redirects the store to a fresh
# temporary directory through R_USER_DATA_DIR, so nothing is written to the real
# user library. The tests pin the storage layout, that a stored system loads back
# identical to its source, the overwrite guard, and the validation gate.

local_store <- function(env = parent.frame()) {
  root <- tempfile("resy_store")
  withr::local_envvar(R_USER_DATA_DIR = root, .local_envir = env)
  withr::defer(unlink(root, recursive = TRUE), envir = env)
  root
}

apennine_json <- function() {
  resy_expert_path("Apennine-test", "2026-06-27")
}

mini_txt <- function() {
  path <- tempfile(fileext = ".txt")
  writeLines(c(
    "SECTION 1: Species aggregation",
    "Achillea millefolium agg.",
    "     Achillea millefolium",
    "     Achillea pratensis",
    "SECTION 1: End",
    "SECTION 2: Species groups",
    "### Grassland-herbs",
    "     Nardus stricta",
    "     Achillea millefolium agg.",
    "### Forest-trees",
    "     Fagus sylvatica",
    "     Abies alba",
    "",
    "SECTION 2: End",
    "SECTION 3: Group definitions",
    "5          GR Grassland",
    "<### Grassland-herbs GR 0>",
    "2          FO Forest",
    "<### Forest-trees GR 0>",
    "SECTION 3: End"
  ), path)
  path
}

invalid_json <- function() {
  path <- tempfile(fileext = ".json")
  jsonlite::write_json(
    list(
      synonyms = list(),
      # groups key missing
      rules = list(list(priority = "5", code = "AB", description = "d",
                        expression = "<### G>"))
    ),
    path, auto_unbox = TRUE
  )
  path
}

md5 <- function(path) unname(tools::md5sum(path))

# ---- Storage layout ----------------------------------------------------------

test_that("a .json file is stored byte-identical under scheme/version", {
  local_store()
  src <- apennine_json()
  out <- resy_add_classification(src, scheme = "MyScheme", version = "1.0")

  expect_null(out$txt)
  expect_equal(basename(out$json), "expert.json")
  expect_equal(basename(dirname(out$json)), "1.0")
  expect_equal(basename(dirname(dirname(out$json))), "MyScheme")
  expect_equal(
    normalizePath(dirname(dirname(dirname(out$json)))),
    normalizePath(RESY:::.resy_classifications_root("user"))
  )
  expect_identical(md5(out$json), md5(src))
})

test_that("a .txt file is stored unchanged with a metadata sidecar", {
  local_store()
  src <- mini_txt()
  out <- resy_add_classification(src, scheme = "MiniTxt", version = "1")

  expect_null(out$json)
  expect_identical(md5(out$txt), md5(src))
  expect_false(file.exists(file.path(dirname(out$txt), "expert.json")))

  meta <- jsonlite::read_json(file.path(dirname(out$txt), "metadata.json"))
  expect_equal(meta$scheme, "MiniTxt")
  expect_equal(meta$version, "1")
  expect_match(meta$created_utc, "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$")
})

test_that("the paths are returned invisibly", {
  local_store()
  expect_invisible(
    resy_add_classification(apennine_json(), scheme = "S", version = "1")
  )
})

# ---- Stored classifications load back ---------------------------------------

test_that("a stored .json classification loads by scheme and version", {
  local_store()
  src <- apennine_json()
  resy_add_classification(src, scheme = "MyScheme", version = "1.0")

  stored <- resy_load_expert(scheme = "MyScheme", version = "1.0")
  expect_s3_class(stored, "resy_parsed_expert")
  expect_identical(stored, resy_load_expert(expertfile = src))
})

test_that("a stored .txt classification loads by scheme and version", {
  local_store()
  src <- mini_txt()
  resy_add_classification(src, scheme = "MiniTxt", version = "1")

  stored <- resy_load_expert(scheme = "MiniTxt", version = "1")
  expect_identical(stored, resy_load_expert(expertfile = src))
  expect_equal(stored$vegtype.formula.names.short, c("GR", "FO"))
})

test_that("the newest stored version is loaded when version is NULL", {
  local_store()
  resy_add_classification(mini_txt(), scheme = "MiniTxt", version = "2026-01-01")
  resy_add_classification(apennine_json(), scheme = "MiniTxt",
                          version = "2026-09-21")

  expect_identical(
    resy_load_expert(scheme = "MiniTxt"),
    resy_load_expert(expertfile = apennine_json())
  )
})

test_that("resy_classify runs on a stored classification", {
  local_store()
  resy_add_classification(apennine_json(), scheme = "MyScheme", version = "1.0")

  obs <- data.table::data.table(
    PlotObservationID = c("p1", "p1"),
    TaxonName         = c("Fagus sylvatica", "Abies alba"),
    Cover_Perc        = c(60, 20)
  )
  header <- data.frame(PlotObservationID = "p1")
  res <- suppressMessages(
    resy_classify(obs, header, scheme = "MyScheme", version = "1.0", mc = 1L)
  )
  ref <- suppressMessages(
    resy_classify(obs, header, scheme = "Apennine-test", mc = 1L)
  )
  expect_identical(res$result.classification, ref$result.classification)
})

test_that("location = 'package' does not see user-stored classifications", {
  local_store()
  resy_add_classification(apennine_json(), scheme = "MyScheme", version = "1.0")
  expect_error(
    resy_load_expert(scheme = "MyScheme", location = "package"),
    "No classifications found"
  )
})

# ---- Overwrite guard ---------------------------------------------------------

test_that("an existing classification is not replaced without overwrite", {
  local_store()
  resy_add_classification(apennine_json(), scheme = "S", version = "1")
  expect_error(
    resy_add_classification(apennine_json(), scheme = "S", version = "1"),
    "already exists"
  )
})

test_that("overwrite = TRUE replaces the stored files of either format", {
  local_store()
  first <- resy_add_classification(apennine_json(), scheme = "S", version = "1")

  second <- resy_add_classification(mini_txt(), scheme = "S", version = "1",
                                    overwrite = TRUE)
  expect_false(file.exists(first$json))
  expect_true(file.exists(second$txt))
  expect_equal(resy_load_expert(scheme = "S", version = "1")$
                 vegtype.formula.names.short, c("GR", "FO"))

  third <- resy_add_classification(apennine_json(), scheme = "S", version = "1",
                                   overwrite = TRUE)
  expect_false(file.exists(second$txt))
  expect_false(file.exists(file.path(dirname(second$txt), "metadata.json")))
  expect_true(file.exists(third$json))
})

# ---- Validation gate ---------------------------------------------------------

test_that("an invalid file is rejected and nothing is stored", {
  root <- local_store()
  expect_error(
    resy_add_classification(invalid_json(), scheme = "Bad", version = "0"),
    "Validation failed"
  )
  expect_false(dir.exists(file.path(root, "R", "RESY", "classifications", "Bad")))
})

test_that("validate = FALSE stores a file without validating it", {
  local_store()
  out <- resy_add_classification(invalid_json(), scheme = "Bad", version = "0",
                                 validate = FALSE)
  expect_true(file.exists(out$json))
})

# ---- Argument checks ---------------------------------------------------------

test_that("arguments are checked before anything is written", {
  local_store()
  expect_error(resy_add_classification(c("a", "b"), "S", "1"), "single file path")
  expect_error(resy_add_classification(tempfile(fileext = ".json"), "S", "1"),
               "File not found")

  csv <- tempfile(fileext = ".csv")
  writeLines("x", csv)
  expect_error(resy_add_classification(csv, "S", "1"), "\\.txt or \\.json")

  expect_error(resy_add_classification(apennine_json(), "", "1"), "`scheme`")
  expect_error(resy_add_classification(apennine_json(), "S", ""), "`version`")
  expect_error(
    resy_add_classification(apennine_json(), "S", "1", location = "elsewhere"),
    "should be one of"
  )
})
