# Tests for internal plot identification utilities
# These functions handle detection, standardization, and normalization of plot IDs
# across observation and header data frames.

test_that(".resy_guess_id_col detects PlotObservationID when present", {
  obs <- data.frame(
    PlotObservationID = c("P1", "P2", "P3"), species = c("Oak", "Birch", "Pine")
    )
  header <- data.frame(
    PlotObservationID = c("P1", "P2", "P3"), elevation = c(100, 200, 300)
    )
  
  result <- .resy_guess_id_col(obs, header)
  expect_equal(result, "PlotObservationID")
})

test_that(".resy_guess_id_col detects PlotID when PlotObservationID absent", {
  obs <- data.frame(
    PlotID = c("P1", "P2", "P3"), species = c("Oak", "Birch", "Pine")
    )
  header <- data.frame(
    PlotID = c("P1", "P2", "P3"), elevation = c(100, 200, 300)
    )
  
  result <- .resy_guess_id_col(obs, header)
  expect_equal(result, "PlotID")
})

test_that(".resy_guess_id_col prioritizes PlotObservationID over PlotID", {
  obs <- data.frame(
    PlotObservationID = c("O1", "O2"),
    PlotID = c("P1", "P2"),
    species = c("Oak", "Birch")
  )
  header <- data.frame(
    PlotObservationID = c("O1", "O2"),
    PlotID = c("P1", "P2"),
    elevation = c(100, 200)
  )
  
  result <- .resy_guess_id_col(obs, header)
  expect_equal(result, "PlotObservationID")
})

test_that(".resy_guess_id_col returns NULL when no standard column found", {
  obs <- data.frame(ID = c("P1", "P2"), species = c("Oak", "Birch"))
  header <- data.frame(ID = c("P1", "P2"), elevation = c(100, 200))
  
  result <- .resy_guess_id_col(obs, header)
  expect_null(result)
})

test_that(".resy_guess_id_col returns NULL when column missing from one data frame", {
  obs <- data.frame(
    PlotObservationID = c("P1", "P2"), species = c("Oak", "Birch")
    )
  header <- data.frame(PlotID = c("P1", "P2"), elevation = c(100, 200))
  
  result <- .resy_guess_id_col(obs, header)
  expect_null(result)
})

test_that(".resy_standardize_plot_id with explicit id_col parameter", {
  obs <- data.table::data.table(
    CustomID = c("P1", "P2", "P3"), species = c("Oak", "Birch", "Pine")
    )
  header <- data.frame(
    CustomID = c("P1", "P2", "P3"), elevation = c(100, 200, 300)
    )
  
  result <- .resy_standardize_plot_id(obs, header, id_col = "CustomID")
  
  expect_equal(result$id_col_used, "CustomID")
  expect_equal(result$obs$PlotObservationID, c("P1", "P2", "P3"))
  expect_equal(result$header$PlotObservationID, c("P1", "P2", "P3"))
})

test_that(".resy_standardize_plot_id auto-detects PlotObservationID", {
  obs <- data.table::data.table(
    PlotObservationID = c("P1", "P2"), species = c("Oak", "Birch")
    )
  header <- data.frame(
    PlotObservationID = c("P1", "P2"), elevation = c(100, 200)
    )
  
  result <- .resy_standardize_plot_id(obs, header)
  
  expect_equal(result$id_col_used, "PlotObservationID")
  expect_equal(result$obs$PlotObservationID, c("P1", "P2"))
  expect_equal(result$header$PlotObservationID, c("P1", "P2"))
})

test_that(".resy_standardize_plot_id auto-detects PlotID", {
  obs <- data.table::data.table(
    PlotID = c("P1", "P2"), species = c("Oak", "Birch")
    )
  header <- data.frame(PlotID = c("P1", "P2"), elevation = c(100, 200))
  
  result <- .resy_standardize_plot_id(obs, header)
  
  expect_equal(result$id_col_used, "PlotID")
  expect_equal(result$obs$PlotObservationID, c("P1", "P2"))
  expect_equal(result$header$PlotObservationID, c("P1", "P2"))
})

test_that(".resy_standardize_plot_id converts numeric IDs to character", {
  obs <- data.table::data.table(
    PlotID = c(1, 2, 3), species = c("Oak", "Birch", "Pine")
    )
  header <- data.frame(PlotID = c(1, 2, 3), elevation = c(100, 200, 300))
  
  result <- .resy_standardize_plot_id(obs, header)
  
  expect_true(is.character(result$obs$PlotObservationID))
  expect_true(is.character(result$header$PlotObservationID))
  expect_equal(result$obs$PlotObservationID, c("1", "2", "3"))
  expect_equal(result$header$PlotObservationID, c("1", "2", "3"))
})

