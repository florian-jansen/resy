# A parsed expert system without its provenance record. Two parses of the same
# system from different files or store entries differ only in `source`.
without_source <- function(x) {
  x$source <- NULL
  x
}
