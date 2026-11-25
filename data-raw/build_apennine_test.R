# Build the Apennine-test example expert system, version 2026-11-25: the
# five types of 2026-06-27 with wider broad types (forest, non-forest and the
# new wetland type) and further forest, grassland and wetland types that fit the
# bundled example plots from Tuscany. Species are matched along EuroSL; a
# genus in a group stands for all its species. Where two types can hold for the
# same plot, the more specific one has the higher priority (chestnut over
# deciduous oak or holm oak forest, Ampelodesmos grassland over maquis, other
# grassland, maquis and wetland over annual grassland).
#
# Run from the package root: Rscript --no-init-file data-raw/build_apennine_test.R

version <- "2026-11-25"
out <- file.path("inst/extdata/classifications/Apennine-test", version, "expert.json")

groups <- list(
  # broad types
  "### Trees" = c("Fagus sylvatica", "Abies alba", "Castanea sativa", "Quercus", "Acer",
                  "Fraxinus", "Ostrya carpinifolia", "Carpinus betulus", "Alnus glutinosa",
                  "Populus", "Salix alba", "Ulmus minor", "Tilia", "Pinus"),
  "### Wetland" = c("Lemna", "Potamogeton", "Callitriche", "Myriophyllum", "Ceratophyllum",
                    "Phragmites australis", "Eleocharis", "Mentha requienii", "Mentha aquatica",
                    "Typha", "Schoenoplectus", "Bolboschoenus maritimus", "Lythrum salicaria",
                    "Petasites hybridus", "Limonium narbonense", "Salicornia", "Sarcocornia",
                    "Arthrocnemum", "Halimione portulacoides", "Juncus maritimus"),
  # forest
  "### Beech-forest-trees" = c("Fagus sylvatica", "Abies alba"),
  "### Beech-forest-herbs" = c("Prenanthes purpurea", "Oxalis acetosella", "Dryopteris filix-mas",
                               "Cephalanthera longifolia", "Anemone nemorosa"),
  "### Thermophilous-trees" = c("Quercus cerris", "Quercus pubescens", "Quercus frainetto",
                                "Acer obtusatum", "Acer campestre", "Acer monspessulanum",
                                "Ostrya carpinifolia", "Fraxinus ornus", "Carpinus orientalis"),
  "### Riparian-trees" = c("Alnus glutinosa", "Salix alba", "Populus nigra", "Populus alba",
                           "Fraxinus angustifolia", "Ulmus minor"),
  # non-forest
  "### Nardus-grassland" = c("Nardus stricta", "Geum montanum", "Potentilla erecta",
                             "Agrostis capillaris", "Vaccinium myrtillus"),
  "### Sub-Mediterranean" = c("Quercus pubescens", "Fraxinus ornus", "Asparagus acutifolius",
                              "Brachypodium genuense", "Brachypodium rupestre"),
  "### Dry-grassland" = c("Bromopsis erecta", "Bothriochloa ischaemum", "Festuca inops",
                          "Festuca circummediterranea", "Koeleria splendens", "Carex caryophyllea",
                          "Eryngium campestre", "Sesleria"),
  "### Annual-grassland" = c("Vulpia", "Aegilops geniculata", "Aegilops neglecta", "Avena barbata",
                             "Aira caryophyllea", "Aira elegans", "Anisantha rubens",
                             "Anisantha madritensis", "Bromus hordeaceus", "Brachypodium distachyon",
                             "Trifolium scabrum", "Trifolium stellatum", "Trifolium campestre"),
  "### Heath-maquis" = c("Erica arborea", "Erica scoparia", "Ulex europaeus", "Cistus",
                         "Arbutus unedo", "Myrtus communis", "Phillyrea", "Pistacia lentiscus",
                         "Calicotome", "Helichrysum stoechas", "Spartium junceum"),
  "### Coastal-dunes" = c("Ammophila arenaria", "Elytrigia juncea", "Eryngium maritimum",
                          "Pancratium maritimum", "Achillea maritima", "Cakile maritima"),
  # wetland
  "### Aquatic" = c("Lemna", "Potamogeton", "Callitriche", "Myriophyllum", "Ceratophyllum"),
  "### Marsh" = c("Phragmites australis", "Eleocharis", "Mentha requienii", "Mentha aquatica",
                  "Typha", "Schoenoplectus", "Bolboschoenus maritimus", "Lythrum salicaria",
                  "Petasites hybridus"),
  "### Saltmarsh" = c("Limonium narbonense", "Salicornia", "Sarcocornia", "Arthrocnemum",
                      "Halimione portulacoides", "Juncus maritimus")
)

