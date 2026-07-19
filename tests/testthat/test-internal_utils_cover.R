# Tests for internal cover calculation utilities
# These functions calculate total vegetation cover from individual species/layer
# coverage values using the complement method for accounting overlaps.

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# .total_cover() - Calculate total cover from individual cover values #########
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

test_that(".total_cover with single species", {
  expect_equal(.total_cover(50), 50)
})

test_that(".total_cover with 100% single species", {
  expect_equal(.total_cover(100), 100)
})

test_that(".total_cover with 0% single species", {
  expect_equal(.total_cover(0), 0)
})

test_that(".total_cover with two non-overlapping species", {
  # With 50% and 30%, expected: 1 - (0.5 * 0.7) = 1 - 0.35 = 0.65 = 65%
  expect_equal(.total_cover(c(50, 30)), 65)
})

test_that(".total_cover with two 100% species", {
  # Both 100% means complete coverage: 1 - (0 * 0) = 1 = 100%
  expect_equal(.total_cover(c(100, 100)), 100)
})

test_that(".total_cover with two 0% species", {
  # Both 0% means no coverage: 1 - (1 * 1) = 0 = 0%
  expect_equal(.total_cover(c(0, 0)), 0)
})

test_that(".total_cover with 100% and 50% species", {
  # 100% and 50%: 1 - (0 * 0.5) = 1 = 100%
  expect_equal(.total_cover(c(100, 50)), 100)
})

test_that(".total_cover with 100% and 0% species", {
  # 100% and 0%: 1 - (0 * 1) = 1 = 100%
  expect_equal(.total_cover(c(100, 0)), 100)
})

test_that(".total_cover with three species example from documentation", {
  # c(60, 40, 20): 1 - (0.4 * 0.6 * 0.8) = 1 - 0.192 = 0.808 = 80.8%
  result <- .total_cover(c(60, 40, 20))
  expect_equal(result, 80.8)
})

test_that(".total_cover produces realistic vegetation plot result", {
  # Typical forest plot with multiple layers
  # Canopy 70%, Shrub 50%, Herb 30%
  result <- .total_cover(c(70, 50, 30))
  # 1 - (0.3 * 0.5 * 0.7) = 1 - 0.105 = 0.895 = 89.5%
  expect_equal(result, 89.5)
})

test_that(".total_cover with five species", {
  covers <- c(50, 40, 30, 20, 10)
  result <- .total_cover(covers)
  # 1 - (0.5 * 0.6 * 0.7 * 0.8 * 0.9)
  expected <- (1 - 0.5 * 0.6 * 0.7 * 0.8 * 0.9) * 100
  expect_equal(result, expected)
})

test_that(".total_cover with many species", {
  covers <- rep(10, 10)  # 10 species each with 10% cover
  result <- .total_cover(covers)
  # 1 - (0.9^10) = 1 - 0.3486784... ≈ 0.6513...
  expected <- (1 - 0.9^10) * 100
  expect_equal(result, round(expected, 10))
})

test_that(".total_cover returns numeric", {
  result <- .total_cover(50)
  expect_type(result, "double")
})

test_that(".total_cover returns scalar", {
  result <- .total_cover(c(50, 50, 50))
  expect_length(result, 1)
})

test_that(".total_cover with rounding to 10 decimal places", {
  # Create a case that would have floating point artifacts
  covers <- c(33.33, 66.67)
  result <- .total_cover(covers)
  # Check that it's rounded to 10 decimal places (no excessive precision)
  expect_equal(
    nchar(as.character(result)), nchar(as.character(round(result, 10)))
    )
})

test_that(".total_cover respects 10 decimal place rounding", {
  # Value that would have long decimal expansion
  result <- .total_cover(c(33.333333, 33.333333, 33.333333))
  # Result should be rounded to 10 decimals
  rounded_result <- round(result, 10)
  expect_equal(result, rounded_result)
})

test_that(".total_cover with very small covers", {
  result <- .total_cover(c(0.01, 0.01, 0.01))
  # 1 - (0.9999 * 0.9999 * 0.9999) ≈ 0.03
  expect_true(result > 0)
  expect_true(result < 0.1)
})

test_that(".total_cover with very high covers", {
  result <- .total_cover(c(99, 99, 99))
  # 1 - (0.01 * 0.01 * 0.01) = 1 - 0.000001 ≈ 99.9999%
  expect_true(result > 99.99)
  expect_equal(result, 100)
})

test_that(".total_cover approaches 100 with multiple high covers", {
  result <- .total_cover(c(95, 95, 95))
  expect_true(result > 99)
  expect_true(result <= 100)
})

test_that(".total_cover is always between 0 and 100", {
  test_cases <- list(
    c(0),
    c(50),
    c(100),
    c(25, 25, 25, 25),
    c(10, 20, 30, 40, 50),
    c(1, 2, 3, 4, 5, 85, 90, 95),
    c(99.9, 99.9, 99.9)
  )
  for (covers in test_cases) {
    result <- .total_cover(covers)
    expect_true(
      result >= 0 && result <= 100,
      label = paste("Cover", paste(covers, collapse = ","), "gives", result)
      )
  }
})

