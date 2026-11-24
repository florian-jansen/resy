// The RESY Maker (vignettes/articles/maker.Rmd): one screen to build an expert
// system on. The types are listed on the left, the rule of the type shown
// stands in the middle as blocks, and the parts are beside it: the species
// groups, the species list and the test plots. RESY in webR classifies the
// plots after every change. The model and the formula syntax are in
// maker_model.js; the R side is resy_maker.R.
import { $, escapeHtml as h, rString, cleanError, fmt, plural, createLoader, fetchAssets, bootSession, saveBlob, store, createShell, pinNavbar, prepareMakerSites } from './resy_core.js';
import { splitFields, readHeader, pick, SPECIES_COLS, SPECIES_COL_LABEL, fillSpeciesColumns, tsvValue } from './resy_files.js';
import { evidenceHtml, wireEvidence } from './resy_evidence.js';
import * as M from './maker_model.js';
import { placeOf, createDotMap } from './resy_map.js';
import { colourVar, cssValue } from './resy_palette.js';

const loader = createLoader({ init: 0, install: 0.55, resy: 0.65, data: 0.8, test: 0.9 });
const app = $('resy-app');
const DIR = '/tmp/maker';

let webR = null, info = null;
let model = M.newModel();
let opened = false;        // a system is open
let edited = false;        // it has changes that opening another system would discard
let kept = false;          // it is kept as the draft: every system but the untouched example the page opens on
let data = null;           // the test plots: { label, example, n_plots, n_records, species: Map, columns }
let test = null;           // the result of the last test, with byRule: Map(rule id -> its counts)
let problems = [];
// `rest` is '?' or '+' while the plots no type takes, or those tied between
// types, are selected in place of the plots of the type shown.
const sel = { tab: 'groups', show: 'all', kind: 'all', group: null, rule: null, species: null, plot: null, rest: null };
const REST = { none: '?', tie: '+' };
// A type has the colour of its place in the list of types, as in the RESY App
// (see resy_palette.js); the plots no type takes are grey.
const cssColour = (name, or) => cssValue(app, name) || or;
const typeColour = (code, order = model.rules.map((r) => r.code)) => cssColour(colourVar(code, order), '#9a9d96');

// Restore the active control when an edited list or rule changes structure.
function replaceContent(container, html) {
  const active = document.activeElement;
  let selector = null, selection = null;
  if (container.contains(active)) {
    const owner = active.closest('[data-node], [data-id], [data-name]');
    const attributes = ['data-act', 'data-ta', 'data-side', 'data-i'];
    const identify = (el, keys) => keys.filter((key) => el.hasAttribute(key)).map((key) => `[${key}="${CSS.escape(el.getAttribute(key))}"]`).join('');
    const field = identify(active, attributes);
    if (field || active.matches('.head, .grip')) {
      selector = (owner ? identify(owner, ['data-node', 'data-id', 'data-name']) + ' ' : '')
        + (field || (active.matches('.head') ? '.head' : '.grip'));
      if (typeof active.selectionStart === 'number') selection = [active.selectionStart, active.selectionEnd];
    }
  }
  container.innerHTML = html;
  const next = selector && container.querySelector(selector);
  if (next) {
    next.focus({ preventScroll: true });
    if (selection) next.setSelectionRange(...selection);
  }
}

// ---- R ----------------------------------------------------------------------------
// One R session; calls are made one after the other.
let chain = Promise.resolve();
const inR = (fn) => { const p = chain.then(fn); chain = p.catch(() => {}); return p; };
const rJson = (code) => inR(async () => JSON.parse(await webR.evalRString(code)));
const rVoid = (code) => inR(() => webR.evalRVoid(code));
const rWrite = (path, content) => inR(() => webR.FS.writeFile(path, typeof content === 'string' ? new TextEncoder().encode(content) : content));
const rRead = (path) => inR(() => webR.FS.readFile(path));

// ---- History, draft --------------------------------------------------------------------
// Every change to the groups, the types or the description is one step back
// with Undo. The species list is not part of it.
const history = { stack: [], at: 0 };
const snapshot = () => structuredClone({ metadata: model.metadata, groups: model.groups, rules: model.rules });
function resetHistory() {
  history.stack = [snapshot()];
  history.at = 0;
}
function commit() {
  history.stack.length = history.at + 1;
  history.stack.push(snapshot());
  if (history.stack.length > 60) history.stack.shift();
  history.at = history.stack.length - 1;
  edited = kept = true;
  changed();
}
// The ids of the entries of `after` that `before` does not have or has with
// another value under one of `keys`. A tree is compared where both have one:
// the tree of a rule is built when the rule is first shown.
function changedIds(before, after, keys) {
  const old = new Map(before.map((x) => [x.id, x]));
  const differs = (a, b, k) => (k === 'tree' ? Boolean(a.tree && b.tree) : true) && JSON.stringify(a[k]) !== JSON.stringify(b[k]);
  return after.filter((y) => { const x = old.get(y.id); return !x || keys.some((k) => differs(x, y, k)); }).map((y) => y.id);
}
// A step back or forward shows what it changed: the type, or the group when no
// type changed with it.
function travel(by) {
  const to = history.at + by;
  if (to < 0 || to >= history.stack.length) return;
  const from = history.stack[history.at], next = history.stack[to];
  const rules = changedIds(from.rules, next.rules, ['code', 'description', 'priority', 'expression', 'tree', 'inherit', 'overrides']);
  const groups = changedIds(from.groups, next.groups, ['name', 'prefix', 'members']);
  history.at = to;
  Object.assign(model, structuredClone(next));
  for (const r of model.rules) touched.add(r.id);
  if (rules.length && !rules.includes(sel.rule)) sel.rule = rules[0];
  if (!rule()) sel.rule = model.rules[0]?.id ?? null;
  if (groups.length && !groups.includes(sel.group)) sel.group = groups[0];
  activeGroup = null;
  changed();
  if (groups.length && !rules.length && sel.tab !== 'groups') showTab('groups');
  render();
  if (groups.length && sel.tab === 'groups') reveal($('g-list').querySelector('li.open'), $('pane-parts'));
}
// Scrolls `pane`, a list that scrolls on its own beside the rule, so that `el`
// is in view below the heading that stays at the top of the pane; with `first`,
// so that `el` is the first entry in view. The page stays where it is.
function reveal(el, pane, first = false) {
  if (!el || pane.scrollHeight <= pane.clientHeight) return;
  const a = el.getBoundingClientRect(), b = pane.getBoundingClientRect();
  const top = b.top + (pane.querySelector('.panehead')?.offsetHeight ?? 0);
  if (first || a.top < top) pane.scrollTop -= top - a.top + 8;
  else if (a.bottom > b.bottom) pane.scrollTop += Math.min(a.bottom - b.bottom, a.top - top) + 8;
}
const revealType = (first = false) => reveal($('t-list').querySelector('li.active'), $('pane-types'), first);
// After any change to the model: check it, keep the draft, test again. A change
// that leaves the system as it was last tested (a number typed and tested, then
// left; a step back to it) needs no test.
let revision = 0;
function changed() {
  revision++;
  problems = M.checkModel(model, data);
  showChrome();
  saveDraft();
  if (testTimer === null && !testing && test && !synDirty && test.json === testJson().json) { touched.clear(); showCounts(); return; }
  scheduleTest();
}
let draftTimer = null;
function saveDraft() {
  if (!opened || !kept) return;
  clearTimeout(draftTimer);
  draftTimer = setTimeout(async () => {
    try {
      await store.set('maker-draft', { model, savedAt: Date.now() });
      $('draft-status').classList.remove('error');
      $('draft-status').textContent = 'Draft saved in this browser.';
    } catch (e) {
      console.warn('[maker] draft not saved', e);
      $('draft-status').classList.add('error');
      $('draft-status').textContent = 'The browser could not save the draft. Use Save to download a copy.';
    }
  }, 1200);
}

// ---- Testing -----------------------------------------------------------------------------
// The system is classified on the test plots a moment after each change. A
// change made while a test runs starts another test when it ends. The counts of
// the last test stay on the page, dimmed, until those of the next one replace
// them, so nothing moves while a test runs.
let testTimer = null, testing = false, again = false, synDirty = true;
const touched = new Set();    // the rules changed since the last test started
// What a test reads: the rules without a problem, and the file written for them.
function testJson() {
  const rules = model.rules.filter((r) => !M.ruleProblem(r, model.rules));
  return { rules, json: JSON.stringify(M.modelToJson(model, { synonyms: false, rules })) };
}
function scheduleTest(delay = 600) {
  if (!webR || !data || !opened) return;
  app.classList.add('stale');
  clearTimeout(testTimer);
  testTimer = setTimeout(runTest, delay);
}
async function runTest() {
  testTimer = null;
  if (testing) { again = true; return; }
  testing = true;
  try {
    do { again = false; await testOnce(); } while (again);
  } catch (e) {
    console.error(e);
    playStatus(cleanError(e), 'error');
  } finally {
    testing = false;
  }
}
async function testOnce() {
  const { rules, json } = testJson();
  const testedData = data;
  touched.clear();
  // The system is as it was last tested: the result of that test stands.
  const fresh = !test || synDirty || test.json !== json;
  let newColumns = false;
  if (fresh) {
    playStatus('Testing…', 'busy');
    if (synDirty) {
      synDirty = false;
      await rWrite(`${DIR}/synonyms.json`, JSON.stringify(Object.fromEntries(model.synonyms)));
      await rVoid(`resy_maker_synonyms("${DIR}/synonyms.json")`);
    }
    await rWrite(`${DIR}/rules.json`, json);
    await inR(() => prepareMakerSites(webR, `${DIR}/rules.json`));
    performance.mark('resy:test-start');
    const out = await rJson(`resy_maker_test("${DIR}/rules.json")`);
    performance.mark('resy:test-end');
    if (data !== testedData || synDirty || json !== testJson().json) { again = true; return; }
    if (!out.ok) {
      playStatus(out.errors?.[0] ?? 'The test did not run.', 'error');
      return;
    }
    const tested = new Map((out.plots?.id ?? []).map((id, i) => [id, i]));
    out.onMap = data.placed.map((p) => tested.get(p.id) ?? -1);
    out.groupPlots = new Map();
    out.tested = rules.length;
    out.json = json;
    const before = test?.plots ? new Map(test.plots.id.map((id, i) => [id, test.plots.code[i]])) : null;
    moved = before && out.plots ? new Set(out.plots.id.flatMap((id, i) => (before.has(id) && before.get(id) !== out.plots.code[i] ? [i] : []))) : null;
    test = out;
    if (out.columns && JSON.stringify(out.columns) !== JSON.stringify(data.columns)) {
      data.columns = out.columns;
      newColumns = true;
    }
    if (!rules.length) validation = null;
  }
  scheduleNotes();
  // The same rules can stand under other ids (a copy that took the place of its original).
  test.byRule = new Map(rules.map((r, i) => [r.id, test.rules?.[i]]));
  test.index = new Map(rules.map((r, i) => [r.id, i]));
  if (!again && testTimer === null) app.classList.remove('stale');
  problems = M.checkModel(model, data);
  if (newColumns) showColumns();
  playStatus(test.ok ? '' : (test.errors[0] ?? 'The test did not run.'), test.ok ? 'idle' : 'error');
  showChrome();
  showCounts();
  loadRulePlots();
  if (sel.tab === 'plots') renderPlots();
  if (sel.tab === 'species') renderSpeciesNotes();
  if (sheet === 'export') renderExport();
  if (sel.plot === null) return;
  if (!test.plots?.id.includes(sel.plot)) clearDetail();
  else if (fresh) explain(sel.plot, true);
  else markTrail();
}
// What RESY's validation says about the system last tested. In webR the
// validation takes longer than the test, so it is read once the counts are on
// the page and no other test waits; until then the notes of the test before stay.
let validation = null, notesTimer = null;
function scheduleNotes() {
  clearTimeout(notesTimer);
  notesTimer = setTimeout(loadNotes, 1500);
}
async function loadNotes() {
  const t = test;
  if (!t?.tested || t.noted || testing || testTimer !== null) return;
  t.noted = true;
  let out;
  try { out = await rJson(`resy_maker_notes("${DIR}/rules.json")`); } catch (e) { console.warn('[maker] system not validated', e); return; }
  if (test !== t) return;
  validation = out;
  if (sel.tab === 'plots') renderPlots();
}
function playStatus(text, kind) {
  $('play-status').classList.toggle('error', kind === 'error');
  $('play-status').innerHTML = (kind === 'busy' ? '<span class="spinner-border spinner-border-sm me-1" aria-hidden="true"></span>' : '') + h(text);
  $('play-status').title = text;
}
const tally = () => {
  const codes = test?.plots?.code ?? [];
  let none = 0, tie = 0;
  for (const c of codes) { if (c === '?') none++; else if (c === '+') tie++; }
  return { n: codes.length, none, tie, classified: codes.length - none - tie };
};

// ---- Around the bench: top bar, sheets, tabs ---------------------------------------------------
function showChrome() {
  app.classList.toggle('empty-system', model.rules.length === 0);
  const errors = errorCount(), warnings = problems.length - errors;
  const t = tally();
  $('undo').disabled = history.at === 0;
  $('redo').disabled = history.at >= history.stack.length - 1;
  const plots = `${data?.example ? 'the example plots' : 'your plots'}${data?.region ? ' in the region on the map' : ''}`;
  $('play-stats').textContent = !data ? '' : t.n
    ? `Testing on ${plots}: ${fmt(t.n)} plots, ${fmt(t.classified)} classified, ${fmt(t.none)} without a type, ${fmt(t.tie)} tied`
    : `Testing on ${plots}: ${plural(data.n_plots, 'plot')}`;
  // The way to one's own plots stands out until they are in use.
  $('plots-open').textContent = data && !data.example ? 'Change the plots' : 'Upload your plots';
  $('plots-open').className = `btn ${data && !data.example ? 'btn-outline-secondary' : 'btn-primary'}`;
  $('play-problems').textContent = errors ? `${plural(errors, 'error')} to fix` : warnings ? plural(warnings, 'note') : '';
  $('play-problems').classList.toggle('error', errors > 0);
  $('n-groups').textContent = fmt(model.groups.length);
  $('n-species').textContent = fmt(model.synonyms.size);
  $('n-plots').textContent = data ? fmt(test?.n_plots ?? data.n_plots) : '';
  for (const el of app.querySelectorAll('[data-meta]')) if (el !== document.activeElement) el.value = model.metadata[el.dataset.meta] ?? '';
}

// One sheet at a time drops from the top bar: opening a system, the test
// plots, the check with the export, the question before everything is cleared.
const SHEETS = { open: disarm, clear: renderClear, plots: renderPlotsSheet, export: renderExport };
let sheet = null, sheetOpener = null;
function showSheet(name) {
  if (name && !sheet) sheetOpener = document.activeElement;
  const closingFocus = !name && sheet && $(`sheet-${sheet}`).contains(document.activeElement);
  sheet = name;
  for (const key of Object.keys(SHEETS)) $(`sheet-${key}`).hidden = key !== sheet;
  for (const b of app.querySelectorAll('[data-sheet][aria-expanded]')) b.setAttribute('aria-expanded', String(b.dataset.sheet === sheet));
  taHide();
  if (sheet) {
    SHEETS[sheet]();
    $(`sheet-${sheet}`).querySelector('input, select, button')?.focus({ preventScroll: true });
  } else if (closingFocus) sheetOpener?.focus({ preventScroll: true });
}
// The parts beside the rule: the groups, the species list, the test plots.
const TABS = { groups: renderGroups, species: renderSpecies, plots: renderPlots };
function showTab(name) {
  sel.tab = name;
  for (const key of Object.keys(TABS)) $(`tab-${key}`).hidden = key !== name;
  for (const b of app.querySelectorAll('[data-tab]')) {
    b.classList.toggle('active', b.dataset.tab === name);
    b.setAttribute('aria-selected', String(b.dataset.tab === name));
    b.tabIndex = b.dataset.tab === name ? 0 : -1;
  }
  taHide();
  TABS[name]();
}
function render() {
  showChrome();
  renderTypes();
  TABS[sel.tab]();
  if (sheet) SHEETS[sheet]();
  loadRulePlots();
  revealType();
}

