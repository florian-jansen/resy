options(shiny.maxRequestSize = 50 * 1024^2)

# Capture app directory at source time; used to locate inst/extdata when the
# RESY package is not installed.
.app_dir <- normalizePath('.')

ensure_pkg <- function(pkgs) {
  for (p in pkgs) {
    if (!requireNamespace(p, quietly = TRUE)) {
      install.packages(p)
    }
  }
}

ensure_pkg(c('shiny', 'data.table', 'DT'))

ensure_resy <- function() {
  if (requireNamespace('RESY', quietly = TRUE)) return(invisible(TRUE))

  local_tar <- c(
    '/home/shiny/RESY_0.4.3.tar.gz',
    'RESY_0.4.3.tar.gz'
  )
  local_tar <- local_tar[file.exists(local_tar)][1]
  if (!is.na(local_tar) && nzchar(local_tar)) {
    install.packages(local_tar, repos = NULL, type = 'source')
  } else {
    stop('Package RESY is not installed and no source file could be found.')
  }
}

ensure_resy()

library(shiny)
library(data.table)
library(DT)
library(RESY)

`%||%` <- function(x, y) if (is.null(x)) y else x


find_extdata_file <- function(rel_path) {
  p1 <- system.file('extdata', rel_path, package = 'RESY')
  if (nzchar(p1) && file.exists(p1)) return(p1)

  p2 <- file.path('/mnt/data/resy_src/RESY/inst/extdata', rel_path)
  if (file.exists(p2)) return(p2)

  # Fallback: inst/extdata relative to this app (inst/shiny)
  p3 <- normalizePath(file.path(.app_dir, '..', 'extdata', rel_path), mustWork = FALSE)
  if (file.exists(p3)) return(p3)

  stop('Datei nicht gefunden: ', rel_path)
}

read_example_data <- function() {
  raw <- fread(find_extdata_file('data_example_species.csv'))
  setnames(raw, c('species', 'cover'), c('TaxonName', 'Cover_Perc'))
  header <- unique(raw[, .(PlotObservationID)])
  list(header = header, obs = raw)
}

# Build the classification dropdown choices from all available schemes/versions.
# Apennine-test is shown first and selected by default; the rest follow in
# alphabetical order. Choices are keyed by the expert file path so the server
# can load the file directly from input$expert_choice.
build_classification_choices <- function() {
  avail <- RESY::resy_available_classifications()
  if (!nrow(avail)) return(c('No classifications found' = ''))

  paths <- ifelse(!is.na(avail$expert_json), avail$expert_json, avail$expert_txt)
  labels <- paste(avail$scheme, avail$version, sep = ' / ')
  choices <- stats::setNames(paths, labels)

  # Put Apennine-test first
  is_apennine <- grepl('Apennine-test', labels, ignore.case = TRUE)
  c(choices[is_apennine], choices[!is_apennine])
}

classification_choices <- build_classification_choices()

# Convert a JSON expert file to the plain-text line format understood by the
# local parser and section editors. Group keys already carry their solver prefix
# (###, ##D …) so they are written to Section 2 verbatim.
json_to_txt_lines <- function(path) {
  if (!requireNamespace('jsonlite', quietly = TRUE))
    stop('jsonlite is required to read JSON expert files.')
  x <- jsonlite::read_json(path, simplifyVector = TRUE)

  if (!all(c('synonyms', 'groups', 'rules') %in% names(x)))
    stop('Unsupported JSON expert format: expected synonyms / groups / rules keys.')

  lines <- character()

  # Section 1: canonical names + indented synonyms
  lines <- c(lines, 'SECTION 1: Start')
  syns <- x$synonyms
  for (nm in names(syns)) {
    lines <- c(lines, nm)
    v <- syns[[nm]]
    if (!is.null(v) && length(v)) lines <- c(lines, paste0('   ', v))
  }
  lines <- c(lines, 'SECTION 1: End')

  # Section 2: group header (prefix already in key) + indented species
  lines <- c(lines, 'SECTION 2: Start')
  grps <- x$groups
  for (nm in names(grps)) {
    lines <- c(lines, nm)
    sp <- grps[[nm]]
    if (!is.null(sp) && length(sp)) lines <- c(lines, paste0('   ', sp))
  }
  lines <- c(lines, 'SECTION 2: End')

  # Section 3: priority + 10 spaces + code + description, then indented expression
  # _comment and other _ keys are ignored by jsonlite column naming conventions
  lines <- c(lines, 'SECTION 3: Start')
  rules <- x$rules  # simplified to a data frame by jsonlite
  for (i in seq_len(nrow(rules))) {
    lines <- c(lines,
      sprintf('%s          %s %s',
        as.character(rules$priority[i]),
        as.character(rules$code[i]),
        as.character(rules$description[i])),
      paste0('   ', as.character(rules$expression[i]))
    )
  }
  lines <- c(lines, 'SECTION 3: End')

  lines
}