forest <- "<#TC Trees GR 25>"
wetland <- "<#TC Wetland GR 25>"
rule <- function(priority, code, description, expression, comment = "")
  c(list(priority = as.character(priority), code = code, description = description,
         expression = expression), if (nzchar(comment)) list(`_comment` = comment))
open_land <- function(x) sprintf("%s NOT %s", x, forest)

rules <- list(
  rule(2, "F", "Forest", forest, "Broad type: trees cover more than 25%"),
  rule(2, "W", "Wetland and water", open_land(wetland), "Broad type: wetland plants cover more than 25%"),
  rule(2, "N", "Non-forest", sprintf("<#T$ GR 0> NOT (%s OR %s)", forest, wetland),
       "Broad type: every other plot with vegetation"),
  # forest
  rule(5, "FB", "Beech-fir montane forest", "(<#TC Beech-forest-trees GR 15> AND <#TC Beech-forest-herbs GR 10>)"),
  rule(4, "FF", "Beech and fir forest", "<#TC Beech-forest-trees GR 25>"),
  rule(5, "FC", "Chestnut forest", "<Castanea sativa GR 25>"),
  rule(4, "FQ", "Thermophilous deciduous forest", "<#TC Thermophilous-trees GR 25>"),
  rule(4, "FI", "Holm oak forest", sprintf("<Quercus ilex GR 10> AND %s", forest)),
  rule(4, "FR", "Riparian forest", "<#TC Riparian-trees GR 25>"),
  # non-forest
  rule(5, "NG", "Nardus acidic grassland", open_land("(<Nardus stricta GR 10> AND <#TC Nardus-grassland GR 25>)")),
  rule(3, "NS", "Sub-Mediterranean scrub and woodland", open_land("<#TC Sub-Mediterranean GR 15>")),
  rule(5, "NA", "Ampelodesmos grassland", open_land("<Ampelodesmos mauritanicus GR 15>")),
  rule(4, "NB", "Dry grassland", open_land("<#TC Dry-grassland GR 15>")),
  rule(3, "NT", "Mediterranean annual grassland", open_land("<#TC Annual-grassland GR 15>")),
  rule(4, "NH", "Heath and maquis", open_land("<#TC Heath-maquis GR 25>")),
  rule(4, "ND", "Coastal dunes", open_land("<#TC Coastal-dunes GR 15>")),
  # wetland
  rule(4, "WA", "Open water", open_land("<#TC Aquatic GR 15>")),
  rule(4, "WM", "Marsh and tall herb vegetation", open_land("<#TC Marsh GR 25>")),
  rule(4, "WS", "Saltmarsh", open_land("<#TC Saltmarsh GR 15>"))
)

x <- list(
  metadata = list(scheme = "Apennine-test", version = version,
                  description = paste("Small example expert system for the vegetation of the",
                                      "Italian Apennines and Tuscany: three broad types",
                                      "(forest, non-forest, wetland) and sixteen types.")),
  backbone = list(name = "EuroSL", url = "https://eurosl.infinitenature.org", version = "2026-11-24"),
  groups = lapply(groups, as.list),
  rules = rules
)
dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
jsonlite::write_json(x, out, auto_unbox = TRUE, pretty = TRUE)
message("Written: ", out)