// ---- Saving and clearing ------------------------------------------------------------------------
// Save downloads the system as it stands, unfinished types included (a type
// whose blocks do not make a formula yet keeps the last formula they made), to
// be opened again later. Export writes the finished system after checking it.
function saveFile() {
  saveBlob(new Blob([JSON.stringify(M.modelToJson(model, { rules: model.rules }), null, 1)], { type: 'application/json' }), `${slug()}.json`);
  $('draft-status').textContent = `Download started: ${slug()}.json`;
}
function renderClear() {
  const name = model.metadata.scheme.trim();
  $('clear-text').textContent = `This removes the ${plural(model.rules.length, 'type')}, the ${plural(model.groups.length, 'group')} and the ${nSpecies(model.synonyms.size)} of ${name ? `“${name}”` : 'the system'}, and the draft kept in this browser. You start again with an empty system; the test plots stay. Undo does not bring it back, a saved copy does: open it under Open….`;
  $('clear-status').textContent = '';
}
async function clearAll() {
  await showSystem({ empty: true });
}

// ---- Opening a system -------------------------------------------------------------------------
const startChoice = () => document.querySelector('input[name=start]:checked').value;
let armed = null;
async function startClicked() {
  const v = startChoice();
  // Opening another system replaces the one being edited: ask for a second click.
  if (edited && (model.rules.length || model.groups.length || model.synonyms.size) && armed !== v) {
    armed = v;
    $('start-go').textContent = 'Replace the system I am editing';
    $('start-go').classList.replace('btn-primary', 'btn-danger');
    $('start-status').textContent = 'Its draft is replaced too. Download it under Export if you want to keep it.';
    return;
  }
  disarm();
  $('start-go').disabled = true;
  try {
    if (v === 'file' && !$('start-file').files[0]) throw new Error('Choose an expert system file first.');
    const source = v === 'new' ? { empty: true } : v === 'file' ? { file: $('start-file').files[0] }
      : { scheme: v, version: v === 'EUNIS' ? $('start-eunis-version').value : null };
    await showSystem(source);
  } catch (e) {
    console.error(e);
    $('start-status').textContent = cleanError(e);
    $('start-status').classList.add('error');
  } finally {
    $('start-go').disabled = false;
  }
}
function disarm() {
  armed = null;
  $('start-go').classList.replace('btn-danger', 'btn-primary');
  $('start-status').textContent = '';
  $('start-status').classList.remove('error');
  $('start-go').textContent = 'Open';
}

// Makes `source` the system being edited: { empty }, { draft }, { scheme,
// version } for a system shipped with RESY, or { file } with a File or
// { name, bytes }. A .json file is read here; RESY turns a .txt file and the
// shipped systems into the JSON format.
async function openSystem(source) {
  $('start-status').textContent = 'Opening…';
  let next;
  if (source.empty) next = M.newModel();
  else if (source.draft) next = source.draft.model;
  else {
    const file = source.file;
    // A File has a bytes() method of its own in current browsers, so the two
    // forms are told apart by type.
    const bytes = !file ? null : file instanceof Blob ? new Uint8Array(await file.arrayBuffer()) : file.bytes;
    let text;
    if (file && /\.json$/i.test(file.name)) {
      text = new TextDecoder().decode(bytes);
    } else {
      let call;
      if (file) {
        if (!/\.txt$/i.test(file.name)) throw new Error('The expert system file must end in .json or .txt.');
        const path = `${DIR}/${file.name.replace(/[^A-Za-z0-9._-]/g, '_')}`;
        await rWrite(path, bytes);
        call = `path = ${rString(path)}`;
      } else call = `scheme = ${rString(source.scheme)}${source.version ? `, version = ${rString(source.version)}` : ''}`;
      await rVoid(`resy_maker_open("${DIR}/open.json", ${call})`);
      text = new TextDecoder().decode(await rRead(`${DIR}/open.json`));
    }
    let json;
    try { json = JSON.parse(text); } catch (e) { throw new Error(`The file is not valid JSON (${e.message}).`); }
    next = M.modelFromJson(json);
    if (file && !next.metadata.scheme) next.metadata.scheme = file.name.replace(/\.(json|txt)$/i, '');
  }
  model = next;
  opened = true;
  edited = Boolean(source.draft);
  kept = !source.example;
  synDirty = true;
  pool = null;
  test = null;
  validation = null;
  shownHits.clear();
  trail = null;
  removed = null;
  ticked.clear();
  // In a system of a few groups the first one is shown with its species when
  // they are few enough to read; a long list of groups starts at its top.
  const first = model.groups[0];
  Object.assign(sel, { group: first && model.groups.length < 9 && first.members.length <= 30 ? first.id : null, rule: model.rules[0]?.id ?? null, species: null, plot: null, show: 'all', kind: 'all' });
  $('detail').hidden = true;
  $('welcome').hidden = true;
  resetHistory();
  changed();
  await showBusiestType();
  $('start-status').textContent = '';
}
// Opens `source` (see openSystem()) and shows it, the type it opens on first
// in the list of types.
async function showSystem(source) {
  await openSystem(source);
  showSheet(null);
  render();
  revealType(true);
}
// A system opens on the type most of the test plots are classified as, so the
// rule shown has plots to look at. The system is tested for that before it is
// shown; without a test it opens on its first type.
async function showBusiestType() {
  if (!webR || !data || !model.rules.length) return;
  clearTimeout(testTimer);
  await runTest();
  if (!test?.ok) return;
  let best = null, most = 0;
  for (const r of model.rules) {
    const n = test.byRule.get(r.id)?.assigned ?? 0;
    if (n > most) { best = r; most = n; }
  }
  if (best) sel.rule = best.id;
}

// ---- Species ----------------------------------------------------------------------------------
const byName = (a, b) => (a < b ? -1 : a > b ? 1 : 0);
const nSpecies = (n) => `${fmt(n)} species`;
const plotsOf = (name) => data?.species.get(name)?.plots ?? 0;

function addSpecies(names) {
  let added = 0;
  for (const raw of names) {
    const name = raw.replace(/\s+/g, ' ').trim();
    if (!name || model.synonyms.has(name)) continue;
    model.synonyms.set(name, [...(data?.species.get(name)?.variants ?? [])]);
    added++;
  }
  if (added) speciesChanged();
  return added;
}
function speciesChanged() {
  synDirty = true;
  pool = null;
  edited = kept = true;
  changed();
}
// The species listed: those of one kind (`sel.kind`) that match the search.
const SPECIES_KINDS = {
  all: ['All species', () => true],
  group: ['In a group', (name, grouped) => grouped.has(name)],
  nogroup: ['In no group', (name, grouped) => !grouped.has(name)],
  plots: ['In the test plots', (name) => plotsOf(name) > 0],
  noplots: ['Not in the test plots', (name) => !plotsOf(name)],
};
const ticked = new Set();     // the species ticked in the list
let removed = null;           // the species last removed, as [name, other names], to put back
function speciesListed() {
  const q = $('sp-q').value.trim().toLowerCase(), grouped = new Set(model.groups.flatMap((g) => g.members));
  const names = [...model.synonyms.keys()].sort(byName), kinds = {};
  for (const [key, [, test]] of Object.entries(SPECIES_KINDS)) kinds[key] = names.filter((n) => test(n, grouped));
  const hits = q ? kinds[sel.kind].filter((n) => n.toLowerCase().includes(q) || model.synonyms.get(n).some((x) => x.toLowerCase().includes(q))) : kinds[sel.kind];
  return { names, kinds, hits, q };
}
function renderSpecies() {
  const missing = data ? [...data.species.keys()].filter((n) => !model.synonyms.has(n)) : [];
  $('sp-add-data').textContent = missing.length ? `Add the ${nSpecies(missing.length)} of the test plots` : 'All species of the test plots are in the list';
  $('sp-add-data').disabled = !missing.length;
  const { names, kinds, hits, q } = speciesListed();
  for (const name of [...ticked]) if (!model.synonyms.has(name)) ticked.delete(name);
  $('sp-filter').innerHTML = Object.entries(SPECIES_KINDS).map(([key, [label]]) => `<option value="${key}"${key === sel.kind ? ' selected' : ''}>${label} (${fmt(kinds[key].length)})</option>`).join('');
  $('sp-count').textContent = q || sel.kind !== 'all' ? `${fmt(hits.length)} of ${nSpecies(names.length)} listed` : nSpecies(names.length);
  // Removes the ticked species; without a tick, all that a kind or a search has narrowed the list to.
  const narrowed = Boolean(q) || sel.kind !== 'all';
  $('sp-remove').textContent = ticked.size ? `Remove the ${fmt(ticked.size)} ticked` : `Remove the ${fmt(hits.length)} listed`;
  $('sp-remove').hidden = !ticked.size && (!narrowed || !hits.length);
  $('sp-removed').hidden = !removed;
  if (removed) $('sp-removed-text').textContent = `${nSpecies(removed.length)} removed from the list.`;
  const SHOWN = 300;
  replaceContent($('sp-list'), hits.slice(0, SHOWN).map((name) => {
    const syn = model.synonyms.get(name), n = plotsOf(name), open = sel.species === name;
    return `<li data-name="${h(name)}"${open ? ' class="open"' : ''}>
      <div class="line">
        <input class="form-check-input" type="checkbox" data-act="sp-tick"${ticked.has(name) ? ' checked' : ''} aria-label="Tick ${h(name)}">
        <span class="nm">${h(name)}<span class="meta">${[syn.length ? plural(syn.length, 'other name') : '', n ? plural(n, 'plot') : ''].filter(Boolean).join(' · ')}</span></span>
        <button type="button" class="btn btn-link btn-sm p-0" data-act="sp-edit">${open ? 'Close' : 'Names'}</button>
        <button type="button" class="mini x" data-act="sp-del" title="Remove ${h(name)} from the list" aria-label="Remove ${h(name)} from the list">✕</button>
      </div>
      ${open ? `<label class="small d-block mt-1">Other names read as ${h(name)}, one per line
        <textarea class="form-control form-control-sm mt-1" rows="${Math.min(8, Math.max(2, syn.length + 1))}" data-act="sp-syn">${h(syn.join('\n'))}</textarea></label>` : ''}
    </li>`;
  }).join('') + (hits.length > SHOWN ? `<li class="more">The first ${SHOWN} are listed. Search to find the others.</li>` : '')
    + (hits.length ? '' : `<li class="more">${names.length ? 'No species matches.' : 'The list is empty.'}</li>`));
  renderSpeciesNotes();
}
// Takes `names` off the species list and keeps them to be put back.
function removeSpecies(names) {
  removed = names.filter((n) => model.synonyms.has(n)).map((n) => [n, model.synonyms.get(n)]);
  for (const [name] of removed) { model.synonyms.delete(name); ticked.delete(name); }
  if (!removed.length) removed = null;
  speciesChanged();
  renderSpecies();
}
function restoreSpecies() {
  for (const [name, syn] of removed ?? []) if (!model.synonyms.has(name)) model.synonyms.set(name, syn);
  removed = null;
  speciesChanged();
  renderSpecies();
}
function renderSpeciesNotes() {
  const notes = [];
  if (test?.n_unmatched) {
    const shown = test.unmatched.slice(0, 6).map((u) => u.name).join(', ');
    notes.push(`${fmt(test.n_unmatched)} of ${fmt(test.n_records)} species records of the test plots carry a name that is not in the species list (${plural(test.n_unmatched_names, 'name')}: ${h(shown)}${test.n_unmatched_names > 6 ? ', …' : ''}). They are not used in the classification.`);
  }
  $('sp-notes').innerHTML = notes.map((n) => `<p class="small note">${n}</p>`).join('');
}

// ---- Groups -----------------------------------------------------------------------------------
// The groups are the parts the rules are made of. The group that is open shows
// its species under its name in the list.
const group = () => model.groups.find((g) => g.id === sel.group) ?? null;
const groupNames = () => new Set(model.groups.map((g) => g.name));
const speciesGroups = () => model.groups.filter((g) => !g.prefix.startsWith('$'));
const PREFIX_LABEL = { '###': 'Species group', '##D': 'Group of a set', '##Q': 'Group (##Q)', '##C': 'Group (##C)', '$$C': 'Site category ($$C)', '$$N': 'Site value ($$N)' };

function usedBy(name) {
  const names = groupNames();
  return model.rules.filter((r) => M.ruleRefs(r, names).groups.has(name));
}
function renderGroups() {
  const q = $('g-q').value.trim().toLowerCase();
  $('g-q').hidden = model.groups.length < 9;
  const list = model.groups.filter((g) => !q || g.name.toLowerCase().includes(q) || g.members.some((m) => m.toLowerCase().includes(q)));
  replaceContent($('g-list'), list.map((g) => {
    const open = g.id === sel.group, part = !g.prefix.startsWith('$');
    return `<li data-id="${g.id}"${open ? ' class="open"' : ''}>
      <div class="head" tabindex="0" role="button" aria-expanded="${open}"${part ? ' draggable="true" title="Select the group to see its species. Drag it into the rule to add a condition on it."' : ''}>
        <span class="nm">${h(g.name || 'Unnamed group')}</span>
        <span class="meta">${nSpecies(g.members.length)}<span data-group-hits="${g.id}"></span></span>
      </div>
      <button type="button" class="mini x del" data-act="row-del" title="Delete the group ${h(g.name)} (Undo brings it back)" aria-label="Delete the group ${h(g.name)}">✕</button>
      ${open ? `<div id="g-editor">${groupEditorHtml(g)}</div>` : ''}
    </li>`;
  }).join('') || `<li class="more">${model.groups.length ? 'No group matches.' : 'No groups yet. A group holds the species that point to a vegetation type, for example the trees of beech forests.'}</li>`);
  showCounts();
}
function groupEditorHtml(g) {
  const prefixes = ['###', '##D', ...(['###', '##D'].includes(g.prefix) ? [] : [g.prefix])];
  const users = usedBy(g.name), r = rule();
  return `
    <div class="fields group">
      <label class="form-label small">Name
        <input class="form-control form-control-sm mt-1" data-act="g-name" value="${h(g.name)}" placeholder="for example Beech-forest-trees" spellcheck="false"></label>
      <label class="form-label small">Kind
        <select class="form-select form-select-sm mt-1" data-act="g-prefix">${prefixes.map((p) => `<option value="${h(p)}"${p === g.prefix ? ' selected' : ''}>${PREFIX_LABEL[p] ?? p}</option>`).join('')}</select></label>
    </div>
    <p class="small error mb-2" id="g-problem" aria-live="polite"></p>
    ${g.prefix === '##D' ? '<p class="small text-body-secondary">The groups of a set have names that start with the same number, such as <code>+01 Dry-grassland</code> and <code>+01 Wet-meadow</code>. The condition “scores highest in its set” holds for the group whose species have the highest sum of square-root covers in the plot.</p>' : ''}
    <ul class="chips">${g.members.map((m) => `
      <li>${h(m)}${plotsOf(m) ? `<span class="n" title="Test plots with this species">${plotsOf(m)}</span>` : ''}
        <button type="button" class="mini x" data-act="g-del-member" data-name="${h(m)}" title="Remove ${h(m)}" aria-label="Remove ${h(m)}">✕</button></li>`).join('')}</ul>
    <input class="form-control form-control-sm" data-ta="member" placeholder="Add a species: type its name" aria-label="Add a species" autocomplete="off" spellcheck="false">
    <details class="mt-2"><summary class="small">Paste a list of species</summary>
      <textarea class="form-control form-control-sm mt-1" rows="4" id="g-paste" placeholder="One species name per line" aria-label="Species to add to the group, one per line"></textarea>
      <button type="button" class="btn btn-outline-primary btn-sm mt-1" data-act="g-paste-add">Add to the group</button></details>
    <p class="small text-body-secondary mt-3 mb-0 used">${users.length ? `Used by ${users.map((u) => `<button type="button" class="btn btn-link btn-sm p-0 align-baseline" data-act="open-rule" data-id="${u.id}">${h(u.code || 'a type')}</button>`).join(', ')}.` : 'Not used by a type yet.'}</p>
    <div class="actions">
      ${r?.tree && !g.prefix.startsWith('$') ? `<button type="button" class="btn btn-outline-primary btn-sm" data-act="g-use">Add to the rule${r.code ? ` of ${h(r.code)}` : ''}</button>` : ''}
      <button type="button" class="btn btn-outline-secondary btn-sm" data-act="g-dup">Duplicate</button>
      <button type="button" class="btn btn-outline-danger btn-sm" data-act="g-del">Delete</button>
    </div>`;
}
function addMembers(g, names) {
  let added = 0;
  for (const raw of names) {
    const name = raw.replace(/\s+/g, ' ').trim();
    if (!name || g.members.includes(name)) continue;
    g.members.push(name);
    if (!model.synonyms.has(name)) { model.synonyms.set(name, [...(data?.species.get(name)?.variants ?? [])]); synDirty = true; pool = null; }
    added++;
  }
  return added;
}
// A name that no other group has, starting from `base`.
function freeName(base, taken) {
  if (!taken.has(base)) return base;
  for (let i = 2; ; i++) if (!taken.has(`${base}-${i}`)) return `${base}-${i}`;
}
function addGroup() {
  const g = M.newGroup(freeName('New-group', groupNames()));
  model.groups.push(g);
  return g;
}
// Shows the group with its species among the parts, ready to be named when it is new.
function openGroup(id, naming = false) {
  sel.group = id;
  $('g-q').value = '';
  showTab('groups');
  const li = $('g-list').querySelector(`li[data-id="${id}"]`);
  li?.scrollIntoView({ block: 'nearest' });
  if (naming) { const name = li?.querySelector('[data-act="g-name"]'); name?.focus(); name?.select(); }
}
// After a change to the groups: the conditions of the rule shown name them.
function groupsChanged() {
  commit();
  renderGroups();
  renderBuilder();
}

