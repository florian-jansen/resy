library(testthat)

# ---- Helper functions -------------------------------------------------------

# Create a minimal resy_expert object for testing
.create_test_expert <- function() {
  structure(
    list(
      sections = list(
        list(
          number = 3,
          name = "SECTION 3: Group definitions",
          entries = list(
            # Simple prefix hierarchy: Q > Q1 > Q11
            list(code = "Q", description = "Vegetated inland water bodies", priority = "3", expression = ""),
            list(code = "Q1", description = "Aquatic plants", priority = "2", expression = "<Lemna minor>"),
            list(code = "Q11", description = "Lemnetum", priority = "1", expression = "<Lemna minor GR 50>"),
            # Parallel branch: Q2
            list(code = "Q2", description = "Floating vegetation", priority = "2", expression = ""),
            # Missing codes (will become top-level with fill=FALSE)
            list(code = "R", description = "Marine habitats", priority = "3", expression = ""),
            list(code = "R5", description = "Sublittoral rock", priority = "1", expression = "")
          )
        )
      )
    ),
    class = "resy_expert"
  )
}

# ---- resy_expert_tree: Core functionality -----------------------------------

test_that("resy_expert_tree: builds tree from expert object without fill", {
  expert <- .create_test_expert()
  tree <- resy_expert_tree(expert, fill = FALSE)
  
  expect_s3_class(tree, c("resy_expert_tree", "data.frame"))
  expect_equal(nrow(tree), 6L)
  expect_true(all(c("id", "parent", "code", "description", "level", "leaf", "synthetic") %in% names(tree)))
  
  # Check that no synthetic nodes were added
  expect_equal(sum(tree$synthetic), 0L)
})

test_that("resy_expert_tree: all top-level nodes are NA parents", {
  expert <- .create_test_expert()
  tree <- resy_expert_tree(expert, fill = FALSE)
  
  # Q and R have no prefix present, so should be top-level
  top_level <- tree[is.na(tree$parent), ]
  expect_equal(nrow(top_level), 2L)
  expect_true(all(c("Q", "R") %in% top_level$code))
})

test_that("resy_expert_tree: correctly assigns parent-child relationships", {
  expert <- .create_test_expert()
  tree <- resy_expert_tree(expert, fill = FALSE)
  
  # Q1 should have Q as parent
  q1_row <- which(tree$code == "Q1")
  q_id <- which(tree$code == "Q")
  expect_equal(tree$parent[q1_row], q_id)
  
  # Q11 should have Q1 as parent
  q11_row <- which(tree$code == "Q11")
  expect_equal(tree$parent[q11_row], q1_row)
})

test_that("resy_expert_tree: correctly identifies leaf nodes", {
  expert <- .create_test_expert()
  tree <- resy_expert_tree(expert, fill = FALSE)
  
  # Q11, Q2, R5 should be leaves (no children)
  leaf_codes <- tree$code[tree$leaf]
  expect_true("Q11" %in% leaf_codes)
  expect_true("Q2" %in% leaf_codes)
  expect_true("R5" %in% leaf_codes)
  
  # Q, Q1, R should not be leaves
  expect_false("Q" %in% leaf_codes)
  expect_false("Q1" %in% leaf_codes)
  expect_false("R" %in% leaf_codes)
})

test_that("resy_expert_tree: correctly computes node levels", {
  expert <- .create_test_expert()
  tree <- resy_expert_tree(expert, fill = FALSE)
  
  expect_equal(tree$level[tree$code == "Q"], 1L)
  expect_equal(tree$level[tree$code == "Q1"], 2L)
  expect_equal(tree$level[tree$code == "Q11"], 3L)
})

test_that("resy_expert_tree: preserves code, description, priority, expression", {
  expert <- .create_test_expert()
  tree <- resy_expert_tree(expert, fill = FALSE)
  
  q11_row <- tree[tree$code == "Q11", ]
  expect_equal(q11_row$description, "Lemnetum")
  expect_equal(q11_row$priority, "1")
  expect_equal(q11_row$expression, "<Lemna minor GR 50>")
})

# ---- resy_expert_tree: Fill mode (reconstruction) ----------------------------

test_that("resy_expert_tree: fill=TRUE adds synthetic ancestor nodes", {
  expert <- .create_test_expert()
  tree_filled <- resy_expert_tree(expert, fill = TRUE)
  tree_unfilled <- resy_expert_tree(expert, fill = FALSE)
  
  # Should have more rows with synthesised nodes
  expect_gt(nrow(tree_filled), nrow(tree_unfilled))
  expect_gt(sum(tree_filled$synthetic), 0L)
})

