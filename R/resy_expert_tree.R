# Build and render the classification hierarchy of an expert system. The tree is
# derived from the type-definition codes (Section 3). Two shapes are available:
# the codes exactly as defined (a definition nests under the longest code that is
# already present as its prefix), or a reconstructed hierarchy in which the
# intermediate group levels implied by the code grammar are synthesised so every
# type sits at its full depth (for EUNIS, "Q11" gains the group levels "Q" and
# "Q1"). Reconstruction never invents a leaf type; synthesised nodes are
# structural groups, flagged so callers can tell them apart.
#
# resy_expert_tree() is dependency-free and is the testable core. The HTML view
# (resy_write_expert_html / resy_view_expert) emits a self-contained page built
# from native <details> elements -- no widget library, no external assets.

#' Build the classification hierarchy of an expert system
#'
#' @description
#' Turns the type definitions of a \code{resy_expert} object (Section 3,
#' the "Group definitions") into a hierarchy.
#'
#' With \code{fill = FALSE} (the default) the tree uses only the codes the
#' expert defines: a definition nests under another when its code has that
#' other code as its longest prefix among all codes present, so an EUNIS file
#' with codes \code{R}, \code{R1} and \code{R12} nests \code{R12} under
#' \code{R1} under \code{R}, while codes with no present prefix stay top-level.
#' No levels are invented, which keeps the hierarchy faithful to files that
#' define only a flat code list.
#'
#' With \code{fill = TRUE} the intermediate group levels implied by the code
#' grammar are reconstructed: each code is split into its ancestor path by
#' \code{code_path}, and any ancestor the expert does not define is added as a
#' structural group node (marked in the \code{synthetic} column). For EUNIS
#' this yields a single tree rooted in the formation groups (\code{M}, \code{N},
#' \code{Q}, \code{R}, ...) with every type at its proper depth.
#'
#' @param expert A \code{resy_expert} object from \code{\link{resy_read_expert}},
#'   read with \code{entries = TRUE} (the default).
#' @param section Integer; the section number holding the type definitions.
#'   Defaults to \code{3}, the EUNIS-ESy convention.
#' @param fill Logical; if \code{TRUE}, reconstruct the intermediate group
#'   levels implied by the codes. Defaults to \code{FALSE}.
#' @param code_path Function mapping one code to the character vector of its
#'   ancestor codes from the root down to and including the code itself. Used
#'   only when \code{fill = TRUE}. The default splits a code into one level per
#'   character (\code{"Q11"} becomes \code{c("Q", "Q1", "Q11")}, \code{"MA1"}
#'   becomes \code{c("M", "MA", "MA1")}), which matches the EUNIS code grammar.
#' @param names Optional code-to-name lookup used to label nodes that the expert
#'   leaves unnamed (typically the synthesised group levels). Either a named
#'   character vector (names are codes) or a data frame whose first two columns
#'   are code and name. \code{\link{resy_eunis_names}} returns the official EUNIS
#'   habitat names in this form. Defaults to \code{NULL} (no external names).
#'
#' @return An object of class \code{resy_expert_tree}: a data frame with one row
#'   per node and columns \code{id}, \code{parent} (\code{NA} for top-level
#'   nodes), \code{code}, \code{description}, \code{priority}, \code{expression},
#'   \code{level} (1 for top-level nodes), \code{leaf}, \code{synthetic}
#'   (\code{TRUE} for a reconstructed group node the expert does not define) and
#'   \code{name_source} (\code{"expert"}, \code{"lookup"} or \code{""}). A
#'   \code{print} method renders it as an indented text tree.
#'
#' @seealso \code{\link{resy_write_expert_html}} and
#'   \code{\link{resy_view_expert}} to render the hierarchy as a self-contained
#'   interactive HTML page.
#' @export
#' @examples
#' f <- system.file("extdata/classifications/Meadow-ESy-2025-01-18-2025.txt",
#'                  package = "RESY")
#' if (nzchar(f)) {
#'   expert <- resy_read_expert(f)
#'   print(resy_expert_tree(expert))            # codes as defined
#'   print(resy_expert_tree(expert, fill = TRUE)) # with group levels filled in
#' }
resy_expert_tree <- function(expert, section = 3L, fill = FALSE,
                             code_path = .resy_code_path, names = NULL) {
  if (!inherits(expert, c("resy_expert", "resy_parsed_expert"))) {
    stop(paste0("`expert` must be a <resy_expert> object from resy_read_expert()",
                " or a <resy_parsed_expert> object from resy_load_expert()."),
         call. = FALSE)
  }
  if (length(section) != 1L || is.na(section)) {
    stop("`section` must be a single section number.", call. = FALSE)
  }

  # resy_parsed_expert path: reconstruct code / description / priority /
  # expression from the solver's internal fields (vegtype.*).
  if (inherits(expert, "resy_parsed_expert")) {
    code        <- expert$vegtype.formula.names.short
    description <- sub("^\\S+\\s*", "", expert$vegtype.formula.names)
    priority    <- as.character(expert$vegtype.priority)
    expression  <- unname(expert$vegtype.formulas)
    sec_name    <- "SECTION 3: Group definitions"
  } else {
    sec <- .resy_section_by_number(expert, section)
    if (is.null(sec)) {
      stop(sprintf("expert has no SECTION %s.", section), call. = FALSE)
    }
    entries <- sec$entries
    if (is.null(entries)) {
      stop(sprintf(paste0("SECTION %s carries no structured entries; read the ",
                          "expert with resy_read_expert(file, entries = TRUE)."),
                   section), call. = FALSE)
    }
    if (length(entries) == 0L) {
      stop(sprintf("SECTION %s defines no types.", section), call. = FALSE)
    }
    if (is.null(entries[[1L]]$code) && is.null(entries[[1L]]$description)) {
      stop(sprintf(paste0("SECTION %s does not hold type definitions (no code/",
                          "description fields); resy_expert_tree() expects a ",
                          "definition section."), section), call. = FALSE)
    }
    code        <- vapply(entries, function(e) .resy_chr1(e$code), character(1))
    description <- vapply(entries, function(e) .resy_chr1(e$description), character(1))
    priority    <- vapply(entries, function(e) .resy_chr1(e$priority), character(1))
    expression  <- vapply(entries, function(e) .resy_chr1(e$expression), character(1))
    sec_name    <- sec$name
  }

  if (isTRUE(fill)) {
    if (!is.function(code_path)) {
      stop("`code_path` must be a function.", call. = FALSE)
    }
    f <- .resy_fill_tree(code, description, priority, expression, code_path)
    code <- f$code; description <- f$description
    priority <- f$priority; expression <- f$expression
    parent <- f$parent; synthetic <- f$synthetic
  } else {
    parent <- .resy_prefix_parent(code)
    synthetic <- rep(FALSE, length(code))
  }

  # Label provenance: descriptions from the expert, optionally filling otherwise
  # unnamed (typically synthesised) nodes from an external code -> name lookup.
  name_source <- ifelse(nzchar(description), "expert", "")
  if (!is.null(names)) {
    lut  <- .resy_as_name_lookup(names)
    need <- !nzchar(description) & code %in% base::names(lut)
    description[need] <- unname(lut[code[need]])
    name_source[need] <- "lookup"
  }

  id    <- seq_along(code)
  level <- .resy_node_levels(parent)
  leaf  <- !(id %in% parent)

  out <- data.frame(
    id = id, parent = parent, code = code, description = description,
    priority = priority, expression = expression, level = level, leaf = leaf,
    synthetic = synthetic, name_source = name_source, stringsAsFactors = FALSE
  )
  attr(out, "section_name") <- sec_name
  class(out) <- c("resy_expert_tree", "data.frame")
  out
}