// ---- Types and their rules ------------------------------------------------------------------------
const rule = () => model.rules.find((r) => r.id === sel.rule) ?? null;
// The full rule of a type, with what it inherits (see fullRule() in
// maker_model.js), and its conditions in the order the test counts them.
const fullOf = (r) => M.fullRule(r, model.rules);
const orderOf = (r) => fullOf(r).order ?? [];
const nameOf = (code) => (code === '?' ? 'Not classified' : code === '+' ? 'Tie between types' : model.rules.find((r) => r.code === code)?.description ?? '');

// Whether the search text above the list of types leaves the type `r` in it.
const typeListed = (r) => {
  const q = $('t-q').value.trim().toLowerCase();
  return !q || `${r.code} ${r.description}`.toLowerCase().includes(q);
};
// The types whose subtypes are folded away in the list, by id.
const folded = new Set();
// The ids of the types above the type `id` in the hierarchy, nearest first.
function ancestors(id, rows = M.typeTree(model.rules)) {
  const parent = new Map(rows.map((x) => [x.rule.id, x.parent])), out = [];
  for (let p = parent.get(id); p; p = parent.get(p)) out.push(p);
  return out;
}
// The ids of the type `id` and of all types below it.
function branchIds(id, rows = M.typeTree(model.rules)) {
  const at = rows.findIndex((x) => x.rule.id === id);
  if (at < 0) return [];
  const out = [id];
  for (let k = at + 1; k < rows.length && rows[k].depth > rows[at].depth; k++) out.push(rows[k].rule.id);
  return out;
}
// The types as a tree: a subtype stands indented under its parent, whose
// subtypes fold away with the arrow in front of it. A search shows the types it
// finds with the types above them.
function renderTypes(editor = true) {
  $('t-q').hidden = model.rules.length < 9;
  const rows = M.typeTree(model.rules), parent = new Map(rows.map((x) => [x.rule.id, x.parent]));
  const q = $('t-q').value.trim(), keep = new Set();
  if (q) for (const x of rows) if (typeListed(x.rule)) for (let id = x.rule.id; id && !keep.has(id); id = parent.get(id)) keep.add(id);
  const foldedAway = (x) => ancestors(x.rule.id, rows).some((p) => folded.has(p));
  const shown = rows.filter((x) => (q ? keep.has(x.rule.id) : !foldedAway(x)));
  $('t-list').classList.toggle('tree', rows.some((x) => x.kids.length));
  // Expert systems nest up to about seven levels. The indent of the lowest level
  // stays within 42px, so its names and counts keep their room in the list.
  const deepest = Math.max(1, ...rows.map((x) => x.depth));
  $('t-list').style.setProperty('--step', `${Math.min(14, 42 / deepest)}px`);
  // A folded type that holds the type shown is marked, as the type shown is hidden.
  const above = sel.rule && !sel.rest ? ancestors(sel.rule, rows) : [];
  $('t-list').innerHTML = shown.map(({ rule: r, depth, kids }) => {
    const open = !folded.has(r.id) || q;
    return `
    <li data-id="${r.id}" class="${[r.id === sel.rule && !sel.rest ? 'active' : '', !open && above.includes(r.id) ? 'holds' : '', q && !typeListed(r) ? 'context' : ''].join(' ')}" style="--depth:${depth}" tabindex="0"${kids.length ? ` aria-expanded="${Boolean(open)}"` : ''}>
      ${kids.length && !q ? `<button type="button" class="fold" data-act="fold" tabindex="-1" title="${open ? 'Fold away' : 'Show'} the ${plural(kids.length, 'subtype')} of ${h(r.code)}" aria-label="${open ? 'Fold away' : 'Show'} the subtypes of ${h(r.code)}"><span aria-hidden="true">${open ? '▾' : '▸'}</span></button>` : ''}
      <button type="button" class="mini x del" data-act="row-del" title="Delete the type ${h(r.code)} (Undo brings it back)" aria-label="Delete the type ${h(r.code)}">✕</button>
      <span class="nm" title="${h(`${r.code} ${r.description}`)}"><i class="sw" style="background:${typeColour(r.code)}"></i><b>${h(r.code || 'Unnamed')}</b> ${h(r.description)}</span>
      <span class="meta">priority ${h(r.priority)}<span data-rule-hits="${r.id}"></span>${kids.length ? `<span data-branch-hits="${r.id}"></span>` : ''}</span>
      <span class="dots" data-dots="${h(r.code)}"></span>
    </li>`;
  }).join('') || `<li class="more">${model.rules.length ? 'No type matches.' : 'No types yet.'}</li>`;
  if (editor) renderTypeEditor();
  showCounts();
}
// Folds the subtypes of the type `id` away, or shows them again.
function foldType(id, fold = !folded.has(id)) {
  if (fold === folded.has(id)) return;
  if (fold) folded.add(id); else folded.delete(id);
  renderTypes(false);
  $('t-list').querySelector(`li[data-id="${id}"]`)?.focus({ preventScroll: true });
}
function renderTypeEditor() {
  const r = rule();
  if (!r) {
    $('t-editor').innerHTML = model.rules.length ? '<p class="text-body-secondary mb-0">Select a type in the list.</p>'
      : `<div class="empty"><p class="h5">Start with a vegetation type</p>
        <p class="text-body-secondary">A type has a code, a name and a rule that says which plots belong to it. The rule is made of conditions on groups of species; you make and fill the groups while you write it.</p>
        <button type="button" class="btn btn-primary" data-act="t-new">New type</button></div>`;
    return;
  }
  const tree = M.ruleTree(r), up = M.parentOf(r, model.rules), from = r.inherit ? fullOf(r).from?.tree : null;
  $('t-editor').innerHTML = `
    <div class="fields type">
      <label class="form-label small">Code
        <input class="form-control form-control-sm mt-1" data-rule-field="code" value="${h(r.code)}" placeholder="FB" spellcheck="false"></label>
      <label class="form-label small">Name
        <input class="form-control form-control-sm mt-1" data-rule-field="description" value="${h(r.description)}" placeholder="Beech-fir montane forest"></label>
      <label class="form-label small">Priority
        <select class="form-select form-select-sm mt-1" data-rule-field="priority">${M.PRIORITIES.slice(0, Math.max(10, M.PRIORITIES.indexOf(r.priority) + 1)).map((p) => `<option${p === r.priority ? ' selected' : ''}>${p}</option>`).join('')}</select></label>
    </div>
    <p class="small text-body-secondary mt-2">RESY assigns each plot to the matching type with the highest priority. Give a subtype a higher priority than its parent.</p>
    ${up ? `<div class="form-check small inherit"><input class="form-check-input" type="checkbox" id="t-inherit" data-act="t-inherit"${r.inherit ? ' checked' : ''}>
      <label class="form-check-label" for="t-inherit">Inherit the rule of <b>${h(up.code)}</b> ${h(up.description)}</label></div>` : ''}
    ${from ? `<div class="from"><p class="form-label small mb-1">From ${h(up.code)}</p>
      <p class="small text-body-secondary mb-1">These conditions of ${h(up.code)} hold for ${h(r.code)} as well and follow every change to ${h(up.code)}. Change one for ${h(r.code)} alone, or leave it out.</p>
      ${fromHtml(from, r, true)}</div>` : ''}
    <p class="form-label small mb-1">${from ? `Own conditions of ${h(r.code)}` : 'Rule'}</p>
    ${tree ? `<div class="palette" id="palette">${PALETTE.map(([kind, label]) => `<button type="button" class="chip k-${kindClass(kind)}" draggable="true" data-palette="${kind}" title="Add this condition (click, or drag it into the rule)">${label}</button>`).join('')}</div>
      <div id="builder">${groupHtml(tree, true)}</div>`
    : `<p class="small error">The formula cannot be shown as blocks${r.problem ? `: ${h(r.problem)}` : ''}. Edit it as text below.</p>`}
    <p class="small mt-2 mb-0" id="t-verdict"></p>
    <p class="small mt-1 mb-0 trail" id="t-trail" hidden></p>
    <details class="mt-2" id="t-text"${tree ? '' : ' open'}><summary class="small">Formula as text</summary>
      ${r.inherit ? `<p class="small mb-1 mt-1">The whole rule, as RESY reads it:</p><code class="small d-block full" id="t-full">${h(fullOf(r).text)}</code>
      <p class="small mb-0 mt-2">Own conditions of ${h(r.code)}:</p>` : ''}
      <textarea class="form-control form-control-sm mt-1 formula" rows="4" data-act="rule-text" aria-label="${r.inherit ? 'Own conditions as a formula' : 'Rule formula'}" spellcheck="false">${h(r.expression)}</textarea>
      <p class="small text-body-secondary mb-0 mt-1">The ESy formula syntax: conditions in <code>&lt; &gt;</code>, joined by <code>AND</code>, <code>OR</code> and <code>NOT</code>. Leave the field to apply a change.</p></details>
    <div class="actions">
      <button type="button" class="btn btn-outline-secondary btn-sm" data-act="t-dup">Duplicate</button>
      <button type="button" class="btn btn-outline-danger btn-sm" data-act="t-del">Delete type</button>
    </div>`;
  showVerdict();
  paintTrail();
}

// The type each inherited condition of `r` comes from, as a map from the id of
// the condition to the code of that type; null when `r` inherits over one level.
function inheritedFrom(r) {
  const origin = new Map();
  let levels = 0;
  for (let a = M.parentOf(r, model.rules); a; a = a.inherit ? M.parentOf(a, model.rules) : null) {
    levels++;
    for (const n of M.ownConditions(a)) if (!origin.has(n.id)) origin.set(n.id, a.code);
  }
  return levels > 1 ? origin : null;
}
// After the type shown starts or stops inheriting, or changes what it inherits:
// draw the rule again, with the focus on the condition `focus` (an id).
function inheritChanged(r, focus = null) {
  touched.add(r.id);
  renderTypeEditor();
  commit();
  renderTypes(false);
  if (focus) $('t-editor').querySelector(`.cond[data-node="${focus}"] .tail button`)?.focus({ preventScroll: true });
}

// The kinds of condition offered, by what stands on the left of the comparison.
const KINDS = [
  ['#TC', 'Total cover of'], ['###', 'Number of species of'], ['species', 'Cover of the species'],
  ['#SC', 'Highest cover of one species of'], ['atleast', 'At least'], ['total', 'Total cover of the plot'],
  ['hnum', 'Site value'], ['hcat', 'Site category'], ['outscore', 'In its set, the group'], ['raw', 'As text'],
];
const OTHER_KINDS = { '##C': 'Summed cover of', '##Q': 'Sum of square-root covers of', '##D': 'Number of species of (set)', plotmax: 'Highest cover of any species' };
const PALETTE = [['#TC', 'Cover of a group'], ['###', 'Number of species'], ['species', 'Cover of a species'], ['#SC', 'Dominant species of a group'], ['hnum', 'Site value'], ['hcat', 'Site category']];
const kindClass = (kind) => ({ '#TC': 'cover', '###': 'count', '##D': 'count', atleast: 'count', species: 'species', '#SC': 'max', hnum: 'site', hcat: 'site', raw: 'raw' }[kind] ?? 'other');
function kindOf(c) {
  if (c.raw !== undefined) return 'raw';
  const l = c.lhs;
  if (l.k === 'measure') return c.op ? l.code : M.isAtLeast(l.code) ? 'atleast' : 'outscore';
  return { name: 'species', total: 'total', hnum: 'hnum', hcat: 'hcat', plotmax: 'plotmax' }[l.k];
}
const pad2 = (v) => String(Math.max(1, Math.min(99, Math.round(Number(v)) || 1))).padStart(2, '0');
const num = (text) => ({ k: 'num', text: String(text) });
const measure = (code, groups) => ({ k: 'measure', code, groups: [...groups], except: [] });
const columnsOf = (type) => (data?.columns ?? []).filter((c) => c.type === type);
// The site columns come with the first test of the data. Until then a condition
// on a column is shown as it will be when its column is there.
const columnsKnown = () => (data?.columns?.length ?? 0) > 0;
function showColumns() {
  const builder = $('builder');
  if (!builder?.querySelector('[data-act="op-col"]')) return;
  if (builder.contains(document.activeElement)) builder.addEventListener('focusout', () => setTimeout(showColumns), { once: true });
  else renderBuilder();
}

// A condition of `kind`, keeping the groups and the number of the condition it replaces.
function conditionOf(kind, prev = null) {
  const old = prev && prev.raw === undefined ? prev : null;
  const groups = old?.lhs.k === 'measure' ? old.lhs.groups : [speciesGroups()[0]?.name ?? ''];
  const value = old?.rhs?.k === 'num' ? old.rhs.text : null;
  switch (kind) {
    case '#TC': case '#SC': case '##C': return { lhs: measure(kind, groups), op: 'GR', rhs: num(value ?? 25) };
    case '###': case '##D': return { lhs: measure(kind, groups), op: 'GE', rhs: num(value ?? 2) };
    case '##Q': return { lhs: measure(kind, groups), op: 'GR', rhs: num(value ?? 5) };
    case 'species': return { lhs: { k: 'name', text: '' }, op: 'GR', rhs: num(value ?? 25) };
    case 'total': return { lhs: { k: 'total', except: [] }, op: 'GE', rhs: num(value ?? 30) };
    case 'plotmax': return { lhs: { k: 'plotmax' }, op: 'GE', rhs: num(value ?? 50) };
    case 'hnum': { const col = columnsOf('number')[0]; return { lhs: { k: 'hnum', col: col?.name ?? '' }, op: 'GR', rhs: num(col?.min ?? 0) }; }
    case 'hcat': { const col = columnsOf('category')[0]; return { lhs: { k: 'hcat', col: col?.name ?? '' }, op: 'EQ', rhs: { k: 'name', text: col?.values[0] ?? '' } }; }
    case 'atleast': return { lhs: measure('#02', groups), op: null, rhs: null };
    case 'outscore': return { lhs: measure('##Q', groups), op: null, rhs: null };
    default: return { raw: prev ? M.serializeCondition(prev) : '' };
  }
}

// What may stand on the right of the comparison, by what stands on the left.
const RHS_LABEL = {
  num: 'the value', share: 'this share of the plot’s total cover:', '#TC': 'the total cover of', '#SC': 'the highest cover of one species of',
  '###': 'the number of species of', total: 'the total cover of all other species', plotmax: 'the highest cover of any species', name: 'the category',
};
const rhsKind = (o) => (o.k === 'measure' ? o.code : o.k);
function rhsKinds(c) {
  const l = c.lhs, code = l.k === 'measure' ? l.code : null;
  let out;
  if (l.k === 'hcat') out = ['name'];
  else if (l.k === 'hnum' || l.k === 'total' || code === '##Q') out = ['num'];
  else if (code === '###' || code === '##D') out = ['num', '###'];
  else out = ['num', 'share', '#TC', '#SC', ...(code === '#TC' ? ['total'] : []), ...(l.k === 'name' || code === '#SC' ? ['plotmax'] : [])];
  return out.includes(rhsKind(c.rhs)) ? out : [...out, rhsKind(c.rhs)];
}
function rhsOf(kind, c) {
  const groups = [speciesGroups()[0]?.name ?? ''];
  switch (kind) {
    case 'num': return num(c.lhs.k === 'measure' && ['###', '##D'].includes(c.lhs.code) ? 2 : 25);
    case 'share': return { k: 'share', pct: '50' };
    case 'total': return { k: 'total', except: [] };
    case 'plotmax': return { k: 'plotmax' };
    case 'name': return { k: 'name', text: '' };
    default: return measure(kind, groups);
  }
}
// The range of the slider for the number of a condition, as [min, max, step], or null.
function numRange(c) {
  const l = c.lhs;
  if (l.k === 'hnum') {
    const col = columnsOf('number').find((x) => x.name === l.col);
    if (!col || col.min == null || !(col.max > col.min)) return null;
    const step = 10 ** Math.floor(Math.log10((col.max - col.min) / 100));
    return [Math.floor(col.min / step) * step, Math.ceil(col.max / step) * step, step];
  }
  if (l.k === 'measure' && ['###', '##D'].includes(l.code)) {
    return [0, Math.max(5, ...l.groups.map((g) => model.groups.find((x) => x.name === g)?.members.length ?? 0)), 1];
  }
  if (l.k === 'measure' && l.code === '##Q') return null;
  return [0, 100, 1];
}

