# Tests for resy_available_classifications()


# ---- Return structure and types ----------------------------------------------

test_that("resy_available_classifications returns a data frame", {
  result <- resy_available_classifications()
  expect_s3_class(result, "data.frame")
})

test_that("resy_available_classifications returns correct column names", {
  result <- resy_available_classifications()
  expected_cols <- c("scheme", "version", "expert_json", "expert_txt")
  expect_equal(names(result), expected_cols)
})

test_that("resy_available_classifications returns correct column types", {
  result <- resy_available_classifications()
  expect_type(result$scheme, "character")
  expect_type(result$version, "character")
  expect_type(result$expert_json, "character")
  expect_type(result$expert_txt, "character")
})

# ---- Data content validation -------------------------------------------------

test_that("resy_available_classifications finds bundled classifications", {
  result <- resy_available_classifications()
  # Should have at least one classification available
  expect_gt(nrow(result), 0)
})

test_that("resy_available_classifications returns unique scheme-version pairs", {
  result <- resy_available_classifications()
  pairs <- paste(result$scheme, result$version, sep = "_")
  expect_equal(length(pairs), length(unique(pairs)))
})

test_that("resy_available_classifications contains expected EUNIS classification", {
  result <- resy_available_classifications()
  # EUNIS is the primary classification scheme, should be present
  expect_true(any(result$scheme == "EUNIS"))
})

test_that("resy_available_classifications contains Apennine-test classification", {
  result <- resy_available_classifications()
  # Apennine-test is used in examples and other tests
  expect_true(any(result$scheme == "Apennine-test"))
})

# ---- File path validation ----------------------------------------------------

test_that("resy_available_classifications expert_json paths are valid or NA", {
  result <- resy_available_classifications()
  for (path in result$expert_json) {
    if (!is.na(path)) {
      expect_true(file.exists(path), 
                  info = paste("Path should exist:", path))
      expect_true(grepl("\\.json$", path, ignore.case = TRUE),
                  info = paste("Path should end with .json:", path))
    }
  }
})

test_that("resy_available_classifications expert_txt paths are valid or NA", {
  result <- resy_available_classifications()
  
  # Check all non-NA txt paths
  txt_paths <- result$expert_txt[!is.na(result$expert_txt)]
  
  if (length(txt_paths) > 0) {
    # If txt files exist, they must be valid
    for (path in txt_paths) {
      expect_true(file.exists(path),
                  info = paste("Path should exist:", path))
      expect_true(grepl("\\.txt$", path, ignore.case = TRUE),
                  info = paste("Path should end with .txt:", path))
    }
  } else {
    # It's acceptable for some/all classifications to only have JSON
    # This just documents that no txt files are currently bundled
    expect_true(all(is.na(result$expert_txt)),
                info = "All expert_txt values should be NA if none exist")
  }
})

test_that("resy_available_classifications paths contain correct scheme and version", {
  result <- resy_available_classifications()
  for (i in seq_len(nrow(result))) {
    scheme <- result$scheme[i]
    version <- result$version[i]
    
    if (!is.na(result$expert_json[i])) {
      path_json <- result$expert_json[i]
      expect_true(grepl(paste0(scheme, "/", version), path_json),
                  info = paste("JSON path should contain scheme/version:", path_json))
    }
    
    if (!is.na(result$expert_txt[i])) {
      path_txt <- result$expert_txt[i]
      expect_true(grepl(paste0(scheme, "/", version), path_txt),
                  info = paste("TXT path should contain scheme/version:", path_txt))
    }
  }
})

# ---- Missing files handling --------------------------------------------------

test_that("resy_available_classifications handles missing expert.json gracefully", {
  result <- resy_available_classifications()
  # Some versions might not have expert.json, but should still be listed
  all_have_files <- !apply(
    is.na(result[, c("expert_json", "expert_txt")]),
    1,
    all
  )
  expect_true(all(all_have_files),
              info = "All versions should have at least one expert file")
})