#' Write an expert-system hierarchy to a self-contained HTML page
#'
#' @description
#' Writes the classification hierarchy built by \code{\link{resy_expert_tree}}
#' to a single, self-contained HTML file: a collapsible tree built from native
#' \code{<details>} elements, with an in-page filter and expand/collapse
#' controls. The page has no external dependencies -- no JavaScript library, no
#' web fonts, no separate asset files -- so it opens identically in any browser
#' and can be shared as one file.
#'
#' @param expert Either a \code{resy_expert} object (from
#'   \code{\link{resy_read_expert}}) or a \code{resy_expert_tree} (from
#'   \code{\link{resy_expert_tree}}).
#' @param file Path to the HTML file to write.
#' @param section Integer; the definition section to use when \code{expert} is a
#'   \code{resy_expert}. Defaults to \code{3}. Ignored for a
#'   \code{resy_expert_tree}.
#' @param fill Logical; reconstruct the intermediate group levels (see
#'   \code{\link{resy_expert_tree}}). Defaults to \code{TRUE} for the view, so
#'   the page shows a single tree rooted in the formation groups. Ignored for a
#'   \code{resy_expert_tree}, which is already built.
#' @param open_level Integer; nodes at this level or shallower start expanded.
#'   Defaults to \code{1} (the top groups are open, their contents collapsed).
#' @param title Page title; defaults to the section name.
#' @param names Optional code-to-name lookup for nodes the expert leaves unnamed
#'   (see \code{\link{resy_expert_tree}}); pass \code{\link{resy_eunis_names}}
#'   for EUNIS. Ignored for a \code{resy_expert_tree}, which is already built.
#' @param name_tag Optional short label shown beside names supplied through
#'   \code{names} (for example \code{"EUNIS"}), to mark them apart from the
#'   expert's own descriptions. Defaults to \code{NULL} (no tag).
#'
#' @return The \code{file} path, invisibly.
#'
#' @seealso \code{\link{resy_view_expert}} to write and open in one call.
#' @export
#' @examples
#' f <- system.file("extdata/classifications/Meadow-ESy-2025-01-18-2025.txt",
#'                  package = "RESY")
#' if (nzchar(f)) {
#'   out <- file.path(tempdir(), "expert-tree.html")
#'   resy_write_expert_html(resy_read_expert(f), out)
#' }
resy_write_expert_html <- function(expert, file, section = 3L, fill = TRUE,
                                   open_level = 1L, title = NULL,
                                   names = NULL, name_tag = NULL) {
  tree <- if (inherits(expert, "resy_expert_tree")) {
    expert
  } else {
    resy_expert_tree(expert, section = section, fill = fill, names = names)
  }
  if (is.null(title) || !nzchar(title)) {
    title <- attr(tree, "section_name")
    if (is.null(title) || !nzchar(title)) title <- "Expert-system hierarchy"
  }
  html <- .resy_tree_html(tree, title = title, open_level = open_level,
                          name_tag = name_tag)
  writeLines(enc2utf8(html), file, useBytes = TRUE)
  invisible(file)
}

