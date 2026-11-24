// Shared by the RESY App (page.js) and the RESY Maker (maker.js): small helpers,
// the loading screen, and the start of a webR session with RESY in it.
const runtime = import('https://webr.r-wasm.org/v0.6.0/webr.mjs');

// webR loads these immutable files through the HTTP cache in its worker.
const runtimeFiles = ['R.wasm', 'libRblas.so', 'libRlapack.so',
  'vfs/usr/lib/R/share.js.metadata', 'vfs/usr/lib/R/share.data.gz'];
const runtimeDownloads = Promise.all(runtimeFiles.map(async (name) => {
  const response = await fetch(`https://webr.r-wasm.org/v0.6.0/${name}`, { cache: 'force-cache' });
  if (!response.ok) throw new Error(`Could not load ${name} (${response.status}).`);
  await response.body.pipeTo(new WritableStream({ write() {} }));
}));

export const base = new URL('.', import.meta.url);
export const $ = (id) => document.getElementById(id);
export const escapeHtml = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
export const rString = (s) => JSON.stringify(String(s));
export const cleanError = (e) => String(e.message ?? e).replace(/^Error( in [^:]*)?:\s*/, '');
export const fmt = (n) => Math.round(n).toLocaleString();
export const plural = (n, word) => `${fmt(n)} ${word}${n === 1 ? '' : 's'}`;

// Each stage marks completed work; the fill advances only when a stage starts.
export function createLoader(stages) {
  let done = false;
  const fill = (f, seconds) => {
    $('hex-fill').style.setProperty('--dur', `${seconds}s`);
    $('hex-fill').style.setProperty('--p', `${(100 * f).toFixed(1)}%`);
  };
  return {
    get done() { return done; },
    text(text, kind = 'busy') {
      if (done) return;
      $('loader-step').textContent = text;
      $('loader').classList.toggle('error', kind === 'error');
    },
    stage(name) {
      if (done) return;
      performance.mark(`resy:${name}`);
      fill(stages[name], 0.15);
    },
    // Resolves once the tool is shown in place of the loading screen.
    hide() {
      if (done) return Promise.resolve();
      done = true;
      fill(1, 0);
      $('loader').hidden = true;
      $('tool').hidden = false;
      $('tool').inert = false;
      performance.mark('resy:ready');
      return Promise.resolve();
    },
  };
}

const get = async (file) => {
  const response = await fetch(new URL(file, base), { cache: 'no-cache' });
  if (!response.ok) throw new Error(`Could not load ${file} (${response.status}).`);
  return response;
};

// Content-addressed images share one download across sessions and browser visits.
const images = new Map();
function fetchImage(image) {
  const url = new URL(image.file, base).href;
  if (!images.has(url)) {
    const pending = (async () => {
      const key = `image:${url}`;
      let compressed = await store.get(key);
      if (!compressed) {
        const response = await fetch(url, { cache: 'force-cache' });
        if (!response.ok) throw new Error(`Could not load the R library (${response.status}).`);
        compressed = await response.blob();
        if (compressed.size !== image.bytes) throw new Error('The R library download is incomplete.');
        await store.set(key, compressed).catch((e) => console.warn('[resy] library cache', e));
      }
      const blob = await new Response(compressed.stream().pipeThrough(new DecompressionStream('gzip'))).blob();
      return { blob, metadata: image.metadata };
    })();
    images.set(url, pending);
    pending.catch(() => images.delete(url));
  }
  return images.get(url);
}

// The manifest and scripts are revalidated; library URLs identify their content.
const manifest = get('bundle.json').then((r) => r.json());
const startupLibraries = manifest.then((info) => Promise.all(
  ['resy', 'core'].map(async (name) => [name, await fetchImage(info.images[name])])));
export async function fetchAssets(scriptNames) {
  const [info, ...scripts] = await Promise.all([
    manifest,
    ...scriptNames.map((name) => get(name).then((r) => r.text()).then((t) => ({ name, bytes: new TextEncoder().encode(t) }))),
  ]);
  return { libraries: startupLibraries, info, scripts };
}

const geography = new WeakMap();
export function ensureGeography(webR) {
  if (!geography.has(webR)) {
    const pending = (async () => {
      const info = await manifest;
      const [gis, tables] = await Promise.all(['gis', 'tables'].map((name) => fetchImage(info.images[name])));
      await webR.FS.mount('WORKERFS', { packages: [gis] }, '/library-resy/RESY/data');
      await mountLibraries(webR, [['tables', tables]]);
    })();
    geography.set(webR, pending);
  }
  return geography.get(webR);
}

