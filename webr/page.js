// Runs RESY in webR for vignettes/articles/app.Rmd. The bundle and the R
// helpers sit next to this script; pkgdown/build_webr_bundle.R builds the bundle.
// The data files are read here in parts and classified in batches of whole
// plots, spread over several webR sessions, so files of any size can be used.
import { WebR } from 'https://webr.r-wasm.org/v0.6.0/webr.mjs';

const base = new URL('.', import.meta.url);
const $ = (id) => document.getElementById(id);
const escapeHtml = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const rString = (s) => JSON.stringify(String(s));
const cleanError = (e) => String(e.message ?? e).replace(/^Error( in [^:]*)?:\s*/, '');
const fmt = (n) => Math.round(n).toLocaleString();

const status = (text, kind = 'busy') => {
  $('status').classList.toggle('error', kind === 'error');
  $('status').innerHTML = (kind === 'busy' ? '<span class="spinner-border spinner-border-sm me-2" aria-hidden="true"></span>' : '') + escapeHtml(text);
  if (!loaderDone) {
    $('loader-step').textContent = text;
    $('loader').classList.toggle('error', kind === 'error');
  }
};

// Startup steps as [start, end] of the hex fill and the seconds each takes on
// a desktop computer; the fill eases towards the end of the running step and
// waits there. The seconds are scaled by how much longer than these times the
// steps so far have taken, so that the fill keeps moving on a slower device.
const STAGES = { init: [0, 0.08, 0.6], install: [0.08, 0.28, 1.6], resy: [0.28, 0.51, 1.9], parse: [0.51, 0.63, 0.9], sf: [0.63, 1, 2.9] };
let loaderDone = false;
let stageStart = null, stageSeconds = 0, previousStage = null;
const fill = (f, seconds) => {
  $('hex-fill').style.setProperty('--dur', `${seconds}s`);
  $('hex-fill').style.setProperty('--p', `${(100 * f).toFixed(1)}%`);
};
const stage = (name) => {
  if (loaderDone) return;
  const now = performance.now() / 1000;
  if (previousStage) stageSeconds += STAGES[previousStage][2]; else stageStart = now;
  previousStage = name;
  const slower = stageSeconds ? Math.max(1, (now - stageStart) / stageSeconds) : 1;
  const [a, b, seconds] = STAGES[name];
  fill(a + 0.9 * (b - a), seconds * slower);
};
const hideLoader = () => {
  if (loaderDone) return;
  fill(1, 0.3);
  setTimeout(() => { loaderDone = true; $('loader').classList.add('done'); }, 350);
  setTimeout(() => { $('loader').hidden = true; $('tool').hidden = false; }, 750);
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
const SESSION_CODE_GB = 0.3;     // compiled R and sf code of a session, beside its memory
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
let bundle = null, script = null, info = null;
let system = null;           // the selected expert system: { key, call, file, info }

async function startSession(first) {
  const webR = new WebR();
  if (first) stage('init');
  await webR.init();
  if (first) { status('Installing R packages…'); stage('install'); }
  await webR.evalRVoid(`webr::install(c("data.table", "jsonlite", "stringi", "dplyr", "rlang", "tidyselect"), quiet = TRUE)`);
  if (first) { status('Loading RESY…'); stage('resy'); }
  await webR.FS.writeFile('/tmp/resylib.tar.gz', bundle);
  await webR.FS.writeFile('/tmp/resy_page.R', script);
  await webR.evalRVoid(`dir.create("/resylib", showWarnings = FALSE)
    utils::untar("/tmp/resylib.tar.gz", exdir = "/resylib", tar = "internal")
    .libPaths(c("/resylib", .libPaths()))
    source("/tmp/resy_page.R")`);
  const s = { webR, busy: false, key: null, info: null, sf: false };
  if (system) await applySystem(s, first);
  pool.push(s);
  release(s);
  showSessions();
  return s;
}

const showSessions = () => {
  $('workers').textContent = `${pool.length} R session${pool.length > 1 ? 's' : ''}${pool.length + starting > pool.length ? `, ${starting} starting` : ''}`;
  $('o-sessions').placeholder = `auto: ${Math.max(1, Math.min(autoSessions(), memoryCap))}`;
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

// Reads the selected expert system into a session, and installs sf there when
// the system needs the EUNIS-ESy site step. A session keeps what it read, so
// a system already in the session is not read again.
async function applySystem(s, first = false) {
  if (s.key === system.key) return s.info;
  if (system.file) {
    await s.webR.evalRVoid('dir.create("/tmp/upload", showWarnings = FALSE)');
    await s.webR.FS.writeFile(system.file.path, system.file.bytes);
  }
  if (first) { status('Reading the expert system…'); stage('parse'); }
  const out = JSON.parse(await s.webR.evalRString(system.call));
  if (out.eunis && !s.sf) {
    if (first) { status('Installing sf for the EUNIS-ESy site step…'); stage('sf'); }
    await ensureSf(s);
  }
  s.key = system.key;
  s.info = out;
  return out;
}

// sf is installed in a session when it first needs it: for the EUNIS-ESy site
// step or for the country outlines of the map download.
async function ensureSf(s) {
  if (s.sf) return;
  await s.webR.evalRVoid('webr::install("sf", quiet = TRUE); library(sf)');
  s.sf = true;
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
  const t0 = performance.now();
  // `no-cache` revalidates with the server, so a new RESY build is picked up
  // as soon as the site is updated.
  const get = (file) => fetch(new URL(file, base), { cache: 'no-cache' });
  [bundle, script, info] = await Promise.all([
    get('resylib.tar.gz').then((r) => r.arrayBuffer()).then((b) => new Uint8Array(b)),
    get('resy_page.R').then((r) => r.text()).then((t) => new TextEncoder().encode(t)),
    get('bundle.json').then((r) => r.json()).catch(() => null),
  ]);
  if (info) $('footer').insertAdjacentHTML('afterbegin', `RESY ${escapeHtml(info.resy)} (${escapeHtml(info.commit)}) · `);
  await chooseSystem();
  const first = await startSession(true);
  await describeSystem(first);
  await loadExamples(first);
  status(`R is ready (${((performance.now() - t0) / 1000).toFixed(0)} s).`, 'idle');
  hideLoader();
  $('run').disabled = false;
  resizePool();
}

// ---- Expert system ---------------------------------------------------------
const systemChoice = () => document.querySelector('input[name=system]:checked').value;

async function chooseSystem() {
  const v = systemChoice();
  if (v !== 'file') {
    system = { key: v, call: `resy_page_set_expert(scheme = ${rString(v)})`, file: null, info: null };
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
  if (loaderDone) status('Reading the expert system…');
  let out;
  try {
    out = await applySystem(s, !loaderDone);
  } catch (e) {
    $('sys-info').className = 'small mt-3 mb-0 error';
    $('sys-info').textContent = cleanError(e);
    system = null;
    throw e;
  }
  system.info = out;
  $('eunis-opts').disabled = !out.eunis;
  const codes = (xs) => {
    const c = xs.map((x) => `<code>${escapeHtml(x)}</code>`);
    return c.length > 1 ? `${c.slice(0, -1).join(', ')} and ${c.at(-1)}` : c[0];
  };
  const own = out.header_cols.filter((c) => !out.derived_cols.includes(c));
  let text = `The ${escapeHtml(out.scheme)} expert system includes ${out.n_types.toLocaleString()} ${out.eunis ? 'habitat ' : ''}types and ${out.n_species.toLocaleString()} species.`;
  if (out.derived_cols.length) text += ` RESY derives ${codes(out.derived_cols)} from <code>Longitude</code> and <code>Latitude</code>.`;
  if (own.length) text += ` It ${out.derived_cols.length ? 'also ' : ''}reads ${codes(own)} from the sites file if ${own.length > 1 ? 'those columns are' : 'that column is'} present.`;
  if (!out.header_cols.length) text += ' It reads no columns from the sites file.';
  $('sys-info').className = 'small mt-3 mb-0';
  setKeepingHeight($('sys-info'), text);
}

// The description of the expert system changes length with the system; it
// keeps the largest height it has had, so the page below it does not move up
// and down as systems are switched.
function setKeepingHeight(el, html) {
  const before = el.offsetHeight;
  el.style.minHeight = '';
  el.innerHTML = html;
  el.style.minHeight = `${Math.max(before, el.offsetHeight)}px`;
}

async function onSystemChange() {
  if (!pool.length || running) return;
  $('run').disabled = true;
  if (systemChoice() === 'file' && !$('f-expert').files[0]) {
    system = null;
    $('sys-info').className = 'small mt-3 mb-0';
    setKeepingHeight($('sys-info'), 'Choose an expert system file, <code>.json</code> or <code>.txt</code>, to classify with it.');
    status('', 'idle');
    return;
  }
  try {
    await chooseSystem();
    const s = await acquire();
    try { await describeSystem(s); } finally { release(s); }
    status('Expert system ready.', 'idle');
  } catch (e) {
    status(cleanError(e), 'error');
  } finally {
    $('run').disabled = false;
  }
}

// ---- Reading the data files -----------------------------------------------
// Lines of a file as text with their byte positions, read in parts so that a
// file of several gigabytes never has to fit in memory at once.
const CHUNK = 8 * 1024 * 1024;
const decoder = new TextDecoder('utf-8');

async function* lineChunks(blob, from = 0, to = blob.size) {
  let pos = from, carry = new Uint8Array(0), carryStart = from;
  while (pos < to) {
    const part = new Uint8Array(await blob.slice(pos, Math.min(pos + CHUNK, to)).arrayBuffer());
    const buf = carry.length ? concat(carry, part) : part;
    const bufStart = carryStart;
    pos += part.length;
    const lines = [], starts = [];
    let a = 0;
    for (let i = 0; i < buf.length; i++) {
      if (buf[i] !== 10) continue;
      lines.push(decodeLine(buf, a, i));
      starts.push(bufStart + a);
      a = i + 1;
    }
    if (pos >= to && a < buf.length) {
      lines.push(decodeLine(buf, a, buf.length));
      starts.push(bufStart + a);
      a = buf.length;
    }
    carry = buf.subarray(a);
    carryStart = bufStart + a;
    yield { lines, starts, end: carryStart };
  }
}
const concat = (a, b) => { const c = new Uint8Array(a.length + b.length); c.set(a); c.set(b, a.length); return c; };
const decodeLine = (buf, a, b) => {
  if (b > a && buf[b - 1] === 13) b--;
  if (a === 0 && buf[0] === 0xef && buf[1] === 0xbb && buf[2] === 0xbf) a = 3;
  return decoder.decode(buf.subarray(a, b));
};

// Fields of one line; quoted fields may hold the delimiter and doubled quotes.
function splitFields(line, delim) {
  if (!line.includes('"')) return line.split(delim);
  const out = [];
  let field = '', quoted = false;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (quoted) {
      if (c === '"' && line[i + 1] === '"') { field += '"'; i++; }
      else if (c === '"') quoted = false;
      else field += c;
    } else if (c === '"') quoted = true;
    else if (c === delim) { out.push(field); field = ''; }
    else field += c;
  }
  out.push(field);
  return out;
}

// Column names and delimiter (tab, semicolon or comma) of a delimited file.
async function readHeader(file) {
  const text = await file.slice(0, 1 << 16).text();
  const line = text.replace(/^﻿/, '').split(/\r?\n/)[0];
  const count = (d) => line.split(d).length;
  const delim = ['\t', ';', ','].sort((a, b) => count(b) - count(a))[0];
  return { delim, cols: splitFields(line, delim).map((c) => c.trim()) };
}

// Accepted names for each column, in order of preference.
const ALIASES = {
  id: ['PlotObservationID', 'PlotID', 'eventID', 'RELEVE_NR', 'releve_nr'],
  name: ['TaxonName', 'scientificName', 'Matched concept', 'Turboveg2 concept', 'Species', 'species', 'Taxon'],
  cover: ['Cover_Perc', 'Cover %', 'Cover', 'cover', 'organismQuantity'],
  lon: ['Longitude', 'decimalLongitude', 'lon', 'longitude'],
  lat: ['Latitude', 'decimalLatitude', 'lat', 'latitude'],
  Country: ['Country', 'country'],
  'Altitude (m)': ['Altitude (m)', 'Altitude'],
};
const pick = (cols, key) => (ALIASES[key] ?? [key]).find((c) => cols.includes(c)) ?? null;

// Fills the column choices for the species file.
const SPECIES_COLS = [['id', 'c-id'], ['name', 'c-name'], ['cover', 'c-cover']];
async function describeSpecies() {
  const f = $('f-species').files[0];
  if (!f) return;
  const { cols } = await readHeader(f);
  for (const [key, id] of SPECIES_COLS) {
    const chosen = pick(cols, key);
    $(id).innerHTML = cols.map((c) => `<option${c === chosen ? ' selected' : ''}>${escapeHtml(c)}</option>`).join('');
  }
  $('size-note').textContent = f.size > 50e6 ? `${(f.size / 1e9).toFixed(f.size > 1e9 ? 1 : 2)} GB: RESY reads it in parts.` : '';
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
const tsvValue = (v) => String(v ?? '').replace(/[\t\r\n]/g, ' ');
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
const mercator = (lon, lat) => {
  const s = Math.sin(lat * Math.PI / 180);
  return [(lon + 180) / 360, 0.5 - Math.log((1 + s) / (1 - s)) / (4 * Math.PI)];
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
  if (running) { stopRequested = true; $('run').disabled = true; return; }
  running = true; stopRequested = false;
  $('run').textContent = 'Stop';
  $('progress').hidden = false;
  setProgress(0);
  try {
    if (!system?.info) throw new Error('Choose an expert system first.');
    const sp = $('f-species').files[0], si = $('f-sites').files[0];
    if (!sp) throw new Error('Choose a species file.');
    if (!si) throw new Error('Choose a sites file.');
    const coast = $('o-coast').checked ? 'TRUE' : 'FALSE';
    const buffer = Number($('o-buffer').value) || 0;
    const opts = `coast_dunes = ${coast}, coast_buffer = ${buffer}`;

    const { delim, cols } = await readHeader(sp);
    const col = Object.fromEntries(SPECIES_COLS.map(([key, id]) => [key, cols.indexOf($(id).value)]));
    for (const [key] of SPECIES_COLS) if (col[key] < 0) throw new Error(`Choose the ${key === 'id' ? 'plot' : key === 'name' ? 'species' : 'cover'} column of the species file.`);

    status('Reading the sites file…');
    const wanted = [...new Set([...system.info.header_cols.filter((c) => !system.info.derived_cols.includes(c)), ...(system.info.eunis ? ['Country', 'Altitude (m)'] : [])])];
    const sites = await readSites(si, wanted, (f) => setProgress(0.02 * f));
    const source = await groupedSpecies(sp, delim, col.id);
    R = newResults({ blob: source, delim, col, sites, opts }, sites.lon.length);
    filterType = null; selected = null;
    $('results').hidden = false;
    clearDetail();

    let target = 1000;
    const inFlight = new Set();
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
    console.error(e);
    status(cleanError(e), 'error');
    if (R) render(true);
  } finally {
    running = false;
    $('run').textContent = 'Classify';
    $('run').disabled = false;
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
  if (Number.isFinite(lon) && Number.isFinite(lat) && Math.abs(lat) < 85) {
    [R.mx[i], R.my[i]] = mercator(lon, lat);
  } else { R.mx[i] = NaN; R.my[i] = NaN; }
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
const MISSING = /^Header columns used by the expert system have missing values: (.*)\. Conditions on them are evaluated as if the value were 0\.$/;
function addWarning(w) {
  const m = w.match(MISSING);
  if (!m) { R.warnings.add(w); return; }
  for (const part of m[1].split(/, (?=[^,]+ \(\d+ plots?\))/)) {
    const p = part.match(/^(.*) \((\d+) plots?\)$/);
    if (p) R.missing.set(p[1], (R.missing.get(p[1]) ?? 0) + Number(p[2]));
  }
}
const missingWarning = () => R.missing.size ? `Header columns used by the expert system have missing values: ${[...R.missing].map(([c, n]) => `${c} (${fmt(n)} plot${n === 1 ? '' : 's'})`).join(', ')}. Conditions on them are evaluated as if the value were 0.` : null;

const formatTime = (s) => s < 90 ? `${s.toFixed(s < 10 ? 1 : 0)} s` : s < 5400 ? `${Math.round(s / 60)} min` : `${(s / 3600).toFixed(1)} h`;
function setProgress(f) {
  $('progress-bar').style.width = `${(100 * Math.min(1, f)).toFixed(1)}%`;
  $('progress').setAttribute('aria-valuenow', (100 * f).toFixed(0));
}

// ---- Rendering ---------------------------------------------------------------
const cssVar = (name) => getComputedStyle($('resy-app')).getPropertyValue(name).trim();
const PALETTE = ['T', 'N', 'M', 'R', 'S', 'P', 'Q', 'U', 'V'];
const level = (code) => (code && /^[A-Z]/.test(code) ? code[0] : 'none');
const nameOf = (code) => code === '?' ? 'Not classified' : code === '+' ? 'Tie between types' : (system?.info?.names?.find((x) => x.code === code)?.name ?? '');
let typeColour = null, filterType = null, selected = null;
const colourOf = (code) => {
  if (code === undefined || code === '?' || code === '+') return cssVar('--lv-none');
  if (typeColour) return cssVar(typeColour.has(code) ? `--lv-${typeColour.get(code)}` : '--lv-other');
  return cssVar(`--lv-${level(code)}`) || cssVar('--lv-other');
};

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

  const notes = [...R.warnings, missingWarning()].filter(Boolean);
  if (R.unmatched) notes.unshift(`Species names in ${fmt(R.unmatched)} of ${fmt(R.nObs)} records are not recognised by the expert system. These records do not contribute to the classification.`);
  $('warnings').innerHTML = notes.map((w) => `<li>${escapeHtml(w)}</li>`).join('');

  renderLegend();
  renderTypes();
  dots.redraw();
  renderTable();
}

// The colours on the map and their labels, for the legend under the map and
// the one in the downloaded SVG. EUNIS-ESy types are coloured by habitat
// group; other systems colour their most frequent types.
function legendItems() {
  const levels = new Map(system.info.levels.map((l) => [l.code, l.name]));
  const used = R.codes.map((c, k) => [c, R.counts[k]]).filter(([, n]) => n > 0);
  const unclassified = { colour: colourOf('?'), label: 'not classified or tie' };
  if (system.info.eunis) {
    typeColour = null;
    const present = [...new Set(used.map(([c]) => (c === '?' || c === '+') ? 'none' : level(c)))].sort();
    return present.map((l) => l === 'none' ? unclassified : { colour: colourOf(l), label: [l, levels.get(l)].filter(Boolean).join(' ') });
  }
  const ranked = used.filter(([c]) => c !== '?' && c !== '+').sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0])).map(([c]) => c);
  typeColour = new Map(ranked.slice(0, PALETTE.length).map((c, i) => [c, PALETTE[i]]));
  return [
    ...[...typeColour.keys()].map((c) => ({ colour: colourOf(c), label: [c, levels.get(c)].filter(Boolean).join(' ') })),
    ...(ranked.length > PALETTE.length ? [{ colour: cssVar('--lv-other'), label: 'other types' }] : []),
    ...(used.some(([c]) => c === '?' || c === '+') ? [unclassified] : []),
  ];
}

function renderLegend() {
  $('legend').innerHTML = legendItems().map((l) => `<span><i style="background:${l.colour}"></i>${escapeHtml(l.label)}</span>`).join('');
}

function renderTypes() {
  const list = R.codes.map((c, k) => ({ code: c, n: R.counts[k] })).filter((t) => t.n > 0)
    .sort((a, b) => b.n - a.n || a.code.localeCompare(b.code));
  const max = list[0]?.n ?? 1;
  $('types').innerHTML = list.map((t) => `
    <li data-code="${escapeHtml(t.code)}" class="${t.code === filterType ? 'active' : ''}" title="${escapeHtml(nameOf(t.code))}">
      <span class="sw" style="background:${colourOf(t.code)}"></span>
      <b>${escapeHtml(t.code)}</b>
      <span class="mid"><span class="nm">${escapeHtml(nameOf(t.code))}</span><div class="bar" style="width:${(100 * t.n / max).toFixed(1)}%"></div></span>
      <span>${fmt(t.n)}</span>
    </li>`).join('');
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
  const { rows, total } = visible(500);
  $('rows').innerHTML = rows.map((i) => {
    const code = R.codes[R.code[i]];
    return `<tr data-i="${i}" class="${i === selected ? 'table-active' : ''}">
      <td>${escapeHtml(R.ids[i])}</td><td><b style="color:${colourOf(code)}">${escapeHtml(code)}</b></td>
      <td>${escapeHtml(nameOf(code))}</td><td class="num">${R.nsp[i] || ''}</td></tr>`;
  }).join('');
  $('shown').textContent = total === R.done && total <= rows.length ? '' :
    `${fmt(total)} of ${fmt(R.done)} plots${total > rows.length ? `, first ${rows.length} listed` : ''}` + (filterType ? ` · type ${filterType}` : '');
}

// ---- Map ---------------------------------------------------------------------
// All plots are drawn as dots on one canvas, so the map stays fast with
// millions of plots.
const dots = {
  map: null, canvas: null,
  init() {
    this.map = L.map('map', { scrollWheelZoom: false, worldCopyJump: false }).setView([50, 10], 4);
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 18, attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    }).addTo(this.map);
    this.canvas = L.DomUtil.create('canvas', 'resy-dots leaflet-zoom-hide');
    this.map.getPanes().overlayPane.appendChild(this.canvas);
    this.map.on('moveend zoomend resize', () => this.draw());
    this.map.on('click', (e) => this.click(e));
    this.fitted = false;
  },
  redraw() {
    if (!this.map) this.init();
    this.map.invalidateSize();
    if (!this.fitted) this.fit();
    this.draw();
  },
  fit() {
    let x0 = Infinity, x1 = -Infinity, y0 = Infinity, y1 = -Infinity, any = false;
    for (let i = 0; i < R.n; i++) {
      const x = R.mx[i];
      if (Number.isNaN(x) || R.code[i] < 0) continue;
      any = true;
      x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, R.my[i]); y1 = Math.max(y1, R.my[i]);
    }
    if (!any) return;
    const toLatLng = (x, y) => L.latLng(Math.atan(Math.sinh(Math.PI * (1 - 2 * y))) * 180 / Math.PI, x * 360 - 180);
    this.map.fitBounds(L.latLngBounds(toLatLng(x0, y1), toLatLng(x1, y0)).pad(0.15));
    this.fitted = true;
  },
  // Pixel position of plot i in the map container, or null.
  pixel(i, scale, ox, oy) {
    const x = R.mx[i];
    if (Number.isNaN(x)) return null;
    return [x * scale - ox, R.my[i] * scale - oy];
  },
  view() {
    const size = this.map.getSize(), scale = 256 * 2 ** this.map.getZoom();
    const o = this.map.getPixelBounds().min;
    return { size, scale, ox: o.x, oy: o.y };
  },
  // Dot radius in CSS pixels: smaller as more plots are shown.
  radius() {
    const n = R.done;
    return n > 200000 ? 1 : n > 20000 ? 1.5 : n > 2000 ? 2.5 : 4.5;
  },
  // Calls fn(x, y, k) for each classified plot in the view, x and y in CSS
  // pixels of the map and k the index of its type, or -1 for a plot greyed out
  // by the type filter. Greyed plots come first, so the others are drawn on top.
  eachDot({ size, scale, ox, oy }, fn) {
    const want = filterType === null ? null : R.codeIndex.get(filterType);
    const pad = this.radius() + 1;
    const visit = (i, k) => {
      const p = this.pixel(i, scale, ox, oy);
      if (p && p[0] > -pad && p[1] > -pad && p[0] < size.x + pad && p[1] < size.y + pad) fn(p[0], p[1], k);
    };
    if (want !== null) for (let i = 0; i < R.n; i++) if (R.code[i] >= 0 && R.code[i] !== want) visit(i, -1);
    for (let i = 0; i < R.n; i++) {
      const k = R.code[i];
      if (k >= 0 && (want === null || k === want)) visit(i, k);
    }
  },
  draw() {
    if (!this.map || !R) return;
    const { size, scale, ox, oy } = this.view();
    if (!size.x || !size.y) return;
    const c = this.canvas, ratio = window.devicePixelRatio || 1;
    c.width = size.x * ratio; c.height = size.y * ratio;
    c.style.width = `${size.x}px`; c.style.height = `${size.y}px`;
    L.DomUtil.setPosition(c, this.map.containerPointToLayerPoint([0, 0]));
    const ctx = c.getContext('2d');
    const img = ctx.createImageData(c.width, c.height), px = new Uint32Array(img.data.buffer);
    const r = Math.max(1, Math.round(this.radius() * ratio));
    const disc = [];
    for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) if (dx * dx + dy * dy <= r * r + r) disc.push([dx, dy]);
    const rgba = (hex, a) => {
      const v = parseInt(hex.replace('#', ''), 16);
      return ((a << 24) | ((v & 255) << 16) | (((v >> 8) & 255) << 8) | (v >> 16)) >>> 0;
    };
    const colours = R.codes.map((code) => rgba(colourOf(code), 235));
    const faded = rgba(cssVar("--lv-none"), 110);
    const W = c.width, H = c.height;
    this.eachDot({ size, scale, ox, oy }, (cx, cy, k) => {
      const x = Math.round(cx * ratio), y = Math.round(cy * ratio), colour = k < 0 ? faded : colours[k];
      for (const [dx, dy] of disc) {
        const xx = x + dx, yy = y + dy;
        if (xx >= 0 && yy >= 0 && xx < W && yy < H) px[yy * W + xx] = colour;
      }
    });
    ctx.putImageData(img, 0, 0);
    if (selected !== null) {
      const p = this.pixel(selected, scale, ox, oy);
      if (p) {
        ctx.beginPath(); ctx.arc(p[0] * ratio, p[1] * ratio, r + 5 * ratio, 0, 2 * Math.PI);
        ctx.lineWidth = 2 * ratio; ctx.strokeStyle = cssVar('--bs-emphasis-color') || '#000'; ctx.stroke();
      }
    }
  },
  click(e) {
    if (!R) return;
    const { scale, ox, oy } = this.view();
    const want = filterType === null ? null : R.codeIndex.get(filterType);
    let best = -1, bestD = 64;
    for (let i = 0; i < R.n; i++) {
      if (R.code[i] < 0 || (want !== null && R.code[i] !== want)) continue;
      const p = this.pixel(i, scale, ox, oy);
      if (!p) continue;
      const d = (p[0] - e.containerPoint.x) ** 2 + (p[1] - e.containerPoint.y) ** 2;
      if (d < bestD) { bestD = d; best = i; }
    }
    if (best >= 0) explain(best);
  },
};

