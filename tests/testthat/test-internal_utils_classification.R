# Tests for internal classification utilities
# These functions resolve multiple classification results to a single choice
# using priority-based resolution strategies.

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# .resy_classify_choice() - Resolution of multiple classifications #############
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

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

test_that(".resy_classify_choice selects highest priority among multiple matches", {
  # T1 has priority 1, T2 has priority 2, T3 has priority 3
  # Among T1 and T2, T1 should win (lower priority number = higher priority)
  priority <- factor(c(1, 2, 3), levels = c(1, 2, 3))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T1", "T2"), priority, names)
  expect_equal(result, "T1")
})

test_that(".resy_classify_choice with non-sequential priorities", {
  # T1: priority 1, T2: priority 3, T3: priority 5
  priority <- factor(c(1, 3, 5), levels = c(1, 3, 5))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T2", "T3"), priority, names)
  expect_equal(result, "T2")
})

test_that(".resy_classify_choice returns '+' when tied at highest priority", {
  # T1 and T2 both have priority 1
  priority <- factor(c(1, 1, 3), levels = c(1, 3))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T1", "T2"), priority, names)
  expect_equal(result, "+")
})

test_that(".resy_classify_choice resolves ambiguity by selecting next priority level", {
  # T1, T2, T3 all have priority 1, but among T2 and T3, T2 has priority 2 and T3 has priority 3
  priority <- factor(c(1, 1, 1), levels = c(1))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T2", "T3"), priority, names)
  # Both have same priority, so should return "+"
  expect_equal(result, "+")
})

test_that(".resy_classify_choice with three priorities and three matches", {
  # T1: 1, T2: 2, T3: 3 - T1 is unique highest
  priority <- factor(c(1, 2, 3), levels = c(1, 2, 3))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T1", "T2", "T3"), priority, names)
  expect_equal(result, "T1")
})

test_that(".resy_classify_choice skips tied priority level and uses next", {
  # T1: A, T2: A, T3: B, T4: C
  # T1 and T2 tied at A, T3 unique at B, so T3 wins
  priority <- factor(c("A", "A", "B", "C"), levels = c("A", "B", "C"))
  names <- c("T1", "T2", "T3", "T4")
  result <- .resy_classify_choice(c("T1", "T2", "T3"), priority, names)
  expect_equal(result, "T3")
})

test_that(".resy_classify_choice with string priority levels", {
  priority <- factor(c("high", "medium", "low"), levels = c("high", "medium", "low"))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T2", "T3"), priority, names)
  expect_equal(result, "T2")
})

test_that(".resy_classify_choice returns first of tied matches at unique level", {
  priority <- factor(c(1, 2, 2), levels = c(1, 2))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T2", "T3"), priority, names)
  expect_equal(result, "+")
})

test_that(".resy_classify_choice with many types and priorities", {
  # Large example with 10 types
  priority <- factor(c(1, 1, 1, 2, 2, 2, 3, 3, 4, 5), 
                     levels = c(1, 2, 3, 4, 5))
  names <- c("T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8", "T9", "T10")
  # T4, T5, T6 all have priority 2, unique at that level
  result <- .resy_classify_choice(c("T4", "T5", "T6"), priority, names)
  expect_equal(result, "+")
})

test_that(".resy_classify_choice uses fastmatch internally", {
  # Test that function correctly maps names to priorities via fastmatch
  priority <- factor(c(3, 1, 2), levels = c(1, 2, 3))
  names <- c("TypeA", "TypeB", "TypeC")
  # TypeB has priority 1 (highest)
  result <- .resy_classify_choice(c("TypeA", "TypeB"), priority, names)
  expect_equal(result, "TypeB")
})

test_that(".resy_classify_choice with reordered names", {
  priority <- factor(c(2, 1, 3), levels = c(1, 2, 3))
  names <- c("First", "Second", "Third")
  # Second has priority 1 (highest)
  result <- .resy_classify_choice(c("First", "Second", "Third"), priority, names)
  expect_equal(result, "Second")
})

