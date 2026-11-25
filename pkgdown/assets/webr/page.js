// Runs RESY in webR for vignettes/articles/app.Rmd. The bundle and the R
// helpers sit next to this script; pkgdown/build_webr_bundle.R builds the bundle.
// The data files are read here in parts and classified in batches of whole
// plots, spread over several webR sessions, so files of any size can be used.
import { $, escapeHtml, rString, cleanError, fmt, plural, createLoader, fetchAssets, bootSession, setFile, saveBlob, store, createShell, pinNavbar, prepareSites, ensureGeography, ensureBackbone } from './resy_core.js';
import { lineChunks, splitFields, splitRecords, fileText, readHeader, pick, SPECIES_COLS, SPECIES_COL_LABEL, fillSpeciesColumns, tsvValue, plotId, tsvPlotId, fieldNumber } from './resy_files.js';
import { compareHtml, evidenceHtml, wireEvidence } from './resy_evidence.js';
import { placeOf, createDotMap } from './resy_map.js';
import { PALETTE, level, colourVar, cssValue } from './resy_palette.js';

const loader = createLoader({ init: 0, install: 0.55, resy: 0.65, parse: 0.85 });
const stage = (name) => loader.stage(name);

const status = (text, kind = 'busy') => {
  $('status').classList.toggle('error', kind === 'error');
  $('status').classList.toggle('text-body-secondary', kind !== 'error');
  $('status').innerHTML = (kind === 'busy' ? '<span class="spinner-border spinner-border-sm me-2" aria-hidden="true"></span>' : '') + escapeHtml(text);
  loader.text(text, kind);
};

// ---- R sessions ------------------------------------------------------------
// Each webR session is one R process in its own worker. Batches go to whichever
// session is free; the first session starts before the page opens. The others
// start when a run has a batch ready and every session is busy, so a small run,
// such as the example data, needs no more than one session, and a phone does
// not hold several R sessions in memory just to open the page.
// Unless a number is entered, the page runs as many sessions as fit: one less
// than the number of processor cores, at most 8, and no more than fit in 60%
// of the device's memory (`navigator.deviceMemory`, given by Chromium browsers;
// without it, at most 4) beside the page. Each session holds its own R, RESY and maps;
// its size is measured after every batch, so the number follows what the
// sessions actually use. A session that runs out of memory is closed, its batch
// goes to another session, and the run continues with one session fewer.
const CORES = Math.max(1, Math.min(8, (navigator.hardwareConcurrency || 2) - 1));
const DEVICE_GB = navigator.deviceMemory ?? null;
const PAGE_GB = 1;               // the page with the results of a large run
const SESSION_CODE_GB = 0.3;     // compiled R code of a session, beside its memory
const SESSION_START_GB = 0.4;    // memory of a session before its first batch is measured
let manualSessions = null;
let memoryCap = Infinity;
const sessionGB = () => SESSION_CODE_GB + Math.max(SESSION_START_GB, ...pool.map((s) => s.heapGB ?? 0));
const autoSessions = () => Math.min(CORES, DEVICE_GB ? Math.floor((0.6 * DEVICE_GB - PAGE_GB) / sessionGB()) : 4);
const poolSize = () => Math.max(1, Math.min(manualSessions ?? autoSessions(), memoryCap));
const OUT_OF_MEMORY = /cannot allocate|out of memory|memory access out of bounds|allocation failed/i;
const pool = [];
let starting = 0;
const waiting = [];
let assets = null, info = null;
let system = null;           // the selected expert system: { key, call, file, info }

async function startSession(first, ready = bootSession(assets)) {
  const webR = await ready;
  const s = { webR, busy: false, key: null, info: null };
  if (system) await applySystem(s, first);
  pool.push(s);
  release(s);
  showSessions();
  return s;
}

// The field gives the most sessions a run may use; the footer, how many are
// running now.
const showSessions = () => {
  $('workers').textContent = `${pool.length} R session${pool.length === 1 ? '' : 's'} running${starting ? `, ${starting} starting` : ''}`;
  $('o-sessions').placeholder = `auto: up to ${Math.max(1, Math.min(autoSessions(), memoryCap))}`;
};

// Closes sessions until there are no more than `poolSize()`, and with `grow`
// starts sessions until there are `poolSize()`. A busy or still starting
// session is closed once it is free. An entered number of sessions starts
// at once.
function resizePool(grow = manualSessions !== null) {
  while (grow && pool.length + starting < poolSize()) {
    starting++;
    showSessions();
    startSession(false).catch((e) => console.warn('[resy] R session failed to start', e))
      .finally(() => { starting--; showSessions(); });
  }
  for (const s of pool.filter((s) => !s.busy).slice(0, Math.max(0, pool.length - poolSize()))) closeSession(s);
  showSessions();
}

function closeSession(s) {
  pool.splice(pool.indexOf(s), 1);
  s.webR.close();
  showSessions();
}

// Reads the selected expert system into a session. A session keeps what it read, so
// a system already in the session is not read again.
async function applySystem(s, first = false, target = system) {
  if (s.key === target.key) return s.info;
  if (target.file) {
    await s.webR.evalRVoid('dir.create("/tmp/upload", showWarnings = FALSE)');
    await s.webR.FS.writeFile(target.file.path, target.file.bytes);
  }
  if (first) { status('Reading the expert system…'); stage('parse'); }
  const out = JSON.parse(await s.webR.evalRString(target.call));
  // A system that is not shipped with RESY matches its names against the
  // whole of EuroSL, loaded once per session.
  if (out.needs_backbone) {
    if (first) status('Loading the taxonomic backbone…');
    await ensureBackbone(s.webR);
  }
  s.key = target.key;
  s.info = out;
  return out;
}

function release(s) {
  s.busy = false;
  if (pool.length > poolSize()) return closeSession(s);
  const next = waiting.shift();
  if (next) { s.busy = true; next(s); }
}

// A free session with the selected expert system.
async function acquire(target = system) {
  const free = pool.find((s) => !s.busy);
  const s = free ?? await new Promise((resolve) => waiting.push(resolve));
  s.busy = true;
  try {
    await applySystem(s, false, target);
  } catch (e) {
    release(s);
    throw e;
  }
  return s;
}

async function start() {
  pinNavbar($('resy-app'));
  const t0 = performance.now();
  const assetsPromise = fetchAssets(['resy_page.R']);
  const session = bootSession(assetsPromise, (step, text) => { status(text); stage(step); });
  assets = await assetsPromise;
  info = assets.info;
  if (info) $('footer').insertAdjacentHTML('afterbegin', `RESY ${escapeHtml(info.resy)} · `);
  fillVersions(info?.eunis_versions ?? []);
  await adoptHandoff();
  system = await chooseSystem();
  const first = await startSession(true, session);
  system.info = first.info;
  showSystem(first.info);
  await loadExamples(first);
  status(`R is ready (${((performance.now() - t0) / 1000).toFixed(0)} s).`, 'idle');
  await loader.hide();
  $('tool').inert = false;
  updateReadiness();
  resizePool();
  shell.ready();
}

// ---- Expert system ---------------------------------------------------------
// An expert system handed over by the RESY Maker (maker.js) is put into the
// file input, as if it had been chosen there.
const handedFile = (handed) => new File([handed.text], handed.name, { type: 'application/json' });
function adopt(file) {
  setFile($('f-expert'), file);
  document.querySelector('input[name=system][value=file]').checked = true;
}
async function adoptHandoff() {
  if (location.hash !== '#from-maker') return;
  const handed = await store.get('to-app');
  if (handed) adopt(handedFile(handed));
}
// The RESY Maker shares the window with this page (see createShell()); an
// expert system it hands over is chosen here as an uploaded file is.
let pendingHandoff = null;
const shell = createShell('app', (handed) => {
  pendingHandoff = handedFile(handed);
  return applyHandoff();
});

async function applyHandoff() {
  if (!pendingHandoff || running || configuring) return;
  const file = pendingHandoff;
  pendingHandoff = null;
  await onSystemChange(file);
  $('sys-h').scrollIntoView({ block: 'nearest' });
}