#' Render an expert-system hierarchy and open it in a browser
#'
#' @description
#' Builds the self-contained HTML tree (see
#' \code{\link{resy_write_expert_html}}) in a temporary file and opens it in the
#' default browser. Use \code{\link{resy_write_expert_html}} directly to keep
#' the file.
#'
#' @inheritParams resy_write_expert_html
#' @param browse Logical; open the file in a browser. Defaults to
#'   \code{interactive()}.
#'
#' @return The path to the written HTML file, invisibly.
#'
#' @seealso \code{\link{resy_expert_tree}} for the underlying data frame.
#' @export
#' @examples
#' \dontrun{
#' f <- system.file("extdata/classifications/Meadow-ESy-2025-01-18-2025.txt",
#'                  package = "RESY")
#' resy_view_expert(resy_read_expert(f))
#' }
resy_view_expert <- function(expert, section = 3L, fill = TRUE,
                             open_level = 1L, title = NULL,
                             names = NULL, name_tag = NULL,
                             browse = interactive()) {
  out <- tempfile(fileext = ".html")
  resy_write_expert_html(expert, out, section = section, fill = fill,
                         open_level = open_level, title = title,
                         names = names, name_tag = name_tag)
  if (isTRUE(browse)) utils::browseURL(out)
  invisible(out)
}

#' Official EUNIS habitat names
#'
#' @description
#' Returns the EUNIS habitat code-to-name lookup bundled with the package, for
#' use as the \code{names} argument of \code{\link{resy_expert_tree}},
#' \code{\link{resy_write_expert_html}} and \code{\link{resy_view_expert}}. It
#' lets the synthesised group levels of a reconstructed EUNIS-ESy tree (which the
#' expert system itself does not define) carry their official habitat names.
#'
#' The names are the official EUNIS 2021 habitat names (European Environment
#' Agency, EUNIS habitat classification), distributed here for reference; they
#' are not part of the expert system and are marked separately when rendered.
#'
#' @return A data frame with columns \code{code} and \code{name}.
#' @export
#' @examples
#' head(resy_eunis_names())
resy_eunis_names <- function() {
  f <- system.file("extdata/eunis_2021_names.csv", package = "RESY")
  if (!nzchar(f)) {
    stop("EUNIS names table not found in the installed package.", call. = FALSE)
  }
  utils::read.csv(f, stringsAsFactors = FALSE, encoding = "UTF-8")
}