export async function prepareSites(webR, path, options) {
  const cached = await webR.evalRBoolean(`resy_page_sites_cached(${rString(path)}, ${options})`);
  if (!cached) await ensureGeography(webR);
}

export async function prepareMakerSites(webR, path) {
  const needed = await webR.evalRBoolean(`resy_maker_needs_geography(${rString(path)})`);
  if (needed) await ensureGeography(webR);
}

// A webR session (one R process in its own worker) with RESY loaded and the
// R scripts sourced in order. `on(step, text)` is called before each step:
// 'init', 'install' and 'resy'.
async function mountLibraries(webR, libraries) {
  const paths = [];
  for (const [name, image] of libraries) {
    const path = `/library-${name}`;
    await webR.FS.mkdir(path);
    await webR.FS.mount('WORKERFS', { packages: [image] }, path);
    paths.push(rString(path));
  }
  await webR.evalRVoid(`.libPaths(c(${paths.join(',')}, .libPaths()))`);
}
export async function bootSession(assetsPromise, on = () => {}) {
  const { WebR } = await runtime;
  const webR = new WebR();
  on('init', 'Starting R and loading libraries…');
  try {
    const prepared = Promise.resolve(assetsPromise).then(async (assets) => {
      await assets.libraries;
      return assets;
    });
    const [, assets] = await Promise.all([webR.init(), prepared, runtimeDownloads]);
    on('install', 'Mounting the R libraries…');
    await mountLibraries(webR, await assets.libraries);
    on('resy', 'Loading RESY…');
    for (const s of assets.scripts) await webR.FS.writeFile(`/tmp/${s.name}`, s.bytes);
    await webR.evalRVoid(assets.scripts.map((s) => `source(${rString(`/tmp/${s.name}`)})`).join('\n'));
    return webR;
  } catch (error) {
    webR.close();
    throw error;
  }
}

// Puts a File into a file input, so the input shows its name.
export function setFile(input, file) {
  const dt = new DataTransfer();
  dt.items.add(file);
  input.files = dt.files;
}

export function saveBlob(blob, name) {
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
}

// The site's navigation bar is fixed to the top of the window and on other
// pages slides away while the page is scrolled down (headroom.js). On the pages
// of the tools it stays, and `app` gets its height as --resy-top, so what
// sticks below it while the page scrolls keeps its place.
export function pinNavbar(app) {
  const bar = document.querySelector('nav.navbar');
  if (!bar || getComputedStyle(bar).position !== 'fixed') return;
  bar.classList.add('resy-pinned');
  const sync = () => app.style.setProperty('--resy-top', `${bar.offsetHeight}px`);
  new ResizeObserver(sync).observe(bar);
  sync();
}

// A small key-value store in the browser (IndexedDB), shared by the pages of
// the site: the Maker keeps its draft in it, and the Maker and the App hand an
// expert system to each other through it.
const db = () => new Promise((resolve, reject) => {
  const open = indexedDB.open('resy', 1);
  open.onupgradeneeded = () => open.result.createObjectStore('kv');
  open.onsuccess = () => resolve(open.result);
  open.onerror = () => reject(open.error);
});
const request = async (mode, run) => {
  const d = await db();
  try {
    return await new Promise((resolve, reject) => {
      const transaction = d.transaction('kv', mode);
      const r = run(transaction.objectStore('kv'));
      transaction.oncomplete = () => resolve(r.result);
      transaction.onabort = () => reject(transaction.error ?? r.error);
    });
  } finally {
    d.close();
  }
};
export const store = {
  get: (key) => request('readonly', (s) => s.get(key)).catch(() => undefined),
  set: (key, value) => request('readwrite', (s) => s.put(value, key)),
  delete: (key) => request('readwrite', (s) => s.delete(key)).catch(() => undefined),
};
// ---- Both tools in one window ------------------------------------------------------------------
// The RESY App and the RESY Maker are two pages, each with its own R session.
// The other tool starts on its first navigation and keeps its session in a
// frame for subsequent visits. The address and the Back button follow it.
const TOOLS = { app: 'app.html', maker: 'maker.html' };
const framed = window.parent !== window && new URLSearchParams(location.search).has('framed');
const toolOf = (url) => Object.keys(TOOLS).find((t) => url.origin === location.origin && url.pathname.endsWith(`/articles/${TOOLS[t]}`)) ?? null;
const plainClick = (e) => e.button === 0 && !e.ctrlKey && !e.metaKey && !e.shiftKey && !e.altKey;