// ---- Why this type? ------------------------------------------------------------
// The panel shows what RESY's resy_eval_plot() prints, as HTML: the decision,
// the species, the lower-level types not reached (closest first) and the rule
// of one of them condition by condition. Selecting another type in the list
// shows its rule instead.
function clearDetail() {
  $('d-empty').hidden = false; $('d-body').hidden = true; $('d-title').textContent = 'Why this type?';
}

const NEAR_SHOWN = 8;
const plural = (n, word) => `${fmt(n)} ${word}${n === 1 ? '' : 's'}`;

function ruleHtml(t, label = '') {
  const conds = t.conditions.map((c, k) => `
    <li class="${c.satisfied ? 'ok' : 'no'}">
      <span class="n">[${k + 1}]</span><span class="st">${escapeHtml(c.status)}</span>
      <span class="tx">${escapeHtml(c.text)}${c.species ? `<span class="sp">${escapeHtml(c.species)}</span>` : ''}</span>
    </li>`).join('');
  return `<div class="rule">
    <p class="mb-1"><b>${escapeHtml(t.code)}</b> ${escapeHtml(t.name)}${label}
      <span class="verdict ${t.holds ? 'ok' : 'no'}">${t.holds ? 'rule holds' : 'rule not met'}</span></p>
    <p class="formula">${escapeHtml(t.rule)}</p>
    <ol class="conds">${conds}</ol>
  </div>`;
}