#' @export
print.resy_expert_tree <- function(x, max = 200L, ...) {
  n_root <- sum(is.na(x$parent))
  n_syn  <- sum(x$synthetic)
  cat(sprintf("<resy_expert_tree> %d node(s), %d top-level%s\n",
              nrow(x), n_root,
              if (n_syn) sprintf(", %d synthesised group(s)", n_syn) else ""))

  kids <- split(x$id, x$parent)        # names are parent ids; NA parents dropped
  label <- .resy_node_labels(x)
  roots <- x$id[is.na(x$parent)]
  shown <- 0L
  truncated <- FALSE

  emit <- function(id, indent) {
    if (shown >= max) {
      truncated <<- TRUE
      return(invisible(NULL))
    }
    shown <<- shown + 1L
    cat(sprintf("%s%s\n", strrep("  ", indent), label[id]))
    ch <- kids[[as.character(id)]]
    for (k in ch) emit(k, indent + 1L)
  }
  for (r in roots) emit(r, 0L)

  if (truncated) {
    cat(sprintf("... (%d more node(s) not shown; increase `max`)\n",
                nrow(x) - shown))
  }
  invisible(x)
}

# --- internals --------------------------------------------------------------

# First non-empty scalar of a field, or "" -- entries store every field as a
# length-1 character, but missing fields are NULL.
.resy_chr1 <- function(x) {
  if (is.null(x) || length(x) == 0L) return("")
  x <- as.character(x[[1L]])
  if (is.na(x)) "" else x
}

# Section object with the given number, or NULL.
.resy_section_by_number <- function(expert, number) {
  for (sec in expert$sections) {
    if (isTRUE(sec$number == number)) return(sec)
  }
  NULL
}

# Ancestor path of a code: one level per character, so each character deepens
# the hierarchy. "Q11" -> c("Q", "Q1", "Q11"); "MA1" -> c("M", "MA", "MA1").
.resy_code_path <- function(code) {
  if (!nzchar(code)) return(code)
  substring(code, 1L, seq_len(nchar(code)))
}

# Reconstruct the full node set from the defined codes and a code-path function.
# Returns codes (defined plus synthesised ancestors) with their parent ids and
# a synthetic flag; defined codes keep their description/priority/expression,
# synthesised group nodes get empty strings.
.resy_fill_tree <- function(code, description, priority, expression, code_path) {
  keep <- nzchar(code)
  paths <- lapply(code[keep], code_path)
  all_codes <- sort(unique(unlist(paths, use.names = FALSE)))

  parent_code <- stats::setNames(rep(NA_character_, length(all_codes)), all_codes)
  for (p in paths) {
    if (length(p) > 1L) {
      for (k in 2:length(p)) parent_code[p[k]] <- p[k - 1L]
    }
  }
  defined <- stats::setNames(all_codes %in% code, all_codes)

  # Collapse synthesised group nodes that wrap a single child. The expert is the
  # authority: a structural level it does not define and that does not branch
  # (a lone "M" above "MA") carries no information, so it is spliced out, while a
  # synthesised node grouping several codes (such as "Q" above Q1..Q6, Qa, Qb) is
  # kept. One node per pass keeps chains (M -> MA) unambiguous.
  repeat {
    counts   <- table(parent_code[!is.na(parent_code)])
    onechild <- names(counts)[counts == 1L]
    victims  <- onechild[onechild %in% all_codes & !defined[onechild]]
    if (!length(victims)) break
    v     <- victims[1L]
    child <- names(parent_code)[which(parent_code == v)]
    parent_code[child] <- parent_code[[v]]
    all_codes   <- all_codes[all_codes != v]
    parent_code <- parent_code[all_codes]
    defined     <- defined[all_codes]
  }

  midx      <- match(all_codes, code)
  synthetic <- is.na(midx)
  pick      <- function(v) ifelse(synthetic, "", v[midx])

  list(
    code        = all_codes,
    description = pick(description),
    priority    = pick(priority),
    expression  = pick(expression),
    parent      = match(parent_code[all_codes], all_codes),
    synthetic   = synthetic
  )
}

# Parent id of each node: the row whose code is the longest proper prefix of
# this node's code among all present codes. NA when no present code is a prefix
# (a top-level node) or when the code itself is empty. Ties cannot occur -- a
# proper prefix of a given length is unique.
.resy_prefix_parent <- function(code) {
  n <- length(code)
  parent <- rep(NA_integer_, n)
  present <- code[nzchar(code)]
  if (length(present) == 0L) return(parent)
  for (i in seq_len(n)) {
    ci <- code[i]
    if (!nzchar(ci)) next
    cand <- present[present != ci & startsWith(ci, present)]
    if (length(cand) == 0L) next
    best <- cand[which.max(nchar(cand))]
    parent[i] <- match(best, code)
  }
  parent
}