// Opens the selected expert system in the RESY Maker.
async function openInMaker(e) {
  e.preventDefault();
  const v = systemChoice(), f = $('f-expert').files[0];
  if (v === 'file' && !f) { await shell.open(null); return; }
  const handed = v === 'file'
    ? { file: { name: f.name, bytes: new Uint8Array(await f.arrayBuffer()) } }
    : { scheme: v, version: v === 'EUNIS' ? $('eunis-version').value : null };
  await shell.open(handed);
}

// The EUNIS-ESy releases shipped with RESY, newest first, as listed in
// bundle.json. Without the list the newest shipped release is used.
function fillVersions(versions) {
  const sel = $('eunis-version');
  sel.innerHTML = versions.map((v, i) => `<option value="${escapeHtml(v)}">${escapeHtml(v)}${i === 0 ? ' (newest)' : ''}</option>`).join('');
  sel.hidden = versions.length < 2;
}

const systemChoice = () => document.querySelector('input[name=system]:checked').value;

let uploadKey = 0;
async function chooseSystem(handed = null) {
  const v = handed ? 'file' : systemChoice();
  if (v !== 'file') {
    const version = v === 'EUNIS' ? $('eunis-version').value : '';
    return {
      key: `${v}:${version}`,
      call: `resy_page_set_expert(scheme = ${rString(v)}${version ? `, version = ${rString(version)}` : ''})`,
      file: null,
      info: null,
    };
  }
  const f = handed ?? $('f-expert').files[0];
  if (!/\.(json|txt)$/i.test(f.name)) throw new Error('The expert system file must end in .json or .txt.');
  const path = `/tmp/upload/${f.name.replace(/[^A-Za-z0-9._-]/g, '_')}`;
  return {
    key: `file:${++uploadKey}`,
    call: `resy_page_set_expert(path = ${rString(path)})`,
    file: { path, bytes: new Uint8Array(await f.arrayBuffer()) },
    info: null,
  };
}

function showSystem(out) {
  $('eunis-opts').disabled = !out.eunis;
  $('o-buffer').disabled = !$('o-coast').checked;
  const codes = (xs) => {
    const c = xs.map((x) => `<code>${escapeHtml(x)}</code>`);
    return c.length > 1 ? `${c.slice(0, -1).join(', ')} and ${c.at(-1)}` : c[0];
  };
  const own = out.header_cols.filter((c) => !out.derived_cols.includes(c));
  let text = `The ${escapeHtml(systemLabel(out))} expert system includes ${out.n_types.toLocaleString()} ${out.eunis ? 'habitat ' : ''}types and ${out.n_species.toLocaleString()} species.`;
  if (out.derived_cols.length) text += ` RESY derives ${codes(out.derived_cols)} from <code>Longitude</code> and <code>Latitude</code>.`;
  if (own.length) text += ` It ${out.derived_cols.length ? 'also ' : ''}reads ${codes(own)} from the sites file if ${own.length > 1 ? 'those columns are' : 'that column is'} present.`;
  if (!out.header_cols.length) text += ' It reads no columns from the sites file.';
  if (out.doi) text += ` Release: <a href="https://doi.org/${escapeHtml(out.doi)}">doi:${escapeHtml(out.doi)}</a>.`;
  $('sys-info').className = 'small mt-3 mb-0';
  $('sys-info').innerHTML = text;
}

// The scheme and release of a system, e.g. "EUNIS 2021-06-01"; an uploaded
// file that is a published release is named as that release.
const systemLabel = (info) => info.version ? `${info.release_scheme} ${info.version}` : info.scheme;

let configuring = false;
async function onSystemChange(handed = null) {
  if (!pool.length || running || configuring) return;
  if (!handed) invalidateResults();
  $('run').disabled = true;
  if (!handed && systemChoice() === 'file' && !$('f-expert').files[0]) {
    system = null;
    $('eunis-opts').disabled = true;
    $('sys-info').className = 'small mt-3 mb-0';
    $('sys-info').innerHTML = 'Choose an expert system file, <code>.json</code> or <code>.txt</code>, to classify with it.';
    status('', 'idle');
    return;
  }
  configuring = true;
  $('system-panel').inert = true;
  $('sys-info').setAttribute('aria-busy', 'true');
  status('Reading the expert system…');
  try {
    const next = await chooseSystem(handed);
    const s = await acquire(next);
    next.info = s.info;
    release(s);
    if (handed) {
      adopt(handed);
      invalidateResults();
    }
    system = next;
    showSystem(next.info);
    status('Expert system ready.', 'idle');
  } catch (e) {
    if (!handed) {
      system = null;
      $('sys-info').className = 'small mt-3 mb-0 error';
      $('sys-info').textContent = cleanError(e);
      $('eunis-opts').disabled = true;
    }
    status(cleanError(e), 'error');
  } finally {
    configuring = false;
    $('system-panel').inert = false;
    $('sys-info').setAttribute('aria-busy', 'false');
    updateReadiness();
    await applyHandoff();
  }
}

// ---- Reading the data files -----------------------------------------------
// Fills the column choices for the species file.
async function describeSpecies() {
  const f = $('f-species').files[0];
  const current = await fillSpeciesColumns(f, escapeHtml, {
    placeholder: f ? 'Choose a column' : 'Choose a file first',
    isCurrent: () => $('f-species').files[0] === f,
  });
  if (!current) return;
  $('size-note').textContent = f?.size > 50e6 ? `${(f.size / 1e9).toFixed(f.size > 1e9 ? 1 : 2)} GB: RESY reads it in parts.` : '';
  updateReadiness();
}

function updateReadiness() {
  const files = DATA_INPUTS.every((id) => $(id).files.length);
  const columns = SPECIES_COLS.every(([, id]) => $(id).value);
  if (!running) $('run').disabled = !loader.done || configuring || !system?.info || !files || !columns;
  $('data-note').textContent = !files ? 'Choose both files to begin, or try the example data.' :
    !columns ? 'Choose the plot, species and cover columns to continue.' :
    DATA_INPUTS.every((_, i) => isExample(i)) ? 'Example ready: 200 plots from Tuscany. Check the columns, then classify.' :
    'Files selected. Check the column choices, then classify.';
}

function invalidateResults() {
  R = null; selected = null; filterType = null;
  dots.index = null;
  table = null;
  rowSizes.disconnect();
  detailRequest++;
  showResults(false, 'No classification yet.');
  $('q').value = '';
  clearDetail();
}

function showResults(available, message = '') {
  $('results').classList.toggle('unavailable', !available);
  $('results').inert = !available || running;
  $('results-empty').textContent = message;
}