test_that(".total_cover monotonic property: more species increases total", {
  # Adding another species (or layer) should not decrease total cover
  result1 <- .total_cover(c(50, 30))
  result2 <- .total_cover(c(50, 30, 20))
  expect_true(result2 >= result1)
})

test_that(".total_cover monotonic property with many examples", {
  # Each addition should maintain or increase total
  result_1 <- .total_cover(50)
  result_2 <- .total_cover(c(50, 40))
  result_3 <- .total_cover(c(50, 40, 30))
  result_4 <- .total_cover(c(50, 40, 30, 20))
  
  expect_true(result_1 <= result_2)
  expect_true(result_2 <= result_3)
  expect_true(result_3 <= result_4)
})

test_that(".total_cover handles edge case of 50-50 split", {
  result <- .total_cover(c(50, 50))
  # 1 - (0.5 * 0.5) = 1 - 0.25 = 0.75 = 75%
  expect_equal(result, 75)
})

test_that(".total_cover handles fractional covers", {
  result <- .total_cover(c(12.5, 37.5, 50))
  # 1 - (0.875 * 0.625 * 0.5) = 1 - 0.2734375 = 0.7265625
  expected <- (1 - 0.875 * 0.625 * 0.5) * 100
  expect_equal(result, expected)
})

test_that(".total_cover handles negative values gracefully", {
  # Negative cover values are biologically nonsensical but shouldn't crash
  result <- .total_cover(c(-10, 50))
  # 1 - (1.1 * 0.5) = 1 - 0.55 = 0.45 = 45%
  expect_equal(result, 45)
})

test_that(".total_cover with value > 100", {
  # Values > 100 are biologically impossible but test robustness
  result <- .total_cover(c(150, 50))
  # 1 - (-0.5 * 0.5) = 1 - (-0.25) = 1.25 = 125%
  expect_equal(result, 125)
})

test_that(".total_cover sequential addition gives deterministic result", {
  # Same input order should give same result
  covers <- c(25, 45, 15, 10)
  result1 <- .total_cover(covers)
  result2 <- .total_cover(covers)
  expect_equal(result1, result2)
})

test_that(".total_cover with permuted input is order-independent", {
  # Order of input shouldn't matter mathematically
  covers <- c(60, 40, 20)
  result1 <- .total_cover(covers)
  result2 <- .total_cover(c(40, 60, 20))
  result3 <- .total_cover(c(20, 40, 60))
  expect_equal(result1, result2)
  expect_equal(result2, result3)
})

test_that(".total_cover practical forest canopy scenarios", {
  # Dense temperate forest
  dense_forest <- .total_cover(c(85, 50, 25))
  expect_true(dense_forest > 90)
  
  # Sparse shrubland
  sparse_shrub <- .total_cover(c(30, 15))
  expect_true(sparse_shrub < 50)
  
  # Grassland
  grassland <- .total_cover(70)
  expect_equal(grassland, 70)
})

test_that(".total_cover with zero-length input", {
  result <- .total_cover(numeric(0))
  # Empty input: 1 - prod(c()) = 1 - 1 = 0
  expect_equal(result, 0)
})

test_that(".total_cover with single zero", {
  result <- .total_cover(0)
  expect_equal(result, 0)
})

test_that(".total_cover with single 100", {
  result <- .total_cover(100)
  expect_equal(result, 100)
})

test_that(".total_cover documentation example 1", {
  # Single species example from documentation
  result <- .total_cover(50)
  expect_equal(result, 50)
})

test_that(".total_cover documentation example 2", {
  # Two species with overlapping coverage from documentation
  result <- .total_cover(c(50, 30))
  expect_equal(result, 65)
})

test_that(".total_cover documentation example 3", {
  # Multiple species example from documentation
  result <- .total_cover(c(60, 40, 20))
  expect_equal(result, 80.8)
})

test_that(".total_cover handles long vectors", {
  # 100 species with varying coverage
  covers <- seq(1, 100, length.out = 100)
  result <- .total_cover(covers)
  expect_true(result > 99)
  expect_true(result <= 100)
})

test_that(".total_cover numerical stability", {
  # Very small values should be handled stably
  tiny_covers <- c(0.0001, 0.0001, 0.0001)
  result <- .total_cover(tiny_covers)
  expect_true(result > 0)
  expect_true(result < 0.001)
})

test_that(".total_cover complements are calculated correctly", {
  # Verify the mathematical formula is implemented correctly
  # For covers c(60, 40): 1 - (0.4 * 0.6) = 1 - 0.24 = 0.76 = 76%
  result <- .total_cover(c(60, 40))
  expect_equal(result, 76)
})

test_that(".total_cover with identical repeating values", {
  # All same coverage
  result <- .total_cover(c(50, 50, 50, 50))
  # 1 - (0.5^4) = 1 - 0.0625 = 0.9375 = 93.75%
  expected <- (1 - 0.5^4) * 100
  expect_equal(result, expected)
})
