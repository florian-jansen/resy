# Tests for internal string utility functions
# These functions handle trimming of leading/trailing whitespace and patterns
# from character vectors.

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# trim() - Remove leading and trailing whitespace ##############################
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

test_that("trim removes leading and trailing spaces", {
  expect_equal(trim("  hello  "), "hello")
})

test_that("trim removes tabs and newlines", {
  expect_equal(trim("\t\nhello\t\n"), "hello")
})

test_that("trim preserves internal whitespace", {
  expect_equal(trim("  hello world  "), "hello world")
})

test_that("trim handles already trimmed strings", {
  expect_equal(trim("hello"), "hello")
})

test_that("trim handles empty strings", {
  expect_equal(trim(""), "")
})

test_that("trim handles strings with only whitespace", {
  expect_equal(trim("   "), "")
  expect_equal(trim("\t\n"), "")
})

test_that("trim vectorizes over character vector", {
  result <- trim(c("  a ", "b  ", " c ", "d"))
  expect_equal(result, c("a", "b", "c", "d"))
})

test_that("trim preserves NA values", {
  result <- trim(c("  a  ", NA, "  b  "))
  expect_equal(result, c("a", NA, "b"))
})

test_that("trim handles mixed whitespace", {
  expect_equal(trim(" \t hello \n "), "hello")
})

test_that("trim with multiple internal spaces", {
  expect_equal(trim("  hello   world  "), "hello   world")
})

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# trim.trailing() - Remove trailing whitespace and patterns ####################
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

test_that("trim.trailing removes trailing spaces", {
  expect_equal(trim.trailing("hello  "), "hello")
})

test_that("trim.trailing removes trailing digits", {
  expect_equal(trim.trailing("text 123"), "text")
})

test_that("trim.trailing removes space-hyphen-digit pattern", {
  expect_equal(trim.trailing("text - 1"), "text")
})

test_that("trim.trailing removes hyphen-space-digit pattern", {
  expect_equal(trim.trailing("text- 1"), "text-")
})

test_that("trim.trailing handles already trimmed strings", {
  expect_equal(trim.trailing("hello"), "hello")
})

test_that("trim.trailing preserves leading whitespace", {
  expect_equal(trim.trailing("  hello  "), "  hello")
})

test_that("trim.trailing preserves internal whitespace", {
  expect_equal(trim.trailing("hello world  "), "hello world")
})

test_that("trim.trailing handles empty strings", {
  expect_equal(trim.trailing(""), "")
})

test_that("trim.trailing handles strings with only whitespace", {
  expect_equal(trim.trailing("   "), "")
})

test_that("trim.trailing vectorizes over character vector", {
  result <- trim.trailing(c("text  ", "hello 123", "world - 5"))
  expect_equal(result, c("text", "hello", "world"))
})

test_that("trim.trailing preserves NA values", {
  result <- trim.trailing(c("hello  ", NA, "world 42"))
  expect_equal(result, c("hello", NA, "world"))
})

test_that("trim.trailing with only digit suffix", {
  expect_equal(trim.trailing("data 999"), "data")
})

test_that("trim.trailing with tab before digits", {
  expect_equal(trim.trailing("text\t123"), "text\t123")
})

test_that("trim.trailing with space-hyphen-space-digit", {
  expect_equal(trim.trailing("label - 7"), "label")
})

test_that("trim.trailing preserves hyphen in middle", {
  expect_equal(trim.trailing("hello-world "), "hello-world")
})

test_that("trim.trailing with numbers not at end", {
  expect_equal(trim.trailing("123hello "), "123hello")
})

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# trim.leading() - Remove leading whitespace ###################################
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

test_that("trim.leading removes leading spaces", {
  expect_equal(trim.leading("  hello"), "hello")
})

test_that("trim.leading removes leading tabs and newlines", {
  expect_equal(trim.leading("\t\nhello"), "hello")
})

test_that("trim.leading preserves trailing whitespace", {
  expect_equal(trim.leading("  hello  "), "hello  ")
})

test_that("trim.leading preserves internal whitespace", {
  expect_equal(trim.leading("  hello world"), "hello world")
})

test_that("trim.leading handles already trimmed strings", {
  expect_equal(trim.leading("hello"), "hello")
})

test_that("trim.leading handles empty strings", {
  expect_equal(trim.leading(""), "")
})

test_that("trim.leading handles strings with only whitespace", {
  expect_equal(trim.leading("   "), "")
  expect_equal(trim.leading("\t\n"), "")
})

test_that("trim.leading vectorizes over character vector", {
  result <- trim.leading(c("  a", "  b  ", "\tc"))
  expect_equal(result, c("a", "b  ", "c"))
})

test_that("trim.leading preserves NA values", {
  result <- trim.leading(c("  hello", NA, "  world"))
  expect_equal(result, c("hello", NA, "world"))
})

test_that("trim.leading with multiple leading spaces", {
  expect_equal(trim.leading("     hello"), "hello")
})

test_that("trim.leading with mixed leading whitespace", {
  expect_equal(trim.leading(" \t\n hello"), "hello")
})

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Interaction tests between trim functions #####################################
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

test_that("trim equals trim.leading then trim.trailing", {
  input <- "  hello world  "
  result1 <- trim(input)
  result2 <- trim.trailing(trim.leading(input))
  expect_equal(result1, result2)
})

test_that("trim.leading followed by trim.trailing on complex string", {
  input <- "  \t text 123  "
  result <- trim.trailing(trim.leading(input))
  expect_equal(result, "text")
})

test_that("chained trimming with vector", {
  input <- c("  a  ", "  b 42  ", "\t c - 1 ")
  result1 <- trim(input)
  result2 <- trim.trailing(trim.leading(input))
  expect_equal(result1, result2)
})

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Edge cases and special characters ############################################
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

test_that("trim handles Unicode whitespace characters", {
  # Testing with regular ASCII whitespace (most portable)
  expect_equal(trim("  hello  "), "hello")
})

test_that("trim preserves special characters", {
  expect_equal(trim("  @#$%^&*()  "), "@#$%^&*()")
})

test_that("trim.trailing preserves hyphens not in pattern", {
  expect_equal(trim.trailing("a-b-c "), "a-b-c")
})

test_that("trim.trailing with trailing newline", {
  expect_equal(trim.trailing("hello\n"), "hello")
})

test_that("trim.leading with leading special characters", {
  expect_equal(trim.leading("  @hello"), "@hello")
})

test_that("all trim functions handle zero-length input", {
  expect_equal(trim(character(0)), character(0))
  expect_equal(trim.leading(character(0)), character(0))
  expect_equal(trim.trailing(character(0)), character(0))
})

test_that("trim functions preserve case", {
  expect_equal(trim("  HELLO  "), "HELLO")
  expect_equal(trim.leading("  HeLLo"), "HeLLo")
  expect_equal(trim.trailing("HeLLo  "), "HeLLo")
})

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Performance and robustness ###################################################
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

test_that("trim handles very long strings", {
  long_string <- paste0(strrep(" ", 1000), "hello", strrep(" ", 1000))
  expect_equal(trim(long_string), "hello")
})

test_that("trim handles large vectors", {
  large_vec <- rep(c("  a  ", "  b  ", "  c  "), 100)
  result <- trim(large_vec)
  expect_length(result, 300)
  expect_true(all(result %in% c("a", "b", "c")))
})

test_that("trim.trailing with only spaces and digits", {
  expect_equal(trim.trailing("  42"), "")
})

test_that("trim.leading preserves content after spaces", {
  expect_equal(trim.leading("   hello-world-test"), "hello-world-test")
})