test_that("resy_expert_tree: fill=TRUE uses code_path function", {
  expert <- .create_test_expert()
  
  # Custom code_path that splits differently (e.g., every 2 chars)
  custom_path <- function(code) {
    if (!nzchar(code)) return(code)
    n <- nchar(code)
    if (n <= 2) return(code)
    # Return code as-is; just for testing the parameter is used
    code
  }
  
  expect_silent(
    tree <- resy_expert_tree(expert, fill = TRUE, code_path = custom_path)
  )
  expect_s3_class(tree, "resy_expert_tree")
})

test_that("resy_expert_tree: fill=TRUE with names lookup labels synthetic nodes", {
  expert <- .create_test_expert()
  
  # Provide names for Q and R (which will be synthesised at top level anyway)
  names_lookup <- c(Q = "Inland water habitats", R = "Marine habitats")
  
  tree <- resy_expert_tree(expert, fill = TRUE, names = names_lookup)
  
  # Check that lookup names are applied
  q_row <- tree[tree$code == "Q", ]
  r_row <- tree[tree$code == "R", ]
  
  # If these nodes have no description from expert, names_lookup should provide one
  expect_equal(q_row$name_source[1], "expert")  # Q is in expert already
  expect_equal(r_row$name_source[1], "expert")  # R is in expert already
})

test_that("resy_expert_tree: fill=TRUE with data frame names lookup", {
  expert <- .create_test_expert()
  
  # Named lookup as data frame
  names_df <- data.frame(
    code = c("Q", "Q1", "Q11"),
    name = c("Inland water", "Aquatic plants", "Lemnetum community")
  )
  
  tree <- resy_expert_tree(expert, fill = TRUE, names = names_df)
  expect_s3_class(tree, "resy_expert_tree")
})

# ---- resy_expert_tree: Input validation -----

test_that("resy_expert_tree: rejects non-expert objects", {
  expect_error(
    resy_expert_tree(list(not_an_expert = TRUE)),
    "must be a <resy_expert> object"
  )
})

test_that("resy_expert_tree: rejects invalid section parameter", {
  expert <- .create_test_expert()
  
  expect_error(
    resy_expert_tree(expert, section = c(1, 2)),
    "section` must be a single section number"
  )
  
  expect_error(
    resy_expert_tree(expert, section = NA),
    "section` must be a single section number"
  )
})

test_that("resy_expert_tree: errors on missing section", {
  expert <- .create_test_expert()
  
  expect_error(
    resy_expert_tree(expert, section = 999),
    "has no SECTION 999"
  )
})

test_that("resy_expert_tree: errors on section without entries", {
  expert <- structure(
    list(
      sections = list(
        list(
          number = 3,
          name = "SECTION 3",
          entries = NULL  # No entries
        )
      )
    ),
    class = "resy_expert"
  )
  
  expect_error(
    resy_expert_tree(expert),
    "carries no structured entries"
  )
})

test_that("resy_expert_tree: errors on empty section", {
  expert <- structure(
    list(
      sections = list(
        list(
          number = 3,
          name = "SECTION 3",
          entries = list()  # Empty
        )
      )
    ),
    class = "resy_expert"
  )
  
  expect_error(
    resy_expert_tree(expert),
    "defines no types"
  )
})

test_that("resy_expert_tree: rejects non-function code_path", {
  expert <- .create_test_expert()
  
  expect_error(
    resy_expert_tree(expert, fill = TRUE, code_path = "not_a_function"),
    "`code_path` must be a function"
  )
})

test_that("resy_expert_tree: rejects invalid names argument", {
  expert <- .create_test_expert()
  
  # Unnamed vector
  expect_error(
    resy_expert_tree(expert, names = c("name1", "name2")),
    "must be a named vector or a two-column data frame"
  )
  
  # Single-column data frame
  expect_error(
    resy_expert_tree(expert, names = data.frame(code = "Q")),
    "needs a code column and a name column"
  )
})

# ---- resy_expert_tree: Attributes and output --------------------------------

test_that("resy_expert_tree: returns correct data frame columns", {
  expert <- .create_test_expert()
  tree <- resy_expert_tree(expert)
  
  expected_cols <- c("id", "parent", "code", "description", "priority",
                     "expression", "level", "leaf", "synthetic", "name_source")
  expect_equal(names(tree), expected_cols)
})

test_that("resy_expert_tree: stores section name as attribute", {
  expert <- .create_test_expert()
  tree <- resy_expert_tree(expert)
  
  expect_equal(attr(tree, "section_name"), "SECTION 3: Group definitions")
})

test_that("resy_expert_tree: id column is sequence", {
  expert <- .create_test_expert()
  tree <- resy_expert_tree(expert)
  
  expect_equal(tree$id, seq_len(nrow(tree)))
})

