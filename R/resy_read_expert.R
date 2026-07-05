# Lossless reader for the expert-system `.txt` format (EUNIS-ESy and compatible
# expert systems). Parses into a structured tree that preserves every byte of
# the source. A structured "entries" view of each known section is layered
# alongside the raw lines for inspection; it does not affect the lossless
# representation, and can be skipped with `entries = FALSE`.
#
# This is the lossless counterpart to resy_parse_expert(): that parser rewrites
# the formulas into the solver's internal form (inserting GR NON, EXCEPT, #T$
# group names, expanding OR-prefixes) and is therefore one-way. The reader here
# retains the file verbatim for inspection or conversion.

#' Read an expert-system file losslessly
#'
#' @description
#' Parses an expert-system definition file (the EUNIS-ESy \code{.txt} format and
#' compatible expert systems) into a structured tree that preserves the source
#' byte-for-byte.
#'
#' This is the lossless counterpart to \code{\link{resy_parse_expert}}. Where
#' \code{resy_parse_expert} rewrites the formulas into the solver's internal
#' form (and is therefore one-way), \code{resy_read_expert} retains the file's
#' structure verbatim for inspection or conversion to other formats.
#'
#' @param file Path to an expert-system \code{.txt} file (for example an
#'   official release such as \code{EUNIS-ESy-2025-10-03.txt}).
#' @param entries Logical, default \code{TRUE}. If \code{TRUE}, each known
#'   section also carries a structured \code{entries} view of its content
#'   (aggregations, groups, definitions). If \code{FALSE} only the raw lines are
#'   kept, which is faster when the goal is a pure round-trip and the semantic
#'   view is not needed.
#'
#' @return An object of class \code{resy_expert}: a list with components
#'   \describe{
#'     \item{\code{meta}}{File-level metadata: \code{line_terminator} (CRLF or
#'       LF) and \code{trailing_newline} (whether the file ends with a
#'       terminator).}
#'     \item{\code{preamble}}{Character vector of any lines before the first
#'       \code{SECTION} header.}
#'     \item{\code{sections}}{A list, in source order, of section objects. Each
#'       has \code{number}, \code{name}, \code{header_line}, \code{body_lines},
#'       \code{end_line} (\code{NA} when the section has no matching
#'       \code{SECTION N: End}), \code{trailing} (lines between this section's
#'       end and the next section or end of file), and, when
#'       \code{entries = TRUE} and the section type is known, \code{entries}: a
#'       structured view of the section content.}
#'   }
#'
#' @seealso \code{\link{resy_parse_expert}} for the solver-form parser.
#' @export
#' @examples
#' \dontrun{
#' f <- "/path/to/EUNIS-ESy-2025-10-03.txt"
#' x <- resy_read_expert(f)
#' length(x$sections)
#' }
resy_read_expert <- function(file, entries = TRUE) {
  if (!is.character(file) || length(file) != 1L || is.na(file)) {
    stop(sprintf(
      "`file` must be a single file path, got %s of length %d.",
      class(file)[1], length(file)
    ), call. = FALSE)
  }
  if (!file.exists(file)) {
    stop(sprintf("file does not exist: %s", file), call. = FALSE)
  }
  if (!is.logical(entries) || length(entries) != 1L || is.na(entries)) {
    stop(sprintf("`entries` must be TRUE or FALSE, got %s.", deparse(entries)),
         call. = FALSE)
  }

  size <- file.info(file)$size
  bytes <- readBin(file, what = "raw", n = size)
  text <- rawToChar(bytes)
  Encoding(text) <- "UTF-8"

  line_term <- .resy_detect_line_terminator(text)
  trailing_newline <- endsWith(text, line_term)

  # strsplit() already drops the single empty field produced by the file's
  # final terminator, but keeps a genuine trailing blank line (`...\r\n\r\n`).
  # The trailing_newline flag records that final terminator so the writer
  # re-adds exactly one -- do NOT drop any line here, or trailing blank lines
  # are lost.
  lines <- strsplit(text, line_term, fixed = TRUE)[[1]]

  split <- .resy_split_sections(lines)
  sections <- if (entries) {
    lapply(split$sections, .resy_parse_section)
  } else {
    split$sections
  }

  structure(
    list(
      meta = list(
        line_terminator = line_term,
        trailing_newline = trailing_newline
      ),
      preamble = split$preamble,
      sections = sections
    ),
    class = c("resy_expert", "list")
  )
}

# Detect the line terminator from the head of the file (cheap on multi-MB
# files). Mixed terminators are not normalised: whichever appears first wins,
# and any stray terminators travel inside the retained line text, so the
# round-trip stays byte-identical.
.resy_detect_line_terminator <- function(text) {
  head <- substr(text, 1L, 4096L)
  if (grepl("\r\n", head, fixed = TRUE)) "\r\n" else "\n"
}

