# Expert systems with a taxonomic backbone: Section 1 names the backbone, and
# plot taxa count for an expert taxon if the backbone places them at or below
# it. A small backbone held in memory stands in for EuroSL.

mini_backbone <- function() {
  data.frame(
    TaxonUsageID   = c("g1", "a1", "s1", "s2", "s3", "x1", "g2", "s4", "s5", "s6"),
    TaxonName      = c("Festuca", "Festuca ovina agg.", "Festuca ovina", "Festuca rupicola",
                       "Festuca sulcata", "Festuca ovina subsp. ovina", "Fagus",
                       "Fagus sylvatica", "Fagus orientalis", "Festuca rubra"),
    status         = c("Accepted", "Accepted", "Accepted", "Accepted", "Synonym",
                       "Accepted", "Accepted", "Accepted", "Accepted", "Accepted"),
    TaxonConceptID = c("g1", "a1", "s1", "s2", "s2", "x1", "g2", "s4", "s5", "s6"),
    TaxonRank      = c("Genus", "Aggregate", "Species", "Species", "Species",
                       "Subspecies", "Genus", "Species", "Species", "Species"),
    parentTaxonID  = c(NA, "g1", "a1", "a1", NA, "s1", NA, "g2", "g2", "g1"),
    stringsAsFactors = FALSE
  )
}

backbone_expert_file <- function(groups, rules) {
  rules$description <- rules$code
  path <- tempfile(fileext = ".json")
  jsonlite::write_json(list(
    metadata = list(scheme = "test", version = "1"),
    backbone = list(name = "EuroSL", url = "https://eurosl.infinitenature.org",
                    version = "test"),
    groups = groups, rules = rules), path, auto_unbox = TRUE)
  path
}

test_that("Section 1 can declare a taxonomic backbone (txt and JSON)", {
  expect_equal(RESY:::.resy_parse_backbone(c("", "EuroSL https://eurosl.infinitenature.org 2026-11-24")),
               list(name = "EuroSL", url = "https://eurosl.infinitenature.org",
                    version = "2026-11-24"))
  expect_null(RESY:::.resy_parse_backbone(c("Abies alba   -  0", "     Abies pectinata  0")))

  txt <- tempfile(fileext = ".txt")
  writeLines(c("SECTION 1: Taxonomic backbone",
               "EuroSL https://eurosl.infinitenature.org 2026-11-24",
               "SECTION 1: End",
               "SECTION 2: Species groups",
               "### Grasses", "     Festuca ovina agg.", "",
               "SECTION 2: End",
               "SECTION 3: Group definitions",
               "1          G    Grassland",
               "<#TC Grasses GR 10>",
               "SECTION 3: End"), txt)
  p <- resy_load_expert(expertfile = txt)
  expect_equal(p$backbone$name, "EuroSL")
  expect_length(p$aggs, 0L)

  j <- backbone_expert_file(list(`### Grasses` = list("Festuca ovina agg.")),
                            data.frame(code = "G", priority = "1",
                                       expression = "<#TC Grasses GR 10>"))
  expect_equal(resy_load_expert(expertfile = j)$backbone$version, "test")
  expect_true(resy_validate_esy(j, verbose = FALSE)$ok)
})

test_that("plot taxa count for the expert taxa above them in the backbone", {
  skip_if_not_installed("vegdata")
  withr::local_options(resy.backbone = mini_backbone())
  path <- backbone_expert_file(
    list(`### Fescues` = list("Festuca ovina agg."), `### Beech` = list("Fagus sylvatica")),
    data.frame(code = c("F", "B", "S"), priority = c("1", "2", "3"),
               expression = c("<#TC Fescues GR 50>", "<#TC Beech GR 50>",
                              "<Festuca ovina agg. GR 50>")))
  obs <- data.frame(
    PlotObservationID = c("p1", "p2", "p3", "p4", "p5", "p6"),
    TaxonName = c("Festuca sulcata",            # synonym of F. rupicola, below the agg.
                  "Festuca ovina subsp. ovina", # two levels below
                  "Fagus sylvatica",
                  "Festuca rubra",              # same genus, not below the agg.
                  "Festuca ovina cf.",          # uncertain: ignored
                  "Fagus orientalis"),          # not used by the expert system
    Cover_Perc = 60)
  header <- data.frame(PlotObservationID = unique(obs$PlotObservationID))
  res <- suppressMessages(resy_classify(obs, header, expertfile = path, mc = 1L))
  cl <- res$result.classification
  expect_equal(unname(cl[c("p1", "p2", "p3")]), c("S", "S", "B"))
  expect_true(all(cl[c("p4", "p5", "p6")] == "?"))

  tr <- res$taxon_resolution
  expect_s3_class(tr, "resy_taxa")
  st <- stats::setNames(tr$status, tr$scientificName)
  expect_equal(unname(st[c("Festuca sulcata", "Festuca rubra", "Festuca ovina cf.",
                           "Fagus orientalis")]),
               c("matched", "not_used", "uncertain_determination", "not_used"))
  expect_equal(tr$TaxonName[tr$scientificName == "Festuca ovina subsp. ovina"],
               "Festuca ovina agg.")
})

