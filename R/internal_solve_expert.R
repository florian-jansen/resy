#' @keywords internal
.resy_membership_parts <- function(x, prefix = NULL) {
  parts <- trimws(unlist(strsplit(x, "\\|", perl = TRUE), use.names = FALSE))
  parts <- parts[nzchar(parts)]
  if (!length(parts)) return(character())
  
  # "|" combines groups: "#TC A|#TC B" is the union of A and B. Every part after
  # the first repeats the condition code, so the code is removed from each part.
  normalize_part <- function(p) {
    p <- trimws(p)
    if (!is.null(prefix) && startsWith(p, prefix)) {
      p <- trimws(substring(p, nchar(prefix) + 1L))
    }
    trimws(sub("^(###|##[QCDN]|#TC|#T\\$|#SC|#\\$\\$|#[0-9]{2})\\s+", "", p))
  }
  parts <- vapply(parts, normalize_part, character(1), USE.NAMES = FALSE)
  parts[nzchar(parts)]
}

#' @keywords internal
.resy_group_taxa_union <- function(x, groups, groups.names, prefix = NULL) {
  ids <- .resy_membership_parts(x, prefix = prefix)
  idx <- fastmatch::fmatch(ids, groups.names)
  idx <- idx[!is.na(idx)]
  if (!length(idx)) return(character())
  taxa <- unique(trimws(unlist(groups[idx], use.names = FALSE)))
  taxa[nzchar(taxa)]
}

#' @keywords internal
.resy_group_taxa_or_species <- function(x, groups, groups.names, prefix = NULL) {
  ids <- .resy_membership_parts(x, prefix = prefix)
  idx <- fastmatch::fmatch(ids, groups.names)
  taxa <- character()
  if (any(!is.na(idx))) {
    taxa <- unique(trimws(unlist(groups[idx[!is.na(idx)]], use.names = FALSE)))
  }
  species <- trimws(ids[is.na(idx)])
  species <- species[nzchar(species)]
  unique(c(taxa, species))
}

# Taxa that one membership condition (an element of `parsed$conditions`) refers
# to, resolved the way the solver resolves them: the leading code token
# ("###", "##Q", "#TC", "#05", ...) is dropped, "|" joins groups, "A EXCEPT B"
# removes the taxa of B from those of A, a "NON" comparison refers to the group
# it names, and a condition without a code is a single species. Header
# conditions ("$$C", "$$N") and whole-plot cover ("#T$", "#$$", "$05") without a
# group return no taxa.
#' @keywords internal
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

# Taxa of a condition of the form "A EXCEPT B": the union of the groups in A
# minus the taxa of the groups or species in B. Without EXCEPT, the union of A.
#' @keywords internal
.resy_except_taxa <- function(x, groups, groups.names, prefix = NULL) {
  parts <- trimws(strsplit(x, "EXCEPT", fixed = TRUE)[[1]])
  taxa <- .resy_group_taxa_union(parts[1], groups, groups.names, prefix = prefix)
  if (length(parts) > 1L) {
    drop <- .resy_group_taxa_or_species(parts[2], groups, groups.names, prefix = prefix)
    taxa <- taxa[is.na(fastmatch::fmatch(taxa, drop))]
  }
  taxa
}

# Per-plot value of `stat(Cover_Perc, TaxonName)` over the observations whose
# taxon is in `taxa` (or, with `exclude = TRUE`, not in `taxa`). Plots without
# such observations are absent from the result.
#' @keywords internal
.resy_plot_stat <- function(obs, taxa, stat, exclude = FALSE) {
  keep <- obs$TaxonName %in% taxa
  if (exclude) keep <- !keep
  if (!any(keep)) return(NULL)
  obs[keep, list(x = stat(Cover_Perc, TaxonName)), by = PlotObservationID]
}

