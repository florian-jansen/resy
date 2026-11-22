# Group names and species named in each element of `x`, a vector of condition
# bodies: "|" combines groups, and every part after the first repeats the
# condition code ("#TC A|#TC B"), so the code (and `prefix`) is removed from
# each part. Returns one character vector per element of `x`.
#' @keywords internal
#' @noRd
.resy_membership_parts_list <- function(x, prefix = NULL) {
  pieces <- strsplit(x, "|", fixed = TRUE)
  id <- rep.int(seq_along(x), lengths(pieces))
  p <- trimws(unlist(pieces, use.names = FALSE))
  if (!is.null(prefix)) {
    pre <- startsWith(p, prefix)
    p[pre] <- trimws(substring(p[pre], nchar(prefix) + 1L))
  }
  p <- trimws(sub("^(###|##[QCDN]|#TC|#T\\$|#SC|#\\$\\$|#[0-9]{2})\\s+", "", p))
  keep <- nzchar(p)
  unname(split(p[keep], factor(id[keep], levels = seq_along(x))))
}

#' @keywords internal
#' @noRd
.resy_membership_parts <- function(x, prefix = NULL) {
  as.character(unlist(.resy_membership_parts_list(x, prefix = prefix), use.names = FALSE))
}

# Taxa of each element of `parts` (a list of group names): the members of the
# groups it names, without duplicates. With `species = TRUE`, a name that is
# not a group is a single species and follows the group members.
#' @keywords internal
#' @noRd
.resy_parts_taxa <- function(parts, groups, groups.names, species = FALSE) {
  id <- rep.int(seq_along(parts), lengths(parts))
  tok <- unlist(parts, use.names = FALSE)
  gi <- fastmatch::fmatch(tok, groups.names)
  hit <- !is.na(gi)
  members <- groups[gi[hit]]
  mid <- rep.int(id[hit], lengths(members))
  val <- trimws(unlist(members, use.names = FALSE))
  if (species) {
    mid <- c(mid, id[!hit])
    val <- c(val, tok[!hit])
  } else {
    mid <- mid[nzchar(val)]
    val <- val[nzchar(val)]
  }
  unname(lapply(split(val, factor(mid, levels = seq_along(parts))), unique))
}

#' @keywords internal
#' @noRd
.resy_group_taxa_union_list <- function(x, groups, groups.names, prefix = NULL) {
  .resy_parts_taxa(.resy_membership_parts_list(x, prefix = prefix), groups, groups.names)
}

#' @keywords internal
#' @noRd
.resy_group_taxa_or_species_list <- function(x, groups, groups.names, prefix = NULL) {
  .resy_parts_taxa(.resy_membership_parts_list(x, prefix = prefix), groups, groups.names,
                   species = TRUE)
}

#' @keywords internal
#' @noRd
.resy_group_taxa_union <- function(x, groups, groups.names, prefix = NULL) {
  .resy_group_taxa_union_list(paste(x, collapse = "|"), groups, groups.names, prefix = prefix)[[1]]
}

#' @keywords internal
#' @noRd
.resy_group_taxa_or_species <- function(x, groups, groups.names, prefix = NULL) {
  .resy_group_taxa_or_species_list(paste(x, collapse = "|"), groups, groups.names,
                                   prefix = prefix)[[1]]
}

# Taxa that one membership condition (an element of `parsed$conditions`) refers
# to, resolved the way the solver resolves them: the leading code token
# ("###", "##Q", "#TC", "#05", ...) is dropped, "|" joins groups, "A EXCEPT B"
# removes the taxa of B from those of A, a "NON" comparison refers to the group
# it names, and a condition without a code is a single species. Header
# conditions ("$$C", "$$N") and whole-plot cover ("#T$", "#$$", "$05") without a
# group return no taxa.
#' @keywords internal
#' @noRd
.resy_condition_taxa <- function(condition, groups, groups.names) {
  x <- trimws(condition)
  if (startsWith(x, "NON ")) x <- trimws(substring(x, 5L))
  if (startsWith(x, "$")) return(character())
  if (!startsWith(x, "#")) return(x)
  code <- substr(x, 1L, 3L)
  x <- trimws(substring(x, 4L))
  if (!nzchar(x)) return(character())
  parts <- trimws(strsplit(x, "EXCEPT", fixed = TRUE)[[1]])
  taxa <- .resy_group_taxa_or_species(parts[1], groups, groups.names, prefix = code)
  if (length(parts) > 1L) {
    taxa <- setdiff(taxa, .resy_group_taxa_or_species(parts[2], groups, groups.names,
                                                      prefix = code))
  }
  taxa
}