const exceptOpen = new WeakSet();
// The list of groups of a condition ends with an entry that makes a new group
// (no group can have this value as its name). The button after the list shows
// the species of the group chosen.
const NEW_GROUP = '<new>';
let madeGroup = null;         // the id of a group just made from such a list
function groupSelect(current, side, i) {
  const names = speciesGroups().map((g) => g.name).filter(Boolean);
  const options = names.includes(current) ? names : [current, ...names];
  return `<select class="form-select form-select-sm grp-pick${names.includes(current) ? '' : ' missing'}" data-act="op-group" data-side="${side}" data-i="${i}" aria-label="Group">
    ${options.map((n) => `<option value="${h(n)}"${n === current ? ' selected' : ''}>${n ? h(n) : 'choose a group'}${n && !names.includes(n) ? ' (does not exist)' : ''}</option>`).join('')}
    <option value="${h(NEW_GROUP)}">New group…</option></select>`
    + (names.includes(current) ? `<button type="button" class="mini txt" data-act="op-group-show" data-name="${h(current)}" title="Show the species of ${h(current)}">species</button>` : '');
}
// A condition on the total cover of the group `name`.
function condOnGroup(name) {
  const c = conditionOf('#TC');
  c.lhs.groups = [name];
  return M.condNode(c);
}
function exceptHtml(o, side) {
  if (!o.except) return '';
  if (!o.except.length && !exceptOpen.has(o)) {
    return side === 'rhs' ? `<button type="button" class="mini txt" data-act="op-except-show" data-side="${side}" title="Leave groups or species out of this value">except…</button>` : '';
  }
  return `<span class="w">not counting</span><input class="form-control form-control-sm ex" data-act="op-except" data-side="${side}" value="${h(o.except.map(M.exceptName).join(', '))}" placeholder="groups or species, separated by commas" spellcheck="false">`;
}
function measureHtml(o, side) {
  return o.groups.map((g, i) => (i ? '<span class="w">and</span>' : '') + groupSelect(g, side, i)).join('')
    + `<button type="button" class="mini" data-act="op-group-add" data-side="${side}" title="Take another group together with it" aria-label="Add a group">+</button>`
    + (o.groups.length > 1 ? `<button type="button" class="mini" data-act="op-group-del" data-side="${side}" title="Remove the last group" aria-label="Remove the last group">−</button>` : '')
    + exceptHtml(o, side);
}
function columnSelect(o) {
  const cols = columnsOf(o.k === 'hnum' ? 'number' : 'category').map((c) => c.name);
  const options = cols.includes(o.col) ? cols : [o.col, ...cols];
  const missing = (n) => columnsKnown() && !cols.includes(n);
  return `<select class="form-select form-select-sm${missing(o.col) ? ' missing' : ''}" data-act="op-col" aria-label="Site column">
    ${options.map((n) => `<option value="${h(n)}"${n === o.col ? ' selected' : ''}>${n ? h(n) : 'choose a column'}${n && missing(n) ? ' (not in the test plots)' : ''}</option>`).join('')}</select>`;
}
function lhsHtml(c, kind) {
  const l = c.lhs;
  switch (kind) {
    case 'species': return `<input class="form-control form-control-sm sp" data-ta="cond-species" value="${h(l.text)}" placeholder="type a species name" aria-label="Species" autocomplete="off" spellcheck="false">`;
    case 'total': return exceptHtml(l, 'lhs');
    case 'plotmax': return '';
    case 'hnum': case 'hcat': return columnSelect(l);
    case 'atleast': return `<input class="form-control form-control-sm n" type="number" min="1" max="99" data-act="atleast-n" value="${Number(l.code.slice(1))}" aria-label="Number of species"><span class="w">species of</span>${measureHtml(l, 'lhs')}<span class="w">occur</span>`;
    case 'outscore': return `${measureHtml(l, 'lhs')}<span class="w">scores highest</span>`;
    default: return measureHtml(l, 'lhs');
  }
}
function rhsHtml(c) {
  const r = c.rhs, kinds = rhsKinds(c);
  const pickKind = kinds.length > 1
    ? `<select class="form-select form-select-sm" data-act="op-kind" aria-label="Compared with">${kinds.map((k) => `<option value="${k}"${k === rhsKind(r) ? ' selected' : ''}>${RHS_LABEL[k] ?? k}</option>`).join('')}</select>` : '';
  switch (r.k) {
    case 'num': {
      const range = numRange(c), unit = c.lhs.k === 'hnum' || (c.lhs.k === 'measure' && !M.MEASURES[c.lhs.code]?.unit) ? '' : '%';
      const waits = !range && c.lhs.k === 'hnum' && !columnsKnown();
      return `${pickKind}<input class="form-control form-control-sm n" type="number" step="any" data-act="op-num" value="${h(r.text)}" aria-label="Value">${unit ? '<span class="w">%</span>' : ''}`
        + (range ? `<span class="dial"><span class="hist" data-hist></span><input type="range" class="form-range" data-act="op-slider" min="${range[0]}" max="${range[1]}" step="${range[2]}" value="${h(r.text)}" aria-label="Value"></span>` : '')
        + (waits ? '<span class="dial"><span class="hist" data-hist></span><input type="range" class="form-range" disabled aria-label="Value"></span>' : '');
    }
    case 'share': return `${pickKind}<input class="form-control form-control-sm n" type="number" min="1" max="99" data-act="op-pct" value="${Number(r.pct)}" aria-label="Per cent"><span class="w">%</span>`;
    case 'measure': return pickKind + measureHtml(r, 'rhs');
    case 'total': return pickKind + exceptHtml(r, 'rhs');
    case 'name': {
      if (c.lhs.k !== 'hcat') return `${pickKind}<input class="form-control form-control-sm sp" data-act="op-level" value="${h(r.text)}" spellcheck="false">`;
      const values = columnsOf('category').find((x) => x.name === c.lhs.col)?.values ?? [];
      if (!values.length && columnsKnown()) return `<input class="form-control form-control-sm sp" data-act="op-level" value="${h(r.text)}" placeholder="category" aria-label="Category" spellcheck="false">`;
      const options = values.includes(r.text) ? values : [r.text, ...values];
      return `<select class="form-select form-select-sm" data-act="op-level" aria-label="Category">${options.map((v) => `<option value="${h(v)}"${v === r.text ? ' selected' : ''}>${v ? h(v) : 'choose a category'}</option>`).join('')}</select>`;
    }
    default: return pickKind;
  }
}
// A condition inherited from the parent type: as the parent has it, with its
// controls locked (`locked`, `off` when the subtype leaves it out), or the
// subtype's own version of it (`of`, the id of the parent's condition).
// `origin` is the code of the type above whose rule the condition comes from.
function condHtml(n, { locked = false, off = false, of = null, origin = null } = {}) {
  const c = n.c, kind = kindOf(c);
  const kinds = OTHER_KINDS[kind] ? [...KINDS, [kind, OTHER_KINDS[kind]]] : KINDS;
  const body = kind === 'raw'
    ? `<input class="form-control form-control-sm raw" data-act="cond-raw" value="${h(c.raw)}" placeholder="for example #TC Trees GR 25" aria-label="Condition as text" spellcheck="false">`
    : lhsHtml(c, kind) + (c.op ? `<select class="form-select form-select-sm" data-act="cond-op" aria-label="Comparison">${Object.entries(M.OPS).map(([op, words]) => `<option value="${op}"${op === c.op ? ' selected' : ''}>${words}</option>`).join('')}</select>${rhsHtml(c)}` : '');
  // The count, the mark of the selected plot and the button to remove the
  // condition keep the end of the first line; the fields flow around that
  // place (see .cond in maker.css) and stand one after the other, without
  // white space between them.
  const inherited = locked || of;
  const grip = inherited ? (origin ? `<span class="origin" title="A condition of the rule of ${h(origin)}">${h(origin)}</span>` : '') : gripHtml('condition');
  const pick = `<select class="form-select form-select-sm kind" data-act="cond-kind" aria-label="What the condition looks at">${kinds.map(([k, label]) => `<option value="${k}"${k === kind ? ' selected' : ''}>${label}</option>`).join('')}</select>`;
  const id = of ?? n.id;
  const tail = !inherited ? '<button type="button" class="mini x" data-act="node-del" title="Remove this condition" aria-label="Remove this condition">✕</button>'
    : of ? `<button type="button" class="mini" data-act="ov-reset" data-of="${id}" title="Back to the condition of the parent type" aria-label="Back to the condition of the parent type">↺</button>`
      : `<button type="button" class="mini" data-act="${off ? 'ov-reset' : 'ov-change'}" data-of="${id}" title="${off ? 'Take this condition in again' : 'Change this condition for this type alone'}" aria-label="${off ? 'Take this condition in again' : 'Change this condition for this type alone'}">${off ? '↺' : '✎'}</button>
        ${off ? '' : `<button type="button" class="mini x" data-act="ov-off" data-of="${id}" title="Leave this condition out for this type" aria-label="Leave this condition out for this type">⊘</button>`}`;
  const tag = locked ? 'fieldset' : 'div';
  return `<div class="cond k-${kindClass(kind)}${locked ? ' locked' : ''}${off ? ' off' : ''}${of ? ' changed' : ''}" data-node="${n.id}">
    <${tag} class="body"${locked ? ' disabled' : ''}>${grip}${pick}${body.trim()}</${tag}>
    <div class="tail">
      <span class="hits" data-hits="${n.id}">${off ? 'left out' : ''}</span><span class="tick" data-mark></span>
      ${tail}
    </div>
  </div>`;
}
// The full rule of the parent type in the rule of a subtype that inherits it,
// with the subtype's overrides.
// A rule inherited over several levels marks each condition with the type it
// comes from (`origin`: id of a condition -> code; null over one level).
function fromHtml(n, r, root = false, origin = inheritedFrom(r)) {
  if (n.type === 'cond') {
    const o = r.overrides?.[n.id], at = origin?.get(n.id) ?? null;
    return o?.node ? condHtml(o.node, { of: n.id, origin: at }) : condHtml(n, { locked: true, off: Boolean(o?.off), origin: at });
  }
  const zone = (list) => `<div class="inh-zone">${list.map((x) => fromHtml(x, r, false, origin)).join('')}</div>`;
  return `<div class="grp ${n.op === 'OR' ? 'or' : 'and'}${root ? ' root' : ''} locked">
    <p class="grp-head small mb-1">${n.op === 'OR' ? 'At least one of these holds' : 'All of these hold'}</p>
    ${zone(n.items)}
    ${n.not.length ? `<div class="grp-not"><p class="lbl">and none of these holds</p>${zone(n.not)}</div>` : ''}
  </div>`;
}
function groupHtml(n, root = false) {
  const adders = (zone) => `<div class="grp-add">
      <button type="button" class="btn btn-outline-primary btn-sm" data-act="add-cond" data-zone="${zone}">+ Condition</button>
      <button type="button" class="btn btn-outline-secondary btn-sm" data-act="add-group" data-zone="${zone}">+ Group of conditions</button>
      ${zone === 'items' && !n.not.length ? '<button type="button" class="btn btn-outline-secondary btn-sm" data-act="add-cond" data-zone="not">+ Exception</button>' : ''}
    </div>`;
  return `<div class="grp ${n.op === 'OR' ? 'or' : 'and'}${root ? ' root' : ''}${n.id === activeGroup ? ' target' : ''}" data-node="${n.id}">
    <div class="grp-head">
      ${root ? '' : gripHtml('group')}
      <select class="form-select form-select-sm" data-act="grp-op" aria-label="How the conditions combine">
        <option value="AND"${n.op === 'AND' ? ' selected' : ''}>All of these hold</option>
        <option value="OR"${n.op === 'OR' ? ' selected' : ''}>At least one of these holds</option></select>
      ${root ? '' : '<button type="button" class="mini x" data-act="node-del" title="Remove this group" aria-label="Remove this group">✕</button>'}
    </div>
    <div class="zone" data-zone="items">${n.items.map(nodeHtml).join('')}</div>
    ${adders('items')}
    ${n.not.length ? `<div class="grp-not"><p class="lbl">and none of these holds</p>
      <div class="zone" data-zone="not">${n.not.map(nodeHtml).join('')}</div>${adders('not')}</div>` : ''}
  </div>`;
}
const nodeHtml = (n) => (n.type === 'cond' ? condHtml(n) : groupHtml(n));
function gripHtml(kind) {
  return `<span class="grip" draggable="true" tabindex="0" role="button" aria-label="Move ${kind}. Use Alt and arrow up or down." title="Drag to move, or use Alt + Up / Down">⠿</span>`;
}

// The node with `id` in the tree of the rule shown, with the list that holds it,
// or the rule's own version of an inherited condition (`of`: the id of the
// parent's condition, and no list).
function findNode(id) {
  let hit = null;
  const r = rule();
  if (r.tree) M.eachNode(r.tree, (n, parent, list) => { if (n.id === id) hit = { node: n, parent, list }; });
  if (!hit) for (const [of, o] of Object.entries(r.overrides ?? {})) if (o.node?.id === id) hit = { node: o.node, parent: null, list: null, of };
  return hit;
}
let activeGroup = null;       // the group a condition picked from the palette goes into
function renderBuilder() {
  const r = rule();
  if (!r?.tree) return;
  replaceContent($('builder'), groupHtml(r.tree, true));
  showCounts();
}
// After a change to the tree of the rule shown: write its formula, show it.
function treeTouched() {
  const r = rule();
  M.syncRule(r);
  touched.add(r.id);
  const text = $('t-editor').querySelector('[data-act="rule-text"]');
  if (text && !r.problem) text.value = r.expression;
  if ($('t-full')) $('t-full').textContent = fullOf(r).text;
  showVerdict();
  paintTrail();
}
function showVerdict() {
  const r = rule(), el = $('t-verdict');
  if (!r || !el) return;
  const p = M.ruleProblem(r, model.rules), res = test?.byRule.get(r.id);
  el.className = `small mt-2 mb-0${p ? ' error' : ''}`;
  if (p) el.textContent = `Not in the test yet: ${p}.`;
  else if (!res || !test.ok) el.textContent = '';
  else {
    const n = test.n_plots, elsewhere = res.holds - res.assigned;
    el.innerHTML = !res.holds ? `The rule holds in none of the ${plural(n, 'test plot')}.`
      : h(`The rule holds in ${fmt(res.holds)} of ${plural(n, 'test plot')}. ${fmt(res.assigned)} of them ${res.assigned === 1 ? 'is' : 'are'} classified as ${r.code}`
        + (elsewhere > 0 ? `; in ${fmt(elsewhere)} another type has a higher priority, or types tie.` : '.'))
        + ' <button type="button" class="btn btn-link btn-sm p-0 align-baseline" data-act="show-plots" data-show="type">Show the plots</button>';
  }
}
// The number of plots a condition holds in, written next to it and kept by the
// id of the condition: the blocks of a rule are drawn again after every change
// to its structure and show the counts they had until the next test.
const shownHits = new Map();
function writeHits(el, id, hits) {
  if (hits === undefined) shownHits.delete(id); else shownHits.set(id, hits);
  el.textContent = hits === undefined ? '' : plural(hits, 'plot');
  el.title = hits === undefined ? '' : `This condition holds in ${fmt(hits)} of ${fmt(test.n_plots)} test plots`;
  el.classList.toggle('zero', hits === 0);
}
// The counts of the last test next to groups, types and conditions.
function showCounts() {
  const ok = test?.ok;
  for (const el of app.querySelectorAll('[data-group-hits]')) {
    const g = model.groups.find((x) => x.id === el.dataset.groupHits), n = ok && g ? test.groups?.[M.groupKey(g)] : undefined;
    el.textContent = n === undefined ? '' : ` · in ${plural(n, 'plot')}`;
  }
  for (const el of app.querySelectorAll('[data-rule-hits]')) {
    const id = el.dataset.ruleHits, r = model.rules.find((x) => x.id === id), res = ok ? test.byRule.get(id) : null;
    el.textContent = r && M.ruleProblem(r, model.rules) ? ' · unfinished' : res ? ` · ${plural(res.assigned, 'plot')}` : '';
    el.classList.toggle('error', Boolean(r && M.ruleProblem(r, model.rules)));
  }
  // A type with subtypes also counts the plots of its whole branch.
  const rows = M.typeTree(model.rules);
  for (const el of app.querySelectorAll('[data-branch-hits]')) {
    const ids = branchIds(el.dataset.branchHits, rows);
    const n = ok ? ids.reduce((s, id) => s + (test.byRule.get(id)?.assigned ?? 0), 0) : null;
    el.textContent = n === null ? '' : `${fmt(n)} with subtypes`;
    el.title = n === null ? '' : `${plural(n, 'plot')} ${n === 1 ? 'is' : 'are'} classified as this type or one of its subtypes`;
  }
  // Below the types: the plots no type takes.
  const t = tally();
  $('t-rest').innerHTML = !ok || !t.n ? '' : [['none', 'Not classified', t.none], ['tie', 'Tied between types', t.tie]]
    .map(([show, label, n]) => `<li data-act="show-plots" data-show="${show}" class="${sel.rest === REST[show] ? 'active' : ''}" tabindex="0"><span class="nm">${label}</span><span class="meta">${plural(n, 'plot')}</span><span class="dots" data-dots="${show === 'none' ? '?' : '+'}"></span></li>`).join('');
  drawDots();
  const r = rule();
  if (r?.tree) {
    // A rule changed since the last test keeps the counts its conditions had;
    // those of the last test are theirs as long as it has as many conditions.
    const res = ok && !M.ruleProblem(r, model.rules) ? test.byRule.get(r.id) : null, kept = ok && touched.has(r.id);
    const last = res?.conds?.length === orderOf(r).length ? res.conds : null;
    orderOf(r).forEach((n, k) => {
      const el = $('t-editor').querySelector(`[data-hits="${n.id}"]`);
      if (el) writeHits(el, n.id, kept ? shownHits.get(n.id) ?? last?.[k] : res?.conds?.[k]);
    });
    showVerdict();
    paintHists();
  }
}

