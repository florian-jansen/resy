// "Why this type?": what RESY's resy_eval_plot() prints for a plot, as HTML,
// shared by the RESY App and the RESY Maker. The panel shows the decision, the
// species, the lower-level types and the sibling types the plot is not
// classified as (types whose rule holds first, then closest first) and the
// rule of one of them condition by condition. compareHtml() draws what
// resy_compare_types() returns for two types and one plot.
import { escapeHtml, fmt, plural } from './resy_core.js';

const NEAR_SHOWN = 8;

// A condition is green when it counts for the rule and red when it counts
// against it. Under `not` that is the reverse of whether the plot meets it
// (status "not met" counts for the rule, "excludes" against it); such a
// condition is marked, and the mark is explained once above the conditions.
const NOT = '<span class="neg">not</span>';
export function ruleHtml(t, label = '') {
  const negated = t.conditions.map((c) => c.status === 'excludes' || (c.status === 'not met' && c.satisfied));
  const conds = t.conditions.map((c, k) => `
    <li class="${c.satisfied ? 'ok' : 'no'}">
      <span class="n">[${k + 1}]</span><span class="st">${escapeHtml(c.status)}</span>
      <span class="tx">${negated[k] ? NOT : ''}${escapeHtml(c.text)}${c.species ? `<span class="sp">${escapeHtml(c.species)}</span>` : ''}</span>
    </li>`).join('');
  return `<div class="rule">
    <p class="mb-1"><b>${escapeHtml(t.code)}</b> ${escapeHtml(t.name)}${label}
      <span class="verdict ${t.holds ? 'ok' : 'no'}">${t.holds ? 'rule holds' : 'rule not met'}</span></p>
    <p class="formula">${escapeHtml(t.rule)}</p>
    ${negated.some(Boolean) ? `<p class="small text-body-secondary mb-1">A condition marked ${NOT} stands under “not” in the rule: it counts for the rule when the plot does not meet it.</p>` : ''}
    <ol class="conds">${conds}</ol>
  </div>`;
}

// The rules of one type in full, as resy_page_explain(type = ) returns them.
export const typeRulesHtml = (ty) => ty.rules.map((r, k) =>
  ruleHtml(r, ty.rules.length > 1 ? `<span class="text-body-secondary">, rule ${k + 1} of ${ty.rules.length}</span>` : '')).join('');

// A type whose rule holds shows the priority it lost on; any other the share of
// conditions of its closest rule the plot meets. `why` (from
// .resy_code_verdict()) is shown above the rule in full.
function nearHtml(ty, nameOf) {
  const item = (t) => `
    <li data-type="${escapeHtml(t.code)}" data-why="${escapeHtml(t.why ?? '')}" tabindex="0" title="Show the rule of ${escapeHtml(t.code)}"${t === ty[0] ? ' class="active"' : ''}>
      <b>${escapeHtml(t.code)}</b>
      <span class="nm">${escapeHtml(nameOf(t.code) || t.name)}${t.rules > 1 && !t.holds ? `<span class="text-body-secondary">, closest of ${t.rules} rules</span>` : ''}</span>
      ${t.holds
        ? `<span class="frac held"><span class="bar"><i style="width:100%"></i></span>holds, prio. ${escapeHtml(t.priority)}</span>`
        : `<span class="frac"><span class="bar"><i style="width:${(100 * t.satisfied / Math.max(1, t.conditions)).toFixed(0)}%"></i></span>${t.satisfied} of ${t.conditions}</span>`}
    </li>`;
  const head = ty.slice(0, NEAR_SHOWN).map(item).join('');
  const rest = ty.slice(NEAR_SHOWN);
  return `<ul class="near">${head}</ul>` + (rest.length ?
    `<details><summary class="small">Show the other ${plural(rest.length, 'type')}</summary><ul class="near">${rest.map(item).join('')}</ul></details>` : '');
}

const whyText = (code, why) => why ? `${code}: ${why}.` : '';