# The conditions of `conditions` that occur in a membership expression, found
# longest first with each match removed before the next, the order in which the
# solver substitutes conditions by their columns.
#' @keywords internal
#' @noRd
.resy_expression_conditions <- function(expression, conditions) {
  rest <- expression
  hit <- character()
  for (cond in conditions[order(nchar(conditions), decreasing = TRUE)]) {
    if (grepl(cond, rest, fixed = TRUE)) {
      hit <- c(hit, cond)
      rest <- gsub(cond, " ", rest, fixed = TRUE)
    }
  }
  hit
}

# Taxa of each condition of the form "A EXCEPT B": the union of the groups in A
# minus the taxa of the groups or species in B. Without EXCEPT, the union of A.
#' @keywords internal
#' @noRd
.resy_except_taxa_list <- function(x, groups, groups.names, prefix = NULL) {
  sides <- strsplit(x, "EXCEPT", fixed = TRUE)
  a <- trimws(vapply(sides, `[`, character(1), 1L))
  has_b <- lengths(sides) > 1L
  taxa <- .resy_group_taxa_union_list(a, groups, groups.names, prefix = prefix)
  if (any(has_b)) {
    b <- trimws(vapply(sides[has_b], `[`, character(1), 2L))
    drop <- .resy_group_taxa_or_species_list(b, groups, groups.names, prefix = prefix)
    taxa[has_b] <- Map(function(t, d) t[is.na(fastmatch::fmatch(t, d))], taxa[has_b], drop)
  }
  taxa
}

# Observations selected for each condition k: those whose taxon is in
# `taxa[[k]]`, or with `exclude = TRUE` all others. Returns one row per
# condition and observation (columns `k` and `row`, the index into `taxon`),
# ordered by condition and then by observation.
#' @keywords internal
#' @noRd
.resy_condition_rows <- function(taxon, taxa, exclude = FALSE) {
  members <- unlist(taxa, use.names = FALSE)
  vocab <- unique(members)
  sets <- unique(data.table::data.table(k = rep.int(seq_along(taxa), lengths(taxa)),
                                        t = match(members, vocab)))
  t_obs <- match(taxon, vocab)
  hit <- which(!is.na(t_obs))
  rows <- sets[data.table::data.table(row = hit, t = t_obs[hit]), on = "t",
               list(k, row), nomatch = NULL, allow.cartesian = TRUE]
  if (exclude) {
    rows <- data.table::CJ(k = seq_along(taxa), row = seq_along(taxon))[!rows, on = c("k", "row")]
  }
  data.table::setorderv(rows, c("k", "row"))
  rows
}

# Per-plot statistic of the cover values selected for each condition column:
# column `cols[k]` of the plot x condition matrix receives the statistic over
# the observations of each plot whose taxon is in `taxa[[k]]` (or, with
# `exclude = TRUE`, not in it). `plot` is the row of plot.cond for each
# observation. `param` holds the per-column number of an "at_least" condition
# or the share of a "share" condition. Plots without selected observations
# keep their value.
#
# Sums and means are taken group by group with base R, so they equal sum() and
# mean() of the old one-condition-at-a-time evaluation to the last bit; counts,
# maxima and products use data.table's grouped versions, which are identical.
#' @keywords internal
#' @noRd
.resy_fill_conditions <- function(plot.cond, taxon, plot, cover, cols, taxa,
                                  stat = c("n", "at_least", "sqrt", "sum", "total",
                                           "share", "max", "mean", "sqrt_q"),
                                  param = NULL, exclude = FALSE) {
  stat <- match.arg(stat)
  if (!length(cols)) return(plot.cond)
  d <- .resy_condition_rows(taxon, taxa, exclude = exclude)
  if (!nrow(d)) return(plot.cond)
  d[, plot := plot[row]]
  base_reduce <- function(value, f) {
    old <- options(datatable.optimize = 0L)
    on.exit(options(old))
    d[, v := value[row]][, list(x = f(v)), by = list(k, plot)]
  }
  g <- switch(stat,
    n        = d[, list(x = .N), by = list(k, plot)],
    at_least = unique(d[, t := taxon[row]], by = c("k", "plot", "t"))[, list(x = .N), by = list(k, plot)],
    sqrt     = base_reduce(sqrt(cover), sum),
    sum      = base_reduce(cover, sum),
    total    = ,
    share    = d[, q := 1 - cover[row] / 100][, list(x = prod(q)), by = list(k, plot)],
    max      = d[, v := cover[row]][, list(x = max(v)), by = list(k, plot)],
    mean     = base_reduce(cover, mean),
    sqrt_q   = base_reduce(cover^0.5, sum)
  )
  x <- switch(stat,
    at_least = as.integer(g$x >= param[g$k]),
    sqrt     = round(g$x, 5),
    total    = round((1 - g$x) * 100, 10),
    share    = round((1 - g$x) * 100, 10) * param[g$k],
    g$x
  )
  plot.cond[cbind(g$plot, cols[g$k])] <- x
  plot.cond
}

