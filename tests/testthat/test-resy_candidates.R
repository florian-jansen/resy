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
  
  # Function returns one row per plot from all_plots, even if no match for that priority
  # p1 has priority_rank=1, p2 does not, so p2 gets NA values
  expect_equal(out$plot_id, c("p1", "p2"))
  expect_equal(out$type, c("A", NA))
  expect_equal(out$priority_rank, c(1L, NA))
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
  
  expect_equal(as.vector(table(out$plot_id)), c(1L, 1L))
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
ranked_result <- function() {
  structure(
    list(
      result.classification = c(p1 = "B", p2 = "C", p3 = "?"),
      candidates = data.table::data.table(
        plot_id       = c("p1", "p1", "p1", "p2"),
        type          = c("B", "A", "D", "C"),
        priority      = c("5", "2", "1", "3"),
        priority_rank = c(3L, 2L, 1L, 2L)
      )
    ),
    class = "resy_result"
  )
}

test_that("top_n keeps the highest priorities", {
  out <- resy_candidates(ranked_result(), top_n = 1L)
  expect_equal(out$type, c("B", "C"))
})

test_that("wide = TRUE gives one row per plot, highest priority first", {
  out <- resy_candidates(ranked_result(), wide = TRUE)

  expect_equal(out$plot_id, c("p1", "p2", "p3"))
  expect_equal(names(out), c("plot_id", "classification",
                             "type_1", "priority_1", "type_2", "priority_2",
                             "type_3", "priority_3"))
  expect_equal(out$classification, c("B", "C", "?"))
  expect_equal(out$type_1, c("B", "C", NA))
  expect_equal(out$priority_1, c("5", "3", NA))
  expect_equal(out$type_3, c("D", NA, NA))
})

test_that("wide = TRUE applies top_n and plot_id", {
  out <- resy_candidates(ranked_result(), plot_id = "p1", top_n = 2L, wide = TRUE)
  expect_equal(nrow(out), 1L)
  expect_equal(unlist(out[, c("type_1", "type_2")], use.names = FALSE), c("B", "A"))
  expect_false("type_3" %in% names(out))
})

test_that("wide = TRUE without candidates lists the plots", {
  res <- ranked_result()
  res$candidates <- res$candidates[0]
  out <- resy_candidates(res, wide = TRUE)
  expect_equal(names(out), c("plot_id", "classification"))
})
