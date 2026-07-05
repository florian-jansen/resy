# ESy/r-esy Refactoring-Plan
**Datum:** 2026-06-27  
**Ziel:** JSON-Pipeline ohne Textformat-Umweg, Funktionsbereinigung, Branch-Konsolidierung

---

## Übersicht der Phasen

| # | Phase | Kern-Änderung |
|---|---|---|
| 1 | Formel-Transformation extrahieren | Gemeinsame interne Funktion für beide Parser |
| 2 | JSON-Parser neu | Direkter JSON → Solver-Pfad |
| 3 | Load/Compile-Kette vereinfachen | Kein rappdirs, kein lokales Verzeichnis |
| 4 | Geo-Hilfsfunktionen intern machen | Nur `prepare_eunis` bleibt exportiert |
| 5 | check_taxonomy neu schreiben | Section-1-Lookup statt TNRS |
| 6 | Branch-Inhalte integrieren | Selektiv aus gilles/engine-bugfixes |
| 7 | Beispieldaten und Toy-Klassifikation | Apennin-Test-Expert-File anlegen |
| 8 | Shiny-App bereinigen | app_v1.R entfernen |
| 9 | NAMESPACE / DESCRIPTION | Importe und Exporte aktualisieren |

---

## Phase 1 – Formel-Transformation extrahieren

**Problem:** Die komplexe Formel-Umschreibung (GR NON-Expansion, EXCEPT-Einfügung, OR-Präfix-Expansion) steckt tief in `parse.classification.expert.file()` innerhalb von `R/resy_parse_expert.R`. Beide Parser (Text und JSON) müssen sie nutzen, ohne voneinander abzuhängen.

**Aktion:**
- Neue Datei `R/internal_formula_transform.R` anlegen
- Funktion `.resy_transform_formulas(aggs, groups, raw_formulas, raw_priority)` extrahieren
  - Input: rohe Aggregierungen, Gruppen und Formelzeilen aus Section 3
  - Output: `list(aggs, groups, membership.expressions, group.defs, formulas, membership.priority)` – identisch mit dem heutigen Rückgabewert von `parse.classification.expert.file()`
- `parse.classification.expert.file()` in `resy_parse_expert.R` ruft `.resy_transform_formulas()` auf statt die Logik selbst zu enthalten
- Tests sicherstellen: EUNIS-Parsing-Ergebnis vor und nach Refactoring identisch

---

## Phase 2 – JSON-Parser (neu)

**Neue Datei:** `R/resy_parse_json.R`

Funktion `resy_parse_json(path)`:
1. Liest die strukturierte JSON-Datei mit `jsonlite::read_json()`
2. Baut `aggs` direkt aus `section1`:
   - Jeder Eintrag: `canonical` → Namen der Liste, `synonyms` → Vektor der Einträge
   - Format: `list("Fagus sylvatica" = c("Fagus sylvatica L.", "Fagus silvatica L."), ...)`
3. Baut `groups` direkt aus `section2`:
   - Jeder Eintrag: Name wird mit `### ` präfigiert (Konvention des Solvers), Wert = `species`-Vektor
   - Format: `list("### Beech-forest-trees" = c("Fagus sylvatica", "Abies alba"), ...)`
4. Baut `raw_formulas` aus `section3`:
   - Namen: `"PRIO       CODE DESCRIPTION"` (Spaltenformat wie im Textfile)
   - Werte: `expression`-String (gleiche Syntax wie im Textformat)
5. Ruft `.resy_transform_formulas(aggs, groups, raw_formulas, raw_priority)` auf
6. Gibt dasselbe Zwischenergebnis-Listenformat zurück wie `parse.classification.expert.file()`

**Wichtig:** `resy_parse_json()` ruft **nicht** `resy_parse_expert()` auf. Die Post-Processing-Schritte (R-Expressions via `parse()`, `logexpr.formula`) laufen gemeinsam in `resy_parse_expert()` für beide Pfade.

**JSON-Schema (ein File pro Klassifikation):**
```json
{
  "metadata": {
    "scheme": "Apennine-test",
    "version": "2026-06-27",
    "description": "Minimal classification for Italian Apennine vegetation"
  },
  "section1": [
    { "canonical": "Fagus sylvatica", "synonyms": ["Fagus sylvatica L.", "Fagus silvatica L."] }
  ],
  "section2": [
    { "name": "Beech-forest-trees", "species": ["Fagus sylvatica", "Abies alba"] }
  ],
  "section3": [
    {
      "priority": 5,
      "code": "BF",
      "description": "Beech-fir montane forest",
      "expression": "<#TC Beech-forest-trees GR 15>"
    }
  ]
}
```
Formeln in `section3.expression` verwenden **dieselbe Syntax** wie das Textformat. Kein neues Formelformat.

---

## Phase 3 – Load/Compile-Kette vereinfachen

### `R/resy_load_expert.R`
- Dispatch nach Dateiendung:
  - `.json` → `resy_parse_json(path)` → `resy_parse_expert(result)`
  - `.txt` → `parse.classification.expert.file(path)` → `resy_parse_expert(result)`
  - `.rds` → `readRDS(path)` (Cache-Pfad, kein Rebuild nötig)