read_expert_lines <- function(path) {
  if (grepl('\\.json$', path, ignore.case = TRUE)) {
    json_to_txt_lines(path)
  } else {
    readLines(path, warn = FALSE, encoding = 'UTF-8')
  }
}

extract_section_body <- function(lines, section_no) {
  idx <- grep(sprintf('^\\s*SECTION\\s+%s\\b', section_no), lines, ignore.case = TRUE)
  if (length(idx) < 2) stop('Section ', section_no, ' could not be found.')
  body <- lines[(idx[1] + 1):(idx[2] - 1)]
  paste(body, collapse = '\n')
}

replace_section_body <- function(lines, section_no, new_text) {
  idx <- grep(sprintf('^\\s*SECTION\\s+%s\\b', section_no), lines, ignore.case = TRUE)
  if (length(idx) < 2) stop('Section ', section_no, ' could not be found.')
  before <- lines[seq_len(idx[1])]
  after <- lines[idx[2]:length(lines)]
  middle <- if (nzchar(new_text)) strsplit(new_text, '\n', fixed = TRUE)[[1]] else character(0)
  c(before, middle, after)
}

build_expert_file <- function(base_lines, section2_text, section3_text) {
  out <- replace_section_body(base_lines, 2, section2_text)
  out <- replace_section_body(out, 3, section3_text)
  tmp <- tempfile(fileext = '.txt')
  writeLines(out, tmp, useBytes = TRUE)
  tmp
}

safe_validate <- function(path) {
  tryCatch(
    RESY::resy_validate_esy(path, strict = FALSE, verbose = FALSE),
    error = function(e) list(ok = FALSE, errors = conditionMessage(e), warnings = character())
  )
}

classify_with_expert <- function(expert_path, example_data) {
  obs <- copy(example_data$obs)
  header <- as.data.frame(example_data$header)

  tmp <- RESY:::.resy_standardize_plot_id(obs, header)
  obs <- tmp$obs
  header <- tmp$header

  parsed <- RESY::resy_load_expert(expertfile = expert_path)
  obs2 <- RESY:::resy_aggregate_taxa(obs, parsed$aggs)
  plot.cond <- RESY:::resy_init_plot_conditions(obs2, parsed$conditions)

  solved <- RESY:::.resy_solve_membership(
    obs = obs2,
    header = header,
    parsed = parsed,
    plot.cond = plot.cond,
    mc = 1
  )

  cand <- data.table(
    plot_id = character(), type = character(),
    priority = character(), priority_rank = integer()
  )
  if (!is.null(solved$types) && length(solved$types) > 0) {
    vt_names <- parsed$vegtype.formula.names.short
    vt_prio  <- parsed$vegtype.priority
    rows <- Filter(Negate(is.null), lapply(names(solved$types), function(pid) {
      ty <- solved$types[[pid]]
      if (!length(ty)) return(NULL)
      pr <- vt_prio[fastmatch::fmatch(ty, vt_names)]
      data.table(
        plot_id       = as.character(pid),
        type          = as.character(ty),
        priority      = pr,
        priority_rank = as.integer(pr)
      )
    }))
    if (length(rows)) {
      cand <- rbindlist(rows, use.names = TRUE, fill = TRUE)
      setorder(cand, plot_id, -priority_rank, type)
    }
  }

  structure(
    c(
      list(
        obs = obs2,
        header = header,
        expertfile = expert_path,
        scheme = 'custom',
        version = NA_character_,
        prefer = 'user',
        candidates = cand
      ),
      solved,
      list(parsed = parsed)
    ),
    class = 'resy_result'
  )
}