// Applies the value of a control of a condition or group to the tree. Returns
// true when the blocks have to be drawn again.
function applyControl(el) {
  const at = findNode(el.closest('[data-node]').dataset.node);
  if (!at) return false;
  const n = at.node, c = n.c, act = el.dataset.act, side = el.dataset.side, v = el.value;
  const o = c && side ? c[side] : null;
  switch (act) {
    case 'grp-op': n.op = v; return true;
    case 'cond-kind': n.c = conditionOf(v, c); return true;
    case 'cond-op': c.op = v; return false;
    case 'op-kind': c.rhs = rhsOf(v, c); return true;
    case 'op-group': {
      let name = v;
      if (v === NEW_GROUP) { const g = addGroup(); madeGroup = g.id; name = g.name; }
      o.groups[Number(el.dataset.i)] = name;
      return true;
    }
    case 'op-col': c.lhs.col = v; if (c.lhs.k === 'hcat') c.rhs = { k: 'name', text: columnsOf('category').find((x) => x.name === v)?.values[0] ?? '' }; return true;
    case 'op-level': c.rhs.text = v.trim(); return false;
    case 'op-num': case 'op-slider': {
      c.rhs.text = v.trim();
      const twin = el.closest('.cond').querySelector(`[data-act="${act === 'op-num' ? 'op-slider' : 'op-num'}"]`);
      if (twin) twin.value = v;
      return false;
    }
    case 'op-pct': c.rhs.pct = pad2(v); return false;
    case 'atleast-n': c.lhs.code = `#${pad2(v)}`; return false;
    case 'cond-raw': c.raw = v.replace(/\s+/g, ' ').trim(); return false;
    case 'op-except': {
      const names = groupNames(), code = o.k === 'measure' ? o.code : '#TC';
      o.except = v.split(',').map((s) => s.replace(/\s+/g, ' ').trim()).filter(Boolean).map((s) => (names.has(s) ? `${code} ${s}` : s));
      return false;
    }
    default: return false;
  }
}
function addNode(parent, list, node, index = parent[list].length) {
  parent[list].splice(index, 0, node);
  if (node.type === 'group') activeGroup = node.id;
  treeTouched();
  renderBuilder();
  commit();
  const el = $('builder').querySelector(`[data-node="${node.id}"]`);
  el?.querySelector('.sp, .grp-pick, .raw, select')?.focus({ preventScroll: true });
  el?.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
}

// Dragging: a block by its grip, or a kind of condition from the palette, into
// the list of a group, at the place the pointer is.
let drag = null;
function dropPlace(e) {
  const zone = e.target.closest('.zone');
  if (!zone || !drag) return null;
  const target = findNode(zone.closest('[data-node]').dataset.node);
  if (!target) return null;
  if (drag.id) {
    let inside = false;
    M.eachNode(findNode(drag.id).node, (x) => { if (x === target.node) inside = true; });
    if (inside) return null;
  }
  const blocks = [...zone.children].filter((el) => el.dataset.node);
  let index = blocks.findIndex((el) => { const b = el.getBoundingClientRect(); return e.clientY < b.top + b.height / 2; });
  if (index < 0) index = blocks.length;
  return { zone, group: target.node, list: zone.dataset.zone, index, before: blocks[index] ?? null };
}
function clearDrop() {
  for (const el of app.querySelectorAll('.drop-into, .drop-before')) el.classList.remove('drop-into', 'drop-before');
}

// ---- Typeahead for species names ------------------------------------------------------------------
// One list for every field with `data-ta`: the species of the list and of the
// test plots, those in many plots first. A name that is not in the species list
// yet is added to it when picked.
let pool = null;
const ta = { input: null, items: [], at: 0 };
function speciesPool() {
  if (!pool) {
    const names = new Set([...model.synonyms.keys(), ...(data ? data.species.keys() : [])]);
    pool = [...names].map((name) => ({ name, lower: name.toLowerCase(), plots: plotsOf(name) }))
      .sort((a, b) => b.plots - a.plots || byName(a.name, b.name));
  }
  return pool;
}
function taShow(input) {
  const q = input.value.trim().toLowerCase();
  if (!q) return taHide();
  const skip = input.dataset.ta === 'member' ? new Set(group()?.members) : new Set();
  const starts = [], inside = [];
  for (const s of speciesPool()) {
    if (skip.has(s.name)) continue;
    if (s.lower.startsWith(q)) starts.push(s); else if (inside.length < 30 && s.lower.includes(q)) inside.push(s);
    if (starts.length >= 30) break;
  }
  Object.assign(ta, { input, items: [...starts, ...inside].slice(0, 30), at: 0 });
  if (!ta.items.length) return taHide();
  const list = $('ta'), box = input.getBoundingClientRect(), frame = app.getBoundingClientRect();
  input.setAttribute('role', 'combobox');
  input.setAttribute('aria-autocomplete', 'list');
  input.setAttribute('aria-controls', 'ta');
  input.setAttribute('aria-expanded', 'true');
  list.style.left = `${box.left - frame.left}px`;
  list.style.top = `${box.bottom - frame.top + 2}px`;
  list.style.width = `${Math.min(Math.max(box.width, 300), frame.right - box.left)}px`;
  taDraw();
  list.hidden = false;
}
function taDraw() {
  $('ta').innerHTML = ta.items.map((s, i) => `<li id="ta-option-${i}" role="option" aria-selected="${i === ta.at}" data-i="${i}" class="${i === ta.at ? 'active' : ''}">${h(s.name)}
    <span class="meta">${s.plots ? `${fmt(s.plots)} plot${s.plots === 1 ? '' : 's'}` : ''}${model.synonyms.has(s.name) ? '' : ' · new in the list'}</span></li>`).join('');
  ta.input?.setAttribute('aria-activedescendant', `ta-option-${ta.at}`);
  $('ta').children[ta.at]?.scrollIntoView({ block: 'nearest' });
}
function taHide() {
  $('ta').hidden = true;
  ta.input?.setAttribute('aria-expanded', 'false');
  ta.input?.removeAttribute('aria-activedescendant');
  ta.input = null;
}
function taPick(name) {
  const input = ta.input ?? document.activeElement;
  name = name.replace(/\s+/g, ' ').trim();
  taHide();
  if (!name || !input?.dataset.ta) return;
  if (input.dataset.ta === 'member') {
    const g = group();
    if (addMembers(g, [name])) groupsChanged();
    $('g-editor').querySelector('[data-ta="member"]')?.focus();
  } else {
    const at = findNode(input.closest('[data-node]').dataset.node);
    at.node.c.lhs.text = name;
    input.value = name;
    if (!model.synonyms.has(name) && data?.species.has(name)) { model.synonyms.set(name, [...data.species.get(name).variants]); synDirty = true; pool = null; }
    treeTouched();
    commit();
  }
}

// ---- The test plots as dots, and the values behind a condition ------------------------------------
// Under each type stand the plots of the last test that are classified as it,
// one dot per plot (one dot for several plots when there are more than
// DOT_CELLS). The dots lit are the plots in which a rule of the type shown
// holds, or the plots of what the pointer is on: a condition, a type, a group.
const DOT_CELLS = 1500;
const CMP = { GR: (a, b) => a > b, GE: (a, b) => a >= b, EQ: (a, b) => a === b };
let moved = null;        // the plots whose type changed in the last test, until they are drawn
let rulePlots = null;    // of the rule shown in the last test: { test, rule, conds: [{ plots, value }], byNode: Map(id of a condition -> { lhs: its left side, value }) }
let glow = null;         // what the pointer is on: { key, note, plots: () => Set | null }
let lit = null;          // the plots lit
let hovered = null;      // the group whose plots are being read for the pointer