test_that("names that cannot be used are split by importance", {
  skip_if_not_installed("vegdata")
  withr::local_options(resy.backbone = mini_backbone())
  path <- backbone_expert_file(
    list(`### Grasses` = list("Festuca ovina", "Festuca valesiaca aggr.")),
    data.frame(code = "G", priority = "1", expression = "<#TC Grasses GR 10>"))
  p <- resy_load_expert(expertfile = path)
  obs <- data.frame(TaxonName = c(
    "Festuca ovina agg.",     # broader than the expert's F. ovina
    "Festuca inventa",        # unknown, genus used by the expert system
    "Planta inventa",         # unknown, genus not used
    "Festuca valesiaca",      # the expert's agg. has no backbone concept
    "Festuca sp.",            # genus only
    "Fagus sylvatica cf."))   # uncertain
  tr <- resy_check_taxonomy(obs, p)
  imp <- stats::setNames(tr$importance, tr$scientificName)
  expect_equal(unname(imp[c("Festuca ovina agg.", "Festuca inventa", "Festuca valesiaca")]),
               rep("important", 3L))
  expect_equal(unname(imp[c("Planta inventa", "Festuca sp.", "Fagus sylvatica cf.")]),
               rep("unimportant", 3L))
  s <- summary(tr)
  expect_setequal(names(s$by_importance), c("important", "unimportant"))
  expect_output(print(s), "Potentially important \\(3\\)")
})

test_that("the synonym layer refuses expert systems with a backbone", {
  local_legacy()
  path <- backbone_expert_file(list(`### G` = list("Fagus sylvatica")),
                               data.frame(code = "G", priority = "1",
                                          expression = "<#TC G GR 10>"))
  expect_error(resy_read_synonyms(expert = resy_load_expert(expertfile = path)),
               "taxonomic backbone")
})

test_that("a diff reports the backbone replacing Section 1", {
  path <- backbone_expert_file(list(`### G` = list("Fagus sylvatica")),
                               data.frame(code = "G", priority = "1",
                                          expression = "<#TC G GR 10>"))
  d <- resy_diff_expert(resy_load_expert(scheme = "Apennine-test", version = "2026-06-27"),
                        resy_load_expert(expertfile = path))
  expect_equal(d$change[d$section == "backbone"], "added")
  expect_false(any(d$section == "aggregate" & d$change != "removed"))
})

test_that("RESY's own matching works without vegdata's", {
  skip_if_not_installed("vegdata")
  withr::local_options(resy.backbone = mini_backbone(), resy.backbone_match = "light")
  bb <- RESY:::.resy_backbone_get("EuroSL")
  bb$memo <- new.env()
  m <- RESY:::.resy_backbone_match(c(
    "Festuca ovina L.",                 # author citation
    "Festuca ovina aggr.",              # aggregate
    "Festuca rubra agg.",               # no aggregate in the backbone
    "Festuca sulcata (Hack.) Nyman",    # synonym with author
    "Fagus sp.",                        # genus
    "Fagus sylvatica auct.",            # misapplied name
    "Fagus sylvatca"), bb)              # no spelling correction
  expect_equal(m$accepted, c("Festuca ovina", "Festuca ovina agg.", NA, "Festuca rupicola",
                             "Fagus", NA, NA))
  expect_equal(m$issue, c(NA, NA, "level_unclear", NA, NA, "misapplied_name", "not_found"))
})

test_that("a prepared backbone restricted to an expert system classifies alike", {
  skip_if_not_installed("vegdata")
  withr::local_options(resy.backbone = mini_backbone(), resy.backbone_match = "light")
  path <- backbone_expert_file(
    list(`### Fescues` = list("Festuca ovina agg.")),
    data.frame(code = "F", priority = "1", expression = "<#TC Fescues GR 50>"))
  p <- resy_load_expert(expertfile = path)
  obs <- data.frame(PlotObservationID = c("p1", "p2", "p3"),
                    TaxonName = c("Festuca sulcata", "Fagus sylvatica", "Festuca rubra"),
                    Cover_Perc = 60)
  header <- data.frame(PlotObservationID = obs$PlotObservationID)
  full <- suppressMessages(resy_classify(obs, header, expert = p, mc = 1L))

  prepared <- RESY:::.resy_backbone_prepare(RESY:::.resy_backbone_get("EuroSL"), list(p))
  expect_true(prepared$subset)
  expect_false("Fagus sylvatica" %in% prepared$list$TaxonName)
  rds <- withr::local_tempfile(fileext = ".rds")
  saveRDS(prepared, rds)
  withr::local_options(resy.backbone = rds)
  sub <- suppressMessages(resy_classify(obs, header, expert = p, mc = 1L))
  expect_identical(sub$result.classification, full$result.classification)
  tr <- sub$taxon_resolution
  # outside the restricted list a name is not a mismatch that matters
  expect_equal(tr$status[tr$scientificName == "Fagus sylvatica"], "outside_expert_taxa")
  expect_equal(tr$importance[tr$scientificName == "Fagus sylvatica"], "unimportant")
})
