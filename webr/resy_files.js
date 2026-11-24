// Reading delimited data files in the browser, shared by the RESY App and the
// RESY Maker.

// Text of a file: UTF-8, or Windows-1252 (the encoding of many spreadsheet
// exports) when the bytes are not valid UTF-8.
const utf8 = new TextDecoder('utf-8', { fatal: true });
const cp1252 = new TextDecoder('windows-1252');
export function decodeText(bytes) {
  try { return utf8.decode(bytes); } catch { return cp1252.decode(bytes); }
}
export const fileText = async (blob) => decodeText(new Uint8Array(await blob.arrayBuffer())).replace(/^﻿/, '');

// Records of a file as text with their byte positions, read in parts so that a
// file of several gigabytes never has to fit in memory at once. A record ends
// at a line break outside quotes: a quoted field (one that starts with a
// quote) may hold line breaks, the delimiter `delim` and doubled quotes.
const CHUNK = 8 * 1024 * 1024;
const QUOTE = 34, NEWLINE = 10;

export async function* lineChunks(blob, delim, from = 0, to = blob.size) {
  const sep = delim.charCodeAt(0);
  let pos = from, carry = new Uint8Array(0), carryStart = from;
  while (pos < to) {
    const part = new Uint8Array(await blob.slice(pos, Math.min(pos + CHUNK, to)).arrayBuffer());
    const buf = carry.length ? concat(carry, part) : part;
    const bufStart = carryStart;
    pos += part.length;
    const lines = [], starts = [];
    let a = 0, quoted = false, fieldStart = true;
    for (let i = 0; i < buf.length; i++) {
      const c = buf[i];
      if (quoted) {
        if (c === QUOTE) { if (buf[i + 1] === QUOTE) i++; else quoted = false; }
        continue;
      }
      if (c === QUOTE && fieldStart) { quoted = true; fieldStart = false; continue; }
      fieldStart = c === sep || c === NEWLINE;
      if (c !== NEWLINE) continue;
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
  return decodeText(buf.subarray(a, b));
};

// Fields of one record; a field that starts with a quote may hold the
// delimiter, line breaks and doubled quotes.
export function splitFields(line, delim) {
  if (!line.includes('"')) return line.split(delim);
  const out = [];
  let field = '', quoted = false, fresh = true;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (quoted) {
      if (c === '"' && line[i + 1] === '"') { field += '"'; i++; }
      else if (c === '"') quoted = false;
      else field += c;
    } else if (c === '"' && fresh) { quoted = true; fresh = false; }
    else if (c === delim) { out.push(field); field = ''; fresh = true; }
    else { field += c; fresh = false; }
  }
  out.push(field);
  return out;
}

// The records of a whole text, as lineChunks() splits a file.
export function splitRecords(text, delim) {
  const out = [];
  let a = 0, quoted = false, fresh = true;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"') { if (text[i + 1] === '"') i++; else quoted = false; }
      continue;
    }
    if (c === '"' && fresh) { quoted = true; fresh = false; continue; }
    fresh = c === delim || c === '\n';
    if (c !== '\n') continue;
    out.push(text.slice(a, i > a && text[i - 1] === '\r' ? i - 1 : i));
    a = i + 1;
  }
  if (a < text.length) out.push(text.slice(a));
  return out;
}

// Column names and delimiter (tab, semicolon or comma) of a delimited file:
// the delimiter that gives the header the most fields, delimiters inside
// quoted names not counted.
export async function readHeader(file) {
  const bytes = new Uint8Array(await file.slice(0, 1 << 16).arrayBuffer());
  const end = bytes.indexOf(NEWLINE);
  const line = decodeText(end < 0 ? bytes : bytes.subarray(0, end)).replace(/^﻿/, '').replace(/\r$/, '');
  const bare = line.replace(/"(?:[^"]|"")*"/g, '');
  const count = (d) => bare.split(d).length;
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
// A plot ID as R reads it from the tab-separated batch files: without the
// spaces around it.
export const plotId = (v) => String(v ?? '').trim();
// Escape TSV separators and literal percent signs for the R batch reader.
export const tsvPlotId = (id) => id.replace(/[%\t\r\n]/g, encodeURIComponent);
// A number written with a decimal point or a decimal comma ("60.5", "60,5"),
// as covers and coordinates come; anything else is NaN. Same rule as
// .page_number() in resy_page.R.
export function fieldNumber(v) {
  const s = String(v ?? '').trim();
  if (!s) return NaN;
  return Number(/^[-+]?\d*,\d+$/.test(s) ? s.replace(',', '.') : s);
}