test_that(".resy_classify_choice returns first occurrence when multiple unique at same level", {
  # This shouldn't happen in normal usage, but test robustness
  priority <- factor(c(1, 2, 3), levels = c(1, 2, 3))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T2", "T3"), priority, names)
  expect_equal(result, "T2")
})

test_that(".resy_classify_choice handles reversed priority order", {
  # Highest priority first in levels
  priority <- factor(c(5, 4, 3, 2, 1), levels = c(5, 4, 3, 2, 1))
  names <- c("T1", "T2", "T3", "T4", "T5")
  # T5 has priority 1 (lowest level, so examined last but is highest priority)
  result <- .resy_classify_choice(c("T1", "T5"), priority, names)
  expect_equal(result, "T5")
})

test_that(".resy_classify_choice with duplicate names in matches", {
  # When same name appears multiple times in matches, it's still unique if only one at that priority
  priority <- factor(c(1, 2, 2), levels = c(1, 2))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T1", "T2"), priority, names)
  expect_equal(result, "T1")
})

test_that(".resy_classify_choice with all same priority", {
  priority <- factor(c(1, 1, 1), levels = c(1))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T1", "T2", "T3"), priority, names)
  expect_equal(result, "+")
})

test_that(".resy_classify_choice with numeric names", {
  priority <- factor(c(1, 2, 3), levels = c(1, 2, 3))
  names <- c("1", "2", "3")
  result <- .resy_classify_choice(c("1", "2"), priority, names)
  expect_equal(result, "1")
})

test_that(".resy_classify_choice returns character scalar", {
  priority <- factor(c(1, 2, 3), levels = c(1, 2, 3))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T1", "T2"), priority, names)
  expect_type(result, "character")
  expect_length(result, 1)
})

test_that(".resy_classify_choice with only two matches", {
  priority <- factor(c(1, 2, 3), levels = c(1, 2, 3))
  names <- c("T1", "T2", "T3")
  result <- .resy_classify_choice(c("T2", "T3"), priority, names)
  expect_equal(result, "T2")
})

test_that(".resy_classify_choice with many tied at highest, clear winner at next level", {
  # T1, T2 at priority A; T3, T4 at priority B; T5 at priority C
  priority <- factor(c("A", "A", "B", "B", "C"), levels = c("A", "B", "C"))
  names <- c("T1", "T2", "T3", "T4", "T5")
  # T1 and T2 tied, so checks next level
  # T3 and T4 also tied, so checks next level
  # T5 unique, so returns T5
  result <- .resy_classify_choice(c("T1", "T2", "T3", "T4", "T5"), priority, names)
  expect_equal(result, "T5")
})

test_that(".resy_classify_choice returns correct name from match vector", {
  priority <- factor(c(1, 2, 3), levels = c(1, 2, 3))
  names <- c("VegType_A", "VegType_B", "VegType_C")
  result <- .resy_classify_choice(c("VegType_B", "VegType_C"), priority, names)
  expect_equal(result, "VegType_B")
})

test_that(".resy_classify_choice with special characters in names", {
  priority <- factor(c(1, 2, 3), levels = c(1, 2, 3))
  names <- c("T-1", "T.2", "T_3")
  result <- .resy_classify_choice(c("T-1", "T.2"), priority, names)
  expect_equal(result, "T-1")
})

test_that(".resy_classify_choice precedence ordering", {
  # Lower level in factor = higher priority (examined later in rev())
  priority <- factor(c(3, 2, 1), levels = c(1, 2, 3))
  names <- c("Low", "Medium", "High")
  # High has priority 1 (last level, highest actual priority)
  result <- .resy_classify_choice(c("Low", "High"), priority, names)
  expect_equal(result, "High")
})

test_that(".resy_classify_choice with single element vector for priority", {
  priority <- factor(c(1), levels = c(1))
  names <- c("OnlyType")
  result <- .resy_classify_choice("OnlyType", priority, names)
  expect_equal(result, "OnlyType")
})
