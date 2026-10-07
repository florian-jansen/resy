test_that(".resy_classify_choice returns '?' for empty input", {
  priority <- factor(c(1, 2, 3), levels = c(1, 2, 3))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(character(0), priority, names)
  expect_equal(result, "?")
})

test_that(".resy_classify_choice returns single match unchanged", {
  priority <- factor(c(1, 2, 3), levels = c(1, 2, 3))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice("T1", priority, names)
  expect_equal(result, "T1")
})

test_that(".resy_classify_choice with single match returns as character", {
  priority <- factor(c(1, 2, 3), levels = c(1, 2, 3))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T2"), priority, names)
  expect_equal(result, "T2")
})

test_that(".resy_classify_choice selects unique match at last level among multiple matches", {
  # Levels examined in reverse: 3, 2, 1. T2 is unique at level 2
  # (level 3 has no match among c("T1", "T2")).
  priority <- factor(c(1, 2, 3), levels = c(1, 2, 3))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T1", "T2"), priority, names)
  expect_equal(result, "T2")
})

test_that(".resy_classify_choice with non-sequential priorities", {
  # Levels examined in reverse: 5, 3, 1. T3 is unique at level 5.
  priority <- factor(c(1, 3, 5), levels = c(1, 3, 5))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T2", "T3"), priority, names)
  expect_equal(result, "T3")
})

test_that(".resy_classify_choice returns '+' when tied at a level", {
  # T1 and T2 both have priority 1, no unique match at any level
  priority <- factor(c(1, 1, 3), levels = c(1, 3))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T1", "T2"), priority, names)
  expect_equal(result, "+")
})

test_that(".resy_classify_choice with all matches at same priority", {
  priority <- factor(c(1, 1, 1), levels = c(1))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T2", "T3"), priority, names)
  expect_equal(result, "+")
})

test_that(".resy_classify_choice with three priorities and three matches", {
  # Levels examined in reverse: 3 first. T3 is unique at level 3.
  priority <- factor(c(1, 2, 3), levels = c(1, 2, 3))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T1", "T2", "T3"), priority, names)
  expect_equal(result, "T3")
})

test_that(".resy_classify_choice skips tied priority level and uses next", {
  # Levels examined in reverse: C, B, A.
  # T1 and T2 tied at A, T3 unique at B, T4 unique at C (no match).
  # First unique level reached in reverse order is B -> T3.
  priority <- factor(c("A", "A", "B", "C"), levels = c("A", "B", "C"))
  names <- c("T1", "T2", "T3", "T4")
  result <- .resy_classify_choice(c("T1", "T2", "T3"), priority, names)
  expect_equal(result, "T3")
})

test_that(".resy_classify_choice with string priority levels", {
  # Levels examined in reverse: low, medium, high. T3 is at "low".
  priority <- factor(c("high", "medium", "low"), levels = c("high", "medium", "low"))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T2", "T3"), priority, names)
  expect_equal(result, "T3")
})

test_that(".resy_classify_choice returns '+' when all matches share one level", {
  priority <- factor(c(1, 2, 2), levels = c(1, 2))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T2", "T3"), priority, names)
  expect_equal(result, "+")
})

test_that(".resy_classify_choice with many types and priorities", {
  # T4, T5, T6 all have priority 2, no unique match at any level
  priority <- factor(c(1, 1, 1, 2, 2, 2, 3, 3, 4, 5),
                     levels = c(1, 2, 3, 4, 5))
  names <- c("T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8", "T9", "T10")
  result <- .resy_classify_choice(c("T4", "T5", "T6"), priority, names)
  expect_equal(result, "+")
})

test_that(".resy_classify_choice uses fastmatch internally", {
  # Levels examined in reverse: 3 first. TypeA is at level 3 and unique.
  priority <- factor(c(3, 1, 2), levels = c(1, 2, 3))
  names <- c("TypeA", "TypeB", "TypeC")
  result <- .resy_classify_choice(c("TypeA", "TypeB"), priority, names)
  expect_equal(result, "TypeA")
})

test_that(".resy_classify_choice with reordered names", {
  # Levels examined in reverse: 3 first. Third is at level 3 and unique.
  priority <- factor(c(2, 1, 3), levels = c(1, 2, 3))
  names <- c("First", "Second", "Third")
  result <- .resy_classify_choice(c("First", "Second", "Third"), priority, names)
  expect_equal(result, "Third")
})