function unchosenHtml(heading, lv, nameOf) {
  const held = lv.types.some((t) => t.holds);
  return `<section class="lower">
      <p class="h6 mt-3 mb-1">${escapeHtml(heading)}</p>
      <p class="small text-body-secondary mb-2">${held ? 'Types whose rule holds but has a lower priority first, then the others by the conditions of each rule that the plot meets.' : 'Conditions of each rule that the plot meets, closest first.'} Select a type to see its rule.</p>
      ${nearHtml(lv.types, nameOf)}
      <p class="why small">${escapeHtml(whyText(lv.types[0].code, lv.types[0].why))}</p>
      <div class="full">${ruleHtml(lv.closest)}</div>
    </section>`;
}

// `nameOf(code)` gives the name of a type.
export function evidenceHtml(ev, nameOf) {
  const out = [`<p class="mb-1">${escapeHtml(ev.sentence ?? '')}</p>`];
  if (ev.holds?.length) out.push(`<p class="small text-body-secondary">Rules that hold: ${ev.holds.map((h) => `${escapeHtml(h.code)} (priority ${escapeHtml(h.priority)})`).join(', ')}</p>`);
  out.push(`<details class="species" open><summary>${fmt(ev.species.length)} species${ev.species.some((s) => s.unknown) ? ' <span class="text-body-secondary">(grey: name not in the expert system)</span>' : ''}</summary>
    <table class="table table-sm mb-0"><tbody>${ev.species.map((s) => `<tr><td${s.unknown ? ' class="text-body-secondary" title="This name is not in the expert system"' : ''}>${escapeHtml(s.species)}</td><td class="num">${s.cover ?? ''}</td></tr>`).join('')}</tbody></table></details>`);
  ev.lower.forEach((lv) => {
    if (!lv.below) { out.push(`<p class="small mt-3 mb-0">${escapeHtml(lv.anchor)} has no lower levels.</p>`); return; }
    if (!lv.types?.length) return;
    out.push(unchosenHtml(lv.anchor === '?' ? 'Top-level types not reached' : `Why not a lower level of ${lv.anchor}?`, lv, nameOf));
  });
  const sb = ev.siblings;
  if (sb?.types?.length) {
    const parent = sb.parent ? `${sb.parent}${nameOf(sb.parent) ? ` (${nameOf(sb.parent)})` : ''}` : null;
    out.push(unchosenHtml(parent ? `Why not another type under ${parent}?` : 'Why not another top-level type?', sb, nameOf));
  }
  return out.join('');
}

// ---- Two types side by side ----------------------------------------------------
// What resy_compare_types() returns for one plot: per type the verdict and its
// rules, then every condition either rule uses with whether the plot meets it
// in each type (conditions both rules use share a number), then the species
// groups. `labels` names the system of each side when the two differ.
const cell = (used, met) => used ? `<td class="${met ? 'ok' : 'no'}">${met ? 'met' : 'not met'}</td>` : '<td class="unused"></td>';

