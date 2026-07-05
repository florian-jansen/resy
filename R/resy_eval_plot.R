utils::globalVariables(c("group_names", "TaxonName"))

#' Evaluate and print details for a single plot
#'
#' @param res A `resy_result` returned by [resy_classify()].
#' @param p Plot identifier (`PlotObservationID`) as character; if numeric, treated as
#'   row index in `header`.
#' @param type If vegetation-type short code is given, relevant conditions are shown
#' @export
resy_eval_plot <- function(res, p, type) {
  stopifnot(inherits(res, "resy_result"))
  
  obs <- res$obs
  header <- res$header
  logi2 <- res$logi2
  logi1 <- res$logi1
  
  vegtype.formula.names <- res$parsed$vegtype.formula.names
  vegtype.formula.names.short <- res$parsed$vegtype.formula.names.short
  vegtype.formulas.p <- res$parsed$vegtype.formulas.p
  vegtype.priority <- res$parsed$vegtype.priority
  membership.expressions <- res$parsed$membership.expressions
  groups <- res$parsed$groups
  groups.names <- res$parsed$groups.names
  
  if (is.numeric(p)) {
    warning('Plot numbers ("PlotObservationID") should be characters (indices), not numeric row numbers.')
    n <- p
    p <- as.character(header$PlotObservationID[n])
  } else {
    p <- as.character(p)
    n <- which(header$PlotObservationID == p)
  }
  obs_plot <- data.table::copy(obs[obs$PlotObservationID == p])
  
  if (!is.null(groups) && !is.null(groups.names) && "TaxonName" %in% names(obs_plot)) {
    grp_taxa <- lapply(groups, trimws)
    names(grp_taxa) <- trimws(groups.names)
    
    obs_plot[, group_names := vapply(
      trimws(TaxonName),
      function(tx) {
        hit <- names(grp_taxa)[vapply(grp_taxa, function(g) tx %in% g, logical(1))]
        if (length(hit)) paste(hit, collapse = " | ") else NA_character_
      },
      character(1)
    )]
    
    pos_taxon <- match("TaxonName", names(obs_plot))
    new_order <- append(names(obs_plot)[names(obs_plot) != "group_names"], "group_names", after = pos_taxon)
    data.table::setcolorder(obs_plot, new_order)
  }
  
  cat("Plant observations for plot", p, ":\n")
  print(obs_plot)
  
  if (!is.null(logi2)) {
    typ <- which(vapply(logi2, function(x) isTRUE(x[n]), logical(1)))
    cat('Possible types of plot "', p, '" (', n, '): ', paste(names(typ), collapse = ", "), "\n", sep = "")
    cat("Priorities of these types:", vegtype.priority[fastmatch::fmatch(names(typ), vegtype.formula.names.short)], "\n")
    cat("Classified as:", .resy_classify_choice(names(typ), vegtype.priority, vegtype.formula.names.short), "\n")
  }
  
  if (!missing(type)) {
    for(i in 1:length(type)) {
    cat('\n')
    typ <- type[i]
    t <- NA_integer_
    if (is.character(typ)) t <- fastmatch::fmatch(typ, vegtype.formula.names.short)
    
    if (is.na(t)) {
      cat("Type not defined.\n")
    } else {
      fml <- vegtype.formulas.p[t]
      
      all_tok <- stringr::str_match_all(fml, "!?\\s*\\(?\\s*col\\s*([0-9]+)")[[1]]
      if (nrow(all_tok) == 0L) {
        cat("Relevant expressions for", typ, ":\n")
        print(data.frame(expressions = character(), result = character(), responsible_taxa = character(), check.names = FALSE), right = FALSE)
        return(invisible(NULL))
      }
      
      col <- unique(as.integer(all_tok[, 2]))
      
      neg_tok <- stringr::str_match_all(fml, "!\\s*\\(?\\s*col\\s*([0-9]+)")[[1]]
      neg_col <- if (nrow(neg_tok)) unique(as.integer(neg_tok[, 2])) else integer()
      
      true_cols <- which(vapply(logi1, function(x) isTRUE(x[n]), logical(1)))
      
      expr_short <- ifelse(
        nchar(membership.expressions[col]) > 100,
        paste0(substr(membership.expressions[col], 1, 100), "..."),
        membership.expressions[col]
      )
      
      .extract_condition_terms <- function(expr) {
        x <- trimws(expr)
        x <- gsub("^<|>$", "", x)
        x <- gsub("^#(?:TC|[0-9]{2})\\s*", "", x)
        x <- gsub("\\s+", " ", x)
        terms <- trimws(unlist(strsplit(x, "\\|", perl = TRUE), use.names = FALSE))
        terms[nzchar(terms)]
      }
      
      .taxa_for_condition <- function(expr, obs_taxa, groups, groups.names) {
        refs <- .extract_condition_terms(expr)
        if (!length(refs)) return(NA_character_)
        
        gn <- trimws(groups.names)
        grp_taxa <- lapply(groups, trimws)
        names(grp_taxa) <- gn
        
        hits <- character()
        
        for (ref in refs) {
          ref2 <- trimws(ref)
          
          if (ref2 %in% gn) {
            hits <- c(hits, intersect(obs_taxa, grp_taxa[[ref2]]))
          } else {
            hits <- c(hits, intersect(obs_taxa, ref2))
          }
        }
        
        hits <- unique(trimws(hits))
        if (!length(hits)) NA_character_ else paste(hits, collapse = " | ")
      }
      
      obs_taxa <- unique(trimws(obs_plot$TaxonName))
      
      responsible_taxa <- vapply(
        col,
        function(j) {
          .taxa_for_condition(
            membership.expressions[j],
            obs_taxa = obs_taxa,
            groups = groups,
            groups.names = groups.names
          )
        },
        character(1)
      )

      result_label <- rep("FALSE", length(col))
      result_label[col %in% true_cols] <- "TRUE"
      result_label[col %in% true_cols & col %in% neg_col] <- "TRUE [NOT]"
      
      cat("Relevant expressions for", typ, ":\n")
      print(
        data.frame(
          row.names = col,
          expressions = expr_short,
          result = result_label,
          responsible_taxa = responsible_taxa,
          check.names = FALSE
        ),
        right = FALSE
      )
    }
    }
  }
  
  invisible(NULL)
}