# Depth of each node (top-level = 1). The prefix relation is acyclic by
# construction (a proper prefix is strictly shorter), so the walk terminates.
.resy_node_levels <- function(parent) {
  vapply(seq_along(parent), function(i) {
    d <- 1L
    p <- parent[i]
    while (!is.na(p)) {
      d <- d + 1L
      p <- parent[p]
    }
    d
  }, integer(1))
}

# Display label for each node: "code description", or whichever is present.
.resy_node_labels <- function(x) {
  has_code <- nzchar(x$code)
  has_desc <- nzchar(x$description)
  ifelse(has_code & has_desc, paste(x$code, x$description),
         ifelse(has_code, x$code,
                ifelse(has_desc, x$description, "(unnamed)")))
}

# Coerce a names argument (named character vector or two-column data frame) to a
# named character lookup, code -> name.
.resy_as_name_lookup <- function(names) {
  if (is.data.frame(names)) {
    if (ncol(names) < 2L) {
      stop("`names` data frame needs a code column and a name column.",
           call. = FALSE)
    }
    stats::setNames(as.character(names[[2L]]), as.character(names[[1L]]))
  } else {
    v <- unlist(names, use.names = TRUE)
    if (is.null(base::names(v))) {
      stop("`names` must be a named vector or a two-column data frame.",
           call. = FALSE)
    }
    stats::setNames(as.character(v), base::names(v))
  }
}

# HTML-escape the three characters that matter inside element content.
.resy_html_escape <- function(s) {
  s <- gsub("&", "&amp;", s, fixed = TRUE)
  s <- gsub("<", "&lt;",  s, fixed = TRUE)
  gsub(">", "&gt;", s, fixed = TRUE)
}

# Build the self-contained HTML page for a resy_expert_tree. Each branch is a
# native <details>; synthesised group nodes are marked. The only script is a
# vanilla-JS filter and expand/collapse, and the tree is fully usable without
# it.
.resy_tree_html <- function(tree, title, open_level = 1L, name_tag = NULL) {
  esc  <- .resy_html_escape
  kids <- split(tree$id, tree$parent)
  src  <- if (is.null(tree$name_source)) rep("", nrow(tree)) else tree$name_source
  tag_html <- if (!is.null(name_tag) && nzchar(name_tag)) {
    sprintf(' <span class="src">%s</span>', esc(name_tag))
  } else ""
  n_desc <- function(id) {
    ch <- kids[[as.character(id)]]
    if (is.null(ch)) 0L else length(ch) + sum(vapply(ch, n_desc, integer(1)))
  }

  node_html <- function(id, indent) {
    code <- esc(tree$code[id]); desc <- esc(tree$description[id])
    syn  <- isTRUE(tree$synthetic[id])
    cls  <- if (syn) "code syn" else "code"
    label <- if (nzchar(code) && nzchar(desc)) {
      # names supplied from a lookup are styled apart and optionally tagged
      dcls <- if (identical(src[id], "lookup")) "desc ref" else "desc"
      dtag <- if (identical(src[id], "lookup")) tag_html else ""
      sprintf('<span class="%s">%s</span> <span class="%s">%s</span>%s',
              cls, code, dcls, desc, dtag)
    } else if (nzchar(code)) {
      sprintf('<span class="%s">%s</span>%s', cls, code,
              if (syn) ' <span class="grp">group</span>' else "")
    } else {
      sprintf('<span class="desc">%s</span>', desc)
    }
    ch  <- kids[[as.character(id)]]
    pad <- strrep("  ", indent)
    if (is.null(ch)) {
      sprintf('%s<li class="leaf">%s</li>', pad, label)
    } else {
      open  <- if (tree$level[id] <= open_level) " open" else ""
      inner <- paste(vapply(ch, node_html, character(1), indent = indent + 2L),
                     collapse = "\n")
      sprintf(paste0('%s<li><details%s><summary>%s <span class="n">%d</span>',
                     '</summary>\n%s<ul>\n%s\n%s</ul>\n%s</details></li>'),
              pad, open, label, n_desc(id), pad, inner, pad, pad)
    }
  }

  roots <- tree$id[is.na(tree$parent)]
  body  <- paste(vapply(roots, node_html, character(1), indent = 2L),
                 collapse = "\n")
  n_syn <- sum(tree$synthetic)
  meta  <- sprintf("%d node(s), %d top-level%s.", nrow(tree), length(roots),
                   if (n_syn) sprintf(", %d synthesised group level(s)", n_syn) else "")

  paste0(
    '<!DOCTYPE html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n',
    '<meta name="viewport" content="width=device-width, initial-scale=1">\n',
    '<title>', esc(title), '</title>\n<style>\n', .resy_tree_css, '\n</style>\n',
    '</head>\n<body>\n<h1>', esc(title), '</h1>\n',
    '<p class="meta">', meta,
    ' Click a row to expand or collapse; use the filter to find a code or name.</p>\n',
    '<div class="bar">\n',
    '<button id="expand">Expand all</button>\n',
    '<button id="collapse">Collapse all</button>\n',
    '<input id="q" type="search" placeholder="filter by code or name" autocomplete="off">\n',
    '</div>\n<ul class="tree">\n', body, '\n</ul>\n',
    '<script>\n', .resy_tree_js, '\n</script>\n</body>\n</html>\n'
  )
}

