// "Why this type?": what RESY's resy_eval_plot() prints for a plot, as HTML,
// shared by the RESY App and the RESY Maker. The panel shows the decision, the
// species, the lower-level types not reached (closest first) and the rule of
// one of them condition by condition.
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

function nearHtml(ty, nameOf) {
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

// `nameOf(code)` gives the name of a type.
export function evidenceHtml(ev, nameOf) {
  const out = [`<p class="mb-1">${escapeHtml(ev.sentence ?? '')}</p>`];
  if (ev.holds?.length) out.push(`<p class="small text-body-secondary">Rules that hold: ${ev.holds.map((h) => `${escapeHtml(h.code)} (priority ${escapeHtml(h.priority)})`).join(', ')}</p>`);
  out.push(`<details class="species" open><summary>${fmt(ev.species.length)} species${ev.species.some((s) => s.unknown) ? ' <span class="text-body-secondary">(grey: name not in the expert system)</span>' : ''}</summary>
    <table class="table table-sm mb-0"><tbody>${ev.species.map((s) => `<tr><td${s.unknown ? ' class="text-body-secondary" title="This name is not in the expert system"' : ''}>${escapeHtml(s.species)}</td><td class="num">${s.cover ?? ''}</td></tr>`).join('')}</tbody></table></details>`);
  ev.lower.forEach((lv) => {
    if (!lv.below) { out.push(`<p class="small mt-3 mb-0">${escapeHtml(lv.anchor)} has no lower levels.</p>`); return; }
    if (!lv.types?.length) return;
    const heading = lv.anchor === '?' ? 'Top-level types not reached' : `Why not a lower level of ${lv.anchor}?`;
    out.push(`<section class="lower">
      <p class="h6 mt-3 mb-1">${escapeHtml(heading)}</p>
      <p class="small text-body-secondary mb-2">Conditions of each rule that the plot meets, closest first. Select a type to see its rule.</p>
      ${nearHtml(lv.types, nameOf)}
      <div class="full">${ruleHtml(lv.closest)}</div>
    </section>`);
  });
  return out.join('');
}

// Shows the rule(s) of the type of a list entry picked in an evidence panel in
// place of the closest rule under that list. `evaluate(type)` resolves to the
// evidence with that type's rules in full; `current()` tells whether the panel
// still shows the plot the entry was picked for.
export function wireEvidence(body, evaluate, current, { retain = false, report = () => {} } = {}) {
  const requests = new WeakMap();
  const show = (li) => {
    const full = li.closest('.lower')?.querySelector('.full');
    if (!full) return;
    const token = current();
    const request = Symbol();
    requests.set(full, request);
    const active = () => current() === token && requests.get(full) === request && full.isConnected;
    for (const x of body.querySelectorAll('.near li.active')) x.classList.remove('active');
    li.classList.add('active');
    full.setAttribute('aria-busy', 'true');
    report(`Evaluating type ${li.dataset.type}…`);
    if (!retain) full.innerHTML = '<p class="text-body-secondary small">Evaluating…</p>';
    evaluate(li.dataset.type).then((ev) => {
      if (!active()) return;
      full.innerHTML = typeRulesHtml(ev.types[0]);
      report('');
    }).catch((e) => {
      if (!active()) return;
      if (!retain) full.textContent = String(e.message ?? e);
      report(String(e.message ?? e));
    }).finally(() => { if (active()) full.setAttribute('aria-busy', 'false'); });
  };
  body.addEventListener('click', (e) => { const li = e.target.closest('.near li'); if (li) show(li); });
  body.addEventListener('keydown', (e) => {
    const li = e.target.closest('.near li');
    if (li && (e.key === 'Enter' || e.key === ' ')) { e.preventDefault(); show(li); }
  });
}
