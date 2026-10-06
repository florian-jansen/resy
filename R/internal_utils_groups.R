
# Prefixes that open a Section 2 group: species groups (###), differential
# groups (##D, ##Q, ##C) and header variables (categorical $$C, numeric $$N).
.resy_group_prefixes <- c("###", "##D", "##Q", "##C", "$$C", "$$N")

# Group name of a Section 2 group key: the text after the prefix and its space.
.resy_group_name <- function(key) substr(key, 5, nchar(key))

# Line numbers of the "SECTION <n>" markers (opener and "SECTION <n>: End").
.resy_section_rows <- function(lines, n) {
  which(grepl(paste0("^\\s*SECTION\\s+", n, "\\b"), lines, ignore.case = TRUE, perl = TRUE))
}