# Inline stylesheet for the tree page (no external fonts or assets).
.resy_tree_css <- '
:root { color-scheme: light dark; }
body { font: 15px/1.45 system-ui, "Segoe UI", Arial, sans-serif; margin: 1.5rem 2rem; max-width: 70rem; }
h1 { font-size: 1.2rem; margin: 0 0 .25rem; }
.meta { color: #777; margin: 0 0 1rem; font-size: .9rem; }
.bar { margin: 0 0 1rem; }
.bar button { font: inherit; padding: .25rem .6rem; margin-right: .4rem; cursor: pointer; }
#q { font: inherit; padding: .25rem .5rem; width: 16rem; }
ul.tree, ul.tree ul { list-style: none; margin: 0; padding-left: 1.15rem; border-left: 1px solid #ddd; }
ul.tree { padding-left: 0; border-left: 0; }
li { margin: .12rem 0; }
li.leaf { padding-left: 1.05rem; }
summary { cursor: pointer; }
summary::-webkit-details-marker { color: #999; }
.code { font-family: ui-monospace, Consolas, monospace; font-weight: 600; color: #176; }
.code.syn { color: #b07; font-weight: 700; }
.grp { font-size: .72em; color: #b07; border: 1px solid #b07; border-radius: 3px; padding: 0 .25em; opacity: .7; }
.desc { color: #333; }
.desc.ref { font-style: italic; color: #555; }
.src { font-size: .72em; color: #888; border: 1px solid #bbb; border-radius: 3px; padding: 0 .25em; }
.n { color: #aaa; font-size: .8em; }
.hidden { display: none; }
@media (prefers-color-scheme: dark) {
  body { background: #16181c; color: #ddd; }
  .desc { color: #cfd3da; } .code { color: #6fd3b8; } .meta, .n { color: #889; }
  .code.syn { color: #e58bd0; } .grp { color: #e58bd0; border-color: #e58bd0; }
  .desc.ref { color: #9aa3ad; } .src { color: #889; border-color: #556; }
  ul.tree, ul.tree ul { border-color: #333; }
}'

# Inline behaviour: expand/collapse all and a substring filter that reveals
# matching nodes and their ancestors. The tree works without this script.
.resy_tree_js <- '
var tree = document.querySelector("ul.tree");
function setAll(open) { tree.querySelectorAll("details").forEach(function (d) { d.open = open; }); }
document.getElementById("expand").onclick   = function () { setAll(true); };
document.getElementById("collapse").onclick = function () { setAll(false); };
document.getElementById("q").oninput = function () {
  var term = this.value.trim().toLowerCase();
  var lis = tree.querySelectorAll("li");
  if (!term) { lis.forEach(function (li) { li.classList.remove("hidden"); }); setAll(false); return; }
  lis.forEach(function (li) { li.classList.add("hidden"); });
  lis.forEach(function (li) {
    var sum = li.querySelector(":scope > details > summary");
    var text = (sum ? sum.textContent : li.textContent).toLowerCase();
    if (text.indexOf(term) !== -1) {
      li.classList.remove("hidden");
      var p = li.parentElement;
      while (p && p !== tree) {
        if (p.tagName === "LI") p.classList.remove("hidden");
        if (p.tagName === "DETAILS") p.open = true;
        p = p.parentElement;
      }
    }
  });
};'
