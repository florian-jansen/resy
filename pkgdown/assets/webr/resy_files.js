// Reading delimited data files in the browser, shared by the RESY App and the
// RESY Maker.

// Lines of a file as text with their byte positions, read in parts so that a
// file of several gigabytes never has to fit in memory at once.
const CHUNK = 8 * 1024 * 1024;
const decoder = new TextDecoder('utf-8');

export async function* lineChunks(blob, from = 0, to = blob.size) {
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
export function splitFields(line, delim) {
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
export async function readHeader(file) {
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
export const pick = (cols, key) => (ALIASES[key] ?? [key]).find((c) => cols.includes(c)) ?? null;

// The columns of the species file a page reads, and the <select> of each.
export const SPECIES_COLS = [['id', 'c-id'], ['name', 'c-name'], ['cover', 'c-cover']];
export const SPECIES_COL_LABEL = { id: 'plot', name: 'species', cover: 'cover' };

// Fills the column choices for a species file.
export async function fillSpeciesColumns(file, escapeHtml, { placeholder = null, isCurrent = () => true } = {}) {
  const { cols } = file ? await readHeader(file) : { cols: [] };
  if (!isCurrent()) return false;
  const empty = placeholder === null ? '' : `<option value="">${escapeHtml(placeholder)}</option>`;
  for (const [key, id] of SPECIES_COLS) {
    const chosen = pick(cols, key);
    document.getElementById(id).innerHTML = empty + cols.map((c) => `<option${c === chosen ? ' selected' : ''}>${escapeHtml(c)}</option>`).join('');
  }
  return true;
}

// A value as a field of a tab-separated file.
export const tsvValue = (v) => String(v ?? '').replace(/[\t\r\n]/g, ' ');
