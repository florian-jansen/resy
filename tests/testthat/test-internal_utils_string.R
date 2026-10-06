# Tests for internal string utility functions
# These functions trim leading/trailing whitespace and trailing artifacts from
# character vectors used internally by RESY.

test_that(".resy_trim removes leading and trailing whitespace", {
  expect_equal(RESY:::.resy_trim("  hello  "), "hello")
  expect_equal(RESY:::.resy_trim("\t\nhello\t\n"), "hello")
  expect_equal(
    RESY:::.resy_trim(c("  a ", "b  ", " c ", "d")),
    c("a", "b", "c", "d")
  )
  expect_equal(
    RESY:::.resy_trim(c("  a  ", NA, "  b  ")),
    c("a", NA, "b")
  )
})

test_that(".resy_trim preserves internal whitespace", {
  expect_equal(RESY:::.resy_trim("  hello world  "), "hello world")
  expect_equal(RESY:::.resy_trim("  hello   world  "), "hello   world")
})

test_that(".resy_trim handles empty values and whitespace-only strings", {
  expect_equal(RESY:::.resy_trim(""), "")
  expect_equal(RESY:::.resy_trim("   "), "")
  expect_equal(RESY:::.resy_trim(character(0)), character(0))
})

test_that(".resy_trim_trailing removes trailing spaces and matching artifacts", {
  expect_equal(RESY:::.resy_trim_trailing("hello  "), "hello")
  expect_equal(RESY:::.resy_trim_trailing("text 123"), "text")
  expect_equal(RESY:::.resy_trim_trailing("label - 7"), "label")
  expect_equal(RESY:::.resy_trim_trailing("hello world  "), "hello world")
  expect_equal(
    RESY:::.resy_trim_trailing(c("hello  ", NA, "world 42")),
    c("hello", NA, "world")
  )
})

test_that(".resy_trim_trailing does not remove non-matching hyphen patterns", {
  expect_equal(RESY:::.resy_trim_trailing("text- 1"), "text- 1")
  expect_equal(RESY:::.resy_trim_trailing("hello-world "), "hello-world")
})

test_that(".resy_trim_leading removes only leading whitespace", {
  expect_equal(RESY:::.resy_trim_leading("  hello"), "hello")
  expect_equal(RESY:::.resy_trim_leading(" \t\n hello"), "hello")
  expect_equal(RESY:::.resy_trim_leading("  hello  "), "hello  ")
  expect_equal(
    RESY:::.resy_trim_leading(c("  a", "  b  ", "\tc")),
    c("a", "b  ", "c")
  )
  expect_equal(
    RESY:::.resy_trim_leading(c("  hello", NA, "  world")),
    c("hello", NA, "world")
  )
})

test_that(".resy_trim_leading handles empty input and whitespace-only strings", {
  expect_equal(RESY:::.resy_trim_leading(""), "")
  expect_equal(RESY:::.resy_trim_leading("   "), "")
  expect_equal(RESY:::.resy_trim_leading(character(0)), character(0))
})