#' @keywords internal
#' @noRd
.resy_solve_membership <- function(obs, header, parsed, plot.cond, mc = 1L) {
  if (!inherits(obs, 'data.table')) obs <- data.table::as.data.table(obs)
  if (missing(header) || is.null(header)) stop('header must be provided (data.frame).')
  groups <- parsed$groups
  groups.names <- parsed$groups.names
  conditions <- parsed$conditions
  membership.expressions <- parsed$membership.expressions
  logexpr.formula <- parsed$logexpr.formula
  vegtype.priority <- parsed$vegtype.priority
  vegtype.formula.names.short <- parsed$vegtype.formula.names.short

  # Make sure PlotObservationID are character indices
  obs[, PlotObservationID := as.character(PlotObservationID)]
  header$PlotObservationID <- as.character(header$PlotObservationID)
  plots <- rownames(plot.cond)
  # Header conditions ($$C, $$N) are filled row by row, so the header must be in
  # the plot order of plot.cond; a plot missing from the header gets an NA row.
  header <- header[match(plots, header$PlotObservationID), , drop = FALSE]

  # Condition text after its four-character code ("#TC ", "##Q ", ...).
  body <- function(x) substr(x, 5, nchar(x))
  union_of <- function(x, prefix = NULL)
    .resy_group_taxa_union_list(x, groups, groups.names, prefix = prefix)
  except_of <- function(x, prefix)
    .resy_except_taxa_list(x, groups, groups.names, prefix = prefix)
  plot_row <- match(obs$PlotObservationID, plots)
  fill <- function(cols, taxa, stat, param = NULL, exclude = FALSE)
    .resy_fill_conditions(plot.cond, obs$TaxonName, plot_row, obs$Cover_Perc, cols, taxa,
                          stat, param = param, exclude = exclude)
  has_except <- grepl("EXCEPT", conditions, fixed = TRUE)
  # All observations of a plot: the complement of no taxa.
  all_taxa <- function(cols) rep(list(character()), length(cols))

  ###  R code for Expert system vegetation classification
  ###  Bruelheide H, Chytry M,  Tichý L & Jansen F  2021
  ###  Results are compared and optimised with the output from JUICE program
  # ############################################################## #
  ### Step 5: Solve the membership conditions                   ####
  ### and fill in the numerical plot x membership condition matrix
  # ############################################################## #

  # GO through all different types of conditions
  # 1. Number of species (###)
  # 2. minimum number of species that have to be present in a group (#01 to #99)
  # 3. Square root of the sum of cover of the group (##Q)
  # 4. Total cover of the group (#TC)
  # 5. Total cover (#T$) and per cent of total cover ($05, $10)
  # 6. Cover of any species in the group (#SC)
  # 7. Cover of single species (#SC and #SC EXCEPT)
  # 8. Highest cover of any species (#$$ EXCEPT)
  # 9. NON conditions, where the sum of square-rooted cover (Q) is compared with
  #    all other species groups of the same set
  # 10. Header data, categorical ($$C) and numeric ($$N)
  # In all cases: handle "|" (combine groups) and EXCEPT

  ############################################### #
  # 5.1. Number of species (###) of a group    ####
  w <- which(startsWith(conditions, "###") | startsWith(conditions, "##D"))
  message('Step 5.1  Number of conditions with number of species of a group: ', length(w))
  plot.cond <- fill(w, union_of(body(conditions[w])), "n")

  #################################################################################### #
  # 5.2. Minimum number of species which have to be present in a group (#01 to #99) ####
  ##!! Not to be confounded with +01, +02 etc. in group names, which is for additional hierarchy with differential species groups !!##
  w <- suppressWarnings(which(!is.na(as.numeric(substr(conditions, 2, 3))) & startsWith(conditions, "#")))
  message('Step 5.2  Number of conditions with minimum number of species: ', length(w))
  plot.cond <- fill(w, union_of(body(conditions[w])), "at_least",
                    param = as.numeric(substr(conditions[w], 2, 3)))

  ##################################################### #
  # 5.3. '##Q sum of square root Cover_Perc'         ####
  w <- which(startsWith(conditions, "##Q") | startsWith(conditions, "##D"))
  message('Step 5.3  Number of conditions with sum of square rooted Cover_Perc of species: ', length(w))
  plot.cond <- fill(w, union_of(body(conditions[w])), "sqrt")

  ###################################################### #
  # 5.4. Total Cover_Perc of the group (##C)          ####
  w <- which(startsWith(conditions, "##C") | startsWith(conditions, "##D"))
  message('Step 5.4  Number of conditions with total Cover_Perc of the group: ', length(w))
  plot.cond <- fill(w, union_of(body(conditions[w])), "sum")

  ########################################################################################## #
  # 5.5 Total Cover_Perc (#TC) and percent of total cover of all other species ($05, $10) ####
  # "#T$" alone is the total cover of the plot.
  w <- which(conditions == "#T$")
  message('Step 5.5  Number of conditions with total Cover_Perc of all other species: ', length(w))
  plot.cond <- fill(w, all_taxa(w), "total", exclude = TRUE)

  # "#T$ A" and "#T$ A|#T$ B": total cover of all species outside the groups.
  # Conditions with EXCEPT are handled below.
  w <- which(startsWith(conditions, "#T$") & nzchar(body(conditions)) & !has_except)
  message('          Number of conditions with total Cover_Perc of all other species except those on the left-hand side: ', length(w))
  plot.cond <- fill(w, union_of(conditions[w], prefix = "#T$"), "total", exclude = TRUE)

  # "#TC A" and "#TC A|#TC B": total cover of the species in the groups.
  w <- which(startsWith(conditions, "#TC") & !has_except)
  plot.cond <- fill(w, union_of(conditions[w], prefix = "#TC"), "total")

  # "$05", "$25", ...: that percentage of the total cover of the plot.
  w <- which(grepl("\\$[0-9]", conditions))
  message('          Number of conditions with $05, $25 etc.: ', length(w))
  plot.cond <- fill(w, all_taxa(w), "share", exclude = TRUE,
                    param = as.numeric(sub("$", "", conditions[w], fixed = TRUE)) / 100)

  # "#TC A|#TC B EXCEPT C" and "#TC A EXCEPT C": total cover of the groups
  # without the taxa of C.
  w <- which(startsWith(conditions, "#TC") & grepl("|#", conditions, fixed = TRUE) & has_except)
  plot.cond <- fill(w, except_of(conditions[w], prefix = "#TC"), "total")
  w <- which(has_except &
               !grepl("|", conditions, fixed = TRUE) &
               !startsWith(conditions, "#SC") &
               !startsWith(conditions, "#$$"))
  plot.cond <- fill(w, except_of(conditions[w], prefix = "#TC"), "total")

  ######################################################### #
  # 5.6   Cover of any species in the group (#SC)   ####
  # The cover of the species is greater than the cover of any single species in
  # the functional species group, except of the species at the left-hand side of
  # the logical operator. "#SC" occurs at the beginning of a condition and after
  # "|#" inside it; on right-hand sides it always comes with EXCEPT and group
  # names or names of single species.
  w <- which(grepl("#SC", conditions, fixed = TRUE))
  message('Step 5.6  Number of conditions with maximum cover of the group: ', length(w))
  plot.cond <- fill(w, except_of(conditions[w], prefix = "#SC"), "max")

  ######################################################## #
  # 5.7. Cover percentage single species and SC left    ####
  w <- which(!startsWith(conditions, "#") &
               !startsWith(conditions, "$") &
               !startsWith(conditions, "NON"))
  message('Step 5.7  Number of conditions with single species, header levels (e.g. country names): ', length(w))
  plot.cond <- fill(w, as.list(conditions[w]), "mean")

  ################################################################## #
  # 5.8   Highest Cover_Perc of any species in plot (#$$ EXCEPT)  ####
  w <- which(conditions == "#$$")
  message('Step 5.8  Number of conditions with maximum Cover_Perc in plot: ', length(w))
  plot.cond <- fill(w, all_taxa(w), "max", exclude = TRUE)

  # "#$$ EXCEPT B": highest cover of any species outside the groups or species of B.
  w <- which(startsWith(conditions, "#$$") & has_except)
  message('          Number of conditions with maximum Cover_Perc in plot EXCEPT species of target group: ', length(w))
  outside <- lapply(conditions[w], function(i)
    .resy_group_taxa_or_species(trimws(strsplit(i, "EXCEPT", fixed = TRUE)[[1]])[[2]],
                                groups, groups.names))
  plot.cond <- fill(w, outside, "max", exclude = TRUE)

  ################################################## #
  # 5.9 NON conditions                              ####
  # "NON ##Q +01 A": the highest sum of square-rooted cover among the other
  # differential groups (##D) of the same set (+01).
  wn <- which(startsWith(conditions, "NON "))
  message('Step 5.9  Number of T$ NON conditions: ', length(wn))
  if (any(substr(conditions[wn], 5, 7) != "##Q"))
    stop('Only square root cover value NON condition implemented.')

  if (length(wn)) {
    group.d <- which(substr(names(groups), 3, 3) == "D")
    q <- matrix(0, nrow = length(plots), ncol = length(group.d))
    q <- .resy_fill_conditions(q, obs$TaxonName, plot_row, obs$Cover_Perc, seq_along(group.d),
                               lapply(group.d, function(i) unlist(groups[i], use.names = FALSE)),
                               "sqrt_q")
    group.d.names <- names(groups)[group.d]
    # Highest value per plot over the columns `others` of q; -Inf where all are NA.
    row_max <- function(others) {
      m <- do.call(pmax, c(lapply(others, function(o) q[, o]), na.rm = TRUE))
      m[is.na(m)] <- -Inf
      round(m, 5)
    }
    done <- list()
    for (j in wn) {
      target <- body(conditions[j])
      substr(target, 1, 3) <- "##D"
      others <- which(substr(group.d.names, 5, 7) == substr(target, 5, 7) &
                        group.d.names != target)
      if (!length(others)) next
      key <- paste(others, collapse = " ")
      if (is.null(done[[key]])) done[[key]] <- row_max(others)
      plot.cond[, j] <- done[[key]]
    }
  }

  ######################################## #
  # 5.10. evaluate header data          ####
  ### Numerical
  w <- conditions[startsWith(conditions, '$$N')]
  message('Step 5.10  Header conditions with numeric values: ', length(w))
  if(length(w) > 0) {
    m <- match(body(w), names(header))
    W <- w[!is.na(m)]
    m <- m[!is.na(m)]
    ind <- matrix(c(rep(1:nrow(header), length(m)),
                    rep(fmatch(W, conditions), each = nrow(header)),
                    as.numeric(unlist(header[, m], use.names = FALSE))), ncol = 3)
    ind[,3][is.na(ind[,3])] <- 0
    plot.cond[ind[,1:2]] <- ind[,3]
  }
  ### Categorical
  is_cat <- startsWith(conditions, '$$C')
  w <- conditions[is_cat]
  message('  Header conditions with character values: ', length(w))
  categorical.header <- intersect(names(header), body(w))
  for(i in categorical.header) {
    own <- which(is_cat & body(conditions) == i)
    b <- as.factor(as.character(header[,i]))
    if(length(levels(b)) > 0) {
      # left hand
      # mark NAs as -1, otherwise they will be set 0 and result in wrong
      # comparisons
      c <- as.numeric(b)
      c[is.na(c)] <- -1
      plot.cond[, own] <- c
      # filling the right-hand side
      index5 <- which(conditions %in% levels(b))
      if(length(index5)>0){
        index7 <- match(header[,i], levels(b))
        # there are NAs in index7 because some header fields are empty, e.g. "Coast_EEA"
        index7[is.na(index7)] <- 0
        # However, we have to translate the levels into numbers, done with c
        for (j in 1:length(index5)){
          c <- which(levels(b)==conditions[index5[j]])
          plot.cond[index7 == c, index5[j]] <- c
        }
      }
    } else plot.cond[, own] <- -1
  }


  ### condition matrix end     ####
  ############################### #

  ############################################################ #
  ###  Step 6: Replace conditions in membership formulas    ####
  ###  by column names of the plot x membership condition matrix
  ############################################################ #
  ### Make all conditions in a membership expression parseable
  ### and also all vegtype formulas
  # The key of this step is the eval(parse(text=x)) command that allows to interpret text as logical expressions in R
  message(paste('adapt conditions', Sys.time()))
  # logi1 holds the results from the evaluation of the membership conditions in plot.cond for every expression.
  # membership expressions are evaluated by referring to col1, col2, ....
  # instead of membership condition names.
  dimnames(plot.cond)[[2]] <- paste("col", seq(1:dim(plot.cond)[[2]]), sep="")

  if(any(is.na(plot.cond))) warning('NA in plot.cond')
  plot.cond[is.na(plot.cond)] <- 0 # NA would ruin the foreach order but appears because of non-solvable conditions
  plot.cond[plot.cond == -Inf] <- 0
  plot.cond <- as.data.frame(plot.cond)

  ############################################################################## #
  ### Step 7: Turn membership expressions text into logical expressions in R  ####
  ############################################################################## #
  # go through the loop of single components of the expressions,
  # both left-hand and right-hand side, which is in conditions and replace them with col1, col2 etc.
  # This has to be done in descending length of conditions
  # membership.expressions.eval <- membership.expressions
  o <- order(nchar(conditions), decreasing =TRUE)

  # # then replace all into logical expressions
  membership.expressions.eval <- stri_replace_all_fixed(membership.expressions,
          pattern = conditions[o], replacement = paste("col", o, sep=""), vectorize_all = FALSE)

  membership.expressions.eval <- gsub("GR", ">", membership.expressions.eval)
  membership.expressions.eval <- gsub("GE",">=", membership.expressions.eval)
  membership.expressions.eval <- gsub("EQ","==", membership.expressions.eval)

  ####################################################################################### #
  ### Step 8: Evaluate member-ship expressions. Obtain logical plot x expression lists ####
  # logi1 holds the results from the evaluation of the membership conditions in plot.cond
  # for every expression. The key of this step is the eval(parse(text=x)) command
  # that allows to interpret text as logical expressions in R.

  logexpr <- sapply(membership.expressions.eval, function(x) parse(text=x))
  logi1 <- with(plot.cond, lapply(logexpr, function(x) eval(x)))
  logi1 <- lapply(logi1, function(z) {
    if (is.numeric(z)) z != 0 else z
  })
  names(logi1) <- paste("col", seq(1:length(membership.expressions)), sep="")
  ################################################################## #
  ### Step 9: Evaluate member-ship formulas. Obtain logical lists ####
  ################################################################## #
  logi2 <- with(logi1, lapply(logexpr.formula, function(x) eval(x)))
  names(logi2) <- vegtype.formula.names.short

  ############################################################# #
  ### Step 10: Apply priority rules for multiple assignments ####
  ############################################################# #

  message(paste('classification from here on', Sys.time()))

  # Types whose formula holds for each plot, in the order of the formulas. A
  # formula that evaluates to a single value holds for the first plot only.
  n_plots <- length(plots)
  holds <- vapply(logi2, function(v) v[seq_len(n_plots)], logical(n_plots))
  dim(holds) <- c(n_plots, length(logi2))
  hit <- which(holds, arr.ind = TRUE)
  types <- split(names(logi2)[hit[, 2]], factor(hit[, 1], levels = seq_len(n_plots)))
  types <- lapply(types, unname)
  names(types) <- plots

  # Plots with the same set of types get the same choice, so each set is
  # resolved once.
  key <- vapply(types, paste, character(1), collapse = "\r")
  first <- !duplicated(key)
  choice <- unlist(.resy_mclapply(types[first], FUN = function(x)
    .resy_classify_choice(x, vegtype.priority, vegtype.formula.names.short), mc = mc))
  result.classification <- choice[match(key, key[first])]
  names(result.classification) <- plots

  list(
    plot.cond = plot.cond,
    logi1 = logi1,
    logi2 = logi2,
    types = types,
    result.classification = result.classification
  )
}