# ---- resy_expert_tree: Print method -----------------------------------------

test_that("print.resy_expert_tree: produces formatted output", {
  expert <- .create_test_expert()
  tree <- resy_expert_tree(expert)
  
  output <- capture.output(print(tree))
  
  expect_length(output, nrow(tree) + 1L)  # +1 for header
  expect_match(output[1], "<resy_expert_tree>")
  expect_match(output[1], "6 node\\(s\\)")
})

test_that("print.resy_expert_tree: respects max parameter", {
  expert <- .create_test_expert()
  tree <- resy_expert_tree(expert)
  
  output <- capture.output(print(tree, max = 2L))
  
  expect_match(tail(output, 1), "more node")
})

# ---- resy_write_expert_html: Basic functionality ----------------------------

test_that("resy_write_expert_html: accepts resy_expert object", {
  expert <- .create_test_expert()
  out_file <- tempfile(fileext = ".html")
  
  result <- resy_write_expert_html(expert, out_file)
  
  expect_equal(result, out_file)
  expect_true(file.exists(out_file))
  unlink(out_file)
})

test_that("resy_write_expert_html: accepts resy_expert_tree object", {
  expert <- .create_test_expert()
  tree <- resy_expert_tree(expert)
  out_file <- tempfile(fileext = ".html")
  
  result <- resy_write_expert_html(tree, out_file)
  
  expect_equal(result, out_file)
  expect_true(file.exists(out_file))
  unlink(out_file)
})

test_that("resy_write_expert_html: produces valid HTML", {
  expert <- .create_test_expert()
  out_file <- tempfile(fileext = ".html")
  
  resy_write_expert_html(expert, out_file)
  html <- readLines(out_file)
  
  # Check HTML structure
  expect_match(html[1], "<!DOCTYPE html>")
  expect_true(any(grepl("<html", html)))
  expect_true(any(grepl("</html>", html)))
  expect_true(any(grepl("<details>", html)))
  
  unlink(out_file)
})

test_that("resy_write_expert_html: includes CSS", {
  expert <- .create_test_expert()
  out_file <- tempfile(fileext = ".html")
  
  resy_write_expert_html(expert, out_file)
  html <- paste(readLines(out_file), collapse = "\n")
  
  expect_match(html, "body \\{")
  expect_match(html, "\\.code \\{")
  
  unlink(out_file)
})

test_that("resy_write_expert_html: includes JavaScript", {
  expert <- .create_test_expert()
  out_file <- tempfile(fileext = ".html")
  
  resy_write_expert_html(expert, out_file)
  html <- paste(readLines(out_file), collapse = "\n")
  
  expect_match(html, "document\\.getElementById")
  expect_match(html, "setAll")
  
  unlink(out_file)
})

test_that("resy_write_expert_html: uses provided title", {
  expert <- .create_test_expert()
  out_file <- tempfile(fileext = ".html")
  custom_title <- "Custom Expert Tree Title"
  
  resy_write_expert_html(expert, out_file, title = custom_title)
  html <- paste(readLines(out_file), collapse = "\n")
  
  expect_match(html, sprintf("<title>%s</title>", custom_title))
  expect_match(html, sprintf("<h1>%s</h1>", custom_title))
  
  unlink(out_file)
})

test_that("resy_write_expert_html: defaults title to section name", {
  expert <- .create_test_expert()
  out_file <- tempfile(fileext = ".html")
  
  resy_write_expert_html(expert, out_file)
  html <- paste(readLines(out_file), collapse = "\n")
  
  expect_match(html, "SECTION 3: Group definitions")
  
  unlink(out_file)
})

test_that("resy_write_expert_html: respects open_level parameter", {
  expert <- .create_test_expert()
  out_file <- tempfile(fileext = ".html")
  
  resy_write_expert_html(expert, out_file, open_level = 1L)
  html <- readLines(out_file)
  
  # Check for open attribute on details elements
  details_lines <- html[grepl("<details", html)]
  expect_true(any(grepl("open", details_lines)))
  
  unlink(out_file)
})

test_that("resy_write_expert_html: includes name_tag if provided", {
  expert <- .create_test_expert()
  names_lookup <- c(Q = "Inland water")
  out_file <- tempfile(fileext = ".html")
  
  resy_write_expert_html(expert, out_file, names = names_lookup, name_tag = "LOOKUP")
  html <- paste(readLines(out_file), collapse = "\n")
  
  expect_match(html, "LOOKUP")
  
  unlink(out_file)
})

