# Lossless round-trip: resy_write_expert(resy_read_expert(f)) reproduces f
# byte-for-byte, including line endings and trailing newline. The fixtures cover
# a file with terminated sections and one whose final section is unterminated.

test_that("read/write round-trip is byte-identical on the fixtures", {
  dir <- testthat::test_path("fixtures")
  files <- list.files(dir, pattern = "\\.txt$", full.names = TRUE)
  skip_if(length(files) == 0L, "fixtures not found")

  for (f in files) {
    tree <- resy_read_expert(f)
    tmp <- tempfile(fileext = ".txt")
    resy_write_expert(tree, tmp)
    expect_identical(
      readBin(tmp, "raw", n = file.info(tmp)$size),
      readBin(f, "raw", n = file.info(f)$size),
      info = basename(f)
    )
    unlink(tmp)
  }
})

test_that("an unterminated final section is preserved and round-trips", {
  f <- testthat::test_path("fixtures", "mini_unterminated.txt")
  skip_if(!file.exists(f), "fixture not found")

  tree <- resy_read_expert(f)
  last <- tree$sections[[length(tree$sections)]]
  expect_true(is.na(last$end_line))

  tmp <- tempfile(fileext = ".txt")
  on.exit(unlink(tmp), add = TRUE)
  resy_write_expert(tree, tmp)
  expect_identical(
    readBin(tmp, "raw", n = file.info(tmp)$size),
    readBin(f, "raw", n = file.info(f)$size)
  )
})

test_that("resy_write_expert validates its inputs", {
  expect_error(resy_write_expert(list(), tempfile()), "resy_expert")
  f <- testthat::test_path("fixtures", "mini_expert.txt")
  skip_if(!file.exists(f), "fixture not found")
  tree <- resy_read_expert(f)
  expect_error(resy_write_expert(tree, c("a", "b")), "single file path")
})
