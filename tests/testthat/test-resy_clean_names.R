# resy_clean_names() strips author citations while preserving the taxonomic
# structure expert-system names depend on: infraspecific ranks, aggregate and
# collective markers, and the hybrid sign. Recovery-style -- a name that is
# already a canonical form must round-trip unchanged.

test_that("clean_names strips authors but keeps ranks and aggregate markers", {
  # Author citations removed, genus + epithet kept.
  expect_equal(resy_clean_names("Fagus sylvatica L."), "Fagus sylvatica")
  expect_equal(
    resy_clean_names("Senecio ovatus (G.Gaertn., B.Mey. & Scherb.) Willd."),
    "Senecio ovatus"
  )

  # Infraspecific rank markers stay attached to their epithet.
  expect_equal(
    resy_clean_names("Epipactis helleborine (L.) Crantz subsp. helleborine"),
    "Epipactis helleborine subsp. helleborine"
  )

  # Aggregate and collective markers are terminal and must be kept -- this is
  # the case reported as lost when parsing EIVE OriginalNames.
  expect_equal(resy_clean_names("Taraxacum officinale agg."),
               "Taraxacum officinale agg.")
  expect_equal(resy_clean_names("Achillea millefolium aggr."),
               "Achillea millefolium aggr.")
  expect_equal(resy_clean_names("Thuidium abietinum s.l."),
               "Thuidium abietinum s.l.")
  expect_equal(resy_clean_names("Aira caryophyllea s.str."),
               "Aira caryophyllea s.str.")
  expect_equal(resy_clean_names("Actaea europaea s.lat."),
               "Actaea europaea s.lat.")
  expect_equal(resy_clean_names("Rubus fruticosus coll."),
               "Rubus fruticosus coll.")

  # Spaced sensu-lato abbreviation collapses to the compact marker.
  expect_equal(resy_clean_names("Festuca ovina s. l."),
               "Festuca ovina s.l.")

  # Aggregate marker can follow an infraspecific epithet.
  expect_equal(resy_clean_names("Aconitum napellus subsp. firmum s.l."),
               "Aconitum napellus subsp. firmum s.l.")

  # A sensu-concept qualifier is dropped, the aggregate form is kept -- matches
  # the bare canonical the expert system uses.
  expect_equal(resy_clean_names("Alchemilla vulgaris aggr. sensu Buser"),
               "Alchemilla vulgaris aggr.")

  # Hybrid sign between genus and epithet: the epithet must survive, not be
  # dropped as an author (matches canonical "Mentha x verticillata aggr.").
  expect_equal(resy_clean_names("Mentha x verticillata aggr."),
               "Mentha x verticillata aggr.")
  expect_equal(resy_clean_names("Salix x rubens Schrank"),
               "Salix x rubens")
  expect_equal(resy_clean_names(paste0("Mentha ", intToUtf8(215L),
                                       " piperita L.")),
               paste0("Mentha ", intToUtf8(215L), " piperita"))

  # Hybrid formula joining two taxa must never collapse onto one parent.
  expect_equal(resy_clean_names("Betula pendula x pubescens"),
               "Betula pendula x pubescens")
  expect_equal(resy_clean_names("Betula pendula Roth x pubescens Ehrh."),
               "Betula pendula x pubescens")
  expect_equal(resy_clean_names("Elytrigia repens x Leymus arenarius"),
               "Elytrigia repens x Leymus arenarius")

  # NA and single-token inputs are preserved.
  expect_true(is.na(resy_clean_names(NA_character_)))
  expect_equal(resy_clean_names("Quercus"), "Quercus")

  # Vectorised, length-preserving.
  expect_equal(
    resy_clean_names(c("Fagus sylvatica L.", NA, "Taraxacum officinale agg.")),
    c("Fagus sylvatica", NA, "Taraxacum officinale agg.")
  )
})