priority_table <- function(res, priority = 1) {
  cand <- as.data.table(RESY::resy_candidates(res, priority = priority))
  if (!all(c('type', 'plot_id') %in% names(cand))) {
    return(data.table(type = character(), N = integer()))
  }

  cand[, plot_id := as.character(plot_id)]
  cand[, type_label := fifelse(is.na(type) | !nzchar(trimws(as.character(type))), 'NA', as.character(type))]
  out <- cand[!is.na(plot_id) & nzchar(plot_id), .(N = uniqueN(plot_id)), by = .(type = type_label)]

  all_plot_ids <- unique(c(
    as.character(res$header$PlotObservationID),
    as.character(res$header$plot_id),
    as.character(res$obs$PlotObservationID),
    as.character(res$obs$plot_id),
    as.character(res$candidates$plot_id)
  ))
  all_plot_ids <- unique(all_plot_ids[!is.na(all_plot_ids) & nzchar(all_plot_ids)])
  classified_plot_ids <- unique(cand[!is.na(type) & nzchar(trimws(as.character(type))) & !is.na(plot_id) & nzchar(plot_id), plot_id])
  na_count <- length(setdiff(all_plot_ids, classified_plot_ids))

  if ('NA' %in% out$type) {
    out[type == 'NA', N := max(N, na_count)]
  } else {
    out <- rbind(out, data.table(type = 'NA', N = na_count), fill = TRUE)
  }

  setorder(out, -N, type)
  out[]
}

wide_priority_23 <- function(res) {
  dt <- res$candidates[
    priority %in% c(2, 3),
    .(types = paste(sort(type), collapse = '+')),
    by = .(plot_id, priority)
  ]
  wide <- dcast(dt, plot_id ~ priority, value.var = 'types')
  for (nm in c('2', '3')) {
    if (!nm %in% names(wide)) wide[, (nm) := NA_character_]
  }
  setcolorder(wide, c('plot_id', '2', '3'))
  wide[]
}

wide_count_table <- function(wide) {
  out <- wide[, .N, by = .(`2`, `3`)]
  setorder(out, -N, `2`, `3`)
  out
}

priority_taxon_table <- function(res, priority = 1, type_code) {
  cand <- as.data.table(RESY::resy_candidates(res, priority = priority))
  if (!all(c('type', 'plot_id') %in% names(cand))) {
    return(data.table(Message = sprintf('Priority %s candidates do not contain the expected columns.', priority)))
  }

  cand[, plot_id := as.character(plot_id)]
  if (identical(type_code, 'NA')) {
    all_plot_ids <- unique(c(
      as.character(res$header$PlotObservationID),
      as.character(res$header$plot_id),
      as.character(res$obs$PlotObservationID),
      as.character(res$obs$plot_id),
      as.character(res$candidates$plot_id)
    ))
    all_plot_ids <- unique(all_plot_ids[!is.na(all_plot_ids) & nzchar(all_plot_ids)])
    classified_plot_ids <- unique(cand[!is.na(type) & nzchar(trimws(as.character(type))) & !is.na(plot_id) & nzchar(plot_id), plot_id])
    plot_ids <- setdiff(all_plot_ids, classified_plot_ids)
  } else {
    plot_ids <- unique(cand[as.character(type) == as.character(type_code) & !is.na(plot_id) & nzchar(plot_id), plot_id])
  }

  if (!length(plot_ids)) {
    return(data.table(Message = sprintf('No plots found for Priority %s type "%s".', priority, type_code)))
  }

  obs <- as.data.table(res$obs)
  plot_col <- if ('PlotObservationID' %in% names(obs)) 'PlotObservationID' else if ('plot_id' %in% names(obs)) 'plot_id' else NULL
  if (is.null(plot_col) || !'TaxonName' %in% names(obs)) {
    return(data.table(Message = 'Observation data do not contain plot IDs and TaxonName.'))
  }

  taxa <- obs[as.character(get(plot_col)) %in% plot_ids & !is.na(TaxonName), .N, by = .(TaxonName)]
  if (!nrow(taxa)) {
    return(data.table(Message = sprintf('No species observations found for Priority %s type "%s".', priority, type_code)))
  }

  setorder(taxa, -N, TaxonName)
  taxa[]
}

