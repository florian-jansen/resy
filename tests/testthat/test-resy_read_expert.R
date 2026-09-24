library(testthat)

test_that("reads a preamble-only file and detects line feed (LF) or carriage
          return + line feed (CRLF) terminator", {
  tmp <- tempfile(fileext = ".txt")
  text <- "Just some preamble\nAnother line\n"
  cat(text, file = tmp, sep = "")
  
  res <- resy_read_expert(tmp)
  
  expect_s3_class(res, "resy_expert")
  expect_equal(length(res$sections), 0L)
  expect_equal(res$preamble, c("Just some preamble", "Another line"))
  # Accept either LF or CRLF depending on platform / how the file was written
  expect_true(res$meta$line_terminator %in% c("\n", "\r\n"))
  expect_true(res$meta$trailing_newline)
})

test_that("parses Section 1 aggregations and produces entries", {
  tmp <- tempfile(fileext = ".txt")
  text <- paste0(
    "SECTION 1: Species\n",
    "Quercus robur -  1\n",
    "Quercus pedunculata 0\n",
    "\n",
    "SECTION 1: End\n"
  )
  cat(text, file = tmp, sep = "")
  
  res <- resy_read_expert(tmp, entries = TRUE)
  expect_equal(length(res$sections), 1L)
  
  sec <- res$sections[[1]]
  expect_equal(sec$number, 1L)
  expect_equal(sec$name, "Species")
  expect_equal(length(sec$body_lines), 3L)
  expect_false(is.na(sec$end_line))
  
  expect_true(!is.null(sec$entries))
  expect_equal(length(sec$entries), 1L)
  entry <- sec$entries[[1]]
  expect_equal(entry$canonical, "Quercus robur")
  expect_equal(entry$synonyms, "Quercus pedunculata")
  expect_equal(entry$canonical_code, "-  1")
  expect_equal(entry$synonym_codes, "0")
})

test_that("handles unterminated sections correctly", {
  tmp <- tempfile(fileext = ".txt")
  text <- paste0(
    "SECTION 2: MyGroup\n",
    "member-a\n",
    "member-b\n"
    # no SECTION 2: End
  )
  cat(text, file = tmp, sep = "")
  
  res <- resy_read_expert(tmp, entries = TRUE)
  expect_equal(length(res$sections), 1L)
  sec <- res$sections[[1]]
  expect_true(is.na(sec$end_line))
  expect_equal(length(sec$body_lines), 2L)
})

test_that("entries = FALSE omits the structured entries view", {
  tmp <- tempfile(fileext = ".txt")
  text <- paste0(
    "SECTION 1: Species\n",
    "A -  1\n",
    "\n",
    "SECTION 1: End\n"
  )
  cat(text, file = tmp, sep = "")
  
  res <- resy_read_expert(tmp, entries = FALSE)
  sec <- res$sections[[1]]
  expect_null(sec$entries)
})