test_that(".resy_classify_choice returns unique match at last examined level", {
  # Levels examined in reverse: 3 first. T3 is unique at level 3.
  priority <- factor(c(1, 2, 3), levels = c(1, 2, 3))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T2", "T3"), priority, names)
  expect_equal(result, "T3")
})

test_that(".resy_classify_choice handles reversed priority order", {
  # Levels examined in reverse: 1 first. T5 is at level 1 and unique.
  priority <- factor(c(5, 4, 3, 2, 1), levels = c(5, 4, 3, 2, 1))
  names <- c("T1", "T2", "T3", "T4", "T5")
  result <- .resy_classify_choice(c("T1", "T5"), priority, names)
  expect_equal(result, "T5")
})

test_that(".resy_classify_choice with duplicate names in matches", {
  # Levels examined in reverse: 2, then 1. T2 is unique at level 2.
  priority <- factor(c(1, 2, 2), levels = c(1, 2))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T1", "T2"), priority, names)
  expect_equal(result, "T2")
})

test_that(".resy_classify_choice with all same priority", {
  priority <- factor(c(1, 1, 1), levels = c(1))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T1", "T2", "T3"), priority, names)
  expect_equal(result, "+")
})

test_that(".resy_classify_choice with numeric names", {
  # Levels examined in reverse: 3, 2, 1. "2" is unique at level 2.
  priority <- factor(c(1, 2, 3), levels = c(1, 2, 3))
  names <- c("1", "2", "3")
  result <- .resy_classify_choice(c("1", "2"), priority, names)
  expect_equal(result, "2")
})

test_that(".resy_classify_choice returns character scalar", {
  priority <- factor(c(1, 2, 3), levels = c(1, 2, 3))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T1", "T2"), priority, names)
  expect_type(result, "character")
  expect_length(result, 1)
})

test_that(".resy_classify_choice with only two matches", {
  # Levels examined in reverse: 3 first. T3 is unique at level 3.
  priority <- factor(c(1, 2, 3), levels = c(1, 2, 3))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T2", "T3"), priority, names)
  expect_equal(result, "T3")
})

test_that(".resy_classify_choice with many tied at some levels, unique winner at another", {
  # Levels examined in reverse: C, B, A.
  # T1, T2 tied at A; T3, T4 tied at B; T5 unique at C -> T5 wins.
  priority <- factor(c("A", "A", "B", "B", "C"), levels = c("A", "B", "C"))
  names <- c("T1", "T2", "T3", "T4", "T5")
  result <- .resy_classify_choice(c("T1", "T2", "T3", "T4", "T5"), priority, names)
  expect_equal(result, "T5")
})

test_that(".resy_classify_choice returns correct name from match vector", {
  # Levels examined in reverse: 3 first. VegType_C is unique at level 3.
  priority <- factor(c(1, 2, 3), levels = c(1, 2, 3))
  names <- c("VegType_A", "VegType_B", "VegType_C")
  result <- .resy_classify_choice(c("VegType_B", "VegType_C"), priority, names)
  expect_equal(result, "VegType_C")
})

test_that(".resy_classify_choice with special characters in names", {
  # Levels examined in reverse: 3, 2, 1. T.2 is unique at level 2.
  priority <- factor(c(1, 2, 3), levels = c(1, 2, 3))
  names <- c("T-1", "T.2", "T_3")
  result <- .resy_classify_choice(c("T-1", "T.2"), priority, names)
  expect_equal(result, "T.2")
})

test_that(".resy_classify_choice precedence ordering", {
  # Levels examined in reverse: 3 first. Low is at level 3 and unique
  # among the matches.
  priority <- factor(c(3, 2, 1), levels = c(1, 2, 3))
  names <- c("Low", "Medium", "High")
  result <- .resy_classify_choice(c("Low", "High"), priority, names)
  expect_equal(result, "Low")
})

test_that(".resy_classify_choice with single element vector for priority", {
  priority <- factor(c(1), levels = c(1))
  names <- c("OnlyType")
  result <- .resy_classify_choice("OnlyType", priority, names)
  expect_equal(result, "OnlyType")
})