// Plot positions and the site columns the expert system reads, kept compactly
// (repeated values such as country names are stored once).
async function readSites(file, wanted) {
  const { delim, cols } = await readHeader(file);
  const iId = cols.indexOf(pick(cols, 'id'));
  if (iId < 0) throw new Error(`The sites file needs the column \`PlotObservationID\`. It has: ${cols.map((c) => `\`${c}\``).join(', ')}.`);
  const iLon = cols.indexOf(pick(cols, 'lon')), iLat = cols.indexOf(pick(cols, 'lat'));
  if (system.info.eunis && (iLon < 0 || iLat < 0)) throw new Error('The sites file needs the columns `Longitude` and `Latitude` for EUNIS-ESy.');
  const extra = wanted.map((w) => [w, cols.indexOf(pick(cols, w))]).filter(([, i]) => i >= 0);
  const store = {
    index: new Map(), lon: [], lat: [], names: extra.map(([w]) => w),
    codes: extra.map(() => []), dicts: extra.map(() => ({ map: new Map(), values: [] })),
  };
  let first = true;
  for await (const chunk of lineChunks(file, delim)) {
    for (const line of chunk.lines) {
      if (first) { first = false; continue; }
      if (!line) continue;
      const f = splitFields(line, delim);
      const id = plotId(f[iId]);
      if (!id) continue;
      store.index.set(id, store.lon.length);
      store.lon.push(iLon >= 0 ? fieldNumber(f[iLon]) : NaN);
      store.lat.push(iLat >= 0 ? fieldNumber(f[iLat]) : NaN);
      extra.forEach(([, i], k) => {
        const d = store.dicts[k], v = f[i] ?? '';
        let code = d.map.get(v);
        if (code === undefined) { code = d.values.length; d.map.set(v, code); d.values.push(v); }
        store.codes[k].push(code);
      });
    }
  }
  store.lon = Float64Array.from(store.lon);
  store.lat = Float64Array.from(store.lat);
  store.codes = store.codes.map((c) => Int32Array.from(c));
  return store;
}

const num = (v) => (Number.isFinite(v) ? String(v) : '');
function sitesTsv(store, ids) {
  const head = ['PlotObservationID', 'Longitude', 'Latitude', ...store.names].join('\t');
  const rows = [head];
  for (const id of ids) {
    const r = store.index.get(id);
    if (r === undefined) continue;
    rows.push([tsvPlotId(id), num(store.lon[r]), num(store.lat[r]), ...store.codes.map((c, k) => tsvValue(store.dicts[k].values[c[r]]))].join('\t'));
  }
  return rows.join('\n') + '\n';
}

// A species file whose rows are not grouped by plot is sorted in memory when
// it is small; a large file has to come grouped (as EVA and Turboveg exports do).
const SORT_LIMIT = 64 * 1024 * 1024;
async function groupedSpecies(file, delim, iId) {
  if (file.size > SORT_LIMIT) return file;
  const lines = splitRecords(await fileText(file), delim);
  const head = lines.shift();
  const rows = lines.filter(Boolean).map((l, i) => ({ l, id: plotId(splitFields(l, delim)[iId]), i }));
  const first = new Map();
  rows.forEach((r) => { if (!first.has(r.id)) first.set(r.id, r.i); });
  rows.sort((a, b) => first.get(a.id) - first.get(b.id) || a.i - b.i);
  return new Blob([[head, ...rows.map((r) => r.l)].join('\n') + '\n']);
}

// ---- Results ---------------------------------------------------------------
// One entry per plot, filled as batches come back, in typed arrays that are
// copied into twice as long ones when full. Codes are indices into `codes`,
// candidate lists indices into `candLists`; positions are Web Mercator
// coordinates in [0, 1] for the map. `R.n` plots are stored.
let R = null;
const COLUMNS = { code: Int32Array, cands: Int32Array, nsp: Int32Array, start: Float64Array, end: Float64Array, mx: Float32Array, my: Float32Array };
function newResults(source, capacity) {
  const r = {
    source, n: 0, ids: [], codes: [], codeIndex: new Map(), counts: [], candLists: [], candIndex: new Map(),
    readSites: new Uint8Array(source.sites.lon.length), readUnplaced: new Set(),
    nObs: 0, unmatched: 0, important: new Set(), nImportant: 0, warnings: new Set(), done: 0, completedBytes: 0, t0: performance.now(),
    sites: { matched: 0, absent: 0, present: new Set(), missing: new Map(), maps: new Map() },
  };
  for (const [k, T] of Object.entries(COLUMNS)) r[k] = new T(Math.max(1024, capacity));
  return r;
}
function growResults(result) {
  for (const [k, T] of Object.entries(COLUMNS)) {
    const a = new T(2 * result[k].length);
    a.set(result[k]);
    result[k] = a;
  }
}
const intern = (index, list, v) => {
  let k = index.get(v);
  if (k === undefined) { k = list.length; index.set(v, k); list.push(v); }
  return k;
};
const codeOf = (result, c) => {
  const k = intern(result.codeIndex, result.codes, c);
  if (result.counts.length < result.codes.length) result.counts.push(0);
  return k;
};

// ---- Running a classification -----------------------------------------------
let running = false, stopRequested = false;
// Batches aim at about two seconds each. An R session keeps the memory of its
// largest batch, so batches stay at most 2,000 plots and 40,000 species
// records.
const BATCH_SECONDS = 2;
const MAX_BATCH = 2000;
const MAX_RECORDS = 40000;

async function run() {
  if (running) { stopRequested = true; $('run').disabled = true; status('Stopping after the active batches finish…'); return; }
  detailRequest++;
  running = true; stopRequested = false;
  $('system-panel').inert = true;
  $('data-inputs').inert = true;
  $('results').inert = true;
  $('results').setAttribute('aria-busy', 'true');
  if ($('results').classList.contains('unavailable')) showResults(false, 'Waiting for classified plots…');
  table = null;
  rowSizes.disconnect();
  $('run').textContent = 'Stop';
  $('progress').hidden = false;
  setProgress(0);
  const inFlight = new Set();
  const failures = [];
  let result = null, readError;
  try {
    if (!system?.info) throw new Error('Choose an expert system first.');
    const sp = $('f-species').files[0], si = $('f-sites').files[0];
    if (!sp) throw new Error('Choose a species file.');
    if (!si) throw new Error('Choose a sites file.');
    const coast = system.info.eunis && $('o-coast').checked;
    if (coast && !$('o-buffer').checkValidity()) throw new Error('Enter a coast buffer of at least 1 metre.');
    const opts = `coast_dunes = ${coast ? 'TRUE' : 'FALSE'}, coast_buffer = ${coast ? $('o-buffer').valueAsNumber : 5000}`;

    const { delim, cols } = await readHeader(sp);
    const col = Object.fromEntries(SPECIES_COLS.map(([key, id]) => [key, cols.indexOf($(id).value)]));
    for (const [key] of SPECIES_COLS) if (col[key] < 0) throw new Error(`Choose the ${SPECIES_COL_LABEL[key]} column of the species file.`);
    const dwc = cols[col.cover] === 'organismQuantity';
    col.unit = dwc ? cols.indexOf('organismQuantityType') : -1;
    if (dwc && col.unit < 0) throw new Error('Add an organismQuantityType column with percent cover units, or choose a percent cover column.');

    status('Reading the sites file…');
    const wanted = [...new Set([...system.info.header_cols.filter((c) => !system.info.derived_cols.includes(c)), ...(system.info.eunis ? ['Country', 'Altitude (m)'] : [])])];
    const sites = await readSites(si, wanted);
    const source = await groupedSpecies(sp, delim, col.id);
    result = newResults({ blob: source, delim, col, sites, opts, header: `PlotObservationID\tname\tcover${dwc ? '\torganismQuantityType' : ''}` }, sites.lon.length);
    result.system = system.info;
    result.typeNames = new Map(result.system.names.map((t) => [t.code, t.name]));
    let target = 1000;
    const newBatch = (start) => ({ lines: [result.source.header], ids: [], first: result.n, start });
    let batch = newBatch(0);
    let current = null, rowsOfCurrent = 0;
    const finishPlot = (end) => {
      if (current === null) return;
      result.end[result.n - 1] = end;
      result.nsp[result.n - 1] = rowsOfCurrent;
    };
    const dispatch = (end) => {
      const b = batch;
      batch = newBatch(end);
      const job = classifyBatch(result, b, end - b.start).then((seconds) => {
        const active = !stopRequested && !failures.length && !readError;
        if (active) target = Math.max(250, Math.min(MAX_BATCH, Math.round(target * Math.min(2, BATCH_SECONDS / Math.max(seconds, 0.05)))));
        showBatchProgress(result, active);
      }).catch((error) => {
        failures.push({ first: b.first, error });
      }).finally(() => inFlight.delete(job));
      inFlight.add(job);
    };

    let first = true;
    status('Classifying…');
    read: for await (const chunk of lineChunks(source, delim)) {
      if (stopRequested || failures.length) break;
      for (let j = 0; j < chunk.lines.length; j++) {
        const line = chunk.lines[j];
        if (first) { first = false; continue; }
        if (!line) continue;
        const f = splitFields(line, delim);
        const id = plotId(f[col.id]);
        if (!id) throw new Error('A row of the species file has no plot ID.');
        if (id !== current) {
          finishPlot(chunk.starts[j]);
          const site = sites.index.get(id);
          if (site === undefined ? result.readUnplaced.has(id) : result.readSites[site]) throw new Error(`The rows of plot ${id} are not together in the species file. Sort the file by plot.`);
          if (batch.ids.length >= target || (batch.ids.length && batch.lines.length > MAX_RECORDS)) {
            while (inFlight.size >= pool.length) {
              resizePool(true);
              await Promise.race(inFlight);
            }
            if (stopRequested || failures.length) break read;
            dispatch(chunk.starts[j]);
          }
          addPlot(result, id, chunk.starts[j], sites, site);
          batch.ids.push(id);
          current = id; rowsOfCurrent = 0;
        }
        rowsOfCurrent++;
        batch.lines.push(speciesTsvRow(f, col, id));
      }
    }
    if (!stopRequested && !failures.length) {
      finishPlot(source.size);
      if (batch.ids.length) dispatch(source.size);
    }
  } catch (e) {
    readError = e;
  } finally {
    await Promise.all(inFlight);
    const errors = [readError, ...failures.sort((a, b) => a.first - b.first).map(({ error }) => error)].filter(Boolean);
    const messages = [...new Set(errors.map(cleanError))];
    const stopped = stopRequested && (!result || result.completedBytes !== result.source.blob.size);
    R = result;
    running = false;
    $('system-panel').inert = false;
    $('data-inputs').inert = false;
    $('results').setAttribute('aria-busy', 'false');
    $('run').textContent = 'Classify';
    updateReadiness();
    $('progress').hidden = true;
    filterType = null; selected = null;
    clearDetail();
    if (R?.done) {
      R.incomplete = stopped || errors.length > 0;
      for (const message of messages) R.warnings.add(message);
      showResults(true);
      dots.fitted = false;
      render();
    } else {
      dots.index = null;
      showResults(false, errors.length ? 'Classification failed.' : 'No plots classified.');
    }
    if (errors.length) {
      errors.forEach((error) => console.error(error));
      const failed = failures.length > 1 ? `${plural(failures.length, 'batch')} failed. ` : '';
      status(`${failed}${messages.join(' ')}`, 'error');
    } else {
      status(`${stopped ? 'Stopped after' : 'Classified'} ${plural(R?.done ?? 0, 'plot')} in ${formatTime(R ? (performance.now() - R.t0) / 1000 : 0)}.`, 'idle');
    }
    await applyHandoff();
  }
}

function speciesTsvRow(fields, { name, cover, unit }, id) {
  const row = [tsvPlotId(id), tsvValue(fields[name]), tsvValue(fields[cover])];
  if (unit >= 0) row.push(tsvValue(fields[unit]));
  return row.join('\t');
}

// `site` is the plot's row in the sites file, or undefined.
function addPlot(result, id, start, sites, site) {
  if (result.n === result.code.length) growResults(result);
  const i = result.n++;
  result.ids.push(id);
  if (site === undefined) result.readUnplaced.add(id); else result.readSites[site] = 1;
  result.code[i] = -1; result.start[i] = start; result.end[i] = start;
  const lon = site === undefined ? NaN : sites.lon[site], lat = site === undefined ? NaN : sites.lat[site];
  [result.mx[i], result.my[i]] = placeOf(lon, lat);
}

// Classifies a batch in a free session. A session that runs out of memory is
// closed and the batch is classified again in another one.
async function classifyBatch(result, b, bytes) {
  const { opts, sites } = result.source;
  let s, out, t;
  for (;;) {
    s = await acquire();
    t = performance.now();
    try {
      await s.webR.FS.writeFile('/tmp/batch_species.tsv', new TextEncoder().encode(b.lines.join('\n') + '\n'));
      await s.webR.FS.writeFile('/tmp/batch_sites.tsv', new TextEncoder().encode(sitesTsv(sites, b.ids)));
      await prepareSites(s.webR, '/tmp/batch_sites.tsv', opts);
      out = JSON.parse(await s.webR.evalRString(`resy_page_batch("/tmp/batch_species.tsv", "/tmp/batch_sites.tsv", ${opts})`));
      break;
    } catch (e) {
      if (pool.length < 2 || !OUT_OF_MEMORY.test(cleanError(e))) { release(s); throw e; }
      console.warn('[resy] an R session ran out of memory; continuing with one session fewer', e);
      memoryCap = pool.length - 1;
      closeSession(s);
      resizePool();
    }
  }
  s.heapGB = out.heap / 2 ** 30;
  release(s);
  if (manualSessions === null) resizePool();
  const at = new Map(b.ids.map((id, k) => [id, b.first + k]));
  if (['id', 'code', 'candidates'].some((key) => !Array.isArray(out[key]) || out[key].length !== at.size) ||
      new Set(out.id).size !== at.size || out.id.some((id) => !at.has(id))) {
    throw new Error(`RESY returned different plot IDs for the batch starting with ${b.ids[0]}.`);
  }
  out.id.forEach((id, k) => {
    const i = at.get(id);
    const c = codeOf(result, out.code[k]);
    result.code[i] = c; result.counts[c]++;
    result.cands[i] = intern(result.candIndex, result.candLists, out.candidates[k]);
  });
  result.done += out.id.length;
  result.nObs += out.n_obs; result.unmatched += out.unmatched;
  for (const name of out.important ?? []) result.important.add(name);
  result.nImportant += out.n_important ?? 0;
  for (const w of out.warnings) result.warnings.add(w);
  mergeSiteCounts(result.sites, out.sites);
  result.completedBytes += bytes;
  return (performance.now() - t) / 1000;
}

function showBatchProgress(result, active) {
  const share = result.completedBytes / result.source.blob.size;
  const seconds = (performance.now() - result.t0) / 1000;
  const left = share > 0.01 ? seconds * (1 - share) / share : null;
  setProgress(share);
  if (active && share < 1) status(`Classified ${plural(result.done, 'plot')} · ${formatTime(seconds)}${left === null ? '' : ` · about ${formatTime(left)} left`}`);
}

function mergeSiteCounts(total, batch) {
  total.matched += batch.matched;
  total.absent += batch.absent;
  for (const column of batch.present) total.present.add(column);
  for (const { column, n } of batch.missing) total.missing.set(column, (total.missing.get(column) ?? 0) + n);
  for (const { column, located, matched } of batch.maps) {
    const counts = total.maps.get(column) ?? { located: 0, matched: 0 };
    counts.located += located;
    counts.matched += matched;
    total.maps.set(column, counts);
  }
}

function siteNotes({ sites, system, warnings }) {
  const notes = new Set(warnings);
  const absent = system.header_cols.filter((c) => !sites.present.has(c));
  if (absent.length) {
    let text = `Rules read site columns that the sites file does not have: ${absent.join(', ')}. A condition on such a column is evaluated with the value 0.`;
    const altitude = [...notes].find((w) => w.startsWith('"Altitude (m)" is missing.'));
    if (altitude && absent.includes('Altitude (m)')) {
      notes.delete(altitude);
      text += ' The article "Get altitude data" shows how to add the altitude.';
    }
    notes.add(text);
  }
  if (sites.absent) notes.add(`${plural(sites.absent, 'plot')} had no matching row in the sites file (${fmt(sites.matched)} matched).`);
  const missing = [...sites.missing].filter(([col, n]) => n > 0 && sites.present.has(col));
  if (missing.length) notes.add(`Site columns read by rules have missing values: ${missing.map(([c, n]) => `${c} (${plural(n, 'plot')})`).join(', ')}. Conditions on them are evaluated as if the value were 0.`);
  for (const [column, { located, matched }] of sites.maps) {
    if (located === matched) continue;
    const map = column === 'Ecoreg' ? 'ecoregion' : 'country';
    if (matched === 0) notes.add(`No site with coordinates falls inside the ${map} base map. Check that longitude and latitude are WGS84 degrees.`);
    else {
      const outside = located - matched;
      notes.add(`${plural(outside, 'plot')} with coordinates ${outside === 1 ? 'falls' : 'fall'} outside the ${map} base map. ${column} is missing for ${outside === 1 ? 'that plot' : 'those plots'}.`);
    }
  }
  return [...notes];
}

const formatTime = (s) => s < 90 ? `${s.toFixed(s < 10 ? 1 : 0)} s` : s < 5400 ? `${Math.round(s / 60)} min` : `${(s / 3600).toFixed(1)} h`;
function setProgress(f) {
  const percent = Math.min(100, Math.floor(10000 * f) / 100);
  $('progress-bar').style.width = `${percent}%`;
  $('progress').setAttribute('aria-valuenow', String(percent));
}

// ---- Rendering ---------------------------------------------------------------
const cssVar = (name) => cssValue($('resy-app'), name);
const nameOf = (code) => code === '?' ? 'Not classified' : code === '+' ? 'Tie between types' : (R?.typeNames.get(code) ?? '');
// typeOrder: the types of a system other than EUNIS-ESy, most frequent first,
// which get the colours (see colourVar()); null colours by habitat group.
let typeOrder = null, filterType = null, selected = null;
const colourOf = (code) => cssVar(colourVar(code, typeOrder));

function render() {
  const count = (c) => R.counts[R.codeIndex.get(c)] ?? 0;
  $('s-plots').textContent = fmt(R.done);
  $('s-class').textContent = fmt(R.done - count('?') - count('+'));
  $('s-none').textContent = fmt(count('?'));
  $('s-tie').textContent = fmt(count('+'));
  $('s-system').innerHTML = `${R.incomplete ? '<strong>Incomplete classification.</strong> ' : ''}Classified with the ${escapeHtml(systemLabel(R.system))} expert system${R.system.doi ? ` (<a href="https://doi.org/${escapeHtml(R.system.doi)}">doi:${escapeHtml(R.system.doi)}</a>)` : ''}.`;

  const notes = siteNotes(R);
  if (R.unmatched) {
    const important = [...R.important].sort();
    const shown = important.slice(0, 10).join(', ') + (important.length > 10 ? ', …' : '');
    notes.unshift(`Species names in ${fmt(R.unmatched)} of ${fmt(R.nObs)} records count for no taxon of the expert system and do not contribute to the classification.`
      + (important.length ? ` ${fmt(important.length)} of these names may matter (${plural(R.nImportant, 'record')}): ${shown}. Check their spelling or determination.` : ''));
  }
  $('warnings').innerHTML = notes.map((w) => `<li>${escapeHtml(w)}</li>`).join('');
  $('notes-n').textContent = `${plural(notes.length, 'note')} on the data and the run`;
  $('notes').style.visibility = notes.length ? '' : 'hidden';

  renderLegend();
  renderTypes();
  dots.redraw();
  const searchableTypes = R.codes.map((code) => `${code} ${nameOf(code)}`.toLowerCase());
  R.search = R.ids.map((id, i) => R.code[i] < 0 ? '' : `${id.toLowerCase()} ${searchableTypes[R.code[i]]}`);
  filterTable();
  $('download').disabled = !R.done;
  $('download-map').disabled = !R.done;
}

// The colours on the map and their labels, for the legend under the map and
// the one in the downloaded SVG. EUNIS-ESy types are coloured by habitat
// group; other systems colour their most frequent types.
function legendItems() {
  const levels = new Map(R.system.levels.map((l) => [l.code, l.name]));
  const used = R.codes.map((c, k) => [c, R.counts[k]]).filter(([, n]) => n > 0);
  const unclassified = { colour: colourOf('?'), label: 'not classified or tie' };
  if (R.system.eunis) {
    typeOrder = null;
    const present = [...new Set(used.map(([c]) => (c === '?' || c === '+') ? 'none' : level(c)))].sort();
    return present.map((l) => l === 'none' ? unclassified : { colour: colourOf(l), label: [l, levels.get(l)].filter(Boolean).join(' ') });
  }
  const ranked = used.filter(([c]) => c !== '?' && c !== '+').sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0])).map(([c]) => c);
  typeOrder = ranked;
  return [
    ...ranked.slice(0, PALETTE.length).map((c) => ({ colour: colourOf(c), label: [c, levels.get(c)].filter(Boolean).join(' ') })),
    ...(ranked.length > PALETTE.length ? [{ colour: cssVar('--lv-other'), label: 'other types' }] : []),
    ...(used.some(([c]) => c === '?' || c === '+') ? [unclassified] : []),
  ];
}

function renderLegend() {
  $('legend').innerHTML = legendItems().map((l) => `<span><i style="background:${l.colour}"></i>${escapeHtml(l.label)}</span>`).join('');
}

function renderTypes() {
  const focus = document.activeElement.closest('#types button')?.dataset.code;
  const list = R.codes.map((c, k) => ({ code: c, n: R.counts[k] })).filter((t) => t.n > 0)
    .sort((a, b) => b.n - a.n || a.code.localeCompare(b.code));
  const max = list[0]?.n ?? 1;
  $('types').innerHTML = list.map((t) => `
    <li><button type="button" data-code="${escapeHtml(t.code)}" aria-pressed="${t.code === filterType}" class="${t.code === filterType ? 'active' : ''}" title="${escapeHtml(nameOf(t.code))}">
      <span class="sw" style="background:${colourOf(t.code)}"></span>
      <b>${escapeHtml(t.code)}</b>
      <span class="mid"><span class="nm">${escapeHtml(nameOf(t.code))}</span><span class="bar" style="width:${(100 * t.n / max).toFixed(1)}%"></span></span>
      <span>${fmt(t.n)}</span>
    </button></li>`).join('');
  $('clear-filter').disabled = filterType === null;
  if (focus) [...$('types').querySelectorAll('button')].find((b) => b.dataset.code === focus)?.focus({ preventScroll: true });
}

const tableWrap = $('rows').closest('.tablewrap');
const MAX_SCROLL_HEIGHT = 8000000;
let table = null;

function filterTable() {
  if (!R || running) return;
  const q = $('q').value.trim().toLowerCase();
  const want = filterType === null ? null : R.codeIndex.get(filterType);
  const rows = [];
  const narrowed = table?.type === want && q.startsWith(table.query) ? table.rows : null;
  const n = narrowed?.length ?? R.n;
  for (let j = 0; j < n; j++) {
    const i = narrowed ? narrowed[j] : j;
    const c = R.code[i];
    if (c < 0 || (want !== null && c !== want)) continue;
    if (q && !R.search[i].includes(q)) continue;
    rows.push(i);
  }
  table = { rows, query: q, type: want, focus: null, reveal: null, width: tableWrap.clientWidth };
  resetRowHeights();
  tableWrap.scrollTop = 0;
  $('rows').parentElement.setAttribute('aria-rowcount', String(rows.length + 1));
  $('shown').textContent = `${fmt(rows.length)} of ${plural(R.done, 'plot')}${filterType ? ` · type ${filterType}` : ''}`;
  renderTable();
}

// A Fenwick tree of measured differences from the estimated row height.
// Unmounted rows keep their height, and wrapped text needs no fixed line count.
function resetRowHeights() {
  table.estimate = parseFloat(getComputedStyle(tableWrap).getPropertyValue('--row-height'));
  table.corrections = new Float64Array(table.rows.length + 1);
  table.heights = new Map();
  table.range = null;
}

function rowOffset(count) {
  let sum = count * table.estimate;
  for (let i = count; i > 0; i -= i & -i) sum += table.corrections[i];
  return sum;
}

function rowAt(pixel) {
  let row = 0;
  for (let bit = 2 ** Math.floor(Math.log2(table.rows.length || 1)); bit >= 1; bit /= 2) {
    const next = row + bit;
    if (next > table.rows.length) continue;
    const height = bit * table.estimate + table.corrections[next];
    if (height <= pixel) { row = next; pixel -= height; }
  }
  return row;
}

const tableViewport = () => tableWrap.clientHeight - $('rows').previousElementSibling.offsetHeight;

function tableScroll() {
  const height = rowOffset(table.rows.length), viewport = tableViewport();
  const physical = Math.min(height, MAX_SCROLL_HEIGHT);
  const factor = height > physical ? (height - viewport) / (physical - viewport) : 1;
  return { height, physical, viewport, factor };
}

const rowSizes = new ResizeObserver((entries) => {
  if (!table || running) return;
  const { height, viewport, factor } = tableScroll();
  const top = tableWrap.scrollTop * factor;
  const anchor = rowAt(top), before = rowOffset(anchor);
  const reveal = table.reveal;
  table.reveal = null;
  let changed = false;
  for (const { target } of entries) {
    if (!target.isConnected) continue;
    const row = Number(target.dataset.row), height = target.getBoundingClientRect().height;
    const diff = height - (table.heights.get(row) ?? table.estimate);
    if (!height || Math.abs(diff) < 0.01) continue;
    table.heights.set(row, height);
    for (let i = row + 1; i < table.corrections.length; i += i & -i) table.corrections[i] += diff;
    changed = true;
  }
  if (!changed) return;
  let next = top + rowOffset(anchor) - before;
  if (top > 0 && top + viewport >= height - factor) next = rowOffset(table.rows.length) - viewport;
  if (reveal !== null) next = keepRowVisible(reveal, next, viewport);
  renderTable(true, next);
});

function renderTable(force = false, top = null) {
  if (!table || running) return;
  const { rows } = table;
  if (!rows.length) {
    rowSizes.disconnect();
    $('rows').innerHTML = '<tr><td colspan="4" class="empty-table">No plots match. Clear the search or choose Show all types.</td></tr>';
    return;
  }
  const { height, physical, viewport, factor } = tableScroll();
  top = Math.max(0, Math.min(top ?? tableWrap.scrollTop * factor, height - viewport));
  const visible = Math.min(rows.length - 1, rowAt(top));
  const first = Math.max(0, visible - 3);
  const last = Math.min(rows.length, rowAt(top + viewport) + 4);
  const focused = document.activeElement.closest('#rows tr[data-row]');
  const pin = focused ? table.focus : null;
  const tab = pin ?? (table.focus !== null && table.focus >= first && table.focus < last ? table.focus : visible);
  const range = `${first}:${last}:${pin}:${tab}${factor === 1 ? '' : `:${top}`}`;
  if (!force && range === table.range) return;
  table.range = range;
  rowSizes.disconnect();
  const mount = rows.slice(first, last).map((_, i) => first + i);
  if (pin !== null && pin < first) mount.unshift(pin);
  if (pin !== null && pin >= last) mount.push(pin);
  // The visible window stays in CSS pixels. Only the spacers compress when
  // the logical row heights exceed the browser's scrollable range.
  const begin = rowOffset(first), end = rowOffset(last);
  const offset = Math.max(0, Math.min(top / factor + begin - top, physical - (end - begin)));
  const after = offset + end - begin;
  const gap = (size) => size > 0.01 ? `<tr class="row-gap" aria-hidden="true"><td colspan="4" style="height:${size}px"></td></tr>` : '';
  let previous = 0;
  const html = mount.map((row) => {
    const i = rows[row], code = R.codes[R.code[i]], at = rowOffset(row);
    const rowHeight = rowOffset(row + 1) - at;
    let px = offset + at - begin;
    if (row < first) px = Math.min(offset - rowHeight, at / begin * offset);
    if (row >= last) px = Math.min(physical - rowHeight, after + (at - end) / (height - end) * (physical - after));
    const spacer = gap(px - previous);
    previous = Math.max(px, previous) + rowHeight;
    return `${spacer}<tr data-i="${i}" data-row="${row}" aria-rowindex="${row + 2}" class="${i === selected ? 'table-active' : ''}">
      <td><button type="button" class="plot-button" tabindex="${row === tab ? 0 : -1}" aria-label="Explain plot ${escapeHtml(R.ids[i])}" aria-pressed="${i === selected}">${escapeHtml(R.ids[i])}</button></td>
      <td><b>${escapeHtml(code)}</b></td><td>${escapeHtml(nameOf(code))}</td><td class="num">${R.nsp[i] || ''}</td></tr>`;
  });
  $('rows').innerHTML = html.join('') + gap(physical - previous);
  tableWrap.scrollTop = top / factor;
  for (const row of $('rows').querySelectorAll('[data-row]')) rowSizes.observe(row);
  if (pin !== null) $('rows').querySelector(`[data-row="${pin}"] button`)?.focus({ preventScroll: true });
}

tableWrap.addEventListener('scroll', () => renderTable(), { passive: true });
new ResizeObserver(() => {
  if (!table || running) return;
  const width = tableWrap.clientWidth;
  if (table.width === width) { renderTable(); return; }
  const anchor = rowAt(tableWrap.scrollTop * tableScroll().factor);
  table.width = width;
  resetRowHeights();
  renderTable(true, rowOffset(anchor));
}).observe(tableWrap);

$('rows').addEventListener('focusin', (e) => {
  const row = e.target.closest('tr[data-row]');
  if (table && row) table.focus = Number(row.dataset.row);
});

const keepRowVisible = (row, top, viewport) => Math.min(rowOffset(row), Math.max(top, rowOffset(row + 1) - viewport));

$('rows').addEventListener('keydown', (e) => {
  const row = e.target.closest('tr[data-row]');
  if (!table || !row || !['ArrowUp', 'ArrowDown', 'Home', 'End'].includes(e.key)) return;
  e.preventDefault();
  const current = Number(row.dataset.row), last = table.rows.length - 1;
  const next = e.key === 'Home' ? 0 : e.key === 'End' ? last : Math.max(0, Math.min(last, current + (e.key === 'ArrowUp' ? -1 : 1)));
  const { viewport, factor } = tableScroll();
  table.focus = next;
  table.reveal = next;
  renderTable(true, keepRowVisible(next, tableWrap.scrollTop * factor, viewport));
});

// ---- Map ---------------------------------------------------------------------
// The classified plots as dots in the colour of their type (see resy_map.js).
// With a type chosen in the list, the plots of the other types are greyed out
// behind its plots.
const dots = createDotMap('map', () => {
  const want = filterType === null ? null : R.codeIndex.get(filterType);
  const colours = R ? R.codes.map(colourOf) : [], faded = cssVar('--lv-none');
  return {
    n: R?.n ?? 0,
    positions: R?.mx ?? null,
    shown: R?.done ?? 0,
    x: (i) => R.mx[i],
    y: (i) => R.my[i],
    state: (i) => { const k = R.code[i]; return k < 0 ? -1 : want === null || k === want ? 1 : 0; },
    colour: (i, front) => (front ? colours[R.code[i]] : faded),
    selected,
  };
}, (i) => explain(i));

// ---- Why this type? ------------------------------------------------------------
// The panel shows what RESY's resy_eval_plot() prints, as HTML (see
// resy_evidence.js). Selecting another type in a list shows its rule instead.
function clearDetail() {
  $('d-empty').hidden = false; $('d-body').hidden = true; $('d-title').textContent = 'Why this type?';
  $('d-body').innerHTML = '';
  $('d-body').inert = false;
  $('d-body').setAttribute('aria-busy', 'false');
  $('d-status').textContent = '';
}

let detailRequest = 0;
async function explain(i) {
  if (!R || running) return;
  const request = ++detailRequest;
  selected = i;
  for (const row of $('rows').querySelectorAll('tr[data-i]')) {
    const active = Number(row.dataset.i) === i;
    row.classList.toggle('table-active', active);
    row.querySelector('button').setAttribute('aria-pressed', String(active));
  }
  dots.draw();
  const code = R.codes[R.code[i]];
  const title = `Plot ${R.ids[i]}: ${code} ${nameOf(code)}`;
  $('d-status').textContent = `Evaluating plot ${R.ids[i]}…`;
  $('d-body').inert = true;
  $('d-body').setAttribute('aria-busy', 'true');
  if (getComputedStyle($('detail')).position !== 'sticky') $('detail').scrollIntoView({ block: 'nearest' });
  try {
    const ev = await evaluatePlot(i);
    if (request !== detailRequest) return;
    $('d-title').textContent = title;
    $('d-empty').hidden = true;
    $('d-body').hidden = false;
    $('d-body').innerHTML = evidenceHtml(ev, nameOf) + comparePickerHtml(ev);
    $('d-body').scrollTop = 0;
    $('d-status').textContent = '';
  } catch (e) {
    if (request === detailRequest) $('d-status').textContent = cleanError(e);
  } finally {
    if (request === detailRequest) {
      $('d-body').inert = false;
      $('d-body').setAttribute('aria-busy', 'false');
    }
  }
}

// Classifies plot i alone, from its rows of the species file, and returns
// resy_page_explain()'s account of it, with the rules of `type` in full.
const evaluatePlot = (i, type = null) => onPlot(i, (id, opts) =>
  `resy_page_explain("/tmp/explain_species.tsv", "/tmp/explain_sites.tsv", ${id}, ${opts}${type ? `, type = ${rString(type)}` : ''})`);

// ---- Two types side by side ----------------------------------------------------
// Under the evidence of a plot: type A of the system in use against type B of
// the same system or, for EUNIS-ESy, of another shipped release, for this plot
// (resy_page_compare(), drawn by compareHtml()). A starts at the plot's type, B
// at its closest sibling or lower level.
const typesOfRelease = new Map();     // release -> [{ code, name }] of its types
const releaseOf = () => R?.system.release_scheme === 'EUNIS' && R.system.version && (info?.eunis_versions?.length ?? 0) > 1 ? R.system.version : null;
const typeOptions = (types, chosen) => types.map((t) =>
  `<option value="${escapeHtml(t.code)}"${t.code === chosen ? ' selected' : ''}>${escapeHtml(t.code)} ${escapeHtml(t.name)}</option>`).join('');
const ownTypes = () => R.system.types.map((code) => ({ code, name: nameOf(code) }));

function comparePickerHtml(ev) {
  const own = ownTypes(), known = new Set(R.system.types);
  const a = known.has(ev.choice) ? ev.choice : (ev.holds?.find((h) => known.has(h.code))?.code ?? own[0]?.code);
  const near = [...(ev.siblings?.types ?? []), ...ev.lower.flatMap((lv) => lv.types ?? [])].map((t) => t.code);
  const b = near.find((c) => known.has(c) && c !== a) ?? own.find((t) => t.code !== a)?.code ?? a;
  const release = releaseOf();
  return `<section class="compare">
      <p class="h6 mt-3 mb-1">Compare two types</p>
      <div class="cmp-pick">
        <select class="form-select form-select-sm" data-cmp="a" aria-label="First type">${typeOptions(own, a)}</select>
        <span class="small">with</span>
        <select class="form-select form-select-sm" data-cmp="b" aria-label="Second type">${typeOptions(own, b)}</select>
        ${release ? `<select class="form-select form-select-sm" data-cmp="release" aria-label="Release of the second type">${info.eunis_versions.map((v) =>
          `<option value="${escapeHtml(v)}"${v === release ? ' selected' : ''}>${escapeHtml(v)}${v === release ? ' (this classification)' : ''}</option>`).join('')}</select>` : ''}
        <button type="button" class="btn btn-outline-primary btn-sm" data-cmp="go">Compare</button>
      </div>
      <div class="cmp-out" aria-busy="false"><p class="small text-body-secondary">Choose two types and select Compare to see, condition by condition, how this plot meets the rule of each.</p></div>
    </section>`;
}

let compareRequest = 0;
async function runCompare(section) {
  const i = selected, token = detailRequest, request = ++compareRequest;
  const pick = (k) => section.querySelector(`[data-cmp="${k}"]`)?.value;
  const a = pick('a'), b = pick('b'), version = pick('release');
  const versionB = version && version !== R.system.version ? version : null;
  const out = section.querySelector('.cmp-out');
  const active = () => token === detailRequest && request === compareRequest && out.isConnected;
  out.setAttribute('aria-busy', 'true');
  $('d-status').textContent = `Comparing ${a} with ${b}${versionB ? ` of ${versionB}` : ''}…`;
  try {
    const cmp = await onPlot(i, (id, opts) =>
      `resy_page_compare("/tmp/explain_species.tsv", "/tmp/explain_sites.tsv", ${id}, ${opts}, a = ${rString(a)}, b = ${rString(b)}${versionB ? `, version_b = ${rString(versionB)}` : ''})`);
    if (!active()) return;
    out.innerHTML = compareHtml(cmp);
    $('d-status').textContent = '';
  } catch (e) {
    if (active()) $('d-status').textContent = cleanError(e);
  } finally {
    if (active()) out.setAttribute('aria-busy', 'false');
  }
}

// The types of the release chosen for B; the type chosen stays if that
// release defines it.
async function changeRelease(section) {
  const token = detailRequest;
  const version = section.querySelector('[data-cmp="release"]').value;
  const select = section.querySelector('[data-cmp="b"]');
  let types = version === R.system.version ? ownTypes() : typesOfRelease.get(version);
  if (!types) {
    select.disabled = true;
    $('d-status').textContent = `Reading the types of EUNIS-ESy ${version}…`;
    const s = await acquire();
    try {
      types = JSON.parse(await s.webR.evalRString(`resy_page_types(${rString(version)})`));
      typesOfRelease.set(version, types);
    } catch (e) {
      if (token === detailRequest) $('d-status').textContent = cleanError(e);
      return;
    } finally {
      release(s);
      select.disabled = false;
    }
  }
  if (token !== detailRequest) return;
  const keep = types.some((t) => t.code === select.value) ? select.value : types[0]?.code;
  select.innerHTML = typeOptions(types, keep);
  $('d-status').textContent = '';
}

$('d-body').addEventListener('click', (e) => {
  const go = e.target.closest('[data-cmp="go"]');
  if (go) runCompare(go.closest('.compare'));
});
$('d-body').addEventListener('change', (e) => {
  const section = e.target.closest('.compare');
  if (!section) return;
  if (e.target.dataset.cmp === 'release') changeRelease(section);
});

// Runs the R call `call(id, opts)` (`id` the plot's identifier and `opts` the
// site options, both as R code) on plot i alone, written from its rows of the
// species file, and returns its JSON parsed.
async function onPlot(i, call) {
  const result = R, src = result.source;
  const lines = [src.header];
  for await (const chunk of lineChunks(src.blob, src.delim, result.start[i], result.end[i])) {
    for (const line of chunk.lines) {
      if (!line) continue;
      const f = splitFields(line, src.delim);
      lines.push(speciesTsvRow(f, src.col, plotId(f[src.col.id])));
    }
  }
  const s = await acquire();
  try {
    if (result !== R) throw new Error('The input changed. Select a plot from the new results.');
    await s.webR.FS.writeFile('/tmp/explain_species.tsv', new TextEncoder().encode(lines.join('\n') + '\n'));
    await s.webR.FS.writeFile('/tmp/explain_sites.tsv', new TextEncoder().encode(sitesTsv(src.sites, [result.ids[i]])));
    await prepareSites(s.webR, '/tmp/explain_sites.tsv', src.opts);
    return JSON.parse(await s.webR.evalRString(call(rString(result.ids[i]), src.opts)));
  } finally {
    release(s);
  }
}

// ---- Download --------------------------------------------------------------------
function download() {
  if (!R) return;
  const q = (v) => /[",\n]/.test(v) ? `"${v.replace(/"/g, '""')}"` : v;
  const sys = `${q(String(R.system.release_scheme ?? R.system.scheme))},${q(String(R.system.version ?? ''))}`;
  const parts = ['plot_id,classification,classification_name,candidates,expert_system,expert_version\n'];
  let block = [];
  for (let i = 0; i < R.n; i++) {
    if (R.code[i] < 0) continue;
    const code = R.codes[R.code[i]];
    block.push(`${q(R.ids[i])},${q(code)},${q(nameOf(code))},${q(R.candLists[R.cands[i]])},${sys}\n`);
    if (block.length === 50000) { parts.push(block.join('')); block = []; }
  }
  parts.push(block.join(''));
  saveResult(new Blob(parts, { type: 'text/csv' }), 'classification.csv');
}

