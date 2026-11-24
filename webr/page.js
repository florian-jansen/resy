// Runs RESY in webR for vignettes/articles/app.Rmd. The bundle and the R
// helpers sit next to this script; pkgdown/build_webr_bundle.R builds the bundle.
// The data files are read here in parts and classified in batches of whole
// plots, spread over several webR sessions, so files of any size can be used.
import { $, escapeHtml, rString, cleanError, fmt, plural, createLoader, fetchAssets, bootSession, setFile, saveBlob, store, createShell, pinNavbar, prepareSites, ensureGeography } from './resy_core.js';
import { lineChunks, splitFields, readHeader, pick, SPECIES_COLS, SPECIES_COL_LABEL, fillSpeciesColumns, tsvValue } from './resy_files.js';
import { evidenceHtml, wireEvidence } from './resy_evidence.js';
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
async function applySystem(s, first = false) {
  if (s.key === system.key) return s.info;
  if (system.file) {
    await s.webR.evalRVoid('dir.create("/tmp/upload", showWarnings = FALSE)');
    await s.webR.FS.writeFile(system.file.path, system.file.bytes);
  }
  if (first) { status('Reading the expert system…'); stage('parse'); }
  const out = JSON.parse(await s.webR.evalRString(system.call));
  s.key = system.key;
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
async function acquire() {
  const free = pool.find((s) => !s.busy);
  const s = free ?? await new Promise((resolve) => waiting.push(resolve));
  s.busy = true;
  try {
    await applySystem(s);
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
  await chooseSystem();
  const first = await startSession(true, session);
  await describeSystem(first);
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
function adopt(handed) {
  setFile($('f-expert'), new File([handed.text], handed.name, { type: 'application/json' }));
  document.querySelector('input[name=system][value=file]').checked = true;
}
async function adoptHandoff() {
  if (location.hash !== '#from-maker') return;
  const handed = await store.get('to-app');
  if (handed) adopt(handed);
}
// The RESY Maker shares the window with this page (see createShell()); an
// expert system it hands over is chosen here as an uploaded file is.
const shell = createShell('app', async (handed) => {
  adopt(handed);
  await onSystemChange();
  $('sys-h').scrollIntoView({ block: 'nearest' });
});

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

async function chooseSystem() {
  const v = systemChoice();
  if (v !== 'file') {
    const version = v === 'EUNIS' ? $('eunis-version').value : '';
    system = {
      key: `${v}:${version}`,
      call: `resy_page_set_expert(scheme = ${rString(v)}${version ? `, version = ${rString(version)}` : ''})`,
      file: null,
      info: null,
    };
    return;
  }
  const f = $('f-expert').files[0];
  if (!/\.(json|txt)$/i.test(f.name)) throw new Error('The expert system file must end in .json or .txt.');
  const path = `/tmp/upload/${f.name.replace(/[^A-Za-z0-9._-]/g, '_')}`;
  system = {
    key: `file:${f.name}:${f.size}:${f.lastModified}`,
    call: `resy_page_set_expert(path = ${rString(path)})`,
    file: { path, bytes: new Uint8Array(await f.arrayBuffer()) },
    info: null,
  };
}

// Reads the expert system in one session and describes it under the choices.
async function describeSystem(s) {
  if (loader.done) status('Reading the expert system…');
  let out;
  try {
    out = await applySystem(s, !loader.done);
  } catch (e) {
    $('sys-info').className = 'small mt-3 mb-0 error';
    $('sys-info').textContent = cleanError(e);
    system = null;
    throw e;
  }
  system.info = out;
  described.set(system.key, out);
  showSystem(out);
}
// The description of each system read so far, by its key: choosing a system
// again shows its description at once, while a session takes it up.
const described = new Map();
function showSystem(out) {
  $('eunis-opts').disabled = !out.eunis;
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
async function onSystemChange() {
  if (!pool.length || running || configuring) return;
  invalidateResults();
  $('run').disabled = true;
  if (systemChoice() === 'file' && !$('f-expert').files[0]) {
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
  try {
    await chooseSystem();
    if (described.has(system.key)) showSystem(described.get(system.key));
    const s = await acquire();
    try { await describeSystem(s); } finally { release(s); }
    status('Expert system ready.', 'idle');
  } catch (e) {
    system = null;
    $('sys-info').className = 'small mt-3 mb-0 error';
    $('sys-info').textContent = cleanError(e);
    $('eunis-opts').disabled = true;
    status(cleanError(e), 'error');
  } finally {
    configuring = false;
    $('system-panel').inert = false;
    $('sys-info').setAttribute('aria-busy', 'false');
    updateReadiness();
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
  $('run').disabled = !loader.done || configuring || !system?.info || !files || !columns;
  $('data-note').textContent = !files ? 'Choose both files to begin, or try the example data.' :
    !columns ? 'Choose the plot, species and cover columns to continue.' :
    DATA_INPUTS.every((_, i) => isExample(i)) ? 'Example ready: 200 plots from Tuscany. Check the columns, then classify.' :
    'Files selected. Check the column choices, then classify.';
}

function invalidateResults() {
  clearTimeout(renderTimer); renderTimer = null;
  R = null; selected = null; filterType = null;
  detailRequest++;
  $('results').hidden = true;
  $('q').value = '';
  clearDetail();
}

// Plot positions and the site columns the expert system reads, kept compactly
// (repeated values such as country names are stored once).
async function readSites(file, wanted, onProgress) {
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
  for await (const chunk of lineChunks(file)) {
    for (const line of chunk.lines) {
      if (first) { first = false; continue; }
      if (!line) continue;
      const f = splitFields(line, delim);
      store.index.set(f[iId], store.lon.length);
      store.lon.push(iLon >= 0 ? parseFloat(f[iLon]) : NaN);
      store.lat.push(iLat >= 0 ? parseFloat(f[iLat]) : NaN);
      extra.forEach(([, i], k) => {
        const d = store.dicts[k], v = f[i] ?? '';
        let code = d.map.get(v);
        if (code === undefined) { code = d.values.length; d.map.set(v, code); d.values.push(v); }
        store.codes[k].push(code);
      });
    }
    onProgress?.(chunk.end / file.size);
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
    rows.push([tsvValue(id), num(store.lon[r]), num(store.lat[r]), ...store.codes.map((c, k) => tsvValue(store.dicts[k].values[c[r]]))].join('\t'));
  }
  return rows.join('\n') + '\n';
}

// A species file whose rows are not grouped by plot is sorted in memory when
// it is small; a large file has to come grouped (as EVA and Turboveg exports do).
const SORT_LIMIT = 64 * 1024 * 1024;
async function groupedSpecies(file, delim, iId) {
  if (file.size > SORT_LIMIT) return file;
  const lines = (await file.text()).replace(/^﻿/, '').split(/\r?\n/);
  const head = lines.shift();
  const rows = lines.filter(Boolean).map((l, i) => ({ l, id: splitFields(l, delim)[iId], i }));
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
    nObs: 0, unmatched: 0, warnings: new Set(), missing: new Map(), done: 0, t0: performance.now(), seconds: 0,
  };
  for (const [k, T] of Object.entries(COLUMNS)) r[k] = new T(Math.max(1024, capacity));
  return r;
}
function growResults() {
  for (const [k, T] of Object.entries(COLUMNS)) {
    const a = new T(2 * R[k].length);
    a.set(R[k]);
    R[k] = a;
  }
}
const intern = (index, list) => (v) => {
  let k = index.get(v);
  if (k === undefined) { k = list.length; index.set(v, k); list.push(v); }
  return k;
};
const codeOf = (c) => {
  const k = intern(R.codeIndex, R.codes)(c);
  if (R.counts.length < R.codes.length) R.counts.push(0);
  return k;
};
const candOf = (c) => intern(R.candIndex, R.candLists)(c);

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
  $('run').textContent = 'Stop';
  $('progress').hidden = false;
  setProgress(0);
  const inFlight = new Set();
  try {
    if (!system?.info) throw new Error('Choose an expert system first.');
    const sp = $('f-species').files[0], si = $('f-sites').files[0];
    if (!sp) throw new Error('Choose a species file.');
    if (!si) throw new Error('Choose a sites file.');
    const coast = $('o-coast').checked ? 'TRUE' : 'FALSE';
    if (!$('o-buffer').checkValidity()) throw new Error('Enter a coast buffer of zero or more metres, in steps of 500.');
    const buffer = Number($('o-buffer').value) || 0;
    const opts = `coast_dunes = ${coast}, coast_buffer = ${buffer}`;

    const { delim, cols } = await readHeader(sp);
    const col = Object.fromEntries(SPECIES_COLS.map(([key, id]) => [key, cols.indexOf($(id).value)]));
    for (const [key] of SPECIES_COLS) if (col[key] < 0) throw new Error(`Choose the ${SPECIES_COL_LABEL[key]} column of the species file.`);

    status('Reading the sites file…');
    const wanted = [...new Set([...system.info.header_cols.filter((c) => !system.info.derived_cols.includes(c)), ...(system.info.eunis ? ['Country', 'Altitude (m)'] : [])])];
    const sites = await readSites(si, wanted, (f) => setProgress(0.02 * f));
    const source = await groupedSpecies(sp, delim, col.id);
    R = newResults({ blob: source, delim, col, sites, opts }, sites.lon.length);
    R.system = system.info;
    R.typeNames = new Map(R.system.names.map((t) => [t.code, t.name]));
    filterType = null; selected = null;
    const firstRun = $('results').hidden;
    $('results').hidden = false;
    if (firstRun) render(true);
    clearDetail();

    let target = 1000;
    const newBatch = () => ({ lines: ['PlotObservationID\tname\tcover'], ids: [], first: R.n });
    let batch = newBatch();
    let current = null, rowsOfCurrent = 0;
    const finishPlot = (end) => {
      if (current === null) return;
      R.end[R.n - 1] = end;
      R.nsp[R.n - 1] = rowsOfCurrent;
    };
    const dispatch = (bytes) => {
      const b = batch;
      batch = newBatch();
      const job = classifyBatch(b, opts, bytes / source.size).then((seconds) => {
        target = Math.max(250, Math.min(MAX_BATCH, Math.round(target * Math.min(2, BATCH_SECONDS / Math.max(seconds, 0.05)))));
      }).finally(() => inFlight.delete(job));
      inFlight.add(job);
      return job;
    };

    let first = true;
    status('Classifying…');
    for await (const chunk of lineChunks(source)) {
      for (let j = 0; j < chunk.lines.length; j++) {
        const line = chunk.lines[j];
        if (first) { first = false; continue; }
        if (!line) continue;
        const f = splitFields(line, delim);
        const id = f[col.id];
        if (id !== current) {
          finishPlot(chunk.starts[j]);
          const site = sites.index.get(id);
          if (site === undefined ? R.readUnplaced.has(id) : R.readSites[site]) throw new Error(`The rows of plot ${id} are not together in the species file. Sort the file by plot.`);
          if (batch.ids.length >= target || batch.lines.length > MAX_RECORDS) {
            while (inFlight.size >= pool.length) {
              resizePool(true);
              await Promise.race(inFlight);
            }
            if (stopRequested) break;
            dispatch(chunk.starts[j]);
          }
          addPlot(id, chunk.starts[j], sites, site);
          batch.ids.push(id);
          current = id; rowsOfCurrent = 0;
        }
        rowsOfCurrent++;
        batch.lines.push(`${tsvValue(id)}\t${tsvValue(f[col.name])}\t${tsvValue(f[col.cover])}`);
      }
      if (stopRequested) break;
    }
    if (!stopRequested) {
      finishPlot(source.size);
      if (batch.ids.length) dispatch(source.size);
    }
    await Promise.all(inFlight);
    if (stopRequested) trimUnclassified();
    R.seconds = (performance.now() - R.t0) / 1000;
    dots.fitted = false;
    render(true);
    status(`${stopRequested ? 'Stopped after' : 'Classified'} ${fmt(R.done)} plots in ${formatTime(R.seconds)}.`, 'idle');
  } catch (e) {
    await Promise.allSettled(inFlight);
    console.error(e);
    status(cleanError(e), 'error');
    if (R) { trimUnclassified(); render(true); }
  } finally {
    running = false;
    $('system-panel').inert = false;
    $('data-inputs').inert = false;
    $('results').inert = false;
    $('results').setAttribute('aria-busy', 'false');
    $('run').textContent = 'Classify';
    updateReadiness();
    $('progress').hidden = true;
  }
}

// `site` is the plot's row in the sites file, or undefined.
function addPlot(id, start, sites, site) {
  if (R.n === R.code.length) growResults();
  const i = R.n++;
  R.ids.push(id);
  if (site === undefined) R.readUnplaced.add(id); else R.readSites[site] = 1;
  R.code[i] = -1; R.start[i] = start; R.end[i] = start;
  const lon = site === undefined ? NaN : sites.lon[site], lat = site === undefined ? NaN : sites.lat[site];
  [R.mx[i], R.my[i]] = placeOf(lon, lat);
}

// Plots read but not classified when the run was stopped are dropped.
function trimUnclassified() {
  let n = R.n;
  while (n > 0 && R.code[n - 1] < 0) n--;
  R.ids.length = n;
  R.n = n;
}

// Classifies a batch in a free session. A session that runs out of memory is
// closed and the batch is classified again in another one.
async function classifyBatch(b, opts, progressAfter) {
  let s, out, t;
  for (;;) {
    s = await acquire();
    t = performance.now();
    try {
      await s.webR.FS.writeFile('/tmp/batch_species.tsv', new TextEncoder().encode(b.lines.join('\n') + '\n'));
      await s.webR.FS.writeFile('/tmp/batch_sites.tsv', new TextEncoder().encode(sitesTsv(R.source.sites, b.ids)));
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
  release(s);
  s.heapGB = out.heap / 2 ** 30;
  if (manualSessions === null) resizePool();
  const at = new Map(b.ids.map((id, k) => [id, b.first + k]));
  out.id.forEach((id, k) => {
    const i = at.get(id);
    if (i === undefined) return;
    const c = codeOf(out.code[k]);
    R.code[i] = c; R.counts[c]++;
    R.cands[i] = candOf(out.candidates[k]);
  });
  R.done += out.id.length;
  R.nObs += out.n_obs; R.unmatched += out.unmatched;
  for (const w of out.warnings) addWarning(w);
  const seconds = (performance.now() - t) / 1000;
  R.progress = Math.max(R.progress ?? 0, progressAfter);
  setProgress(0.02 + 0.98 * R.progress);
  R.seconds = (performance.now() - R.t0) / 1000;
  const left = R.progress > 0.01 ? R.seconds * (1 - R.progress) / R.progress : null;
  if (running) status(`Classified ${fmt(R.done)} plots · ${formatTime(R.seconds)}${left === null ? '' : ` · about ${formatTime(left)} left`}`);
  render(false);
  return seconds;
}

// Each batch reports its own counts of plots with missing header values; they
// are added up into one warning. Other warnings are listed once.
const MISSING = /^Site columns read by rules have missing values: (.*)\. Conditions on them are evaluated as if the value were 0\.$/;
function addWarning(w) {
  const m = w.match(MISSING);
  if (!m) { R.warnings.add(w); return; }
  for (const part of m[1].split(/, (?=[^,]+ \(\d+ plots?\))/)) {
    const p = part.match(/^(.*) \((\d+) plots?\)$/);
    if (p) R.missing.set(p[1], (R.missing.get(p[1]) ?? 0) + Number(p[2]));
  }
}
const missingWarning = () => R.missing.size ? `Site columns read by rules have missing values: ${[...R.missing].map(([c, n]) => `${c} (${fmt(n)} plot${n === 1 ? '' : 's'})`).join(', ')}. Conditions on them are evaluated as if the value were 0.` : null;

const formatTime = (s) => s < 90 ? `${s.toFixed(s < 10 ? 1 : 0)} s` : s < 5400 ? `${Math.round(s / 60)} min` : `${(s / 3600).toFixed(1)} h`;
function setProgress(f) {
  $('progress-bar').style.width = `${(100 * Math.min(1, f)).toFixed(1)}%`;
  $('progress').setAttribute('aria-valuenow', (100 * f).toFixed(0));
}

// ---- Rendering ---------------------------------------------------------------
const cssVar = (name) => cssValue($('resy-app'), name);
const nameOf = (code) => code === '?' ? 'Not classified' : code === '+' ? 'Tie between types' : (R?.typeNames.get(code) ?? '');
// typeOrder: the types of a system other than EUNIS-ESy, most frequent first,
// which get the colours (see colourVar()); null colours by habitat group.
let typeOrder = null, filterType = null, selected = null;
const colourOf = (code) => cssVar(colourVar(code, typeOrder));

let lastRender = 0, renderTimer = null;
function render(now) {
  if (!R) return;
  const wait = 1500 - (performance.now() - lastRender);
  if (!now && wait > 0) {
    if (!renderTimer) renderTimer = setTimeout(() => { renderTimer = null; render(true); }, wait);
    return;
  }
  clearTimeout(renderTimer); renderTimer = null;
  lastRender = performance.now();
  const count = (c) => R.counts[R.codeIndex.get(c)] ?? 0;
  $('s-plots').textContent = fmt(R.done);
  $('s-class').textContent = fmt(R.done - count('?') - count('+'));
  $('s-none').textContent = fmt(count('?'));
  $('s-tie').textContent = fmt(count('+'));
  $('s-time').textContent = formatTime(R.seconds);
  $('s-system').innerHTML = `Classified with the ${escapeHtml(systemLabel(R.system))} expert system${R.system.doi ? ` (<a href="https://doi.org/${escapeHtml(R.system.doi)}">doi:${escapeHtml(R.system.doi)}</a>)` : ''}.`;

  const notes = [...R.warnings, missingWarning()].filter(Boolean);
  if (R.unmatched) notes.unshift(`Species names in ${fmt(R.unmatched)} of ${fmt(R.nObs)} records are not recognised by the expert system. These records do not contribute to the classification.`);
  $('warnings').innerHTML = notes.map((w) => `<li>${escapeHtml(w)}</li>`).join('');
  $('notes-n').textContent = `${plural(notes.length, 'note')} on the data and the run`;
  $('notes').style.visibility = notes.length ? '' : 'hidden';

  renderLegend();
  renderTypes();
  dots.redraw();
  renderTable();
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
      <span class="mid"><span class="nm">${escapeHtml(nameOf(t.code))}</span><div class="bar" style="width:${(100 * t.n / max).toFixed(1)}%"></div></span>
      <span>${fmt(t.n)}</span>
    </button></li>`).join('');
  $('clear-filter').disabled = filterType === null;
  if (focus) [...$('types').querySelectorAll('button')].find((b) => b.dataset.code === focus)?.focus({ preventScroll: true });
}

// Plots shown in the table: those of the selected type that match the filter
// text, at most `limit` of them, and how many match in all.
function visible(limit) {
  const q = $('q').value.trim().toLowerCase();
  const want = filterType === null ? null : R.codeIndex.get(filterType);
  const rows = [];
  let total = 0;
  for (let i = 0; i < R.n; i++) {
    const c = R.code[i];
    if (c < 0 || (want !== null && c !== want)) continue;
    if (q && !`${R.ids[i]} ${R.codes[c]} ${nameOf(R.codes[c])}`.toLowerCase().includes(q)) continue;
    total++;
    if (rows.length < limit) rows.push(i);
  }
  return { rows, total };
}

function renderTable() {
  if (!R) return;
  const { rows, total } = visible(500);
  $('rows').innerHTML = rows.map((i) => {
    const code = R.codes[R.code[i]];
    return `<tr data-i="${i}" class="${i === selected ? 'table-active' : ''}">
      <td><button type="button" class="plot-button" aria-label="Explain plot ${escapeHtml(R.ids[i])}" aria-pressed="${i === selected}">${escapeHtml(R.ids[i])}</button></td><td><b>${escapeHtml(code)}</b></td>
      <td>${escapeHtml(nameOf(code))}</td><td class="num">${R.nsp[i] || ''}</td></tr>`;
  }).join('') || '<tr><td colspan="4" class="empty-table">' + (running ? 'Waiting for classified plots…' : 'No plots match. Clear the search or choose Show all types.') + '</td></tr>';
  $('shown').textContent = `${fmt(total)} of ${fmt(R.done)} plots${total > rows.length ? `, first ${rows.length} listed` : ''}` + (filterType ? ` · type ${filterType}` : '');
}

// ---- Map ---------------------------------------------------------------------
// The classified plots as dots in the colour of their type (see resy_map.js).
// With a type chosen in the list, the plots of the other types are greyed out
// behind its plots.
const dots = createDotMap('map', () => {
  const want = filterType === null ? null : R.codeIndex.get(filterType);
  const colours = R ? R.codes.map(colourOf) : [], faded = cssVar('--lv-none');
  return {
    n: R?.n ?? 0,
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
  $('d-body').setAttribute('aria-busy', 'true');
  if (getComputedStyle($('detail')).position !== 'sticky') $('detail').scrollIntoView({ block: 'nearest' });
  try {
    const ev = await evaluatePlot(i);
    if (request !== detailRequest) return;
    $('d-title').textContent = title;
    $('d-empty').hidden = true;
    $('d-body').hidden = false;
    $('d-body').innerHTML = evidenceHtml(ev, nameOf);
    $('d-body').scrollTop = 0;
    $('d-status').textContent = '';
  } catch (e) {
    if (request === detailRequest) $('d-status').textContent = cleanError(e);
  } finally {
    if (request === detailRequest) $('d-body').setAttribute('aria-busy', 'false');
  }
}

// Classifies plot i alone, from its rows of the species file, and returns
// resy_page_explain()'s account of it, with the rules of `type` in full.
async function evaluatePlot(i, type = null) {
  const result = R, src = result.source;
  const lines = ['PlotObservationID\tname\tcover'];
  for await (const chunk of lineChunks(src.blob, result.start[i], result.end[i])) {
    for (const line of chunk.lines) {
      if (!line) continue;
      const f = splitFields(line, src.delim);
      lines.push(`${tsvValue(f[src.col.id])}\t${tsvValue(f[src.col.name])}\t${tsvValue(f[src.col.cover])}`);
    }
  }
  const s = await acquire();
  try {
    if (result !== R) throw new Error('The input changed. Select a plot from the new results.');
    await s.webR.FS.writeFile('/tmp/explain_species.tsv', new TextEncoder().encode(lines.join('\n') + '\n'));
    await s.webR.FS.writeFile('/tmp/explain_sites.tsv', new TextEncoder().encode(sitesTsv(src.sites, [result.ids[i]])));
    await prepareSites(s.webR, '/tmp/explain_sites.tsv', src.opts);
    return JSON.parse(await s.webR.evalRString(`resy_page_explain("/tmp/explain_species.tsv", "/tmp/explain_sites.tsv", ${rString(result.ids[i])}, ${src.opts}${type ? `, type = ${rString(type)}` : ''})`));
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
  saveBlob(blob, `resy_${systemLabel(result?.system ?? system.info).replace(/\.(json|txt)$/i, '').replace(/[^A-Za-z0-9_-]/g, '_')}_${suffix}`);
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
$('q').addEventListener('input', renderTable);
$('rows').addEventListener('click', (e) => { const tr = e.target.closest('tr[data-i]'); if (tr) explain(Number(tr.dataset.i)); });
wireEvidence($('d-body'), (type) => evaluatePlot(selected, type), () => detailRequest,
  { retain: true, report: (text) => { $('d-status').textContent = text; } });
$('types').addEventListener('click', (e) => {
  const button = e.target.closest('button'); if (!button) return;
  filterType = filterType === button.dataset.code ? null : button.dataset.code;
  renderTypes(); renderTable(); dots.draw();
});
$('clear-filter').addEventListener('click', () => {
  filterType = null; renderTypes(); renderTable(); dots.draw();
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
$('reset-data').addEventListener('click', resetData);
for (const [kind, header] of Object.entries({ species: 'PlotObservationID,scientificName,Cover_Perc', sites: 'PlotObservationID,Longitude,Latitude' })) {
  $(`template-${kind}`).addEventListener('click', () => saveBlob(new Blob([header + '\n'], { type: 'text/csv' }), `resy_${kind}_template.csv`));
}
$('f-expert').addEventListener('change', () => { document.querySelector('input[name=system][value=file]').checked = true; onSystemChange(); });
for (const el of document.querySelectorAll('input[name=system]')) el.addEventListener('change', onSystemChange);
$('eunis-version').addEventListener('change', () => { document.querySelector('input[name=system][value=EUNIS]').checked = true; onSystemChange(); });
$('to-maker').addEventListener('click', (e) => openInMaker(e).catch((error) => status(cleanError(error), 'error')));

$('retry-start').addEventListener('click', () => location.reload());
start().catch((e) => {
  status(`R could not start: ${e.message ?? e}`, 'error');
  $('retry-start').hidden = false;
  shell.failed(e);
});