test_that(".resy_standardize_plot_id errors when id_col not in obs", {
  obs <- data.table::data.table(species = c("Oak", "Birch"))
  header <- data.frame(CustomID = c("P1", "P2"), elevation = c(100, 200))
  
  expect_error(
    .resy_standardize_plot_id(obs, header, id_col = "CustomID"),
    "id_col 'CustomID' not found in obs"
  )
})

test_that(".resy_standardize_plot_id errors when id_col not in header", {
  obs <- data.table::data.table(
    CustomID = c("P1", "P2"), species = c("Oak", "Birch")
    )
  header <- data.frame(elevation = c(100, 200))
  
  expect_error(
    .resy_standardize_plot_id(obs, header, id_col = "CustomID"),
    "id_col 'CustomID' not found in header"
  )
})

test_that(".resy_standardize_plot_id errors when no ID column found", {
  obs <- data.table::data.table(species = c("Oak", "Birch"))
  header <- data.frame(elevation = c(100, 200))
  
  expect_error(
    .resy_standardize_plot_id(obs, header),
    "No plot id column found in both obs and header"
  )
})

test_that(".resy_get_id_col returns PlotObservationID with priority", {
  obs <- data.frame(PlotObservationID = c("P1", "P2"), PlotID = c("Q1", "Q2"))
  header <- data.frame(
    PlotObservationID = c("P1", "P2"), PlotID = c("Q1", "Q2")
    )
  
  result <- .resy_get_id_col(obs, header)
  
  expect_equal(result, "PlotObservationID")
})

test_that(".resy_get_id_col prioritizes user-specified id_col", {
  obs <- data.frame(CustomID = c("C1", "C2"), PlotID = c("P1", "P2"))
  header <- data.frame(CustomID = c("C1", "C2"), PlotID = c("P1", "P2"))
  
  result <- .resy_get_id_col(obs, header, id_col = "CustomID")
  
  expect_equal(result, "CustomID")
})

test_that(".resy_get_id_col falls back to standard names when user column missing", {
  obs <- data.frame(PlotID = c("P1", "P2"))
  header <- data.frame(PlotID = c("P1", "P2"))
  
  result <- .resy_get_id_col(obs, header, id_col = "CustomID")
  
  expect_equal(result, "PlotID")
})

test_that(".resy_get_id_col errors when no suitable column found", {
  obs <- data.frame(species = c("Oak", "Birch"))
  header <- data.frame(elevation = c(100, 200))
  
  expect_error(
    .resy_get_id_col(obs, header),
    "No suitable plot id column found in both obs and header"
  )
})

test_that(".resy_get_id_col errors message shows tried columns", {
  obs <- data.frame(species = c("Oak", "Birch"))
  header <- data.frame(elevation = c(100, 200))
  
  expect_error(
    .resy_get_id_col(obs, header, id_col = "CustomID"),
    "CustomID.*PlotObservationID.*PlotID"
  )
})

test_that(".resy_normalize_ids_obs converts to character PlotObservationID", {
  obs <- data.frame(PlotID = c(1, 2, 3), species = c("Oak", "Birch", "Pine"))
  
  result <- .resy_normalize_ids_obs(obs, "PlotID")
  
  expect_true(is.character(result$PlotObservationID))
  expect_equal(result$PlotObservationID, c("1", "2", "3"))
})

test_that(".resy_normalize_ids_obs preserves existing PlotObservationID", {
  obs <- data.frame(
    PlotID = c("P1", "P2"), PlotObservationID = c("old1", "old2")
    )
  
  result <- .resy_normalize_ids_obs(obs, "PlotID")
  
  expect_equal(result$PlotObservationID, c("P1", "P2"))
})

test_that(".resy_normalize_ids_obs maintains data.table class", {
  obs <- data.table::data.table(
    PlotID = c("P1", "P2"), species = c("Oak", "Birch")
    )
  
  result <- .resy_normalize_ids_obs(obs, "PlotID")
  
  expect_true(data.table::is.data.table(result))
})

test_that(".resy_normalize_ids_header converts to character PlotObservationID", {
  header <- data.frame(PlotID = c(1, 2, 3), elevation = c(100, 200, 300))
  
  result <- .resy_normalize_ids_header(header, "PlotID")
  
  expect_true(is.character(result$PlotObservationID))
  expect_equal(result$PlotObservationID, c("1", "2", "3"))
})

test_that(".resy_normalize_ids_header preserves other columns", {
  header <- data.frame(
    PlotID = c("P1", "P2"), elevation = c(100, 200), aspect = c("N", "S")
    )
  
  result <- .resy_normalize_ids_header(header, "PlotID")
  
  expect_equal(result$elevation, c(100, 200))
  expect_equal(result$aspect, c("N", "S"))
})

test_that(".resy_normalize_ids_header maintains data.frame class", {
  header <- data.frame(PlotID = c("P1", "P2"), elevation = c(100, 200))
  
  result <- .resy_normalize_ids_header(header, "PlotID")
  
  expect_true(is.data.frame(result))
})