function saveResult(blob, suffix, result = R) {
  saveBlob(blob, `resy_${systemLabel(result?.system ?? system.info).replace(/\.(json|txt)$/i, '').replace(/[^A-Za-z0-9_-]/g, '_')}_${result?.incomplete ? 'incomplete_' : ''}${suffix}`);
}

// The map as it is shown, as an SVG: the country outlines, the plots in their
// colours, the selected plot and the legend. Plots that fall on the same spot
// in the same colour are drawn once, and each colour is one path of round dots,
// so the file stays small with millions of plots.
async function downloadMap() {
  if (!R || !dots.map) return;
  const button = $('download-map');
  button.disabled = true;
  button.textContent = 'Preparing map…';
  status('Preparing the map download…');
  try {
    const result = R;
    const v = dots.view(), W = v.size.x, H = v.size.y;
    const faded = cssVar('--lv-none');
    const spots = new Map();
    dots.eachDot(v, (x, y, i, front) => {
      const key = front ? colourOf(R.codes[R.code[i]]) : 'faded';
      if (!spots.has(key)) spots.set(key, new Set());
      spots.get(key).add(`${x.toFixed(1)} ${y.toFixed(1)}`);
    });
    const r = dots.radius();
    const items = legendItems();
    const p = dots.selectedPixel(v);
    const s = await acquire();
    let land;
    try {
      await ensureGeography(s.webR);
      land = JSON.parse(await s.webR.evalRString(`resy_page_land(${v.scale}, ${v.ox}, ${v.oy}, ${W}, ${H})`));
    } finally {
      release(s);
    }
    const total = H + 12 + 16 * items.length + 6;
    const svg = [
      `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${total}" viewBox="0 0 ${W} ${total}" font-family="Helvetica, Arial, sans-serif">`,
      `<rect width="${W}" height="${total}" fill="#fff"/>`,
      `<clipPath id="view"><rect width="${W}" height="${H}"/></clipPath>`,
      `<g clip-path="url(#view)">`,
      `<rect width="${W}" height="${H}" fill="#e6edf2"/>`,
      `<g fill="#fbfbf8" stroke="#9aa4ad" stroke-width="0.6" stroke-linejoin="round" fill-rule="evenodd">${land.paths.map((d) => `<path d="${d}"/>`).join('')}</g>`,
      `<g fill="none" stroke-linecap="round" stroke-width="${2 * r}">`,
      ...[...spots].map(([key, set]) => `<path stroke="${key === 'faded' ? faded : key}" stroke-opacity="${key === 'faded' ? 0.43 : 0.92}" d="${[...set].map((p) => `M${p}h0`).join('')}"/>`),
      '</g>',
    ];
    if (p && p[0] >= 0 && p[1] >= 0 && p[0] <= W && p[1] <= H) {
      svg.push(`<circle cx="${p[0].toFixed(1)}" cy="${p[1].toFixed(1)}" r="${r + 5}" fill="none" stroke="#000" stroke-width="2"/>`);
    }
    svg.push(`<text x="${W - 6}" y="${H - 6}" font-size="9" fill="#6b7178" text-anchor="end">Country borders: Eurostat GISCO</text>`,
      '</g>',
      `<g transform="translate(0 ${H + 12})" font-size="11">`,
      ...items.map((l, k) => `<circle cx="6" cy="${4 + 16 * k}" r="4" fill="${l.colour}"/><text x="16" y="${8 + 16 * k}" fill="#333">${escapeHtml(l.label)}</text>`),
      '</g>',
      '</svg>');
    saveResult(new Blob([svg.join('\n')], { type: 'image/svg+xml' }), 'map.svg', result);
    status('Map download ready.', 'idle');
  } catch (e) {
    console.error(e);
    status(cleanError(e), 'error');
  } finally {
    button.disabled = false;
    button.textContent = 'Download map (SVG)';
  }
}