async function loadRulePlots() {
  const r = rule(), t = test, i = t?.ok && r?.tree ? t.index.get(r.id) : undefined;
  if (rulePlots && rulePlots.rule !== r?.id) rulePlots = null;
  if (i === undefined || (rulePlots?.test === t && rulePlots.rule === r.id)) return;
  let out;
  try { out = await rJson(`resy_maker_rule_plots(${i + 1})`); } catch (e) { console.warn('[maker] plots of the rule not read', e); return; }
  if (test !== t || touched.has(r.id) || out.conds.length !== orderOf(r).length) return;
  rulePlots = { test: t, rule: r.id, conds: out.conds, byNode: new Map(orderOf(r).map((n, k) => [n.id, { lhs: JSON.stringify(n.c.lhs ?? null), value: out.conds[k].value ?? null }])) };
  if (sel.rule === r.id) { paintHists(); lightDots(); }
}
// What the left side of condition `k` of the rule shown measures in each plot.
// The values of the test before stay in use while those of the last test are
// read: a changed number leaves them as they are, and so does a condition
// added, moved or removed beside this one.
function condValues(k) {
  const r = rule(), n = (r ? orderOf(r)[k] : undefined), was = n && rulePlots?.rule === r.id ? rulePlots.byNode.get(n.id) : null;
  return was && JSON.stringify(n.c.lhs ?? null) === was.lhs ? was.value : null;
}
// The plots in which condition `k` of the rule shown holds: counted here from
// the values when the condition compares them with a number, so a number being
// changed shows its plots before the next test; from the last test otherwise.
function condPlots(k) {
  const r = rule(), c = (r ? orderOf(r)[k]?.c : undefined), v = condValues(k);
  if (!c) return null;
  if (v && c.rhs?.k === 'num' && CMP[c.op] && c.rhs.text.trim() !== '' && !Number.isNaN(Number(c.rhs.text))) {
    const x = Number(c.rhs.text), holds = CMP[c.op], out = new Set();
    v.forEach((a, i) => { if (holds(a, x)) out.add(i); });
    return out;
  }
  return rulePlots?.test === test && rulePlots.rule === r.id && !touched.has(r.id) ? new Set(rulePlots.conds[k]?.plots) : null;
}
function litPlots() {
  if (glow) return glow.plots();
  const p = test.plots, out = new Set();
  if (sel.rest) {
    p.code.forEach((c, i) => { if (c === sel.rest) out.add(i); });
    return out;
  }
  const code = rule()?.code;
  if (!code) return null;
  for (let i = 0; i < p.id.length; i++) if (holdsIn(i, code)) out.add(i);
  return out;
}
function drawDots() {
  const p = test?.ok ? test.plots : null, fresh = moved;
  moved = null;
  const boxes = app.querySelectorAll('[data-dots]');
  if (!p) { for (const el of boxes) el.innerHTML = ''; $('t-lit').hidden = true; return; }
  const per = Math.ceil(p.id.length / DOT_CELLS), by = new Map();
  p.code.forEach((c, i) => { if (!by.has(c)) by.set(c, []); by.get(c).push(i); });
  const order = model.rules.map((r) => r.code);
  for (const el of boxes) {
    const at = by.get(el.dataset.dots) ?? [];
    el.dataset.per = per;
    el.style.setProperty('--c', typeColour(el.dataset.dots, order));
    el.innerHTML = per === 1
      ? at.map((i) => `<i data-plot="${i}"${fresh?.has(i) ? ' class="moved"' : ''} title="Plot ${h(p.id[i])}"></i>`).join('')
      : '<i></i>'.repeat(Math.ceil(at.length / per));
    el.title = per === 1 ? '' : `One dot for ${fmt(per)} plots`;
  }
  lightDots();
}
function lightDots() {
  const p = test?.ok ? test.plots : null;
  if (!p) return;
  // While the plots of a changed condition are not known yet, those lit before stay.
  const now = litPlots(), on = now ?? lit, by = new Map();
  lit = on;
  for (const el of app.querySelectorAll('[data-dots]')) {
    if (el.dataset.per === '1') {
      for (const d of el.children) {
        const i = Number(d.dataset.plot);
        d.classList.toggle('on', Boolean(on?.has(i)));
        d.classList.toggle('sel', p.id[i] === sel.plot);
      }
      continue;
    }
    // Several plots to a dot: as many dots are lit as their plots make up.
    if (!by.size && on) for (const i of on) by.set(p.code[i], (by.get(p.code[i]) ?? 0) + 1);
    const n = Math.round((by.get(el.dataset.dots) ?? 0) / Number(el.dataset.per));
    [...el.children].forEach((d, k) => d.classList.toggle('on', k < n));
  }
  if (!now) return;
  drawMap();
  const code = rule()?.code, note = glow ? glow.note(on.size)
    : sel.rest ? `${plural(on.size, 'plot')} ${sel.rest === '?' ? 'not classified' : 'tied between types'}`
    : code ? `${plural(on.size, 'plot')} meet the rule of ${code}` : '';
  // The dot before the note has the colour of the type whose plots are lit.
  const tint = glow?.key.startsWith('g') ? '' : ` style="background:${typeColour(sel.rest ?? code)}"`;
  $('t-lit').innerHTML = `<i class="dot"${tint}></i> ${h(note)}`;
  $('t-lit').hidden = !note;
}
// The plots of the test data on a map, when the sites file gives their
// position, in the colour of their type: the plots lit in front, the other
// tested plots faded behind them, those outside the region tested in a pale
// grey. With nothing lit all tested plots are in front. A click selects a
// tested plot.
const plotMap = createDotMap('t-map', () => {
  const p = test?.ok ? test.plots : null, on = lit, placed = data?.placed ?? [], of = p ? test.onMap : null;
  const order = model.rules.map((r) => r.code), colours = new Map();
  const faded = cssColour('--lv-none', '#9a9d96'), outside = cssColour('--bs-gray-500', '#adb5bd');
  const colourOfPlot = (i) => {
    const c = p.code[i];
    if (!colours.has(c)) colours.set(c, typeColour(c, order));
    return colours.get(c);
  };
  const chosen = p && sel.plot !== null ? placed.findIndex((x) => x.id === sel.plot) : -1;
  return {
    n: placed.length,
    shown: p ? p.id.length : placed.length,
    x: (j) => placed[j].x,
    y: (j) => placed[j].y,
    state: (j) => (of && of[j] >= 0 && (!on || on.has(of[j])) ? 1 : 0),
    colour: (j, inFront) => (of && of[j] >= 0 ? (inFront ? colourOfPlot(of[j]) : faded) : outside),
    picks: (j) => Boolean(of && of[j] >= 0),
    selected: chosen < 0 ? null : chosen,
  };
}, (j) => pickPlot(data.placed[j].id));
function drawMap() {
  if (!$('t-mapbox').hidden) plotMap.redraw();
}
// A rectangle drawn on the map limits the test to the plots in it; `box` is
// that rectangle (see drawBox() in resy_map.js), or null for all plots.
async function setRegion(box) {
  const ids = box ? data.placed.filter((p) => p.x >= box.x0 && p.x <= box.x1 && p.y >= box.y0 && p.y <= box.y1).map((p) => p.id) : null;
  if (ids && !ids.length) { $('map-note').textContent = 'No plot lies in this rectangle.'; return; }
  if (ids) {
    await rWrite(`${DIR}/region.json`, JSON.stringify(ids));
    await rVoid(`resy_maker_region("${DIR}/region.json")`);
  } else await rVoid('resy_maker_region()');
  data.region = box;
  if (test) test.json = null;
  plotMap.showBox(box);
  $('map-all').hidden = !box;
  $('map-note').textContent = '';
  showChrome();
  scheduleTest(0);
}
const regionFailed = (e) => { console.error(e); $('map-note').textContent = cleanError(e); };
$('map-region').addEventListener('click', () => {
  if (plotMap.drawing || !plotMap.map) return;
  $('map-region').setAttribute('aria-pressed', 'true');
  $('map-note').textContent = 'Drag a rectangle on the map. Escape cancels.';
  plotMap.drawBox((box) => {
    $('map-region').setAttribute('aria-pressed', 'false');
    $('map-note').textContent = '';
    if (box) setRegion(box).catch(regionFailed);
  });
});
$('map-all').addEventListener('click', () => setRegion(null).catch(regionFailed));
function setGlow(next) {
  if ((glow?.key ?? null) === (next?.key ?? null)) return;
  glow = next;
  lightDots();
}
// The histogram above the slider of a condition: the plots of the last test by
// the value the condition compares, the part of each bar that meets the
// condition in the colour of the condition. Bar heights follow the logarithm
// of the number of plots, so a few plots stay visible beside many.
function paintHist(k) {
  const r = rule(), n = orderOf(r)[k], c = n.c;
  const el = $('t-editor').querySelector(`.cond[data-node="${n.id}"] [data-hist]`);
  if (!el) return;
  const v = condValues(k), range = numRange(c), holds = CMP[c.op], x = Number(c.rhs.text);
  if (!range || !holds) { el.innerHTML = ''; return; }
  if (!v) return;
  const [lo, hi, step] = range, places = Math.round((hi - lo) / step) + 1, each = places <= 41;
  const bins = each ? places : 50, width = each ? step : (hi - lo) / bins;
  const total = new Array(bins).fill(0), met = new Array(bins).fill(0);
  for (const a of v) {
    const j = Math.max(0, Math.min(bins - 1, each ? Math.round((a - lo) / step) : Math.floor((a - lo) / width)));
    total[j]++;
    if (holds(a, x)) met[j]++;
  }
  const top = Math.max(...total), short = (a) => Number(a.toFixed(4));
  el.innerHTML = total.map((t, j) => {
    if (!t) return '';
    const at = each ? j / (bins - 1) : (j + 0.5) / bins;
    const where = each ? `at ${short(lo + j * step)}` : `from ${short(lo + j * width)} to ${short(lo + (j + 1) * width)}`;
    return `<i style="left:calc(8px + (100% - 16px) * ${at.toFixed(4)});width:calc((100% - 16px) / ${each ? bins - 1 : bins} - 1px);height:${(100 * Math.log1p(t) / Math.log1p(top)).toFixed(0)}%" title="${plural(t, 'plot')} ${where}, ${fmt(met[j])} meet the condition"><b style="height:${(100 * met[j] / t).toFixed(0)}%"></b></i>`;
  }).join('');
}
function paintHists() {
  (rule() ? orderOf(rule()) : []).forEach((_, k) => paintHist(k));
}
// While the number of a condition is changed: its plots, counted from the values of the last test.
function liveCond(id) {
  const k = orderOf(rule()).findIndex((n) => n.id === id), on = k < 0 || !condValues(k) ? null : condPlots(k);
  if (!on) return;
  const el = $('t-editor').querySelector(`[data-hits="${id}"]`);
  if (el) writeHits(el, id, on.size);
  paintHist(k);
  lightDots();
}
async function groupPlots(g) {
  const t = test, key = M.groupKey(g);
  if (!t.groupPlots.has(key)) t.groupPlots.set(key, new Set(await rJson(`resy_maker_group_plots(${rString(key)})`)));
  return t.groupPlots.get(key);
}
// The pointer resting on a condition, a type or a group lights its plots. What
// it only passes over on its way lights nothing.
let aim = null;
function aimGlow(next) {
  clearTimeout(aim);
  aim = setTimeout(() => setGlow(next), 180);
}
app.addEventListener('mouseover', async (e) => {
  if (!test?.ok || !test.plots) return;
  const cond = e.target.closest('#t-editor .cond[data-node]'), type = e.target.closest('#t-list li[data-id]'), grp = e.target.closest('#g-list > li[data-id]');
  if (!grp) hovered = null;
  if (cond) {
    const k = (rule() ? orderOf(rule()) : []).findIndex((n) => n.id === cond.dataset.node) ?? -1;
    return aimGlow(k < 0 ? null : { key: `c${cond.dataset.node}`, note: (n) => `${plural(n, 'plot')} meet this condition`, plots: () => condPlots(k) });
  }
  if (type) {
    const r = model.rules.find((x) => x.id === type.dataset.id);
    if (!r || (r.id === sel.rule && !sel.rest) || !test.byRule.get(r.id)) return aimGlow(null);
    const on = new Set();
    for (let i = 0; i < test.plots.id.length; i++) if (holdsIn(i, r.code)) on.add(i);
    return aimGlow({ key: `t${r.id}`, note: (n) => `${plural(n, 'plot')} meet the rule of ${r.code}`, plots: () => on });
  }
  if (grp) {
    const g = model.groups.find((x) => x.id === grp.dataset.id), key = `g${grp.dataset.id}`, t = test;
    if (!g || hovered === key || !(M.groupKey(g) in (test.groups ?? {}))) return;
    hovered = key;
    let on;
    try { on = await groupPlots(g); } catch (err) { console.warn('[maker] plots of the group not read', err); return; }
    if (hovered === key && test === t) aimGlow({ key, note: (n) => `${plural(n, 'plot')} with a species of ${g.name}`, plots: () => on });
    return;
  }
  if (!(glow?.key.startsWith('c') && e.target.closest('#builder'))) aimGlow(null);
});
app.addEventListener('mouseleave', () => { hovered = null; aimGlow(null); });

// ---- Plots ----------------------------------------------------------------------------------------
// The plots of the last test, listed beside the rule. `sel.show` says which:
// all of them, those in which a rule of the type shown holds, those without a
// type, or those tied between types.
const holdsIn = (i, code) => test.plots.code[i] === code || ` ${test.plots.candidates[i]} `.includes(` ${code} `);
function renderPlots() {
  const t = tally(), code = rule()?.code, p = test?.plots;
  let held = 0;
  if (p && code) for (let i = 0; i < p.id.length; i++) if (holdsIn(i, code)) held++;
  const options = [['all', `All plots (${fmt(t.n)})`], ...(p && code ? [['type', `A rule of ${code} holds (${fmt(held)})`]] : []),
    ['none', `Not classified (${fmt(t.none)})`], ['tie', `Tied between types (${fmt(t.tie)})`]];
  if (!options.some(([key]) => key === sel.show)) sel.show = 'all';
  $('show').innerHTML = options.map(([key, label]) => `<option value="${key}"${key === sel.show ? ' selected' : ''}>${h(label)}</option>`).join('');
  const said = (key) => [...new Set([...(validation?.[key] ?? []), ...(test?.[key] ?? [])])];
  const notes = [...said('errors').map((e) => `Error: ${e}`), ...said('warnings')];
  const unfinished = model.rules.filter((r) => M.ruleProblem(r, model.rules)).length;
  if (unfinished) notes.unshift(`${plural(unfinished, 'type')} ${unfinished === 1 ? 'is' : 'are'} unfinished and not in the test.`);
  if (!model.rules.length) notes.unshift('The system has no types yet, so no plot is classified.');
  // The notes open under their number; an error among them opens them.
  $('warnings').innerHTML = notes.map((w) => `<li>${h(w)}</li>`).join('');
  $('notes').hidden = !notes.length;
  $('notes-n').textContent = `${plural(notes.length, 'note')} on the system and the test`;
  renderRows();
}
function renderRows() {
  const q = $('q').value.trim().toLowerCase(), p = test?.plots, code = rule()?.code, rows = [];
  const want = { all: () => true, type: (i) => holdsIn(i, code), none: (i) => p.code[i] === '?', tie: (i) => p.code[i] === '+' }[sel.show];
  let total = 0;
  for (let i = 0; p && i < p.id.length; i++) {
    if (!want(i)) continue;
    if (q && !`${p.id[i]} ${p.code[i]} ${nameOf(p.code[i])}`.toLowerCase().includes(q)) continue;
    total++;
    if (rows.length < 500) rows.push(i);
  }
  replaceContent($('rows'), rows.map((i) => `<tr data-id="${h(p.id[i])}" class="${p.id[i] === sel.plot ? 'table-active' : ''}" title="${h(nameOf(p.code[i]))}">
    <td><button type="button" class="plot-pick btn btn-link btn-sm p-0" data-act="plot-pick" aria-label="Explain plot ${h(p.id[i])}">${h(p.id[i])}</button></td><td><b>${h(p.code[i])}</b></td><td>${h(p.candidates[i])}</td></tr>`).join(''));
  $('shown').innerHTML = [
    !p ? '' : total > rows.length ? `${fmt(total)} plots, first ${rows.length} listed.` : !total ? 'No plot.' : sel.plot === null ? 'Select a plot to see why it has its type.' : '',
    p && sel.plot !== null ? plotNote() : '',
  ].filter(Boolean).join(' ');
}
// What selecting a plot has put on the page, and the way to its explanation,
// which stands below the rule.
function plotNote() {
  const code = test.plots.code[test.plots.id.indexOf(sel.plot)], shown = rule()?.code;
  const what = code === '?' ? 'has no type' : code === '+' ? 'is tied between types' : `is classified as ${code}`;
  const marks = !shown ? '' : shown === code ? ' Its rule is the one shown: ✓ and ✗ mark the conditions the plot meets and misses.'
    : ` ✓ and ✗ mark the conditions of ${shown} it meets and misses.`;
  return `Plot ${h(sel.plot)} ${h(what)}.${h(marks)} <button type="button" class="btn btn-link btn-sm p-0 align-baseline" data-act="show-detail">Why this type?</button>`;
}
// Selects the plots no type takes ('?'), those tied between types ('+'), or
// neither (null): their entry below the types is marked and their plots lit.
function setRest(code) {
  if (sel.rest === code) return;
  sel.rest = code;
  for (const li of $('t-rest').querySelectorAll('li[data-show]')) li.classList.toggle('active', REST[li.dataset.show] === code);
  for (const li of $('t-list').querySelectorAll('li[data-id]')) li.classList.toggle('active', !code && li.dataset.id === sel.rule);
  lightDots();
}
function showPlots(show) {
  sel.show = show;
  setRest(REST[show] ?? null);
  showTab('plots');
  $('pane-parts').scrollIntoView({ block: 'nearest', behavior: 'smooth' });
}

// One plot: why it has its type, below the bench, and in the rule shown the
// conditions it meets and misses.
function clearDetail() {
  sel.plot = null;
  trail = null;
  $('detail').hidden = true;
  for (const tr of $('rows').querySelectorAll('.table-active')) tr.classList.remove('table-active');
  paintTrail();
  lightDots();
}
// Selecting a plot explains it and selects what it is classified as: its type,
// or the plots no type takes, or those tied. From the list of the plots that
// meet the rule shown, the type shown stays.
function pickPlot(id, showType = true) {
  const code = test.plots.code[test.plots.id.indexOf(id)];
  if (showType) {
    const r = model.rules.find((x) => x.code === code);
    if (code === '?' || code === '+') setRest(code);
    else if (r && (r.code !== rule()?.code || sel.rest)) openRule(r.id);
  }
  explain(id);
}
const evaluatePlot = (id, type = null) => rJson(`resy_maker_explain(${rString(id)}${type ? `, type = ${rString(type)}` : ''})`);
async function explain(id, again = false) {
  sel.plot = id;
  renderRows();
  lightDots();
  const code = test.plots.code[test.plots.id.indexOf(id)];
  $('d-title').textContent = `Plot ${id}: ${code} ${nameOf(code)}`;
  $('detail').hidden = false;
  $('detail').setAttribute('aria-busy', 'true');
  if (!$('d-body').hasChildNodes()) $('d-body').innerHTML = '<p class="text-body-secondary mb-0">Evaluating…</p>';
  markTrail();
  try {
    const ev = await evaluatePlot(id);
    if (sel.plot === id) $('d-body').innerHTML = evidenceHtml(ev, nameOf);
  } catch (e) {
    if (sel.plot === id) $('d-body').textContent = cleanError(e);
  } finally {
    if (sel.plot === id) $('detail').setAttribute('aria-busy', 'false');
  }
}
// The conditions of the rule shown that the selected plot meets, from the last test.
let trail = null;       // { plot, rule: its id, holds, conds: [true | false | null] }
async function markTrail() {
  const r = rule(), id = sel.plot;
  if (trail?.plot !== id || trail.rule !== r?.id || id === null) { trail = null; paintTrail(); }
  if (!r?.tree || id === null || !test?.ok || touched.has(r.id) || !test.byRule.get(r.id)) return;
  // A code can carry several rules; RESY returns them in the order of the system.
  const k = model.rules.filter((x) => x.code === r.code && test.byRule.has(x.id)).indexOf(r);
  let found;
  try { found = (await evaluatePlot(id, r.code)).types?.[0]?.rules?.[k]; } catch (e) { console.warn('[maker] plot not evaluated', e); return; }
  if (sel.plot !== id || sel.rule !== r.id || touched.has(r.id) || found?.conditions?.length !== orderOf(r).length) return;
  trail = { plot: id, rule: r.id, holds: found.holds, conds: found.conditions.map((c) => c.satisfied) };
  paintTrail();
}
function paintTrail() {
  const editor = $('t-editor'), r = rule(), line = $('t-trail');
  const on = Boolean(trail && r && trail.rule === r.id && trail.conds.length === orderOf(r).length);
  for (const el of editor.querySelectorAll('.cond')) el.classList.remove('held', 'failed');
  for (const el of editor.querySelectorAll('[data-mark]')) { el.textContent = ''; el.removeAttribute('title'); }
  // The line stays while a plot is selected, so the rule keeps its height
  // while the marks of the next plot are read.
  if (line) {
    line.hidden = sel.plot === null || !r?.tree;
    if (!on && !line.hidden) line.textContent = `Plot ${sel.plot}`;
  }
  if (!on || !line) return;
  orderOf(r).forEach((n, k) => {
    const el = editor.querySelector(`.cond[data-node="${n.id}"]`), ok = trail.conds[k];
    if (!el || typeof ok !== 'boolean') return;
    el.classList.add(ok ? 'held' : 'failed');
    const mark = el.querySelector('[data-mark]');
    mark.textContent = ok ? '✓' : '✗';
    mark.title = `Plot ${trail.plot} ${ok ? 'meets' : 'does not meet'} this condition`;
  });
  line.innerHTML = `Plot ${h(trail.plot)}: the rule ${trail.holds ? 'holds' : 'does not hold'}. ✓ and ✗ mark the conditions the plot meets and misses.
    <button type="button" class="btn btn-link btn-sm p-0 align-baseline" data-act="trail-clear">Clear</button>`;
}
function renderPlotsSheet() {
  $('data-note').textContent = data ? `The system is tested on ${data.label}: ${plural(data.n_plots, 'plot')} with ${fmt(data.n_records)} species records. Choose your own files to test on your plots instead (up to ${TEST_LIMIT_MB} MB of species records; the RESY App classifies files of any size).` : '';
  $('data-example').hidden = !data || data.example;
}

