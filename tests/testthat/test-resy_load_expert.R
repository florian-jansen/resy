# Tests for resy_load_expert()

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

# ---- Direct file input -------------------------------------------------------

test_that("resy_load_expert loads a JSON expert file directly", {
  path <- apennine_json()
  expert <- resy_load_expert(expertfile = path)
  
  expect_s3_class(expert, "resy_parsed_expert")
  expect_true(is.list(expert))
  expect_true(length(expert) > 0)
})

test_that("resy_load_expert loads a .txt expert file directly", {
  path <- mini_txt()
  expert <- resy_load_expert(expertfile = path)
  
  expect_s3_class(expert, "resy_parsed_expert")
  expect_equal(expert$vegtype.formula.names.short, c("GR", "FO"))
})

test_that("expertfile takes precedence over scheme and version", {
  path <- apennine_json()
  expert <- resy_load_expert(expertfile = path, scheme = "NotUsed",
                             version = "0.0")
  
  expect_s3_class(expert, "resy_parsed_expert")
  expect_identical(expert, resy_load_expert(expertfile = path))
})

# ---- Lookup by scheme/version ------------------------------------------------

test_that("resy_load_expert loads a bundled classification by scheme and version", {
  expert <- resy_load_expert(scheme = "Apennine-test", version = "2026-06-27")
  
  expect_s3_class(expert, "resy_parsed_expert")
  expect_equal(expert$vegtype.formula.names.short, c("GR", "FO"))
})

test_that("resy_load_expert uses the newest version when version is NULL", {
  local_store()
  
  resy_add_classification(
    apennine_json(),
    scheme = "MiniScheme",
    version = "2026-01-01"
  )
  resy_add_classification(
    apennine_json(),
    scheme = "MiniScheme",
    version = "2026-09-21"
  )
  
  expert <- resy_load_expert(scheme = "MiniScheme")
  expect_s3_class(expert, "resy_parsed_expert")
  expect_identical(expert, resy_load_expert(
    scheme = "MiniScheme",
    version = "2026-09-21"
  ))
})

test_that("resy_load_expert prefers user storage over package storage", {
  local_store()
  
  resy_add_classification(apennine_json(), scheme = "MyScheme", version = "1.0")
  
  expert <- resy_load_expert(
    scheme = "MyScheme",
    version = "1.0",
    location = c("user", "package")
  )
  
  expect_s3_class(expert, "resy_parsed_expert")
})

test_that("location = 'package' only searches the package store", {
  local_store()
  
  resy_add_classification(apennine_json(), scheme = "MyScheme", version = "1.0")
  
  expect_error(
    resy_load_expert(scheme = "MyScheme", location = "package"),
    "No classifications found"
  )
})

# ---- Error handling ----------------------------------------------------------

test_that("resy_load_expert errors when the scheme is missing", {
  expect_error(
    resy_load_expert(scheme = "DefinitelyNotARealScheme"),
    "No classifications found for scheme: 'DefinitelyNotARealScheme'."
  )
})

test_that("resy_load_expert errors when the given version is missing", {
  expect_error(
    resy_load_expert(scheme = "Apennine-test", version = "9999-99-99"),
    "Classification not found for scheme='Apennine-test', version='9999-99-99'."
  )
})

test_that("resy_load_expert errors when a version directory has no expert file", {
  local_store()
  
  root <- RESY:::.resy_classifications_root("user")
  dir.create(file.path(root, "NoExpert", "v0"), recursive = TRUE, showWarnings = FALSE)
  
  expect_error(
    resy_load_expert(scheme = "NoExpert", version = "v0"),
    "No expert file \\(json/txt\\) found for scheme='NoExpert', version='v0'."
  )
})

# ---- Internal dispatch -------------------------------------------------------

test_that(".resy_parse_by_ext handles JSON and TXT files", {
  json_path <- apennine_json()
  txt_path <- mini_txt()
  
  expect_s3_class(RESY:::.resy_parse_by_ext(json_path), "resy_parsed_expert")
  expect_s3_class(RESY:::.resy_parse_by_ext(txt_path), "resy_parsed_expert")
  
  tmp <- tempfile(fileext = ".dat")
  writeLines("dummy", tmp)
  expect_s3_class(RESY:::.resy_parse_by_ext(tmp), "resy_parsed_expert")
})