- `scheme`/`version`-Lookup: nur noch in `inst/extdata/classifications/` (package-intern)
- **Kein rappdirs**, kein User-Verzeichnis
- `location`-Parameter entfällt

### `R/resy_compile_expert.R`
- Funktion wird **entfernt** (kein Vorkompilieren mehr nötig; JSON wird direkt geparst)
- Beim ersten `resy_classify()`-Aufruf wird das JSON geparst; kein RDS-Cache

### `R/resy_classifications_root.R`
- Datei wird **entfernt**
- Ersetzt durch einfachen `system.file("extdata", "classifications", package = "RESY")`-Call direkt in `resy_load_expert`

### `R/resy_expert_path.R`
- Vereinfachen: nur noch `location = "package"`, `format` erweitern auf `c("json", "rds", "txt")`
- User-Verzeichnis-Logik entfernen
- `resy_expert_path()` bleibt exportiert als Read-only-Hilfsfunktion

### `R/resy_available_classifications.R`
- Vereinfachen: scannt nur noch `inst/extdata/classifications/`
- Gibt `data.frame(scheme, version, expert_json, expert_txt)` zurück (ohne `location`-Spalte)
- Bleibt exportiert

---

## Phase 4 – Geo-Hilfsfunktionen intern machen

**Umbenennung:** Funktionen bleiben inhaltlich erhalten, werden aber nicht mehr exportiert.

| Datei | Bisheriger Name | Neuer Name | Export |
|---|---|---|---|
| `R/check_coordinates.R` | `check_coordinates()` | `.check_coordinates()` | nein |
| `R/check_country.R` | `check_country()` | `.check_country()` | nein |
| `R/check_ecoregions.R` | `check_ecoregions()` | `.check_ecoregions()` | nein |
| `R/check_coast_dunes.R` | `check_coast_dunes()` | `.check_coast_dunes()` | nein |

`prepare_eunis()` bleibt exportiert und ruft diese intern auf. Roxygen-Dokumentation entsprechend anpassen (`@keywords internal`, `export()` aus NAMESPACE entfernen).

---

## Phase 5 – `check_taxonomy` neu schreiben

**Alte Version:** TNRS-Aufruf (online, fragil, hardcodierte Spaltenindizes). Wird komplett ersetzt.

**Neue Version:** `check_taxonomy(obs, parsed)`
- `obs`: data.frame/data.table mit Spalte `TaxonName`
- `parsed`: `resy_parsed_expert`-Objekt (Ausgabe von `resy_parse_expert`)
- Logik:
  1. Alle bekannten Namen aus `parsed$aggs` extrahieren (kanonische Namen + alle Synonyme = Section 1)
  2. `obs$TaxonName` gegen diese Liste matchen
  3. Rückgabe: data.frame mit Spalten `TaxonName`, `matched` (logical), `canonical` (gematches Äquivalent oder NA)
- Kein Netzwerk-Aufruf, keine externe Abhängigkeit
- Wird exportiert

**DESCRIPTION:** `TNRS` aus `Imports` entfernen.

---

## Phase 6 – Branch-Inhalte integrieren

### Zu übernehmende Dateien (aus `origin/gilles` bzw. `origin/engine-bugfixes`)

| Datei | Herkunft | Aktion |
|---|---|---|
| `R/resy_read_expert.R` | origin/gilles (reader-writer) | übernehmen |
| `R/resy_write_expert.R` | origin/gilles (reader-writer) | übernehmen |
| `R/resy_expert_tree.R` | origin/gilles | übernehmen (inkl. `resy_write_expert_html`, `resy_view_expert`, `resy_eunis_names`) |
| Bugfixes in `resy_classify` + Tests | origin/engine-bugfixes | mergen |

### Zu verwerfende Inhalte aus origin/gilles

| Datei | Grund |
|---|---|
| `R/resy_crosswalk.R` | zu komplex, nicht benötigt |
| `R/resy_asset.R` | Download-on-demand, nicht gewünscht |
| `R/resy_asset_builtin.R` | wie oben |

### Merge-Reihenfolge (Git)
```bash
git checkout master
git tag backup/before-merge-$(date +%Y%m%d)
git merge origin/engine-bugfixes
# Dann manuell Dateien aus origin/gilles cherry-picken:
git checkout origin/gilles -- R/resy_read_expert.R R/resy_write_expert.R R/resy_expert_tree.R
# vegform: nur Shiny-App
git checkout vegform -- inst/shiny/app.R   # nur falls neuer als master-Version
```

---

## Phase 7 – Beispieldaten und Toy-Klassifikation

### Neue Datei: `inst/extdata/classifications/Apennine-test/2026-06-27/expert.json`

Drei Vegetationstypen, die die Beispieldaten (`data_example_species.csv`, `data_example_sites.csv`) abdecken:

| Code | Beschreibung | Kern-Kennarten |
|---|---|---|
| `BF` | Beech-fir montane forest | *Fagus sylvatica*, *Abies alba*, *Prenanthes purpurea* |
| `NG` | Nardus acidic grassland | *Nardus stricta*, *Geum montanum*, *Potentilla erecta* |
| `SM` | Sub-Mediterranean scrub and woodland | *Quercus pubescens*, *Fraxinus ornus*, *Brachypodium* spp. |

**Section 1:** Alle Arten aus `data_example_species.csv` als kanonische Namen (Author-Epitheta abschneiden), mit dem Original-String als Synonym. Vollständig – auch Arten, die in keiner Gruppe sind.

**Section 2:** Drei Gruppen (je ~5–8 Arten) entsprechend der drei Typen.

**Section 3:** Drei Typen mit einfachen Gruppen-Expressions (`<#TC GruppenName GR Schwellenwert>`).

### Zu entfernende Dateien aus `inst/extdata/classifications/`

| Pfad | Grund |
|---|---|
| `EUNIS/2025-10-03/expert.txt` | nur JSON im Dateibaum |
| `EUNIS/2025-10-03/expert.rds` | kein Pre-Compile mehr |
| `EUNIS-ESy-2026-02-25.txt` | loses File, nicht versioniert |
| `EuroVegChecklist-ESy-2021-08-10.txt` | loses File |
| `Meadow-ESy-2025-01-18-2025.txt` | loses File |
| `Lemnetea/` | Entwicklungs-Artefakt |
| `VegformMV/` | vegform raus |
| `EUNIS/data/Readdata.R` | Entwicklungs-Skript |

`EUNIS/2025-10-03/expert.json` bleibt als primäre EUNIS-Klassifikation.

### Beispieldaten
`inst/extdata/data_example_sites.csv` und `inst/extdata/data_example_species.csv` bleiben unverändert (italienische Küsten-/Bergvegetation, 200 Plots).

---

## Phase 8 – Shiny-App

- `inst/shiny/app.R` bleibt (master-Version)
- `inst/shiny/app_v1.R` wird entfernt (vegform-Artefakt)

---

## Phase 9 – NAMESPACE / DESCRIPTION

### DESCRIPTION: Imports entfernen
- `TNRS` entfernen
- `rappdirs` entfernen

### NAMESPACE: Exporte entfernen
- `check_coordinates`
- `check_country`
- `check_ecoregions`
- `resy_compile_expert`
- `resy_classifications_root` (Datei wird gelöscht)

### NAMESPACE: Neue Exporte hinzufügen
- `resy_parse_json`
- `resy_read_expert`
- `resy_write_expert`
- `resy_expert_tree`
- `resy_write_expert_html`
- `resy_view_expert`
- `resy_eunis_names`
- `check_taxonomy` (neu geschrieben)

---

## Dateien-Übersicht nach Refactoring

### Neue Dateien
```
R/internal_formula_transform.R   # .resy_transform_formulas()
R/resy_parse_json.R              # resy_parse_json()
R/resy_read_expert.R             # von origin/gilles
R/resy_write_expert.R            # von origin/gilles
R/resy_expert_tree.R             # von origin/gilles
inst/extdata/classifications/Apennine-test/2026-06-27/expert.json
```

### Gelöschte Dateien
```
R/resy_compile_expert.R
R/resy_classifications_root.R
inst/extdata/classifications/EUNIS/2025-10-03/expert.txt
inst/extdata/classifications/EUNIS/2025-10-03/expert.rds
inst/extdata/classifications/EUNIS-ESy-2026-02-25.txt
inst/extdata/classifications/EuroVegChecklist-ESy-2021-08-10.txt
inst/extdata/classifications/Meadow-ESy-2025-01-18-2025.txt
inst/extdata/classifications/Lemnetea/          (Verzeichnis)
inst/extdata/classifications/VegformMV/         (Verzeichnis)
inst/extdata/classifications/EUNIS/data/
inst/shiny/app_v1.R
```

### Modifizierte Dateien
```
R/resy_parse_expert.R       # parse.classification.expert.file() delegiert an .resy_transform_formulas()
R/resy_load_expert.R        # JSON-Dispatch, kein rappdirs, kein User-Dir
R/resy_expert_path.R        # json-Format, nur package-Location
R/resy_available_classifications.R  # nur inst/extdata scannen
R/check_coordinates.R       # intern (.check_coordinates), kein Export
R/check_country.R           # intern
R/check_ecoregions.R        # intern
R/check_coast_dunes.R       # intern
R/check_taxonomy.R          # komplett neu: Section-1-Lookup
DESCRIPTION                 # TNRS, rappdirs raus
NAMESPACE                   # Exporte aktualisieren
```

---

## Offene Entscheidungen

1. **RDS-Cache:** Soll `resy_load_expert()` optional ein `.rds` erzeugen, wenn es noch nicht existiert (für Performance bei großen Files wie EUNIS)?  
   _Vorschlag: Ja, aber nur im Package-Verzeichnis selbst, kein User-Dir._

2. **`resy_expert_path()` Export:** Nach Vereinfachung bleibt die Funktion nützlich für User, die wissen wollen, wo eine Klassifikation liegt. Export behalten?  
   _Vorschlag: Ja._
