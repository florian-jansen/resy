#' @keywords internal
.resy_membership_parts <- function(x, prefix = NULL) {
  parts <- trimws(unlist(strsplit(x, "\\|", perl = TRUE), use.names = FALSE))
  parts <- parts[nzchar(parts)]
  if (!length(parts)) return(character())
  
  normalize_part <- function(p) {
    p <- trimws(p)
    if (!is.null(prefix) && startsWith(p, prefix)) {
      p <- trimws(substring(p, nchar(prefix) + 1L))
    }
    p
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

#' @keywords internal
.resy_solve_membership <- function(obs, header, parsed, plot.cond, mc = 1L) {
  # parsed <- resy_load_expert(expertfile = NULL, scheme = "VegformMV", version = '2026-03-05')
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
  # 9. NON conditions, where species number (N), cover (C) or sum of squared  cover (Q) is compared with all other species groups
  # 10. Header data, categorical ($$C) and numeric ($$N)
  # In all cases: handle “|” (combine groups) and EXCEPT

  if(!'data.table' %in% class(obs)) stop('obs must be of class data.table')
    ############################################### #
    # 5.1. Number of species (###) of a group    ####
    w = which(startsWith(conditions, "###") | startsWith(conditions, "##D"))
    message('Step 5.1  Number of conditions with number of species of a group: ', length(w))
    FUN <- function(i) {
      taxa <- .resy_group_taxa_union(i, groups, groups.names)
      obs[obs$TaxonName %in% taxa, list(x = .N), by = PlotObservationID]
    }
    if(length(w) > 0) {
       cond <- sapply(conditions[w], function(x) substr(x, 5, nchar(x)), USE.NAMES = FALSE)
       l <-  .resy_mclapply(cond, function(x) FUN(x), mc.cores=mc)
       ind <- matrix(c(fmatch(unlist(sapply(l, function(x) x$PlotObservationID)), dimnames(plot.cond)[[1]]),
                      rep(w, sapply(l, function(x) nrow(x))) ), ncol = 2)
       plot.cond[ind] <- unlist(sapply(l, function(x) x$x, USE.NAMES = FALSE))
    }

    #################################################################################### #
    # 5.2. Minimum number of species which have to be present in a group (#01 to #99) ####
    ##!! Not to be confounded with +01, +02 etc. in group names, which is for additional hierarchy with differential species groups !!##
    w <- suppressWarnings(which(!is.na(as.numeric(substr(conditions,2,3))) & startsWith(conditions, "#")))
    message('Step 5.2  Number of conditions with minimum number of species: ', length(w))
    cond <- sapply(conditions[w], function(x) substr(x, 5, nchar(x)), USE.NAMES = FALSE)
    nb <- as.numeric(sapply(conditions[w], function(x) substr(x, 2, 3), USE.NAMES = FALSE))
    FUN <- function(i, nb) {
      taxa <- .resy_group_taxa_union(i, groups, groups.names)
      result <- obs[obs$TaxonName %in% taxa,
                    .(x = uniqueN(TaxonName)),
                    by = PlotObservationID]
      result[, y := as.integer(x >= nb)]
      result
    }
    # FUN(cond[[1]], nb[[1]])
    l =  .resy_mcmapply(FUN, cond, nb, SIMPLIFY = FALSE)
    ind <- matrix(c(fmatch(unlist(sapply(l, function(x) x$PlotObservationID)), dimnames(plot.cond)[[1]]),
                    rep(w, sapply(l, function(x) nrow(x))), unlist(sapply(l, function(x) x$y, USE.NAMES = FALSE)) ), ncol = 3)
    plot.cond[ind[,1:2]] <- ind[,3]

    ##################################################### #
    # 5.3. '##Q sum of square root Cover_Perc'         ####
    w = which(startsWith(conditions, "##Q") | startsWith(conditions, "##D"))
    message('Step 5.3  Number of conditions with sum of square rooted Cover_Perc of species: ', length(w))
    if(length(w) > 0) {
      cond <- sapply(conditions[w], function(x) substr(x, 5, nchar(x)), USE.NAMES = FALSE)
      FUN <- function(i) {
        taxa <- .resy_group_taxa_union(i, groups, groups.names)
        obs[obs$TaxonName %in% taxa, list(x=sum(sqrt(Cover_Perc))), by=PlotObservationID]
      }
      l <-  .resy_mclapply(cond, function(x) FUN(x), mc.cores=mc)
      ind <- matrix(c(fmatch(unlist(sapply(l, function(x) x$PlotObservationID)), dimnames(plot.cond)[[1]]),
                      rep(w, sapply(l, function(x) nrow(x))) ), ncol = 2)
      plot.cond[ind] <- unlist(sapply(l, function(x) round(x$x,5), USE.NAMES = FALSE))

    }

   ###################################################### #
   # 5.4. Total Cover_Perc of the group (##C)          ####
    w = which(startsWith(conditions, "##C") | startsWith(conditions, "##D"))
    message('Step 5.4  Number of conditions with total Cover_Perc of the group: ', length(w))
    if(length(w) > 0) {
      cond <- sapply(conditions[w], function(x) substr(x, 5, nchar(x)), USE.NAMES = FALSE)
      FUN <- function(i) {
        taxa <- .resy_group_taxa_union(i, groups, groups.names)
        obs[obs$TaxonName %in% taxa, list(x=sum(Cover_Perc)), by=PlotObservationID]
      }
      l =  .resy_mclapply(cond, function(x) FUN(x), mc.cores=mc)
      ind <- matrix(c(fmatch(unlist(sapply(l, function(x) x$PlotObservationID)), dimnames(plot.cond)[[1]]),
                    rep(w, sapply(l, function(x) nrow(x))) ), ncol = 2)
      plot.cond[ind] <- unlist(sapply(l, function(x) x$x, USE.NAMES = FALSE))
    }


    ########################################################################################## #
    # 5.5 Total Cover_Perc (#TC) and percent of total cover of all other species ($05, $10) ####
    # check whether there is "#T$" as single condition also on the left-hand side, e.g. with "GE" as operator:
    # "#T$ GE 30" which means that total Cover_Perc is greater or equal than 30%
    # if(any(trim(tstrsplit(membership.expressions, "GE", fixed=TRUE)[[1]])=="#T$")) warning('"#T$ GE" detected.')
    w <- which(conditions == "#T$")
    message('Step 5.5  Number of conditions with total Cover_Perc of all other species: ', length(w))
    plot.cond[,w] <- tapply(obs$Cover_Perc, obs$PlotObservationID, .total_cover)

    # '#T$' total Cover_Perc of all other species except those on the left-hand side
    # we exclude "|#" and "EXCEPT" because we handle these cases separately below
    w <- which(startsWith(conditions, "#T$") &
                 regexpr("|#", conditions, fixed=T) == -1 &
                 regexpr("EXCEPT", conditions, fixed=T) == -1)
    message('          Number of conditions with total Cover_Perc of all other species except those on the left-hand side: ', length(w))
    #  d <- which(substr(conditions[w], 6,7) %in% discr)
    cond <- sapply(conditions[w], function(x) substr(x, 5, nchar(x)), USE.NAMES = FALSE)
    w <- w[cond != '']   # necessary because we still have #T$ in the conditions
    cond <- cond[cond != '']
    FUN <- function(i) {
      taxa <- .resy_group_taxa_union(i, groups, groups.names, prefix = "#T$")
      result <- obs[!obs$TaxonName %in% taxa, list(x= .total_cover(Cover_Perc)), by=PlotObservationID]
      return(result)
    }
    l =  .resy_mclapply(cond, function(x) FUN(x), mc.cores=mc)
    ind <- matrix(c(fmatch(unlist(sapply(l, function(x) x$PlotObservationID)), unique(obs$PlotObservationID)),
                    rep(w, sapply(l, function(x) nrow(x)) ) ), ncol = 2)
    plot.cond[ind] <- unlist(sapply(l, function(x) x$x, USE.NAMES = FALSE))

    ### #TC total cover of all species in this group  ###
    # we exclude "|#" and "EXCEPT" because we handle these cases separately below
    wn <- which(startsWith(conditions, "#TC") & !grepl("|#", conditions, fixed=TRUE) & !grepl("EXCEPT",conditions, fixed=TRUE))
    # also includes | operator, which is a combination of the two groups the species groups have to be combined
    # "#TC Atlantic-heath-shrubs|#TC Lowland-to-alpine-heath-shrubs"
    if(length(wn) > 0) {
      FUN <- function(i) {
        taxa <- .resy_group_taxa_union(i, groups, groups.names, prefix = NULL)  # prefix = '#TC
        obs[obs$TaxonName %in% taxa, list(x= .total_cover(Cover_Perc)), by=PlotObservationID]
      }
      l <- .resy_mclapply(substr(conditions[wn],5, nchar(conditions[wn])), FUN, mc.cores = mc)
      ind <- matrix(c(fmatch(unlist(sapply(l, function(x) x$PlotObservationID)), dimnames(plot.cond)[[1]]),
                      rep(wn, sapply(l, function(x) nrow(x))) ), ncol = 2)
      plot.cond[ind] <- unlist(sapply(l, function(x) x$x, USE.NAMES = FALSE))
    }

    # We calculate total cover and then take the percentage
    w <- which(grepl("\\$[0-9]",conditions))
    # conditions[w]
    message('          Number of conditions with $05, $25 etc.: ', length(w))
    if(length(w) > 0) {
      cond <- conditions[w]
      FUN <- function(i) {
        prop.total.cover <- as.numeric(sub("$","", i, fixed=TRUE))/100
        return(obs[, list(x= .total_cover(Cover_Perc)*prop.total.cover), by=PlotObservationID])
      }
      l =  .resy_mclapply(cond, function(x) FUN(x), mc.cores=mc)
      ind <- matrix(c(fmatch(unlist(sapply(l, function(x) x$PlotObservationID)), dimnames(plot.cond)[[1]]),
                      rep(w, sapply(l, function(x) nrow(x))) ), ncol = 2)
      plot.cond[ind] <- unlist(sapply(l, function(x) x$x, USE.NAMES = FALSE))
    }

    ### now handle cases of | and EXCEPT ###
    # first: deal with | without EXCEPT a) #T$
    wn <- which(startsWith(conditions, "#T$") & grepl("|#", conditions, fixed=TRUE) & !grepl("EXCEPT",conditions, fixed=TRUE))
    if(length(wn) > 0) {
      # #TS means total cover of all species not in these groups
      FUN <- function(i) {
        b <- .resy_group_taxa_union(i, groups, groups.names, prefix = "#T$")
        return(obs[!obs$TaxonName %in% b, list(x= .total_cover(Cover_Perc)), by=PlotObservationID])
      }
      l <- .resy_mclapply(conditions[wn], FUN, mc.cores = mc)
      ind <- matrix(c(fmatch(unlist(sapply(l, function(x) x$PlotObservationID)), dimnames(plot.cond)[[1]]),
                      rep(wn, sapply(l, function(x) nrow(x))) ), ncol = 2)
      plot.cond[ind] <- unlist(sapply(l, function(x) x$x, USE.NAMES = FALSE))
    }

    # second: deal with | without except b) #TC
    wn <- which(startsWith(conditions, "#TC") & grepl("\\|#", conditions) & !grepl("EXCEPT",conditions, fixed=TRUE))
    if(length(wn) > 0) {
      # #TS means total cover of all species not in these groups
      FUN <- function(i) {
        taxa <- .resy_group_taxa_union(i, groups, groups.names, prefix = "#TC")
        return(obs[obs$TaxonName %in% taxa, list(x= .total_cover(Cover_Perc)), by=PlotObservationID])
      }
      l <- .resy_mclapply(conditions[wn], FUN, mc.cores = mc)
      ind <- matrix(c(fmatch(unlist(sapply(l, function(x) x$PlotObservationID)), dimnames(plot.cond)[[1]]),
                      rep(wn, sapply(l, function(x) nrow(x))) ), ncol = 2)
      plot.cond[ind] <- unlist(sapply(l, function(x) x$x, USE.NAMES = FALSE))
    }

    # third: | and except
    # 1. divide condition at EXCEPT in left- and right hand side
    # make sure that the condition starts with #TC

    wn <- which(startsWith(conditions, "#TC") & grepl("|#", conditions, fixed=TRUE) & grepl("EXCEPT",conditions, fixed=TRUE))
    # only occurs with #TC and single species
    if(length(wn) > 0) {
      FUN <- function(i) {
        d <- trimws(unlist(strsplit(i, "EXCEPT", fixed = TRUE), use.names = FALSE))
        b1 <- .resy_group_taxa_union(d[1], groups, groups.names, prefix = "#TC")
        b2 <- .resy_group_taxa_or_species(d[2], groups, groups.names, prefix = "#TC")
        b <- b1[is.na(fastmatch::fmatch(b1, b2))]
        return(obs[obs$TaxonName %in% b, list(x= .total_cover(Cover_Perc)), by=PlotObservationID])
      }
      l <- .resy_mclapply(conditions[wn], FUN, mc.cores = mc)
      ind <- matrix(c(fmatch(unlist(sapply(l, function(x) x$PlotObservationID)), dimnames(plot.cond)[[1]]),
                      rep(wn, sapply(l, function(x) nrow(x))) ), ncol = 2)
      plot.cond[ind] <- unlist(sapply(l, function(x) x$x, USE.NAMES = FALSE))
    }


    # fourth: deal with EXCEPT only (without #SC, which we have dealt with before)
    wn <- which(grepl("EXCEPT",conditions, fixed=TRUE) &
                  !grepl("|", conditions, fixed=TRUE) &
                  !startsWith(conditions, "#SC") &
                  !startsWith(conditions, "#$$"))
    # conditions[wn]
    # all have #TC: if other conditions exist they would have to be dealt with separately
    if(length(wn) > 0) {
      FUN <- function(i) {
        a <- trimws(unlist(strsplit(i, "EXCEPT", fixed = TRUE)))
        b <- .resy_group_taxa_union(a[1], groups, groups.names, prefix = "#TC")
        c <- .resy_group_taxa_or_species(a[2], groups, groups.names, prefix = "#TC")
        b <- b[is.na(fastmatch::fmatch(b, c))]
        return(obs[obs$TaxonName %in% b, list(x= .total_cover(Cover_Perc)), by=PlotObservationID])
      }
      l <- .resy_mclapply(conditions[wn], FUN, mc.cores = mc)
      ind <- matrix(c(fmatch(unlist(sapply(l, function(x) x$PlotObservationID)), dimnames(plot.cond)[[1]]),
                      rep(wn, sapply(l, function(x) nrow(x))) ), ncol = 2)
      plot.cond[ind] <- unlist(sapply(l, function(x) x$x, USE.NAMES = FALSE))
    }

   ######################################################### #
   # 5.6   Cover of any species in the group (#SC)   ####
    ### #SC maximum cover of the group ###
    # The cover of the species is greater than the cover of any single species in the functional species group,
    # except of the species at the left-hand side of logical operator.
    w <- which(grepl("#SC", conditions, fixed=TRUE))
    # "#SC" occurs both at the beginning of the condition and after "|#" inside
    # "#SC" on left-hand sides can appear with group names
    # it would be logical to write this with EXCEPT, but which currently is not done
    # "#SC" on right-hand sides does appear always with EXCEPT and group names
    # or names of single species. EXCEPT had been inserted by us in
    # ParsingExpertFile.R by us into the code
    # Here we handle all possible cases
    message('Step 5.6  Number of conditions with maximum cover of the group: ', length(w))
    if(length(w) > 0) {
      FUN <- function(i) {
        a <- trimws(unlist(strsplit(i, "EXCEPT", fixed = TRUE)))
        b <- .resy_group_taxa_union(a[1], groups, groups.names, prefix = "#SC")
        if (length(a) > 1) {
          c <- .resy_group_taxa_or_species(a[2], groups, groups.names, prefix = "#SC")
          b <- b[is.na(fastmatch::fmatch(b, c))]
        }
        if(any(obs$TaxonName %in% b)) {
         return(obs[obs$TaxonName %in% b, list(x=max(Cover_Perc)), by=PlotObservationID])
        } else {
         return(data.table::data.table(PlotObservationID=NULL, x=NULL))
        }
      }
      # for(n in 1:length(w)) FUN(i=conditions[w][n])
      l =  .resy_mclapply(conditions[w], function(x) FUN(x), mc.cores=mc)
      ind <- matrix(c(fmatch(unlist(sapply(l, function(x) x$PlotObservationID)), dimnames(plot.cond)[[1]]),
                      rep(w, sapply(l, function(x) nrow(x))) ), ncol = 2)
      plot.cond[ind] <- unlist(sapply(l, function(x) x$x, USE.NAMES = FALSE))
    }


    ######################################################## #
    # 5.7. Cover percentage single species and SC left    ####
    w <- conditions[!startsWith(conditions, "#") &
                      !startsWith(conditions, "$") &
                      !startsWith(conditions, "NON")]
    message('Step 5.7  Number of conditions with single species, header levels (e.g. country names): ', length(w))
    FUN <- function(i) obs[obs$TaxonName %in% i, list(x=mean(Cover_Perc)), by=PlotObservationID]
    l <-  .resy_mclapply(w, FUN, mc.cores=mc)
    ind <- matrix(c(fmatch(unlist(sapply(l, function(x) x$PlotObservationID)), dimnames(plot.cond)[[1]]),
                    rep(fmatch(w, conditions), sapply(l, function(x) nrow(x))) ), ncol = 2)
    plot.cond[ind] <- unlist(sapply(l, function(x) x$x, USE.NAMES = FALSE))

    ################################################################## #
    # 5.8   Highest Cover_Perc of any species in plot (#$$ EXCEPT)  ####
    w = which(conditions=="#$$")
    # only those that contain #$$ and no further EXCEPT condition
    message('Step 5.8  Number of conditions with maximum Cover_Perc in plot: ', length(w))
    if(length(w) > 0)
      plot.cond[,w] <- tapply(obs$Cover_Perc, obs$PlotObservationID, max)

    ## highest Cover_Perc in plot #$$ EXCEPT for species from a species group ###
    w = which(startsWith(conditions, "#$$") & grepl("EXCEPT", conditions,fixed=T))
    message('          Number of conditions with maximum Cover_Perc in plot EXCEPT species of target group: ', length(w))
    if(length(w) > 0) {
      FUN <- function(i) {
        a <- trimws(unlist(strsplit(i, "EXCEPT", fixed=TRUE)))
        b <- .resy_group_taxa_or_species(a[[2]], groups, groups.names)
        return(obs[!obs$TaxonName %in% b, list(x=max(Cover_Perc)), by=PlotObservationID])
      }
      l <- .resy_mclapply(conditions[w], FUN, mc.cores = mc)
      ind <- matrix(c(fmatch(unlist(sapply(l, function(x) x$PlotObservationID)), dimnames(plot.cond)[[1]]),
                      rep(w, sapply(l, function(x) nrow(x))) ), ncol = 2)
      plot.cond[ind] <- unlist(sapply(l, function(x) x$x, USE.NAMES = FALSE))
     }

    ################################################## #
    # 5.9 Total cover of all other species     ####
    # except those of the group (#T$ NON)

    wn <- grep("NON", conditions, ignore.case = FALSE)
    message('Step 5.9  Number of T$ NON conditions: ', length(wn))

    if(length(wn[!grep('##Q', conditions[wn])]) > 0) stop('Only square root cover value NON condition implemented.')
    # currently only the sqrt(cover) of all the species in the corresponding group is calculated,
    # We need to calculated the sqrt(cover) of all other groups in the system!
    conditions.wn <- substr(conditions[wn],5 , nchar(conditions[wn]))
    substr(conditions.wn,1,3) <- "##D"
    # the ##D groups are used for the same purpose as the ##Q groups
    index6 <- which(substr(names(groups),3,3)=="D")
    # these are all differential groups used for a comparison
    a <- match(conditions.wn, names(groups)[index6])
    # any(is.na(a)) # F, all membership.conditions3 are found in the group names
    # the following opposite check is not necessary
    b <- match(names(groups)[index6],conditions.wn)

    # we need to calculate species number (N), cover (C) and sum of squared
    # cover (Q) of all these groups
    # currently only implemented for Q, but see stop condition above
    plot.group.non.Q <- matrix(0, nrow=length(unique(obs$PlotObservationID)), ncol=length(index6)) ##Q

    if(length(index6) > 0) {
      FUN <- function(i) obs[obs$TaxonName %in% unlist(groups[i], use.names=FALSE), list(x=sum(Cover_Perc^0.5)), by=PlotObservationID]
      l =  .resy_mclapply(index6, function(x) FUN(x), mc.cores=mc)
      ind <- matrix(c(fmatch(unlist(sapply(l, function(x) x$PlotObservationID)), unique(obs$PlotObservationID)),
                      rep(1:length(index6), sapply(l, function(x) nrow(x))) ), ncol = 2)
      plot.group.non.Q[ind] <- unlist(sapply(l, function(x) x$x, USE.NAMES = FALSE))
    }

    pgna <- names(groups)[index6]
    result <- NULL
    plot.group.non.N <- matrix(0, nrow=length(unique(obs$PlotObservationID)), ncol=length(index6)) ##N
    for(j in 1:length(conditions.wn)){
      # including the + sign at the beginning of the group name
      # only groups of the same set are compared with each other
      # at the same time the group itself is excluded
      group.set <- substr(conditions.wn[j],5,7)
      index9 <- which(substr(pgna,5,7)==group.set & pgna!=conditions.wn[j])
      if(length(index9) > 0) {
      # b is: 1==N, 2==C, 3==Q
      a <- substr(conditions[wn[j]],7,7)
      if (a=="N" | a=="D"){
        # in membership.conditions2 all groups are coded "D", rather than "N"
        # thus we ask for both options
        x <- apply(plot.group.non.N[,-index9],1, FUN=max, na.rm=T)
      } else {
        if (a=="C"){
          x <- apply(plot.group.non.C[,-index9],1, FUN=max, na.rm=T)
        } else {
          # then it is "Q"
          x <- apply(plot.group.non.Q[,index9,drop=F],1, FUN=max, na.rm=T)
        }
      }
      result <- cbind(result, x)
      index5 <- which(conditions==conditions[wn[j]])
      plot.cond[,index5] <- round(result[,j],5)
      # columns in result are conditions.wn
      }
    }


    ######################################## #
    # 5.10. evaluate header data          ####
    ### Numerical
    w <- conditions[startsWith(conditions, '$$N')]
    message('Step 5.10  Header conditions with numeric values: ', length(w))
    if(length(w) > 0) {
      m <- match(substr(w, 5, nchar(w)), names(header))
      W <- w[!is.na(m)]
      m <- m[!is.na(m)]
      ind <- matrix(c(rep(1:nrow(header), length(m)),
                                       rep(fmatch(W, conditions), each = nrow(header)),
                                       as.numeric(unlist(header[, m], use.names = FALSE))), ncol = 3)
      ind[,3][is.na(ind[,3])] <- 0
      plot.cond[ind[,1:2]] <- ind[,3]
    }
    ### Categorical
    w <- conditions[startsWith(conditions, '$$C')]
    message('  Header conditions with character values: ', length(w))
    categorical.header <- intersect(names(header), substr(w, 5, nchar(w)))
    for(i in categorical.header) {
  #    header[,i][is.na(header[,i])] <- NA
      b <- as.factor(as.character(header[,i]))
      if(length(levels(b)) > 0) {
      # left hand
      # mark NAs as -1, otherwise they will be set 0 and result in wrong
      # comparisons
      c <- as.numeric(b)
      c[is.na(c)] <- -1
      plot.cond[, grep(i, conditions)] <- c
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
      } else plot.cond[, grepl(i, conditions)] <- -1
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

  types <-  .resy_mclapply(1:length(logi2[[1]]), function(x) names(which(sapply(logi2, '[', x))))
  names(types) <- unique(obs$PlotObservationID)


  result.classification <- unlist( .resy_mclapply(types, FUN = function(x) .resy_classify_choice(x, vegtype.priority, vegtype.formula.names.short)))

  list(
    plot.cond = plot.cond,
    logi1 = logi1,
    logi2 = logi2,
    types = types,
    result.classification = result.classification
  )
}