# Fill columns `cols` of the plot x condition matrix: column `cols[k]` receives
# the per-plot statistic over `taxa[[k]]`. `stat` is one function for all
# columns or a list with one function per column. Rows are matched by plot id.
#' @keywords internal
.resy_fill_conditions <- function(plot.cond, obs, cols, taxa, stat,
                                  exclude = FALSE, mc = 1L) {
  if (!length(cols)) return(plot.cond)
  stats <- if (is.function(stat)) rep(list(stat), length(cols)) else stat
  l <- .resy_mclapply(seq_along(cols), function(k)
    .resy_plot_stat(obs, taxa[[k]], stats[[k]], exclude = exclude), mc = mc)
  n <- vapply(l, function(d) if (is.null(d)) 0L else nrow(d), integer(1))
  if (!sum(n)) return(plot.cond)
  rows <- fastmatch::fmatch(unlist(lapply(l, `[[`, "PlotObservationID"), use.names = FALSE),
                            rownames(plot.cond))
  plot.cond[cbind(rows, rep(cols, n))] <- unlist(lapply(l, `[[`, "x"), use.names = FALSE)
  plot.cond
}

# Per-plot statistics of the cover values (and taxa) of the selected observations.
.resy_stat_n      <- function(cover, taxa) length(cover)
.resy_stat_sqrt   <- function(cover, taxa) round(sum(sqrt(cover)), 5)
.resy_stat_sum    <- function(cover, taxa) sum(cover)
.resy_stat_total  <- function(cover, taxa) .total_cover(cover)
.resy_stat_max    <- function(cover, taxa) max(cover)
.resy_stat_mean   <- function(cover, taxa) mean(cover)
.resy_stat_sqrt_q <- function(cover, taxa) sum(cover^0.5)

