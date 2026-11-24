# .resy_transform_formulas() completes the membership expressions of a system
# before the solver reads them. The test checks that an #SC comparison gets its
# EXCEPT clause by its literal text, so a condition holding a regular-expression
# character such as "|" or "+" changes exactly the expressions that contain it.

transform_sc <- function(formulas) {
  RESY:::.resy_transform_formulas(
    aggs = list(), groups = list(), membership.formulas = formulas,
    membership.formula.names = paste(seq_along(formulas), paste0("T", seq_along(formulas)))
  )
}

test_that("an #SC condition with '|' completes only its own expression", {
  out <- transform_sc(c("<#SC A|#SC B GR #SC C>", "<#SC A GR 5>"))
  expect_equal(out$membership.expressions,
               c("#SC A|#SC B GR #SC C EXCEPT #SC A|#SC B", "#SC A GR 5"))
  expect_equal(unname(out$formulas),
               c("<#SC A|#SC B GR #SC C EXCEPT #SC A|#SC B>", "<#SC A GR 5>"))
})

test_that("an #SC condition on a discriminating group with '+' is completed", {
  out <- transform_sc("<#SC +12 Conifers GR #SC Pinus>")
  expect_equal(out$membership.expressions,
               "#SC +12 Conifers GR #SC Pinus EXCEPT #SC +12 Conifers")
  expect_equal(unname(out$formulas), "<#SC +12 Conifers GR #SC Pinus EXCEPT #SC +12 Conifers>")
})