function nearHtml(ty) {
  const item = (t) => `
    <li data-type="${escapeHtml(t.code)}" tabindex="0" title="Show the rule of ${escapeHtml(t.code)}"${t === ty[0] ? ' class="active"' : ''}>
      <b>${escapeHtml(t.code)}</b>
      <span class="nm">${escapeHtml(nameOf(t.code) || t.name)}${t.rules > 1 ? `<span class="text-body-secondary">, closest of ${t.rules} rules</span>` : ''}</span>
      <span class="frac"><span class="bar"><i style="width:${(100 * t.satisfied / Math.max(1, t.conditions)).toFixed(0)}%"></i></span>${t.satisfied} of ${t.conditions}</span>
    </li>`;
  const head = ty.slice(0, NEAR_SHOWN).map(item).join('');
  const rest = ty.slice(NEAR_SHOWN);
  return `<ul class="near">${head}</ul>` + (rest.length ?
    `<details><summary class="small">Show the other ${plural(rest.length, 'type')}</summary><ul class="near">${rest.map(item).join('')}</ul></details>` : '');
}

function evidenceHtml(ev) {
  const out = [`<p class="mb-1">${escapeHtml(ev.sentence ?? '')}</p>`];
  if (ev.holds?.length) out.push(`<p class="small text-body-secondary">Rules that hold: ${ev.holds.map((h) => `${escapeHtml(h.code)} (priority ${escapeHtml(h.priority)})`).join(', ')}</p>`);
  out.push(`<details class="species" open><summary>${fmt(ev.species.length)} species</summary>
    <table class="table table-sm mb-0"><tbody>${ev.species.map((s) => `<tr><td>${escapeHtml(s.species)}</td><td class="num">${s.cover ?? ''}</td></tr>`).join('')}</tbody></table></details>`);
  ev.lower.forEach((lv) => {
    if (!lv.below) { out.push(`<p class="small mt-3 mb-0">${escapeHtml(lv.anchor)} has no lower levels.</p>`); return; }
    if (!lv.types?.length) return;
    const heading = lv.anchor === '?' ? 'Top-level types not reached' : `Why not a lower level of ${lv.anchor}?`;
    out.push(`<section class="lower">
      <p class="h6 mt-3 mb-1">${escapeHtml(heading)}</p>
      <p class="small text-body-secondary mb-2">Conditions of each rule that the plot meets, closest first. Select a type to see its rule.</p>
      ${nearHtml(lv.types)}
      <div class="full">${ruleHtml(lv.closest)}</div>
    </section>`);
  });
  return out.join('');
}