// ---- Example data ------------------------------------------------------------------
// The example CSVs are put into the file inputs as File objects, so the inputs
// show their names and a chosen file simply replaces one of them.
const examples = { files: null };
const DATA_INPUTS = ['f-species', 'f-sites'];
const isExample = (i) => $(DATA_INPUTS[i]).files[0] === examples.files?.[i];

async function loadExamples(s) {
  const paths = await s.webR.evalRRaw('resy_page_examples()', 'string[]');
  examples.files = await Promise.all(paths.map(async (p) =>
    new File([await s.webR.FS.readFile(p)], p.split('/').at(-1), { type: 'text/csv' })));
}

async function resetData() {
  invalidateResults();
  DATA_INPUTS.forEach((id, i) => setFile($(id), examples.files[i]));
  await describeSpecies();
  status('Example files selected.', 'idle');
}

// An empty field lets the page choose the number of sessions.
$('o-sessions').addEventListener('change', () => {
  const v = $('o-sessions').value.trim();
  manualSessions = v === '' ? null : Math.max(1, Math.min(8, Math.round(Number(v)) || 1));
  $('o-sessions').value = manualSessions ?? '';
  if (pool.length) resizePool();
  else showSessions();
});
showSessions();
$('run').addEventListener('click', run);
$('download').addEventListener('click', download);
$('download-map').addEventListener('click', downloadMap);
$('q').addEventListener('input', filterTable);
$('rows').addEventListener('click', (e) => { const tr = e.target.closest('tr[data-i]'); if (tr) explain(Number(tr.dataset.i)); });
wireEvidence($('d-body'), (type) => evaluatePlot(selected, type), () => detailRequest,
  { retain: true, report: (text) => { $('d-status').textContent = text; } });