// `name` is the tool of this page, 'app' or 'maker'. `receive(handed)` takes
// what the other tool hands over (an expert system) when this tool is shown.
// `ready()` announces a loaded tool; `open(handed)` opens its partner and
// passes the expert system to it.
export function createShell(name, receive) {
  const other = name === 'app' ? 'maker' : 'app';
  const root = document.documentElement;

  if (framed) {
    // This page is the tool in the frame: without the site's navigation bar
    // and footer, and with its other links opening in the whole window.
    root.classList.add('resy-framed');
    document.head.append(Object.assign(document.createElement('base'), { target: '_top' }));
    const back = (handed = null) => window.parent.resyShell.show(other, handed);
    document.addEventListener('click', (e) => {
      const a = e.target.closest?.('a[href]'), tool = a && plainClick(e) ? toolOf(new URL(a.href)) : null;
      if (!tool || a.hash) return;
      e.preventDefault();
      if (tool === other) back();
    });
    return {
      ready: () => window.parent.resyShell.register({ receive, title: document.title }),
      failed: (error) => window.parent.resyShell.failed(error),
      open: async (handed) => { await back(handed); return true; },
    };
  }

  let partner = null, scrollY = 0, loading = null, resolvePartner = null, rejectPartner = null;
  const title = document.title;
  const url = (tool) => new URL(TOOLS[tool], location.href).pathname;
  // Shows `tool`: this page's own content, or the frame over it.
  function show(tool, push = true) {
    const toOther = tool === other, wasOther = root.classList.contains('resy-other');
    if (toOther && !wasOther) { scrollY = window.scrollY; window.scrollTo(0, 0); }
    root.classList.toggle('resy-other', toOther);
    if (!toOther && wasOther) window.scrollTo(0, scrollY);
    document.title = toOther ? partner?.title ?? `RESY ${other === 'app' ? 'App' : 'Maker'}` : title;
    if (push && !location.pathname.endsWith(TOOLS[tool])) history.pushState(null, '', url(tool));
    if (toOther) document.querySelector('.resy-frame').contentWindow.focus();
  }
  window.resyShell = {
    register(api) { partner = api; root.dataset.resyPartner = 'ready'; resolvePartner?.(); loading = Promise.resolve(); },
    failed(error) { rejectPartner?.(new Error(cleanError(error))); },
    // Called by the tool in the frame: back to this page's tool, with what is handed over.
    async show(tool, handed) { show(tool); if (handed) await receive(handed); },
  };
  document.addEventListener('click', async (e) => {
    const a = e.target.closest?.('a[href]'), tool = a && plainClick(e) ? toolOf(new URL(a.href)) : null;
    if (!tool || a.hash) return;
    e.preventDefault();
    if (tool !== other) return show(tool);
    a.setAttribute('aria-busy', 'true');
    const ready = loadPartner();
    show(other);
    try { await ready; } catch (e) { console.warn('[resy] tool startup', e); }
    finally { a.removeAttribute('aria-busy'); }
  });
  window.addEventListener('popstate', () => {
    const tool = toolOf(new URL(location.href));
    if (tool === other && !partner) location.reload();
    else if (tool) show(tool, false);
  });
  function loadPartner() {
    if (!loading) {
      loading = new Promise((resolve, reject) => { resolvePartner = resolve; rejectPartner = reject; });
      root.style.setProperty('--resy-nav', `${document.querySelector('nav.navbar')?.offsetHeight ?? 0}px`);
      document.body.append(Object.assign(document.createElement('iframe'), { className: 'resy-frame', src: `${TOOLS[other]}?framed`, title: other === 'app' ? 'RESY App' : 'RESY Maker' }));
    }
    return loading;
  }
  return {
    ready() {},
    failed() {},
    async open(handed) {
      const ready = loadPartner();
      show(other);
      await ready;
      if (handed) await partner.receive(handed);
      show(other);
      return true;
    },
  };
}