// The rule(s) of `type` in place of the closest rule under the list it was picked from.
function showType(li) {
  const full = li.closest('.lower')?.querySelector('.full');
  const i = selected;
  if (!full || i === null) return;
  for (const x of $('d-body').querySelectorAll('.near li.active')) x.classList.remove('active');
  li.classList.add('active');
  full.innerHTML = '<p class="text-body-secondary small">Evaluating…</p>';
  evaluatePlot(i, li.dataset.type).then((ev) => {
    if (selected !== i) return;
    const ty = ev.types[0];
    full.innerHTML = ty.rules.map((r, k) => ruleHtml(r, ty.rules.length > 1 ? `<span class="text-body-secondary">, rule ${k + 1} of ${ty.rules.length}</span>` : '')).join('');
  }).catch((e) => { full.textContent = cleanError(e); });
}

async function explain(i) {
  selected = i;
  renderTable();
  dots.draw();
  const code = R.codes[R.code[i]];
  $('d-title').textContent = `Plot ${R.ids[i]}: ${code} ${nameOf(code)}`;
  $('d-empty').hidden = true;
  $('d-body').hidden = false;
  $('d-body').innerHTML = '<p class="text-body-secondary mb-0">Evaluating…</p>';
  try {
    const ev = await evaluatePlot(i);
    if (selected === i) $('d-body').innerHTML = evidenceHtml(ev);
  } catch (e) {
    $('d-body').textContent = cleanError(e);
  }
  $('detail').scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

// Classifies plot i alone, from its rows of the species file, and returns
// resy_page_explain()'s account of it, with the rules of `type` in full.
async function evaluatePlot(i, type = null) {
  const src = R.source;
  const lines = ['PlotObservationID\tname\tcover'];
  for await (const chunk of lineChunks(src.blob, R.start[i], R.end[i])) {
    for (const line of chunk.lines) {
      if (!line) continue;
      const f = splitFields(line, src.delim);
      lines.push(`${tsvValue(f[src.col.id])}\t${tsvValue(f[src.col.name])}\t${tsvValue(f[src.col.cover])}`);
    }
  }
  const s = await acquire();
  try {
    await s.webR.FS.writeFile('/tmp/explain_species.tsv', new TextEncoder().encode(lines.join('\n') + '\n'));
    await s.webR.FS.writeFile('/tmp/explain_sites.tsv', new TextEncoder().encode(sitesTsv(src.sites, [R.ids[i]])));
    return JSON.parse(await s.webR.evalRString(`resy_page_explain("/tmp/explain_species.tsv", "/tmp/explain_sites.tsv", ${rString(R.ids[i])}, ${src.opts}${type ? `, type = ${rString(type)}` : ''})`));
  } finally {
    release(s);
  }
}

// ---- Download --------------------------------------------------------------------
function download() {
  if (!R) return;
  const q = (v) => /[",\n]/.test(v) ? `"${v.replace(/"/g, '""')}"` : v;
  const parts = ['plot_id,classification,classification_name,candidates\n'];
  let block = [];
  for (let i = 0; i < R.n; i++) {
    if (R.code[i] < 0) continue;
    const code = R.codes[R.code[i]];
    block.push(`${q(R.ids[i])},${q(code)},${q(nameOf(code))},${q(R.candLists[R.cands[i]])}\n`);
    if (block.length === 50000) { parts.push(block.join('')); block = []; }
  }
  parts.push(block.join(''));
  saveBlob(new Blob(parts, { type: 'text/csv' }), 'classification.csv');
}

function saveBlob(blob, suffix) {
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `resy_${String(system.info.scheme).replace(/\.(json|txt)$/i, '').replace(/[^A-Za-z0-9_-]/g, '_')}_${suffix}`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
}

// The map as it is shown, as an SVG: the country outlines, the plots in their
// colours, the selected plot and the legend. Plots that fall on the same spot
// in the same colour are drawn once, and each colour is one path of round dots,
// so the file stays small with millions of plots.
async function downloadMap() {
  if (!R || !dots.map) return;
  const button = $('download-map');
  button.disabled = true;
  try {
    const v = dots.view(), W = v.size.x, H = v.size.y;
    const s = await acquire();
    let land;
    try {
      await ensureSf(s);
      land = JSON.parse(await s.webR.evalRString(`resy_page_land(${v.scale}, ${v.ox}, ${v.oy}, ${W}, ${H})`));
    } finally {
      release(s);
    }
    const faded = cssVar('--lv-none');
    const spots = new Map();
    dots.eachDot(v, (x, y, k) => {
      const key = k < 0 ? 'faded' : colourOf(R.codes[k]);
      if (!spots.has(key)) spots.set(key, new Set());
      spots.get(key).add(`${x.toFixed(1)} ${y.toFixed(1)}`);
    });
    const r = dots.radius();
    const items = legendItems();
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
    const p = selected === null ? null : dots.pixel(selected, v.scale, v.ox, v.oy);
    if (p && p[0] >= 0 && p[1] >= 0 && p[0] <= W && p[1] <= H) {
      svg.push(`<circle cx="${p[0].toFixed(1)}" cy="${p[1].toFixed(1)}" r="${r + 5}" fill="none" stroke="#000" stroke-width="2"/>`);
    }
    svg.push(`<text x="${W - 6}" y="${H - 6}" font-size="9" fill="#6b7178" text-anchor="end">Country borders: Eurostat GISCO</text>`,
      '</g>',
      `<g transform="translate(0 ${H + 12})" font-size="11">`,
      ...items.map((l, k) => `<circle cx="6" cy="${4 + 16 * k}" r="4" fill="${l.colour}"/><text x="16" y="${8 + 16 * k}" fill="#333">${escapeHtml(l.label)}</text>`),
      '</g>',
      '</svg>');
    saveBlob(new Blob([svg.join('\n')], { type: 'image/svg+xml' }), 'map.svg');
  } catch (e) {
    console.error(e);
    status(cleanError(e), 'error');
  } finally {
    button.disabled = false;
  }
}

// ---- Example data ------------------------------------------------------------------
// The example CSVs are put into the file inputs as File objects, so the inputs
// show their names and a chosen file simply replaces one of them.
const examples = { files: null };
const DATA_INPUTS = ['f-species', 'f-sites'];
const setFile = (input, file) => {
  const dt = new DataTransfer();
  dt.items.add(file);
  input.files = dt.files;
};
const isExample = (i) => $(DATA_INPUTS[i]).files[0] === examples.files?.[i];
const showReset = () => { $('reset-data').hidden = DATA_INPUTS.every((_, i) => isExample(i)); };

async function loadExamples(s) {
  const paths = await s.webR.evalRRaw('resy_page_examples()', 'string[]');
  examples.files = await Promise.all(paths.map(async (p) =>
    new File([await s.webR.FS.readFile(p)], p.split('/').at(-1), { type: 'text/csv' })));
  await resetData();
}

async function resetData() {
  DATA_INPUTS.forEach((id, i) => setFile($(id), examples.files[i]));
  showReset();
  await describeSpecies();
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
$('rows').addEventListener('click', (e) => { const tr = e.target.closest('tr'); if (tr) explain(Number(tr.dataset.i)); });
$('d-body').addEventListener('click', (e) => { const li = e.target.closest('.near li'); if (li) showType(li); });
$('d-body').addEventListener('keydown', (e) => {
  const li = e.target.closest('.near li');
  if (li && (e.key === 'Enter' || e.key === ' ')) { e.preventDefault(); showType(li); }
});
$('types').addEventListener('click', (e) => {
  const li = e.target.closest('li'); if (!li) return;
  filterType = filterType === li.dataset.code ? null : li.dataset.code;
  renderTypes(); renderTable(); dots.draw();
});
for (const id of DATA_INPUTS) $(id).addEventListener('change', () => {
  const i = DATA_INPUTS.indexOf(id);
  if (!$(id).files.length && examples.files) setFile($(id), examples.files[i]);
  showReset();
  if (id === 'f-species') describeSpecies().catch((e) => status(cleanError(e), 'error'));
});
$('reset-data').addEventListener('click', resetData);
$('f-expert').addEventListener('change', () => { document.querySelector('input[name=system][value=file]').checked = true; onSystemChange(); });
for (const el of document.querySelectorAll('input[name=system]')) el.addEventListener('change', onSystemChange);

start().catch((e) => status(`R could not start: ${e.message ?? e}`, 'error'));