capture_eval_plot <- function(res, plot_id, type_code) {
  paste(
    capture.output(
      RESY::resy_eval_plot(res = res, p = plot_id, type = type_code)
    ),
    collapse = '
'
  )
}

ui <- fluidPage(
  tags$head(
    tags$style(HTML('
      .section-editor textarea { font-family: monospace; }
      .mono, pre { font-family: monospace; }
      .shiny-output-error-validation { color: #b30000; }
    '))
  ),
  titlePanel('RESY Shiny App: Editor für Section 2 und 3'),
  sidebarLayout(
    sidebarPanel(
      width = 6,
      selectInput(
        'expert_choice',
        'Classification (if you choose a large expert file it might take dozens of seconds to load: be patient)',
        choices  = classification_choices,
        selected = classification_choices[1]
      ),
      tags$hr(),
      div(
        class = 'section-editor',
        textAreaInput('section2', 'Section 2', value = '', rows = 18, width = '100%'),
        textAreaInput('section3', 'Section 3', value = '', rows = 18, width = '100%')
      ),
      fluidRow(
        column(6, actionButton('reset_sections', 'Reset Sections', width = '100%')),
        column(6, actionButton('run_classification', 'Classify', class = 'btn-primary', width = '100%'))
      ),
      tags$hr(),
      verbatimTextOutput('validation_text')
    ),
    mainPanel(
      width = 6,
      tabsetPanel(
        tabPanel(
          'Overview',
          h4('Status'),
          verbatimTextOutput('status_text'),
          fluidRow(
            column(6, selectInput('overview_priority', 'Priority level', choices = as.character(1:3), selected = '1'))
          ),
          h4(textOutput('overview_priority_title', inline = TRUE)),
          DTOutput('priority_table_view'),
          uiOutput('overview_secondary_title'),
          DTOutput('overview_secondary_table')
        ),
        tabPanel(
          'Plot-View',
          fluidRow(
            column(6, selectInput('plot_filter_p2', 'Filter: Candidate Type', choices = c('All' = '__all__'))),
            column(6, selectInput('plot_id', 'Plot-ID', choices = NULL))
          ),
          fluidRow(
            column(12, selectInput('type_code', 'Typ select resy_eval_plot()', choices = NULL))
          ),
          h4('resy_eval_plot()'),
          verbatimTextOutput('eval_text')
        ),
        tabPanel(
          'Candidates & Data',
          h4('All Candidates'),
          DTOutput('candidates_table')
        )
      )
    )
  )
)

server <- function(input, output, session) {
  example_data <- read_example_data()

  rv <- reactiveValues(
    base_lines = NULL,
    base_path = NULL,
    result = NULL,
    wide = NULL,
    validation = NULL,
    status = 'No Classification applied.'
  )

  # Auto-load whenever the classification dropdown changes (including on startup).
  # observe() + req() is used instead of observeEvent(ignoreInit=FALSE) because
  # the latter fires before the selectInput has its initial value, hits the NULL
  # guard and never re-triggers. observe() re-runs reactively every time
  # input$expert_choice actually carries a valid path.
  observe({
    path <- input$expert_choice
    req(nzchar(path %||% ''), file.exists(path))

    lines <- read_expert_lines(path)
    rv$base_path  <- path
    rv$base_lines <- lines

    updateTextAreaInput(session, 'section2', value = extract_section_body(lines, 2))
    updateTextAreaInput(session, 'section3', value = extract_section_body(lines, 3))

    val <- safe_validate(path)
    rv$validation <- val
    rv$status <- paste0('Loaded: ', basename(dirname(path)), '/', basename(path))
  })

  observeEvent(input$reset_sections, {
    req(rv$base_lines)
    updateTextAreaInput(session, 'section2', value = extract_section_body(rv$base_lines, 2))
    updateTextAreaInput(session, 'section3', value = extract_section_body(rv$base_lines, 3))
  })

  current_expert_path <- eventReactive(input$run_classification, {
    req(rv$base_lines)
    build_expert_file(rv$base_lines, input$section2 %||% '', input$section3 %||% '')
  })

  observeEvent(input$run_classification, {
    path <- current_expert_path()
    val <- safe_validate(path)
    rv$validation <- val

    if (!isTRUE(val$ok)) {
      rv$status <- 'Validation failed. Fix errors in Section 2/3.'
      rv$result <- NULL
      rv$wide <- NULL
      return(invisible(NULL))
    }

    res <- classify_with_expert(path, example_data)
    rv$result <- res
    rv$wide <- wide_priority_23(res)
    rv$status <- paste0(
      'Classification successful. ',
      nrow(res$candidates %||% data.table()), ' Candidate lines for ',
      uniqueN((res$candidates %||% data.table(plot_id = character()))$plot_id), ' Plots.'
    )
  })

  observe({
    res <- rv$result
    if (is.null(res)) return()

    all_types <- sort(unique(as.character(res$candidates[!is.na(type), type])))

    # Detect plots that received no candidate type (NA / unclassified)
    all_plot_ids <- unique(c(
      as.character(res$header$PlotObservationID),
      as.character(res$header$plot_id)
    ))
    all_plot_ids <- all_plot_ids[!is.na(all_plot_ids) & nzchar(all_plot_ids)]
    classified   <- unique(res$candidates[
      !is.na(type) & nzchar(trimws(as.character(type))), as.character(plot_id)
    ])
    na_choice <- if (length(setdiff(all_plot_ids, classified)) > 0L)
      c('NA (unclassified)' = '__na__') else character(0)

    updateSelectInput(session, 'plot_filter_p2',
      choices = c('All' = '__all__', na_choice, stats::setNames(all_types, all_types)))
  })

  filtered_plot_choices <- reactive({
    res <- rv$result
    req(res)

    filter_val <- input$plot_filter_p2

    if (identical(filter_val, '__all__') || !nzchar(filter_val %||% '')) {
      return(sort(unique(as.character(res$candidates$plot_id))))
    }

    if (identical(filter_val, '__na__')) {
      all_plot_ids <- unique(c(
        as.character(res$header$PlotObservationID),
        as.character(res$header$plot_id)
      ))
      all_plot_ids <- all_plot_ids[!is.na(all_plot_ids) & nzchar(all_plot_ids)]
      classified   <- unique(res$candidates[
        !is.na(type) & nzchar(trimws(as.character(type))), as.character(plot_id)
      ])
      return(sort(setdiff(all_plot_ids, classified)))
    }

    # Return only plots where the selected type appears among their candidates
    cand <- as.data.table(res$candidates)
    sort(unique(cand[as.character(type) == filter_val & !is.na(plot_id), as.character(plot_id)]))
  })

  observe({
    ids <- filtered_plot_choices()
    req(length(ids) > 0)

    selected <- isolate(input$plot_id)
    if (!length(selected) || !selected %in% ids) selected <- ids[1]

    updateSelectInput(session, 'plot_id', choices = ids, selected = selected)
  })

  observe({
    res <- rv$result
    req(res, input$plot_id)
    cand <- RESY::resy_candidates(res, plot_id = input$plot_id)
    types <- unique(cand$type)
    if (!length(types)) types <- unique(res$parsed$vegtype.formula.names.short)

    selected <- isolate(input$type_code)
    if (!length(selected) || !selected %in% types) {
      selected <- if ('3+' %in% types) '3+' else types[1]
    }
    updateSelectInput(session, 'type_code', choices = types, selected = selected)
  })

  output$validation_text <- renderText({
    val <- rv$validation
    if (is.null(val)) return('No Validation yet.')

    fmt_warnings <- function(warns, max_show = 10) {
      if (!length(warns)) return('Warnings: none')
      # Collapse near-duplicate lines that share the same prefix (up to first '\'')
      prefixes <- sub("^([^']+).*$", "\\1", warns)
      groups   <- split(warns, prefixes)
      # Flatten back: one representative line per group, with count if > 1
      condensed <- vapply(groups, function(g) {
        if (length(g) == 1L) g[1] else paste0(g[1], ' [+', length(g) - 1L, ' similar]')
      }, character(1))
      n <- length(condensed)
      shown   <- condensed[seq_len(min(n, max_show))]
      trailer <- if (n > max_show) sprintf('\n  ... and %d more (total %d warnings)', n - max_show, length(warns)) else ''
      paste0('Warnings (', length(warns), '):\n ', paste('-', shown, collapse = '\n '), trailer)
    }

    parts <- c(
      paste('OK:', isTRUE(val$ok)),
      if (length(val$errors))
        paste('Errors:\n', paste('-', val$errors, collapse = '\n'))
      else
        'Errors: none',
      fmt_warnings(val$warnings)
    )
    paste(parts, collapse = '\n\n')
  })

  output$status_text <- renderText({
    rv$status
  })

  observe({
    req(rv$result)
    prios <- sort(unique(as.integer(rv$result$candidates$priority)))
    prios <- prios[!is.na(prios)]
    if (!length(prios)) prios <- 1:3
    selected <- input$overview_priority %||% as.character(prios[1])
    if (!selected %in% as.character(prios)) selected <- as.character(prios[1])
    updateSelectInput(session, 'overview_priority', choices = as.character(prios), selected = selected)
  })

  selected_overview_priority <- reactive({
    suppressWarnings(as.integer(input$overview_priority %||% '1'))
  })

  selected_overview_type <- reactive({
    req(rv$result)
    sel <- input$priority_table_view_rows_selected
    if (is.null(sel) || !length(sel)) return(NULL)
    tbl <- priority_table(rv$result, priority = selected_overview_priority())
    if (sel[1] < 1 || sel[1] > nrow(tbl)) return(NULL)
    tbl$type[sel[1]]
  })

  output$overview_priority_title <- renderText({
    sprintf('Priority %s', selected_overview_priority())
  })

  output$priority_table_view <- renderDT({
    req(rv$result)
    datatable(
      priority_table(rv$result, priority = selected_overview_priority()),
      filter = 'top',
      selection = list(mode = 'single', target = 'row'),
      options = list(pageLength = 15)
    )
  })

  output$overview_secondary_title <- renderUI({
    type_code <- selected_overview_type()
    prio <- selected_overview_priority()
    if (is.null(type_code) || !length(type_code)) {
      h4(sprintf('Species observations for selected Priority %s type', prio))
    } else {
      h4(sprintf('Species observations for Priority %s type "%s"', prio, type_code))
    }
  })

  output$overview_secondary_table <- renderDT({
    req(rv$result)
    type_code <- selected_overview_type()
    prio <- selected_overview_priority()
    if (is.null(type_code) || !length(type_code)) {
      return(datatable(data.table(Message = sprintf('Click a row in the Priority %s table to see species frequencies.', prio)), options = list(dom = 't')))
    }
    datatable(priority_taxon_table(rv$result, priority = prio, type_code = type_code), filter = 'top', options = list(pageLength = 15))
  })

  output$candidates_table <- renderDT({
    req(rv$result)
    datatable(rv$result$candidates, filter = 'top', options = list(pageLength = 20, scrollX = TRUE))
  })

  output$eval_text <- renderText({
    req(rv$result, input$plot_id, input$type_code)
    capture_eval_plot(rv$result, input$plot_id, input$type_code)
  })
}

shinyApp(ui, server)