// The test plots are handed to R whole, as two tab-separated files with fixed
// column names: the species records, and the sites with all their columns.
const TEST_LIMIT_MB = 30;
const rowsOf = async (file) => {
  const { delim, cols } = await readHeader(file);
  const lines = (await file.text()).replace(/^﻿/, '').split(/\r?\n/);
  lines.shift();
  return { cols, rows: lines.filter(Boolean).map((l) => splitFields(l, delim)) };
};
async function setData(speciesFile, sitesFile, label, example, columns = null) {
  if (speciesFile.size > TEST_LIMIT_MB * 1e6) throw new Error(`The species file is larger than ${TEST_LIMIT_MB} MB. Test on a part of it, and classify the whole file in the RESY App.`);
  const sp = await rowsOf(speciesFile);
  const col = Object.fromEntries(SPECIES_COLS.map(([key]) => [key, sp.cols.indexOf(columns?.[key] ?? pick(sp.cols, key))]));
  for (const [key] of SPECIES_COLS) if (col[key] < 0) throw new Error(`Choose the ${SPECIES_COL_LABEL[key]} column of the species file.`);
  const species = ['PlotObservationID\tname\tcover', ...sp.rows.map((f) => `${tsvValue(f[col.id])}\t${tsvValue(f[col.name])}\t${tsvValue(f[col.cover])}`)].join('\n') + '\n';
  const si = await rowsOf(sitesFile);
  const id = pick(si.cols, 'id');
  if (!id) throw new Error(`The sites file needs the column \`PlotObservationID\`. It has: ${si.cols.map((c) => `\`${c}\``).join(', ')}.`);
  const rename = new Map([[id, 'PlotObservationID'], [pick(si.cols, 'lon'), 'Longitude'], [pick(si.cols, 'lat'), 'Latitude']]);
  const sites = [si.cols.map((c) => tsvValue(rename.get(c) ?? c)).join('\t'), ...si.rows.map((f) => si.cols.map((_, k) => tsvValue(f[k])).join('\t'))].join('\n') + '\n';
  const at = { id: si.cols.indexOf(id), lon: si.cols.indexOf(pick(si.cols, 'lon')), lat: si.cols.indexOf(pick(si.cols, 'lat')) };
  const place = new Map(at.lon < 0 || at.lat < 0 ? [] : si.rows.map((f) => [f[at.id], placeOf(parseFloat(f[at.lon]), parseFloat(f[at.lat]))]).filter(([, p]) => !Number.isNaN(p[0])));
  await rWrite(`${DIR}/species.tsv`, species);
  await rWrite(`${DIR}/sites.tsv`, sites);
  const out = await rJson(`resy_maker_set_data("${DIR}/species.tsv", "${DIR}/sites.tsv")`);
  data = { label, example, n_plots: out.n_plots, n_records: out.n_records, species: new Map(out.species.map((s) => [s.name, s])), columns: [],
    placed: [...place].map(([plot, p]) => ({ id: plot, x: p[0], y: p[1] })), region: null };
  plotMap.fitted = false;
  plotMap.showBox(null);
  $('map-all').hidden = true;
  $('t-mapbox').hidden = !place.size;
  pool = null;
  test = null;
  clearDetail();
}
const examples = { files: null };
async function useExamples() {
  await setData(examples.files[0], examples.files[1], 'the example plots shipped with RESY (Tuscany)', true);
}
async function useOwnData() {
  const sp = $('f-species').files[0], si = $('f-sites').files[0];
  $('data-status').classList.remove('error');
  $('data-status').textContent = 'Reading the files…';
  $('data-use').disabled = true;
  try {
    await setData(sp, si, `${sp.name} and ${si.name}`, false, Object.fromEntries(SPECIES_COLS.map(([key, id]) => [key, $(id).value])));
    $('data-status').textContent = '';
    changed();
    showSheet(null);
    render();
  } catch (e) {
    console.error(e);
    $('data-status').textContent = cleanError(e);
    $('data-status').classList.add('error');
  } finally {
    $('data-use').disabled = false;
  }
}

// ---- Export ---------------------------------------------------------------------------------------
const slug = () => `${model.metadata.scheme}-${model.metadata.version}`.replace(/[^A-Za-z0-9._-]+/g, '-').replace(/^-+|-+$/g, '') || 'expert-system';
const errorCount = () => problems.filter((p) => p.level === 'error').length;
const jsonText = () => JSON.stringify(M.modelToJson(model), null, 1);
let checked = { revision: -1, result: null };

function renderExport() {
  const errors = errorCount();
  const item = (p) => `<li class="${p.level}"><span class="tag">${p.level === 'error' ? 'To fix' : 'Note'}</span> ${h(p.text)}
    <button type="button" class="btn btn-link btn-sm p-0 align-baseline" data-act="show-problem" data-kind="${p.kind}" data-id="${p.id ?? ''}">Show</button></li>`;
  // What has to be fixed comes first and in full; of many notes the first few
  // are listed, so the export stays in view below them.
  const NOTES = 4;
  const toFix = problems.filter((p) => p.level === 'error'), notes = problems.filter((p) => p.level !== 'error');
  const more = notes.length > NOTES + 1 ? notes.splice(NOTES) : [];
  $('x-problems').innerHTML = [...toFix, ...notes].map(item).join('')
    + (more.length ? `<li><details><summary class="small">Show the other ${plural(more.length, 'note')}</summary><ul class="problems">${more.map(item).join('')}</ul></details></li>` : '')
    || '<li class="ok">Nothing to fix.</li>';
  for (const id of ['x-json', 'x-txt', 'x-app']) $(id).disabled = errors > 0 || !model.rules.length;
  $('x-snippet').textContent = `library(RESY)\nexpert <- resy_load_expert(expertfile = "${slug()}.json")\nresult <- resy_classify(obs = obs, header = header, expert = expert)`;
  if (errors || !model.rules.length) {
    $('x-check').className = 'small mb-0 text-body-secondary';
    $('x-check').textContent = errors ? `Fix ${errors === 1 ? 'the error' : `the ${fmt(errors)} errors`} above to export the system.` : 'Add a type to export the system.';
    return;
  }
  checkExport().catch((e) => { $('x-check').className = 'small mb-0 error'; $('x-check').textContent = cleanError(e); });
}
// Writes the complete JSON file into the R session and has RESY read it.
async function checkExport() {
  if (checked.revision !== revision) {
    const at = revision;
    $('x-check').className = 'small mb-0 text-body-secondary';
    $('x-check').innerHTML = '<span class="spinner-border spinner-border-sm me-1" aria-hidden="true"></span>RESY is reading the system…';
    await rWrite(`${DIR}/export.json`, jsonText());
    checked = { revision: at, result: await rJson(`resy_maker_check("${DIR}/export.json")`) };
  }
  const r = checked.result;
  if (checked.revision !== revision || sheet !== 'export') return r;
  $('x-check').className = `small mb-0${r.ok ? '' : ' error'}`;
  $('x-check').textContent = (r.ok
    ? `RESY reads the system: ${plural(model.rules.length, 'rule')} for ${plural(new Set(model.rules.map((x) => x.code)).size, 'type')}, ${plural(model.groups.length, 'group')}, ${nSpecies(model.synonyms.size)}.`
    : `RESY does not read the system: ${r.errors.join(' ')}`)
    + (r.warnings.length ? ` Notes of its validation: ${r.warnings.map((w) => (/[.!?]$/.test(w) ? w : `${w}.`)).join(' ')}` : '');
  return r;
}
async function exportAs(kind) {
  const status = $('x-status');
  status.classList.remove('error');
  try {
    status.textContent = 'Checking…';
    const r = await checkExport();
    if (!r.ok) throw new Error('RESY does not read the system; see above.');
    if (kind === 'json') saveBlob(new Blob([jsonText()], { type: 'application/json' }), `${slug()}.json`);
    if (kind === 'txt') {
      status.textContent = 'Writing the .txt file and reading it back…';
      await rVoid(`resy_maker_write_txt("${DIR}/export.json", "${DIR}/export.txt")`);
      saveBlob(new Blob([await rRead(`${DIR}/export.txt`)], { type: 'text/plain' }), `${slug()}.txt`);
    }
    if (kind === 'app') {
      const handed = { name: `${slug()}.json`, text: jsonText() };
      showSheet(null);
      await shell.open(handed);
    }
    status.textContent = '';
  } catch (e) {
    console.error(e);
    status.textContent = cleanError(e);
    status.classList.add('error');
  }
}
function showProblem(kind, id) {
  showSheet(null);
  if (kind === 'group') openGroup(id || sel.group);
  else if (kind === 'rule') { if (id) openRule(id); $('pane-rule').scrollIntoView({ block: 'nearest' }); }
  else if (kind === 'species') showTab('species');
  else $('m-scheme').focus();
}

// ---- Events ---------------------------------------------------------------------------------------
const act = (e) => e.target.closest('[data-act]');
const inField = (el) => el.matches('input:not([type=range]):not([type=radio]), textarea');

app.addEventListener('click', (e) => {
  if (e.target.closest('#ta')) return;
  const opener = e.target.closest('[data-sheet]');
  if (opener) return showSheet(sheet === opener.dataset.sheet ? null : opener.dataset.sheet);
  const tab = e.target.closest('[data-tab]');
  if (tab) return showTab(tab.dataset.tab);
  const dot = e.target.closest('[data-plot]');
  if (dot) return pickPlot(test.plots.id[Number(dot.dataset.plot)]);
  const el = act(e);
  switch (el?.dataset.act) {
    case 'sheet-close': return showSheet(null);
    case 'show-problem': return showProblem(el.dataset.kind, el.dataset.id);
    case 'open-rule': return openRule(el.dataset.id);
    case 'show-plots': return showPlots(el.dataset.show);
    case 'trail-clear': return clearDetail();
    case 'show-detail': return $('detail').scrollIntoView({ block: 'start', behavior: 'smooth' });
    default:
  }
});
// A sheet closes on Escape and on a click anywhere else on the page.
document.addEventListener('click', (e) => { if (sheet && e.target.isConnected && !e.target.closest('.sheet, [data-sheet]')) showSheet(null); });
document.addEventListener('focusin', (e) => {
  if (sheet && !e.target.closest('.sheet, [data-sheet]')) showSheet(null);
});
$('undo').addEventListener('click', () => travel(-1));
$('redo').addEventListener('click', () => travel(1));
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && sheet && $('ta').hidden) { e.preventDefault(); return showSheet(null); }
  if (!(e.ctrlKey || e.metaKey) || inField(e.target) || !opened) return;
  const key = e.key.toLowerCase();
  if (key === 'z' && !e.shiftKey) { e.preventDefault(); travel(-1); }
  if (key === 'y' || (key === 'z' && e.shiftKey)) { e.preventDefault(); travel(1); }
});
$('t-rest').addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); e.target.click(); } });
$('welcome-x').addEventListener('click', () => { $('welcome').hidden = true; });
app.querySelector('[role="tablist"]').addEventListener('keydown', (e) => {
  const tabs = [...app.querySelectorAll('[data-tab]')], at = tabs.indexOf(e.target);
  if (at < 0 || !['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(e.key)) return;
  e.preventDefault();
  const next = e.key === 'Home' ? 0 : e.key === 'End' ? tabs.length - 1 : (at + (e.key === 'ArrowRight' ? 1 : -1) + tabs.length) % tabs.length;
  showTab(tabs[next].dataset.tab);
  tabs[next].focus({ preventScroll: true });
});

// Name, version and description of the system
app.addEventListener('input', (e) => { if (e.target.dataset?.meta) model.metadata[e.target.dataset.meta] = e.target.value.trim(); });
app.addEventListener('change', (e) => { if (e.target.dataset?.meta) commit(); });

// Saving and clearing
$('save').addEventListener('click', saveFile);
$('clear-save').addEventListener('click', () => { saveFile(); $('clear-status').textContent = `Saved as ${slug()}.json in your downloads.`; });
$('clear-go').addEventListener('click', clearAll);

// Opening a system
$('start-go').addEventListener('click', startClicked);
for (const el of document.querySelectorAll('input[name=start]')) el.addEventListener('change', disarm);
$('start-file').addEventListener('change', () => { document.querySelector('input[name=start][value=file]').checked = true; disarm(); });
$('start-eunis-version').addEventListener('change', () => { document.querySelector('input[name=start][value=EUNIS]').checked = true; disarm(); });

// Species
$('sp-q').addEventListener('input', renderSpecies);
$('sp-add-data').addEventListener('click', () => { addSpecies(data.species.keys()); renderSpecies(); });
$('sp-paste-toggle').addEventListener('click', () => { $('sp-paste').hidden = !$('sp-paste').hidden; if (!$('sp-paste').hidden) $('sp-text').focus(); });
$('sp-paste-add').addEventListener('click', () => { addSpecies($('sp-text').value.split(/\r?\n/)); $('sp-text').value = ''; $('sp-paste').hidden = true; renderSpecies(); });
$('tab-species').addEventListener('click', (e) => {
  const el = act(e), name = e.target.closest('li[data-name]')?.dataset.name;
  if (!el) return;
  if (el.dataset.act === 'sp-edit') { sel.species = sel.species === name ? null : name; renderSpecies(); }
  if (el.dataset.act === 'sp-del') removeSpecies([name]);
  if (el.dataset.act === 'sp-tick') {
    // With Shift, the tick goes to every species between this one and the one ticked before.
    const rows = [...$('sp-list').querySelectorAll('li[data-name]')].map((li) => li.dataset.name), from = rows.indexOf(lastTick), to = rows.indexOf(name);
    const range = e.shiftKey && from >= 0 ? rows.slice(Math.min(from, to), Math.max(from, to) + 1) : [name];
    for (const n of range) { if (el.checked) ticked.add(n); else ticked.delete(n); }
    lastTick = name;
    renderSpecies();
  }
});
let lastTick = null;
$('sp-filter').addEventListener('change', () => { sel.kind = $('sp-filter').value; renderSpecies(); });
$('sp-remove').addEventListener('click', () => removeSpecies(ticked.size ? [...ticked] : speciesListed().hits));
$('sp-restore').addEventListener('click', restoreSpecies);
$('tab-species').addEventListener('change', (e) => {
  if (e.target.dataset.act !== 'sp-syn') return;
  const name = e.target.closest('li[data-name]').dataset.name;
  model.synonyms.set(name, [...new Set(e.target.value.split(/\r?\n/).map((s) => s.replace(/\s+/g, ' ').trim()).filter((s) => s && s !== name))]);
  speciesChanged();
});

// Groups
const groupsTab = $('tab-groups');
// Selecting the name of a group opens it; selecting it again closes it.
const pickGroup = (e) => {
  const head = e.target.closest('.head');
  if (!head) return false;
  const id = head.closest('li').dataset.id;
  sel.group = sel.group === id ? null : id;
  renderGroups();
  return true;
};
$('g-q').addEventListener('input', renderGroups);
$('g-new').addEventListener('click', () => {
  const g = addGroup();
  commit();
  renderBuilder();
  openGroup(g.id, true);
});
function deleteGroup(g) {
  model.groups.splice(model.groups.indexOf(g), 1);
  if (sel.group === g.id) sel.group = null;
  groupsChanged();
}
groupsTab.addEventListener('click', (e) => {
  const row = e.target.closest('[data-act="row-del"]');
  if (row) return deleteGroup(model.groups.find((g) => g.id === row.closest('li').dataset.id));
  if (pickGroup(e)) return;
  const el = act(e), g = group();
  if (!el || !g) return;
  switch (el.dataset.act) {
    case 'g-del-member': g.members = g.members.filter((m) => m !== el.dataset.name); break;
    case 'g-paste-add': addMembers(g, $('g-paste').value.split(/\r?\n/)); break;
    case 'g-dup': {
      const copy = { ...structuredClone(g), id: M.uid(), name: freeName(`${g.name}-copy`, groupNames()) };
      model.groups.splice(model.groups.indexOf(g) + 1, 0, copy);
      sel.group = copy.id;
      break;
    }
    case 'g-del': return deleteGroup(g);
    case 'g-use': {
      const r = rule();
      if (!r?.tree) return;
      addNode((activeGroup && findNode(activeGroup)?.node) || r.tree, 'items', condOnGroup(g.name));
      return renderGroups();
    }
    default: return;
  }
  groupsChanged();
});
groupsTab.addEventListener('keydown', (e) => {
  if (!e.target.matches('.head')) return;
  if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); pickGroup(e); }
  if (e.key === 'Delete') { e.preventDefault(); deleteGroup(model.groups.find((g) => g.id === e.target.closest('li').dataset.id)); }
});
function groupNameFeedback(el, name) {
  const g = group();
  const p = M.groupNameProblem(name) ?? (name !== g.name && groupNames().has(name) ? 'another group has this name' : null);
  $('g-problem').textContent = p ? `This name cannot be used: ${p}.` : '';
  el.setAttribute('aria-invalid', String(Boolean(p)));
  el.setAttribute('aria-describedby', 'g-problem');
  return p;
}
groupsTab.addEventListener('input', (e) => {
  if (e.target.dataset.act === 'g-name') groupNameFeedback(e.target, e.target.value);
});
groupsTab.addEventListener('change', (e) => {
  const g = group(), el = e.target;
  if (el.dataset.act === 'g-prefix') { g.prefix = el.value; return groupsChanged(); }
  if (el.dataset.act !== 'g-name') return;
  // Spaces become hyphens, as in the group names of the EUNIS-ESy releases.
  const name = el.value.trim().replace(/\s+/g, ' ').replace(/^(\+\d+ )?(.*)$/, (_, set, rest) => (set ?? '') + rest.replace(/ /g, '-'));
  if (name === g.name) { el.value = name; return; }
  if (groupNameFeedback(el, name)) return;
  const n = M.renameGroup(model, g.name, name);
  g.name = name;
  for (const r of model.rules) touched.add(r.id);
  groupsChanged();
  const text = $('t-editor').querySelector('[data-act="rule-text"]'), r = rule();
  if (text && r && !r.problem) text.value = r.expression;
  if (n) $('g-editor').querySelector('.used').insertAdjacentText('beforeend', ` Renamed in ${plural(n, 'rule')}.`);
});
// A group dragged into the rule becomes a condition on its total cover.
groupsTab.addEventListener('dragstart', (e) => {
  const head = e.target.closest?.('.head[draggable]');
  const g = head && model.groups.find((x) => x.id === head.closest('li').dataset.id);
  if (!g || !rule()?.tree) return;
  drag = { kind: '#TC', group: g.name };
  e.dataTransfer.effectAllowed = 'copy';
  e.dataTransfer.setData('text/plain', g.name);
});

// Types
function pickType(e) {
  const li = e.target.closest('li[data-id]');
  if (!li || e.target.closest('[data-plot]')) return;
  if (e.target.closest('[data-act="fold"]')) return foldType(li.dataset.id);
  if (e.target.closest('[data-act="row-del"]') || e.key === 'Delete') deleteRule(model.rules.find((r) => r.id === li.dataset.id));
  else openRule(li.dataset.id);
}
// Deletes a type; the type shown stays, or the next one takes its place.
function deleteRule(r) {
  const i = model.rules.indexOf(r);
  if (i < 0) return;
  model.rules.splice(i, 1);
  commit();
  openRule(sel.rule === r.id ? model.rules[Math.min(i, model.rules.length - 1)]?.id ?? null : sel.rule);
}
// Shows the type with `id`. A search that leaves it out of the list of types
// is cleared, so the type shown is always marked in the list.
function openRule(id) {
  sel.rule = id;
  activeGroup = null;
  setRest(null);
  const r = rule();
  if (r && !typeListed(r)) $('t-q').value = '';
  if (r) for (const p of ancestors(r.id)) folded.delete(p);
  renderTypes();
  revealType();
  loadRulePlots();
  if (sel.tab === 'plots') renderPlots();
  if (sel.tab === 'groups') renderGroups();
  if (sel.plot !== null) markTrail();
}
function newType() {
  const r = M.newRule();
  model.rules.push(r);
  commit();
  openRule(r.id);
  $('t-editor').querySelector('[data-rule-field="code"]').focus();
}
$('t-list').addEventListener('click', pickType);
$('t-list').addEventListener('keydown', (e) => {
  if (!e.target.matches('li[data-id]')) return;
  if (['Enter', ' ', 'Delete'].includes(e.key)) { e.preventDefault(); pickType(e); }
  // The arrow keys of a tree: left folds the subtypes away, right shows them.
  if (e.target.hasAttribute('aria-expanded') && ['ArrowLeft', 'ArrowRight'].includes(e.key)) { e.preventDefault(); foldType(e.target.dataset.id, e.key === 'ArrowLeft'); }
});
$('t-q').addEventListener('input', () => renderTypes(false));
$('t-new').addEventListener('click', newType);
$('t-editor').addEventListener('keydown', (e) => {
  if (!e.target.matches('.grip') || !e.altKey || !['ArrowUp', 'ArrowDown'].includes(e.key)) return;
  e.preventDefault();
  const at = findNode(e.target.closest('[data-node]').dataset.node), list = at.parent[at.list];
  const from = list.indexOf(at.node), to = from + (e.key === 'ArrowUp' ? -1 : 1);
  if (to < 0 || to >= list.length) return;
  list.splice(from, 1);
  list.splice(to, 0, at.node);
  treeTouched();
  renderBuilder();
  commit();
});
$('t-editor').addEventListener('click', (e) => {
  if (e.target.closest('[data-act="t-new"]')) return newType();
  const r = rule();
  if (!r) return;
  const chip = e.target.closest('[data-palette]');
  if (chip) {
    const target = (activeGroup && findNode(activeGroup)?.node) || r.tree;
    return addNode(target, 'items', M.condNode(conditionOf(chip.dataset.palette)));
  }
  const grp = e.target.closest('#builder .grp');
  if (grp && grp.dataset.node !== activeGroup) {
    activeGroup = grp.dataset.node;
    for (const x of $('builder').querySelectorAll('.grp')) x.classList.toggle('target', x === grp);
  }
  const el = act(e);
  if (!el) return;
  // Inheriting the rule of the parent type, and the overrides of its conditions.
  if (el.dataset.act === 't-inherit') {
    r.inherit = el.checked;
    r.overrides ??= {};
    if (r.tree) M.syncRule(r);
    return inheritChanged(r);
  }
  if (['ov-change', 'ov-off', 'ov-reset'].includes(el.dataset.act)) {
    const of = el.dataset.of;
    r.overrides ??= {};
    if (el.dataset.act === 'ov-reset') delete r.overrides[of];
    else if (el.dataset.act === 'ov-off') r.overrides[of] = { off: true };
    else {
      const n = fullOf(r).from?.order.find((x) => x.id === of);
      if (!n) return;
      r.overrides[of] = { node: M.condNode(structuredClone(n.c)) };
    }
    return inheritChanged(r, el.dataset.act === 'ov-change' ? r.overrides[of].node.id : of);
  }
  const at = el.closest('[data-node]') ? findNode(el.closest('[data-node]').dataset.node) : null;
  switch (el.dataset.act) {
    case 'add-cond': return addNode(at.node, el.dataset.zone, M.condNode(conditionOf('#TC')));
    case 'add-group': return addNode(at.node, el.dataset.zone, M.groupNode(at.node.op === 'AND' ? 'OR' : 'AND'));
    case 'node-del': at.parent[at.list].splice(at.parent[at.list].indexOf(at.node), 1); break;
    case 'op-group-add': at.node.c[el.dataset.side].groups.push(speciesGroups()[0]?.name ?? ''); break;
    case 'op-group-del': at.node.c[el.dataset.side].groups.pop(); break;
    case 'op-group-show': {
      const g = model.groups.find((x) => x.name === el.dataset.name);
      return g ? openGroup(g.id) : undefined;
    }
    case 'op-except-show': exceptOpen.add(at.node.c[el.dataset.side]); renderBuilder(); return;
    case 't-dup': {
      M.ruleTree(r);
      const copy = { ...structuredClone(r), id: M.uid(), code: `${r.code}-copy` };
      if (copy.tree) M.eachNode(copy.tree, (n) => { n.id = M.uid(); });
      model.rules.splice(model.rules.indexOf(r) + 1, 0, copy);
      commit();
      return openRule(copy.id);
    }
    case 't-del': return deleteRule(r);
    default: return;
  }
  treeTouched();
  renderBuilder();
  commit();
});
// Typing changes the formula at once; leaving the field makes it one step for Undo.
$('t-editor').addEventListener('input', (e) => {
  const el = e.target, r = rule();
  if (!r || el.tagName === 'SELECT') return;
  if (el.dataset.ruleField) {
    r[el.dataset.ruleField] = el.value.trim();
    // A new code can move the type to another place in the hierarchy.
    renderTypes(false);
    showVerdict();
    return;
  }
  if (el.dataset.ta === 'cond-species') { findNode(el.closest('[data-node]').dataset.node).node.c.lhs.text = el.value.replace(/\s+/g, ' ').trim(); treeTouched(); scheduleTest(); return; }
  if (!el.dataset.act || el.dataset.act === 'rule-text') return;
  applyControl(el);
  treeTouched();
  if (el.dataset.act === 'op-num' || el.dataset.act === 'op-slider') liveCond(el.closest('.cond').dataset.node);
  scheduleTest(el.dataset.act === 'op-slider' ? 250 : 600);
});
$('t-editor').addEventListener('change', (e) => {
  const el = e.target, r = rule();
  if (!r) return;
  if (el.dataset.ruleField) { r[el.dataset.ruleField] = el.value.trim(); touched.add(r.id); commit(); return; }
  if (el.dataset.act === 'rule-text') { M.setRuleText(r, el.value); touched.add(r.id); commit(); return renderTypeEditor(); }
  if (el.dataset.ta === 'cond-species') return commit();
  if (!el.dataset.act) return;
  let redraw = applyControl(el);
  if (el.dataset.act === 'cond-raw') {
    const at = findNode(el.closest('[data-node]').dataset.node);
    at.node.c = M.parseCondition(at.node.c.raw);
    redraw = at.node.c.raw === undefined;
  }
  treeTouched();
  if (redraw) renderBuilder();
  commit();
  // A group made from the list of a condition is shown among the parts, to be named and filled.
  if (madeGroup) { const id = madeGroup; madeGroup = null; openGroup(id, true); }
});
$('t-editor').addEventListener('dragstart', (e) => {
  const chip = e.target.closest('[data-palette]'), grip = e.target.closest('.grip');
  if (!chip && !grip) return;
  drag = chip ? { kind: chip.dataset.palette } : { id: grip.closest('[data-node]').dataset.node };
  e.dataTransfer.effectAllowed = chip ? 'copy' : 'move';
  e.dataTransfer.setData('text/plain', chip ? chip.textContent : 'condition');
  if (grip) {
    const block = grip.closest('[data-node]');
    e.dataTransfer.setDragImage(block, 12, 12);
    requestAnimationFrame(() => block.classList.add('dragging'));
  }
});
$('t-editor').addEventListener('dragover', (e) => {
  const place = dropPlace(e);
  clearDrop();
  if (!place) return;
  e.preventDefault();
  e.dataTransfer.dropEffect = drag.kind ? 'copy' : 'move';
  (place.before ?? place.zone).classList.add(place.before ? 'drop-before' : 'drop-into');
});
$('t-editor').addEventListener('drop', (e) => {
  const place = dropPlace(e);
  clearDrop();
  if (!place) return;
  e.preventDefault();
  if (drag.kind) {
    const node = drag.group ? condOnGroup(drag.group) : M.condNode(conditionOf(drag.kind));
    drag = null;
    addNode(place.group, place.list, node, place.index);
    if (sel.tab === 'groups') renderGroups();
    return;
  }
  const from = findNode(drag.id), list = from.parent[from.list], i = list.indexOf(from.node);
  list.splice(i, 1);
  place.group[place.list].splice(list === place.group[place.list] && i < place.index ? place.index - 1 : place.index, 0, from.node);
  drag = null;
  treeTouched();
  renderBuilder();
  commit();
});
app.addEventListener('dragend', () => {
  drag = null;
  clearDrop();
  for (const el of app.querySelectorAll('.dragging')) el.classList.remove('dragging');
});

// Typeahead
app.addEventListener('input', (e) => { if (e.target.dataset?.ta) taShow(e.target); });
app.addEventListener('focusout', (e) => { if (e.target.dataset?.ta) setTimeout(() => { if (ta.input === e.target && document.activeElement !== e.target) taHide(); }, 150); });
app.addEventListener('keydown', (e) => {
  if (!e.target.dataset?.ta) return;
  const shown = !$('ta').hidden;
  if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
    if (!shown) return;
    e.preventDefault();
    ta.at = (ta.at + (e.key === 'ArrowDown' ? 1 : ta.items.length - 1)) % ta.items.length;
    taDraw();
  } else if (e.key === 'Enter') {
    e.preventDefault();
    ta.input = e.target;
    taPick(shown ? ta.items[ta.at].name : e.target.value);
  } else if (e.key === 'Escape') taHide();
});
$('ta').addEventListener('mousedown', (e) => {
  const li = e.target.closest('li');
  if (!li) return;
  e.preventDefault();
  taPick(ta.items[Number(li.dataset.i)].name);
});

// Plots
$('show').addEventListener('change', () => { sel.show = $('show').value; renderRows(); });
$('q').addEventListener('input', renderRows);
$('rows').addEventListener('click', (e) => { const tr = e.target.closest('tr'); if (tr) pickPlot(tr.dataset.id, sel.show !== 'type'); });
$('d-close').addEventListener('click', clearDetail);
wireEvidence($('d-body'), (type) => evaluatePlot(sel.plot, type), () => sel.plot);
$('f-species').addEventListener('change', () => {
  const f = $('f-species').files[0];
  if (f) fillSpeciesColumns(f, h).catch((e) => { $('data-status').textContent = cleanError(e); });
  $('data-use').disabled = !(f && $('f-sites').files[0]);
});
$('f-sites').addEventListener('change', () => { $('data-use').disabled = !($('f-species').files[0] && $('f-sites').files[0]); });
$('data-use').addEventListener('click', useOwnData);
$('data-example').addEventListener('click', async () => { await useExamples(); changed(); showSheet(null); render(); });

// Export
$('x-json').addEventListener('click', () => exportAs('json'));
$('x-txt').addEventListener('click', () => exportAs('txt'));
$('x-app').addEventListener('click', () => exportAs('app'));

// ---- Startup --------------------------------------------------------------------------------------
// The RESY App shares the window with this page (see createShell()); an expert
// system it hands over is opened here.
const shell = createShell('maker', showSystem);

// The page opens on a system to work on: the one handed over by the RESY App,
// the draft kept in this browser, or the Apennine example. The top bar and the
// lists beside the rule stick below the site's navigation bar (see pinNavbar()).
async function start() {
  pinNavbar(app);
  new ResizeObserver(() => app.style.setProperty('--maker-toolbar', `${$('top').offsetHeight}px`)).observe($('top'));
  for (const panel of app.querySelectorAll('.sheet')) {
    panel.querySelector('.card-body').insertAdjacentHTML('beforeend', '<button type="button" class="mini sheet-close" data-act="sheet-close" aria-label="Close panel" title="Close panel">✕</button>');
  }
  const assetsPromise = fetchAssets(['resy_page.R', 'resy_maker.R']);
  const session = bootSession(assetsPromise, (step, text) => { loader.text(text); loader.stage(step); });
  const assets = await assetsPromise;
  info = assets.info;
  if (info) $('footer').insertAdjacentHTML('afterbegin', `RESY ${h(info.resy)} · `);
  const versions = info?.eunis_versions ?? [];
  $('start-eunis-version').innerHTML = versions.map((v, i) => `<option value="${h(v)}">${h(v)}${i === 0 ? ' (newest)' : ''}</option>`).join('');
  $('start-eunis-version').hidden = versions.length < 2;
  webR = await session;
  loader.text('Reading the example plots…');
  loader.stage('data');
  await rVoid(`dir.create("${DIR}", showWarnings = FALSE)`);
  const paths = await inR(() => webR.evalRRaw('resy_page_examples()', 'string[]'));
  examples.files = await Promise.all(paths.map(async (p) => new File([await rRead(p)], p.split('/').at(-1), { type: 'text/csv' })));
  await useExamples();
  const handed = location.hash === '#open' ? await store.get('to-maker') : null;
  const draft = handed ? null : await store.get('maker-draft');
  loader.text('Opening the system and testing it on the example plots…');
  loader.stage('test');
  await openSystem(handed ?? (draft ? { draft } : { scheme: 'Apennine-test', example: true }));
  $('welcome').hidden = Boolean(handed || draft);
  showTab('groups');
  render();
  // The lists have no size until the tool is shown.
  await loader.hide();
  revealType(true);
  shell.ready();
}
start().catch((e) => { console.error(e); loader.text(`The Maker could not start: ${cleanError(e)}`, 'error'); shell.failed(e); });
