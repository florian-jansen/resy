# resy_compare_types() sets two types side by side, from one expert system or
# two. The tests check the shared numbering of conditions, the species groups
# member by member, the reading for one plot, and the errors for types that are
# not defined and plots without classification results.

test_that("two types of one system share the numbering of their conditions", {
  cmp <- resy_compare_types(apennine_result(), "N", "FB")
  expect_s3_class(cmp, "resy_type_comparison")
  expect_equal(cmp$sides$code, c("N", "FB"))
  expect_equal(cmp$sides$name, c("Non-forest", "Beech-fir montane forest"))
  expect_equal(cmp$rules$text, c("([1] or [2]) and not [3]", "[3] and [4]"))
  expect_equal(cmp$rules$priority, c(2L, 5L))
  shared <- cmp$conditions[cmp$conditions$n == 3L, ]
  expect_equal(shared$expression, "#TC Beech-forest-trees GR 15")
  expect_true(shared$in_a && shared$in_b)
  expect_equal(cmp$conditions$in_a, c(TRUE, TRUE, TRUE, FALSE))
  expect_equal(cmp$conditions$in_b, c(FALSE, FALSE, TRUE, TRUE))
  expect_equal(cmp$groups$group, c("Nardus-grassland", "Sub-Mediterranean",
                                   "Beech-forest-trees", "Beech-forest-herbs"))
  expect_equal(cmp$groups$in_b, c(FALSE, FALSE, TRUE, TRUE))
  expect_null(cmp$plot)
  out <- paste(capture.output(print(cmp)), collapse = "\n")
  expect_match(out, "Rule (priority 2): ([1] or [2]) and not [3]", fixed = TRUE)
  expect_match(out, "in both: Beech-forest-trees", fixed = TRUE)
  expect_match(out, "only FB: Beech-forest-herbs", fixed = TRUE)
})

test_that("for one plot each condition is read in each type and each type gets a verdict", {
  res <- apennine_result()
  p <- names(res$result.classification)[res$result.classification == "NG"][1]
  cmp <- resy_compare_types(res, "NG", "NS", plot = p)
  expect_equal(cmp$plot$id, p)
  expect_equal(cmp$plot$a$choice, "NG")
  expect_equal(cmp$plot$a$text, "classified as NG (priority 5)")
  expect_false(cmp$plot$b$holds)
  expect_match(cmp$plot$b$text, "^rule not met: 0 of 1 conditions satisfied$")
  expect_equal(cmp$conditions$met_a, c(TRUE, TRUE, NA))
  expect_equal(cmp$conditions$met_b, c(NA, NA, FALSE))
  expect_match(cmp$conditions$text[1], "^cover of Nardus stricta is ")
  expect_equal(cmp$rules$holds, c(TRUE, FALSE))
  out <- paste(capture.output(print(cmp)), collapse = "\n")
  expect_match(out, paste0("Conditions for plot ", p, ":"), fixed = TRUE)
  expect_match(out, "NS: rule not met", fixed = TRUE)
})

test_that("the same type in two systems compares its groups member by member", {
  a <- resy_load_expert(scheme = "Apennine-test")
  b <- a
  i <- match("Beech-forest-herbs", b$groups.names)
  b$groups[[i]] <- c(setdiff(b$groups[[i]], b$groups[[i]][1]), "Galium odoratum")
  b$source$version <- "edited"
  cmp <- resy_compare_types(a, "FB", "FB", y = b)
  g <- cmp$groups[cmp$groups$group == "Beech-forest-herbs", ]
  expect_equal(g$only_a, trimws(a$groups[[i]][1]))
  expect_equal(g$only_b, "Galium odoratum")
  expect_equal(cmp$groups$only_a[cmp$groups$group == "Beech-forest-trees"], "")
  expect_equal(cmp$rules$text, c("[1] and [2]", "[1] and [2]"))
  out <- paste(capture.output(print(cmp)), collapse = "\n")
  expect_match(out, "Beech-forest-herbs differs: only in A:", fixed = TRUE)
})

test_that("a type the system does not define and a plot without results are errors", {
  res <- apennine_result()
  expect_error(resy_compare_types(res, "NG", "ZZ"), "Type ZZ is not defined in")
  expect_error(resy_compare_types(res$parsed, "NG", "NS", plot = "AN57"),
               "needs `x` and `y` to be classification results")
  expect_error(resy_compare_types(res, "NG", "NS", plot = "nope"),
               "not in the classification result")
})