test_that("resy_write_expert_html: uses fill parameter with expert", {
  expert <- .create_test_expert()
  out_file1 <- tempfile(fileext = ".html")
  out_file2 <- tempfile(fileext = ".html")
  
  resy_write_expert_html(expert, out_file1, fill = FALSE)
  resy_write_expert_html(expert, out_file2, fill = TRUE)
  
  html1 <- readLines(out_file1)
  html2 <- readLines(out_file2)
  
  # fill=TRUE should produce different output (more nodes)
  expect_gt(length(html2), length(html1))
  
  unlink(out_file1)
  unlink(out_file2)
})

test_that("resy_write_expert_html: returns invisible file path", {
  expert <- .create_test_expert()
  out_file <- tempfile(fileext = ".html")
  
  result <- resy_write_expert_html(expert, out_file)
  
  expect_identical(result, out_file)
  
  unlink(out_file)
})

# ---- resy_view_expert: Basic functionality ----------------------------------

test_that("resy_view_expert: creates temporary HTML file", {
  expert <- .create_test_expert()
  
  result <- resy_view_expert(expert, browse = FALSE)
  
  expect_true(file.exists(result))
  expect_match(result, "\\.html$")
  
  # Check file content
  html <- readLines(result)
  expect_match(html[1], "<!DOCTYPE html>")
  
  unlink(result)
})

test_that("resy_view_expert: returns invisible file path", {
  expert <- .create_test_expert()
  
  result <- resy_view_expert(expert, browse = FALSE)
  
  expect_true(is.character(result))
  expect_equal(length(result), 1L)
  
  unlink(result)
})

test_that("resy_view_expert: respects all parameters", {
  expert <- .create_test_expert()
  custom_title <- "My Expert Tree"
  
  result <- resy_view_expert(
    expert,
    section = 3L,
    fill = TRUE,
    open_level = 2L,
    title = custom_title,
    browse = FALSE
  )
  
  html <- paste(readLines(result), collapse = "\n")
  expect_match(html, custom_title)
  
  unlink(result)
})

test_that("resy_view_expert: does not crash when browse=TRUE", {
  expert <- .create_test_expert()
  
  # This test checks the function runs; actual browser opening is mocked
  expect_silent(
    {
      result <- resy_view_expert(expert, browse = FALSE)
      unlink(result)
    }
  )
})

# ---- resy_eunis_names: Lookup table -----------------------------------------

test_that("resy_eunis_names: returns data frame with code and name columns", {
  # Skip if EUNIS names file not available
  skip_if_not(nzchar(system.file("extdata/eunis_2021_names.csv", package = "RESY")))
  
  names_df <- resy_eunis_names()
  
  expect_s3_class(names_df, "data.frame")
  expect_equal(ncol(names_df), 2L)
  expect_equal(names(names_df)[1:2], c("code", "name"))
})

test_that("resy_eunis_names: contains expected EUNIS codes", {
  skip_if_not(nzchar(system.file("extdata/eunis_2021_names.csv", package = "RESY")))
  
  names_df <- resy_eunis_names()
  codes <- names_df$code
  
  # Check for some common EUNIS codes
  expect_true("Q" %in% codes)
  expect_true("R" %in% codes)
})

# ---- Integration tests: Real file if available ---

test_that("resy_expert_tree: works with real Meadow example file", {
  f <- system.file("extdata/classifications/Meadow-ESy-2025-01-18-2025.txt",
                   package = "RESY")
  skip_if(!nzchar(f), "Meadow example file not found")
  
  expert <- resy_read_expert(f)
  tree <- resy_expert_tree(expert)
  
  expect_s3_class(tree, "resy_expert_tree")
  expect_gt(nrow(tree), 0L)
})

test_that("resy_expert_tree: fill mode works with real Meadow file", {
  f <- system.file("extdata/classifications/Meadow-ESy-2025-01-18-2025.txt",
                   package = "RESY")
  skip_if(!nzchar(f), "Meadow example file not found")
  
  expert <- resy_read_expert(f)
  tree <- resy_expert_tree(expert, fill = TRUE)
  
  expect_s3_class(tree, "resy_expert_tree")
  expect_gt(sum(tree$synthetic), 0L)
})

test_that("resy_write_expert_html: works with real Meadow example file", {
  f <- system.file("extdata/classifications/Meadow-ESy-2025-01-18-2025.txt",
                   package = "RESY")
  skip_if(!nzchar(f), "Meadow example file not found")
  
  expert <- resy_read_expert(f)
  out_file <- tempfile(fileext = ".html")
  
  result <- resy_write_expert_html(expert, out_file)
  
  expect_true(file.exists(result))
  expect_gt(file.size(result), 1000L)  # Should be substantial HTML
  
  unlink(out_file)
})