export function compareHtml(cmp) {
  const [a, b] = cmp.sides;
  const twoSystems = a.system !== b.system;
  // The same type in two systems is told apart by its system ("EUNIS 2020-06-08").
  const label = (s) => a.code !== b.code ? s.code : s.system.replace(/ \(.*\)$/, '');
  const head = (s) => `<th scope="col"><b>${escapeHtml(s.code)}</b> ${escapeHtml(s.name)}${twoSystems ? `<span class="sys">${escapeHtml(s.system)}</span>` : ''}</th>`;
  const rules = (side) => cmp.rules.filter((r) => r.side === side).map((r, k, all) => `
      <p class="formula${all.length > 1 && r.judged ? ' judged' : ''}">${all.length > 1 ? `Rule ${r.rule} of ${all.length}, ` : ''}priority ${escapeHtml(r.priority)}: ${escapeHtml(r.text)}</p>`).join('');
  const verdict = (side) => {
    const v = cmp.plot[side];
    return `<p class="verdict-line ${v.choice === cmp.sides.find((s) => s.side === side).code ? 'ok' : v.holds ? 'held' : 'no'}">${escapeHtml(v.text)}</p>`;
  };
  const conds = cmp.conditions.map((c) => `
      <tr><td class="n">[${c.n}]</td><td class="tx">${escapeHtml(c.text ?? c.expression)}</td>${cell(c.in_a, c.met_a)}${cell(c.in_b, c.met_b)}</tr>`).join('');
  const groups = cmp.groups ?? [];
  const both = groups.filter((g) => g.in_a && g.in_b), onlyA = groups.filter((g) => g.in_a && !g.in_b), onlyB = groups.filter((g) => !g.in_a && g.in_b);
  const names = (gs) => gs.map((g) => escapeHtml(g.group)).join(', ');
  const differs = both.filter((g) => g.only_a || g.only_b).map((g) => `<li><b>${escapeHtml(g.group)}</b>: ${[
    g.only_a ? `only in ${escapeHtml(label(a))}: ${escapeHtml(g.only_a)}` : '', g.only_b ? `only in ${escapeHtml(label(b))}: ${escapeHtml(g.only_b)}` : ''].filter(Boolean).join('; ')}</li>`).join('');
  return `<table class="cmp-sides"><thead><tr>${head(a)}${head(b)}</tr></thead>
      <tbody><tr><td>${verdict('a')}${rules('a')}</td><td>${verdict('b')}${rules('b')}</td></tr></tbody></table>
    <table class="cmp-conds"><colgroup><col class="c-n"><col><col class="c-v"><col class="c-v"></colgroup><thead><tr><th scope="col" colspan="2">Condition</th><th scope="col">${escapeHtml(label(a))}</th><th scope="col">${escapeHtml(label(b))}</th></tr></thead>
      <tbody>${conds}</tbody></table>
    ${groups.length ? `<details class="cmp-groups"><summary class="small">Species groups</summary><ul class="small">
      ${both.length ? `<li>In both: ${names(both)}</li>` : ''}
      ${onlyA.length ? `<li>Only ${escapeHtml(label(a))}: ${names(onlyA)}</li>` : ''}
      ${onlyB.length ? `<li>Only ${escapeHtml(label(b))}: ${names(onlyB)}</li>` : ''}
      ${differs}</ul></details>` : ''}`;
}

// Shows the rule(s) of the type of a list entry picked in an evidence panel in
// place of the closest rule under that list. `evaluate(type)` resolves to the
// evidence with that type's rules in full; `current()` tells whether the panel
// still shows the plot the entry was picked for.
export function wireEvidence(body, evaluate, current, { retain = false, report = () => {} } = {}) {
  const requests = new WeakMap();
  let reporting = null;
  const show = (li) => {
    const full = li.closest('.lower')?.querySelector('.full');
    if (!full) return;
    const token = current();
    if (token == null) return;
    const request = reporting = Symbol();
    requests.set(full, request);
    const active = () => current() === token && requests.get(full) === request && full.isConnected;
    const section = li.closest('.lower');
    for (const x of section.querySelectorAll('.near li.active')) x.classList.remove('active');
    li.classList.add('active');
    const why = section.querySelector('.why');
    if (why) why.textContent = whyText(li.dataset.type, li.dataset.why);
    full.setAttribute('aria-busy', 'true');
    report(`Evaluating type ${li.dataset.type}…`);
    if (!retain) full.innerHTML = '<p class="text-body-secondary small">Evaluating…</p>';
    evaluate(li.dataset.type).then((ev) => {
      if (!active()) return;
      full.innerHTML = typeRulesHtml(ev.types[0]);
      if (reporting === request) report('');
    }).catch((e) => {
      if (!active()) return;
      if (!retain) full.textContent = String(e.message ?? e);
      if (reporting === request) report(String(e.message ?? e));
    }).finally(() => { if (active()) full.setAttribute('aria-busy', 'false'); });
  };
  body.addEventListener('click', (e) => { const li = e.target.closest('.near li'); if (li) show(li); });
  body.addEventListener('keydown', (e) => {
    const li = e.target.closest('.near li');
    if (li && (e.key === 'Enter' || e.key === ' ')) { e.preventDefault(); show(li); }
  });
}