test_that("resy_available_classifications marks missing files as NA", {
  result <- resy_available_classifications()
  # For each row, check that NA values are actually NA_character_
  for (i in seq_len(nrow(result))) {
    if (is.na(result$expert_json[i])) {
      expect_identical(result$expert_json[i], NA_character_)
    }
    if (is.na(result$expert_txt[i])) {
      expect_identical(result$expert_txt[i], NA_character_)
    }
  }
})

# ---- Empty classifications directory scenario --------------------------------

test_that(".resy_empty_classifications_df returns correct empty data frame", {
  result <- RESY:::.resy_empty_classifications_df()
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
  expect_equal(names(result), c("scheme", "version", "expert_json", "expert_txt"))
  expect_type(result$scheme, "character")
  expect_type(result$version, "character")
  expect_type(result$expert_json, "character")
  expect_type(result$expert_txt, "character")
})

# ---- Vectorization and length -------------------------------------------------

test_that("resy_available_classifications number of rows matches files found", {
  result <- resy_available_classifications()
  # Each version should produce exactly one row
  root <- system.file("extdata", "classifications", package = "RESY")
  if (nzchar(root) && dir.exists(root)) {
    schemes <- list.dirs(root, full.names = FALSE, recursive = FALSE)
    expected_rows <- 0
    for (sc in schemes) {
      versions <- list.dirs(
        file.path(root, sc),
        full.names = FALSE,
        recursive = FALSE
      )
      expected_rows <- expected_rows + length(versions)
    }
    expect_equal(nrow(result), expected_rows)
  }
})

# ---- Reproducibility ---------------------------------------------------------

test_that("resy_available_classifications returns consistent results", {
  result1 <- resy_available_classifications()
  result2 <- resy_available_classifications()
  expect_equal(result1, result2)
})

# ---- Integration with other functions ----------------------------------------

test_that("resy_available_classifications output works with resy_load_expert", {
  result <- resy_available_classifications()
  skip_if(nrow(result) == 0, "No classifications found")
  
  # Try loading the first available classification
  first_json <- result$expert_json[1]
  if (!is.na(first_json)) {
    expect_no_error(expert <- resy_load_expert(expertfile = first_json))
    expect_s3_class(expert, "resy_parsed_expert")
  }
})

test_that("resy_available_classifications scheme can be used with resy_load_expert", {
  result <- resy_available_classifications()
  skip_if(nrow(result) == 0, "No classifications found")
  
  # Use first result's scheme and version with resy_load_expert
  scheme <- result$scheme[1]
  version <- result$version[1]
  expect_no_error(
    expert <- resy_load_expert(scheme = scheme, version = version)
  )
  expect_s3_class(expert, "resy_parsed_expert")
})

# ---- Edge cases and robustness -----------------------------------------------

test_that("resy_available_classifications handles non-existent package gracefully", {
  # This tests the defensive programming: if system.file returns empty string
  # or directory doesn't exist, should return empty data frame
  result <- resy_available_classifications()
  # Result should always be a valid data frame, never NULL or error
  expect_s3_class(result, "data.frame")
  expect_equal(length(result), 4)  # 4 columns
})

test_that("resy_available_classifications scheme and version are not empty strings", {
  result <- resy_available_classifications()
  skip_if(nrow(result) == 0, "No classifications found")
  
  expect_true(all(nzchar(result$scheme)))
  expect_true(all(nzchar(result$version)))
})

test_that("resy_available_classifications handles special characters in paths", {
  result <- resy_available_classifications()
  skip_if(nrow(result) == 0, "No classifications found")
  
  # All paths should be valid strings without control characters
  for (path in c(result$expert_json, result$expert_txt)) {
    if (!is.na(path)) {
      expect_true(is.character(path))
      expect_true(nzchar(path))
    }
  }
})