#' @keywords internal
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
    lapply(x, .resy_group_taxa_union, groups = groups, groups.names = groups.names,
           prefix = prefix)
  except_of <- function(x, prefix)
    lapply(x, .resy_except_taxa, groups = groups, groups.names = groups.names,
           prefix = prefix)
  fill <- function(cols, taxa, stat, exclude = FALSE)
    .resy_fill_conditions(plot.cond, obs, cols, taxa, stat, exclude = exclude, mc = mc)
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
  plot.cond <- fill(w, union_of(body(conditions[w])), .resy_stat_n)

  #################################################################################### #
  # 5.2. Minimum number of species which have to be present in a group (#01 to #99) ####
  ##!! Not to be confounded with +01, +02 etc. in group names, which is for additional hierarchy with differential species groups !!##
  w <- suppressWarnings(which(!is.na(as.numeric(substr(conditions, 2, 3))) & startsWith(conditions, "#")))
  message('Step 5.2  Number of conditions with minimum number of species: ', length(w))
  at_least <- lapply(as.numeric(substr(conditions[w], 2, 3)), function(nb) {
    force(nb)
    function(cover, taxa) as.integer(data.table::uniqueN(taxa) >= nb)
  })
  plot.cond <- fill(w, union_of(body(conditions[w])), at_least)

  ##################################################### #
  # 5.3. '##Q sum of square root Cover_Perc'         ####
  w <- which(startsWith(conditions, "##Q") | startsWith(conditions, "##D"))
  message('Step 5.3  Number of conditions with sum of square rooted Cover_Perc of species: ', length(w))
  plot.cond <- fill(w, union_of(body(conditions[w])), .resy_stat_sqrt)

  ###################################################### #
  # 5.4. Total Cover_Perc of the group (##C)          ####
  w <- which(startsWith(conditions, "##C") | startsWith(conditions, "##D"))
  message('Step 5.4  Number of conditions with total Cover_Perc of the group: ', length(w))
  plot.cond <- fill(w, union_of(body(conditions[w])), .resy_stat_sum)

  ########################################################################################## #
  # 5.5 Total Cover_Perc (#TC) and percent of total cover of all other species ($05, $10) ####
  # "#T$" alone is the total cover of the plot.
  w <- which(conditions == "#T$")
  message('Step 5.5  Number of conditions with total Cover_Perc of all other species: ', length(w))
  plot.cond <- fill(w, all_taxa(w), .resy_stat_total, exclude = TRUE)

  # "#T$ A" and "#T$ A|#T$ B": total cover of all species outside the groups.
  # Conditions with EXCEPT are handled below.
  w <- which(startsWith(conditions, "#T$") & nzchar(body(conditions)) & !has_except)
  message('          Number of conditions with total Cover_Perc of all other species except those on the left-hand side: ', length(w))
  plot.cond <- fill(w, union_of(conditions[w], prefix = "#T$"), .resy_stat_total,
                    exclude = TRUE)

  # "#TC A" and "#TC A|#TC B": total cover of the species in the groups.
  w <- which(startsWith(conditions, "#TC") & !has_except)
  plot.cond <- fill(w, union_of(conditions[w], prefix = "#TC"), .resy_stat_total)

  # "$05", "$25", ...: that percentage of the total cover of the plot.
  w <- which(grepl("\\$[0-9]", conditions))
  message('          Number of conditions with $05, $25 etc.: ', length(w))
  share_of_total <- lapply(as.numeric(sub("$", "", conditions[w], fixed = TRUE)) / 100,
                           function(p) { force(p); function(cover, taxa) .total_cover(cover) * p })
  plot.cond <- fill(w, all_taxa(w), share_of_total, exclude = TRUE)

  # "#TC A|#TC B EXCEPT C" and "#TC A EXCEPT C": total cover of the groups
  # without the taxa of C.
  w <- which(startsWith(conditions, "#TC") & grepl("|#", conditions, fixed = TRUE) & has_except)
  plot.cond <- fill(w, except_of(conditions[w], prefix = "#TC"), .resy_stat_total)
  w <- which(has_except &
               !grepl("|", conditions, fixed = TRUE) &
               !startsWith(conditions, "#SC") &
               !startsWith(conditions, "#$$"))
  plot.cond <- fill(w, except_of(conditions[w], prefix = "#TC"), .resy_stat_total)

  ######################################################### #
  # 5.6   Cover of any species in the group (#SC)   ####
  # The cover of the species is greater than the cover of any single species in
  # the functional species group, except of the species at the left-hand side of
  # the logical operator. "#SC" occurs at the beginning of a condition and after
  # "|#" inside it; on right-hand sides it always comes with EXCEPT and group
  # names or names of single species.
  w <- which(grepl("#SC", conditions, fixed = TRUE))
  message('Step 5.6  Number of conditions with maximum cover of the group: ', length(w))
  plot.cond <- fill(w, except_of(conditions[w], prefix = "#SC"), .resy_stat_max)

  ######################################################## #
  # 5.7. Cover percentage single species and SC left    ####
  w <- which(!startsWith(conditions, "#") &
               !startsWith(conditions, "$") &
               !startsWith(conditions, "NON"))
  message('Step 5.7  Number of conditions with single species, header levels (e.g. country names): ', length(w))
  plot.cond <- fill(w, as.list(conditions[w]), .resy_stat_mean)

  ################################################################## #
  # 5.8   Highest Cover_Perc of any species in plot (#$$ EXCEPT)  ####
  w <- which(conditions == "#$$")
  message('Step 5.8  Number of conditions with maximum Cover_Perc in plot: ', length(w))
  plot.cond <- fill(w, all_taxa(w), .resy_stat_max, exclude = TRUE)

  # "#$$ EXCEPT B": highest cover of any species outside the groups or species of B.
  w <- which(startsWith(conditions, "#$$") & has_except)
  message('          Number of conditions with maximum Cover_Perc in plot EXCEPT species of target group: ', length(w))
  outside <- lapply(conditions[w], function(i)
    .resy_group_taxa_or_species(trimws(strsplit(i, "EXCEPT", fixed = TRUE)[[1]])[[2]],
                                groups, groups.names))
  plot.cond <- fill(w, outside, .resy_stat_max, exclude = TRUE)

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
    q <- .resy_fill_conditions(`rownames<-`(q, plots), obs, seq_along(group.d),
                               lapply(group.d, function(i) unlist(groups[i], use.names = FALSE)),
                               .resy_stat_sqrt_q, mc = mc)
    group.d.names <- names(groups)[group.d]
    for (j in wn) {
      target <- body(conditions[j])
      substr(target, 1, 3) <- "##D"
      others <- which(substr(group.d.names, 5, 7) == substr(target, 5, 7) &
                        group.d.names != target)
      if (length(others))
        plot.cond[, j] <- round(apply(q[, others, drop = FALSE], 1, max, na.rm = TRUE), 5)
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

  types <- .resy_mclapply(seq_along(plots), function(x) names(which(sapply(logi2, '[', x))),
                          mc = mc)
  names(types) <- plots

  result.classification <- unlist(.resy_mclapply(types, FUN = function(x)
    .resy_classify_choice(x, vegtype.priority, vegtype.formula.names.short), mc = mc))

  list(
    plot.cond = plot.cond,
    logi1 = logi1,
    logi2 = logi2,
    types = types,
    result.classification = result.classification
  )
}