# Partition the lines into a preamble plus a source-ordered list of sections.
# Every line lands in exactly one bucket and order is preserved, so
# concatenating the buckets reproduces the input byte-for-byte. A section spans
# from its `SECTION N: <name>` opener to the first matching `SECTION N: End`;
# the next section is the first opener after that end (so openers nested inside
# an unmatched span stay in the body and are never double-counted). A section
# with no matching end is unterminated: it takes the rest of the file as its
# body and the writer omits the end line. Returns:
#   preamble - lines before the first opener (the whole file if there is none)
#   sections - list of: number, name, header_line, body_lines,
#              end_line (NA if unterminated), trailing
.resy_split_sections <- function(lines) {
  n <- length(lines)
  open_re <- "^SECTION ([0-9]+): (.+)$"
  end_re  <- "^SECTION ([0-9]+): End$"

  is_end  <- grepl(end_re, lines, perl = TRUE)
  is_open <- grepl(open_re, lines, perl = TRUE) & !is_end
  open_pos <- which(is_open)

  # Section number on each end line, pre-extracted so matching is a vectorised
  # lookup rather than a per-line regex inside the scan.
  end_num <- rep(NA_integer_, n)
  end_num[is_end] <- as.integer(sub(end_re, "\\1", lines[is_end], perl = TRUE))

  first_open <- if (length(open_pos) > 0L) open_pos[1L] else NA_integer_
  preamble <- if (is.na(first_open)) {
    lines                                  # no sections: whole file is preamble
  } else if (first_open > 1L) {
    lines[seq_len(first_open - 1L)]
  } else {
    character(0)
  }

  sections <- list()
  i <- first_open
  while (!is.na(i) && i <= n) {
    num  <- as.integer(sub(open_re, "\\1", lines[i], perl = TRUE))
    name <- sub(open_re, "\\2", lines[i], perl = TRUE)

    # Matching close: first `SECTION num: End` strictly after the opener.
    end_hits <- which(is_end & end_num == num)
    end_at <- end_hits[end_hits > i][1L]

    if (is.na(end_at)) {
      sections[[length(sections) + 1L]] <- list(
        number = num, name = name, header_line = lines[i],
        body_lines = if (i < n) lines[(i + 1L):n] else character(0),
        end_line = NA_character_, trailing = character(0)
      )
      break
    }

    # Trailing content runs from after the end line to the next opener (or EOF).
    nxt <- open_pos[open_pos > end_at][1L]
    stop_at <- if (is.na(nxt)) n else nxt - 1L
    sections[[length(sections) + 1L]] <- list(
      number = num, name = name, header_line = lines[i],
      body_lines = if (end_at > i + 1L) {
        lines[(i + 1L):(end_at - 1L)]
      } else {
        character(0)
      },
      end_line = lines[end_at],
      trailing = if (stop_at > end_at) {
        lines[(end_at + 1L):stop_at]
      } else {
        character(0)
      }
    )
    i <- nxt
  }

  list(preamble = preamble, sections = sections)
}

# Attach a structured `entries` view for known section types. Unknown sections
# keep their raw lines only. The entries view is for inspection; the round-trip
# never depends on it.
.resy_parse_section <- function(sec) {
  parsed <- switch(
    as.character(sec$number),
    "1" = .resy_parse_aggregation(sec$body_lines),
    "2" = .resy_parse_groups(sec$body_lines),
    "3" = .resy_parse_definitions(sec$body_lines),
    "4" = .resy_parse_similarity(sec$body_lines),
    NULL
  )
  if (!is.null(parsed)) sec$entries <- parsed
  sec
}

# --- Section 1: Species aggregation -----------------------------------------

# Block = one canonical line (carries a `-` flag) followed by zero or more
# synonym lines; blocks are separated by blank lines. Section 1 is the largest
# section (>100k lines in EUNIS), so the name/code split is vectorised over the
# whole body at once rather than parsed line by line.
.resy_parse_aggregation <- function(lines) {
  bi <- .resy_block_index(lines)
  if (length(bi$keep) == 0L) return(list())
  body <- lines[bi$keep]
  nc <- .resy_split_name_code(body)
  unname(lapply(split(seq_along(body), bi$grp), function(ii) {
    list(
      canonical      = nc$name[ii[1L]],
      canonical_code = nc$code[ii[1L]],
      synonyms       = nc$name[ii[-1L]],
      synonym_codes  = nc$code[ii[-1L]]
    )
  }))
}

# Vectorised split of aggregation lines into a name and a trailing code field.
# The code is a bare integer (synonyms: "0") or a `-` flag plus an integer
# (canonical lines: "-  0"); lines with neither keep the whole text as the name.
.resy_split_name_code <- function(lines) {
  re <- "^(.*?)\\s+(-\\s+\\d+|\\d+)\\s*$"
  has <- grepl(re, lines, perl = TRUE)
  name <- ifelse(has, sub(re, "\\1", lines, perl = TRUE), lines)
  code <- ifelse(has, sub(re, "\\2", lines, perl = TRUE), "")
  list(name = trimws(name), code = code)
}

# --- Section 2: Species groups ----------------------------------------------