$('types').addEventListener('click', (e) => {
  const button = e.target.closest('button'); if (!button) return;
  filterType = filterType === button.dataset.code ? null : button.dataset.code;
  renderTypes(); filterTable(); dots.draw();
});
$('clear-filter').addEventListener('click', () => {
  filterType = null; renderTypes(); filterTable(); dots.draw();
  $('q').focus({ preventScroll: true });
});
for (const id of DATA_INPUTS) $(id).addEventListener('change', async () => {
  invalidateResults();
  try {
    if (id === 'f-species') await describeSpecies();
    updateReadiness();
    status('Data changed. Classify to update the results.', 'idle');
  } catch (e) { status(cleanError(e), 'error'); }
});
for (const id of [...SPECIES_COLS.map(([, id]) => id), 'o-coast', 'o-buffer']) $(id).addEventListener('change', () => { invalidateResults(); updateReadiness(); });
$('o-coast').addEventListener('change', () => { $('o-buffer').disabled = !$('o-coast').checked; });
$('reset-data').addEventListener('click', resetData);
for (const [kind, header] of Object.entries({ species: 'PlotObservationID,scientificName,Cover_Perc', sites: 'PlotObservationID,Longitude,Latitude' })) {
  $(`template-${kind}`).addEventListener('click', () => saveBlob(new Blob([header + '\n'], { type: 'text/csv' }), `resy_${kind}_template.csv`));
}
$('f-expert').addEventListener('change', () => { document.querySelector('input[name=system][value=file]').checked = true; onSystemChange(); });
for (const el of document.querySelectorAll('input[name=system]')) el.addEventListener('change', () => onSystemChange());
$('eunis-version').addEventListener('change', () => { document.querySelector('input[name=system][value=EUNIS]').checked = true; onSystemChange(); });
$('to-maker').addEventListener('click', (e) => openInMaker(e).catch((error) => status(cleanError(error), 'error')));

$('retry-start').addEventListener('click', () => location.reload());
start().catch((e) => {
  status(`R could not start: ${e.message ?? e}`, 'error');
  $('retry-start').hidden = false;
  shell.failed(e);
});
