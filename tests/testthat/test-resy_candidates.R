test_that("resy_candidates returns all candidate rows by default", {
  res <- structure(
    list(
      result = list(p1 = 1, p2 = 1),
      candidates = data.table::data.table(
        plot_id      = c("p1", "p1", "p2", "p2"),
        type         = c("A", "B", "C", "D"),
        priority    = c("high", "mid", "low", "very low"),
        priority_rank = c(1L, 2L, 1L, 2L)
      )
    ),
    class = "resy_result"
  )
  
  out <- resy_candidates(res)
  
  expect_s3_class(out, "data.table")
  expect_identical(
    names(out),
    c("plot_id", "type", "priority", "priority_rank")
  )
  expect_equal(out$plot_id, c("p1", "p1", "p2", "p2"))
  expect_equal(out$type, c("A", "B", "C", "D"))
})

test_that("resy_candidates filters by plot_id", {
  res <- structure(
    list(
      result = list(p1 = 1, p2 = 1),
      candidates = data.table::data.table(
        plot_id      = c("p1", "p1", "p2", "p2"),
        type         = c("A", "B", "C", "D"),
        priority    = c("high", "mid", "low", "very low"),
        priority_rank = c(1L, 2L, 1L, 2L)
      )
    ),
    class = "resy_result"
  )
  
  out <- resy_candidates(res, plot_id = "p1")
  
  expect_equal(unique(out$plot_id), "p1")
  expect_setequal(out$type, c("A", "B"))
})

test_that("resy_candidates supports priority = n and keeps at most one row per plot", {
  res <- structure(
    list(
      result = list(p1 = 1, p2 = 1),
      candidates = data.table::data.table(
        plot_id      = c("p1", "p1", "p2", "p2"),
        type         = c("A", "B", "C", "D"),
        priority    = c("high", "mid", "low", "very low"),
        priority_rank = c(1L, 1L, 2L, 2L)
      )
    ),
    class = "resy_result"
  )
  
  out <- resy_candidates(res, priority = 1L)
  
  expect_equal(out$plot_id, "p1")
  expect_equal(out$type, "A")
  expect_equal(out$priority_rank, 1L)
})

test_that("resy_candidates supports min_priority", {
  res <- structure(
    list(
      result = list(p1 = 1, p2 = 1),
      candidates = data.table::data.table(
        plot_id      = c("p1", "p1", "p2", "p2"),
        type         = c("A", "B", "C", "D"),
        priority    = c("high", "mid", "low", "very low"),
        priority_rank = c(1L, 2L, 1L, 2L)
      )
    ),
    class = "resy_result"
  )
  
  out <- resy_candidates(res, min_priority = 2L)
  
  expect_true(all(out$priority_rank >= 2L))
  expect_setequal(out$type, c("B", "D"))
})

test_that("resy_candidates limits rows per plot with top_n", {
  res <- structure(
    list(
      result = list(p1 = 1, p2 = 1),
      candidates = data.table::data.table(
        plot_id      = c("p1", "p1", "p2", "p2"),
        type         = c("A", "B", "C", "D"),
        priority    = c("high", "mid", "low", "very low"),
        priority_rank = c(1L, 2L, 1L, 2L)
      )
    ),
    class = "resy_result"
  )
  
  out <- resy_candidates(res, top_n = 1L)
  
  expect_equal(table(out$plot_id), c(p1 = 1L, p2 = 1L))
  expect_true(all(out$priority_rank %in% c(1L, 2L)))
})

test_that("resy_candidates rejects contradictory priority filters", {
  res <- structure(
    list(
      result = list(p1 = 1),
      candidates = data.table::data.table(
        plot_id      = "p1",
        type         = "A",
        priority    = "high",
        priority_rank = 1L
      )
    ),
    class = "resy_result"
  )
  
  expect_error(
    resy_candidates(res, priority = 1L, min_priority = 1L),
    "Use only one of 'priority' or 'min_priority'."
  )
})

test_that("resy_candidates errors if no candidate table is present", {
  res <- structure(
    list(result = list(p1 = 1)),
    class = "resy_result"
  )
  
  expect_error(
    resy_candidates(res),
    "No candidate table found in result"
  )
})