# Block = one header line declaring a group, followed by indented member lines.
# Known header prefixes: `###` (sociological/functional group), `##D`
# (discriminating group), `$$C` (categorical site variable), `$$N` (numeric
# site variable). Unknown prefixes are tolerated and recorded with NA fields.
.resy_parse_groups <- function(lines) {
  prefix_re <- "^(###|##D|\\$\\$C|\\$\\$N)\\s*"
  lapply(.resy_split_blocks(lines), function(block) {
    header <- block[1L]
    m <- regmatches(header, regexec(prefix_re, header, perl = TRUE))[[1]]
    members <- if (length(block) > 1L) trimws(block[-1L]) else character(0)
    if (length(m) < 2L) {
      list(prefix = NA_character_, name = NA_character_, members = members)
    } else {
      list(prefix = m[2L],
           name = trimws(sub(prefix_re, "", header, perl = TRUE)),
           members = members)
    }
  })
}

# --- Section 3: Group (vegetation-type) definitions -------------------------

# Block = one header line followed by (typically) one expression line. The
# expression is kept as a raw string; AST parsing is a separate milestone.
.resy_parse_definitions <- function(lines) {
  lapply(.resy_split_blocks(lines), function(block) {
    fields <- .resy_parse_definition_header(block[1L])
    expression <- if (length(block) > 1L) {
      paste(block[-1L], collapse = "\n")
    } else {
      ""
    }
    c(fields, list(expression = expression))
  })
}

# Pull priority / code / description out of a Section 3 header line.
#
# The official format (Tichý et al., Appendix S1) is:
#   char 1     : priority digit/letter
#   chars 2-11 : 10 spaces (distance E)
#   chars 12-16: vegetation-type code (5 characters, space-padded if shorter)
#   chars 17+  : full name / description (preceded by a space)
#
# In practice the code field may be shorter than 5 characters (e.g. "BF" for a
# 2-character code) and may or may not be space-padded.  To handle both cases
# robustly, when the standard priority+spaces prefix is present we extract the
# code as the first whitespace-delimited token starting at column 12 rather
# than reading a fixed 5-character window.  The regex fallback covers lines
# that lack the standard prefix.
.resy_parse_definition_header <- function(header) {
  if (grepl("^[0-9A-Za-z] {10}\\S", header, perl = TRUE)) {
    rest <- substr(header, 12L, nchar(header))
    code <- sub("^(\\S+).*$", "\\1", rest)
    description <- trimws(sub("^\\S+\\s*", "", rest))
    return(list(
      priority    = substr(header, 1L, 1L),
      code        = code,
      description = description
    ))
  }
  m <- regmatches(header,
                  regexec("^([0-9A-Za-z])\\s{2,}(\\S+)\\s+(.+?)\\s*$",
                          header, perl = TRUE))[[1]]
  if (length(m) >= 4L) {
    list(priority = m[2L], code = m[3L], description = m[4L])
  } else {
    list(priority = NA_character_, code = NA_character_,
         description = trimws(header))
  }
}

# --- Section 4: Similarity --------------------------------------------------

# Reserved by the schema; empty in current releases. Raw lines are still
# preserved for the round-trip.
.resy_parse_similarity <- function(lines) {
  list()
}

# --- Helpers ----------------------------------------------------------------

# Indices of the non-blank lines and the block id of each (consecutive non-blank
# runs share an id). Single source of grouping for both .resy_split_blocks() and
# the vectorised Section 1 parser. A blank line is empty or whitespace-only.
.resy_block_index <- function(lines) {
  is_blank <- !nzchar(trimws(lines))
  keep <- which(!is_blank)
  list(keep = keep, grp = cumsum(is_blank)[keep])
}

# Split a section body into blocks of consecutive non-blank lines, in source
# order. Used only to build the inspection `entries`; the raw `body_lines` keep
# the blanks for the round-trip.
.resy_split_blocks <- function(lines) {
  if (length(lines) == 0L) return(list())
  bi <- .resy_block_index(lines)
  if (length(bi$keep) == 0L) return(list())
  unname(split(lines[bi$keep], bi$grp))
}

#' @export
print.resy_expert <- function(x, ...) {
  term <- if (identical(x$meta$line_terminator, "\r\n")) "CRLF" else "LF"
  trailer <- if (isTRUE(x$meta$trailing_newline)) ", trailing newline" else ""
  cat(sprintf("<resy_expert> %d section(s), %s line endings%s\n",
              length(x$sections), term, trailer))
  if (length(x$preamble) > 0L) {
    cat(sprintf("  preamble: %d line(s)\n", length(x$preamble)))
  }
  for (sec in x$sections) {
    n_entries <- if (is.null(sec$entries)) NA_integer_ else length(sec$entries)
    entry_note <- if (is.na(n_entries)) {
      ""
    } else {
      sprintf(", %d entries", n_entries)
    }
    end_note <- if (is.na(sec$end_line)) " [unterminated]" else ""
    cat(sprintf("  SECTION %s: %s -- %d body line(s)%s%s\n",
                sec$number, sec$name, length(sec$body_lines),
                entry_note, end_note))
  }
  invisible(x)
}
