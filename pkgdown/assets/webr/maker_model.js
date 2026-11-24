// The expert system the RESY Maker edits, without any page code: the model, the
// text form of a rule (the ESy formula syntax RESY reads) and its tree form
// (what the page shows as blocks), and the JSON expert file.
//
// A formula combines conditions `<...>` with AND, OR and NOT, where `A NOT B`
// means "A and not B"; AND and NOT bind more strongly than OR, as in RESY,
// which evaluates the formula as the R expression `A & !B`. A condition
// compares two operands with GR (more than), GE (at least) or EQ (equal), or is
// a single operand that is true or false by itself.

// Ids stay unique when a draft saved in an earlier visit is opened again.
let counter = 0;
export const uid = () => `n${(++counter).toString(36)}_${Math.random().toString(36).slice(2, 7)}`;

// ---- Conditions ---------------------------------------------------------------
// An operand is one of
//   { k: 'num', text }                    a number
//   { k: 'share', pct }                   "$25": 25% of the total cover of the plot
//   { k: 'hnum' | 'hcat', col }           "$$N col" / "$$C col": a site column
//   { k: 'plotmax' }                      "#$$": highest cover of any species
//   { k: 'total', except }                "#T$": total cover of the plot
//   { k: 'measure', code, groups, except } "#TC A|#TC B EXCEPT ...": a value of groups
//   { k: 'name', text }                   a species (its cover) or a category of a site column
// `except` holds the entries after EXCEPT as written ("#TC Trees", "Pinus mugo").
// A condition is { lhs, op, rhs }, { lhs, op: null, rhs: null }, or { raw }
// for text the page has no blocks for; a raw condition is kept as written.

export const OPS = { GR: 'is more than', GE: 'is at least', EQ: 'equals' };

// What each condition code measures of its groups, as RESY's solver does.
export const MEASURES = {
  '#TC': { words: 'total cover of', unit: '%' },
  '###': { words: 'number of species of', unit: '' },
  '#SC': { words: 'highest cover of one species of', unit: '%' },
  '##D': { words: 'number of species of', unit: '' },
  '##Q': { words: 'sum of square-root covers of', unit: '' },
  '##C': { words: 'summed cover of', unit: '%' },
};
// Codes that make a condition by themselves: "##Q A" holds when A scores higher
// than every other group of its set, "#03 A" when at least 3 species of A occur.
const BARE = /^(##Q|##C|##D|#\d\d)$/;
export const isAtLeast = (code) => /^#\d\d$/.test(code);

const CODED = /^(###|##D|##Q|##C|#TC|#SC|#\d\d) (.+)$/;

export function parseOperand(s) {
  let m;
  if (/^-?\d+(\.\d+)?$/.test(s)) return { k: 'num', text: s };
  if ((m = s.match(/^\$(\d+)$/))) return { k: 'share', pct: m[1] };
  if ((m = s.match(/^\$\$([NC]) (.+)$/))) return { k: m[1] === 'N' ? 'hnum' : 'hcat', col: m[2] };
  if (s === '#$$') return { k: 'plotmax' };
  if (s === '#T$') return { k: 'total', except: [] };
  if ((m = s.match(/^#T\$ EXCEPT (.+)$/))) return { k: 'total', except: m[1].split('|') };
  if ((m = s.match(CODED))) {
    const code = m[1];
    const sides = m[2].split(' EXCEPT ');
    if (sides.length > 2) return null;
    const groups = sides[0].split('|').map((p, i) => (i === 0 ? p : p.startsWith(`${code} `) ? p.slice(4) : ''));
    if (groups.some((g) => !g.trim())) return null;
    return { k: 'measure', code, groups, except: sides[1] ? sides[1].split('|') : [] };
  }
  if (!s || /^[#$]/.test(s)) return null;
  return { k: 'name', text: s };
}

export function serializeOperand(o) {
  const except = o.except?.length ? ` EXCEPT ${o.except.join('|')}` : '';
  switch (o.k) {
    case 'num': case 'name': return o.text;
    case 'share': return `$${o.pct}`;
    case 'hnum': return `$$N ${o.col}`;
    case 'hcat': return `$$C ${o.col}`;
    case 'plotmax': return '#$$';
    case 'total': return `#T$${except}`;
    case 'measure': return o.groups.map((g) => `${o.code} ${g}`).join('|') + except;
    default: throw new Error(`unknown operand ${o.k}`);
  }
}

export const serializeCondition = (c) =>
  c.raw !== undefined ? c.raw : c.op ? `${serializeOperand(c.lhs)} ${c.op} ${serializeOperand(c.rhs)}` : serializeOperand(c.lhs);

// The condition written as `text`. Text that the blocks would not write back
// exactly as it stands stays raw.
export function parseCondition(text) {
  const t = text.trim();
  let c = null;
  const m = t.match(/^(.+?) (GR|GE|EQ) (.+)$/);
  if (m) {
    const lhs = parseOperand(m[1]), rhs = parseOperand(m[3]);
    const left = lhs && !['num', 'share'].includes(lhs.k), right = rhs && !['hnum', 'hcat'].includes(rhs.k);
    if (left && right) c = { lhs, op: m[2], rhs };
  } else {
    const lhs = parseOperand(t);
    if (lhs?.k === 'measure' && BARE.test(lhs.code)) c = { lhs, op: null, rhs: null };
  }
  return c && serializeCondition(c) === t ? c : { raw: t };
}

// The name of the group or species an EXCEPT entry stands for, and whether it
// is written as a group ("#TC Trees") or as a species ("Pinus mugo").
export const exceptName = (entry) => entry.replace(/^(###|##[QCD]|#TC|#SC|#T\$|#\d\d) /, '');
export const exceptIsGroup = (entry) => entry !== exceptName(entry);

function operandProblem(o) {
  switch (o.k) {
    case 'num': return /^-?\d+(\.\d+)?$/.test(o.text) ? null : 'a number is missing';
    case 'share': return /^\d+$/.test(o.pct) ? null : 'a percentage is missing';
    case 'hnum': case 'hcat': return o.col.trim() ? null : 'a site column is missing';
    case 'name': return o.text.trim() ? null : 'a name is missing';
    case 'measure': return o.groups.length && o.groups.every((g) => g.trim()) ? null : 'a group is missing';
    default: return null;
  }
}
export function conditionProblem(c) {
  if (c.raw !== undefined) return c.raw.trim() ? (/[<>]/.test(c.raw) ? 'a condition cannot contain < or >' : null) : 'the condition is empty';
  return operandProblem(c.lhs) ?? (c.op ? operandProblem(c.rhs) : null);
}

// ---- Formulas -------------------------------------------------------------------
// A tree node is { id, type: 'cond', c } or
// { id, type: 'group', op: 'AND' | 'OR', items, not }: the items joined by `op`,
// and none of the nodes in `not`.

export const condNode = (c) => ({ id: uid(), type: 'cond', c });
export const groupNode = (op = 'AND', items = [], not = []) => ({ id: uid(), type: 'group', op, items, not });

function tokens(text) {
  const out = [];
  const re = /\s*(?:<([^<>]*)>|([()])|([A-Z]+))/y;
  let at = 0;
  while (at < text.length) {
    re.lastIndex = at;
    const m = re.exec(text);
    if (!m) {
      if (!text.slice(at).trim()) break;
      throw new Error(`the formula has text outside a condition: "${text.slice(at, at + 30).trim()}"`);
    }
    at = re.lastIndex;
    if (m[1] !== undefined) out.push({ t: 'cond', text: m[1] });
    else if (m[2]) out.push({ t: m[2] });
    else if (['AND', 'OR', 'NOT'].includes(m[3])) out.push({ t: m[3] });
    else throw new Error(`the formula has the word "${m[3]}" outside a condition`);
  }
  return out;
}

// The tree of a formula, always a group at the top, and its conditions in the
// order they are written. Groups nested in a group of the same kind are merged
// into it, which does not change what the formula means.
export function parseFormula(text) {
  const toks = tokens(text), order = [];
  let i = 0;
  const peek = () => toks[i]?.t;
  const unary = () => {
    const tok = toks[i++];
    if (!tok) throw new Error('the formula ends where a condition is expected');
    if (tok.t === 'cond') { const n = condNode(parseCondition(tok.text)); order.push(n); return n; }
    if (tok.t === '(') {
      const n = or();
      if (toks[i++]?.t !== ')') throw new Error('a bracket is not closed');
      return n;
    }
    throw new Error(`"${tok.t}" stands where a condition is expected`);
  };
  const and = () => {
    const items = [], not = [];
    const add = (n) => {
      if (n.type === 'group' && n.op === 'AND') { items.push(...n.items); not.push(...n.not); } else items.push(n);
    };
    add(unary());
    for (;;) {
      if (peek() === 'AND') { i++; add(unary()); }
      else if (peek() === 'NOT') { i++; not.push(unary()); }
      else break;
    }
    if (items.length === 1 && !not.length) return items[0];
    if (items.length === 1 && items[0].type === 'group' && !items[0].not.length) { items[0].not = not; return items[0]; }
    return groupNode('AND', items, not);
  };
  const or = () => {
    const items = [];
    const add = (n) => {
      if (n.type === 'group' && n.op === 'OR' && !n.not.length) items.push(...n.items); else items.push(n);
    };
    add(and());
    while (peek() === 'OR') { i++; add(and()); }
    return items.length === 1 ? items[0] : groupNode('OR', items);
  };
  const top = or();
  if (i < toks.length) {
    throw new Error(toks[i].t === 'cond' ? 'two conditions follow each other without AND, OR or NOT between them' : `"${toks[i].t}" is not expected here`);
  }
  return { tree: top.type === 'group' ? top : groupNode('AND', [top]), order };
}

// The formula of a tree and its conditions in the order they are written.
export function serializeFormula(root) {
  const order = [];
  const nested = (n) => (n.type === 'group' && (n.items.length + n.not.length > 1) ? `(${ser(n)})` : ser(n));
  const ser = (n) => {
    if (n.type === 'cond') { order.push(n); return `<${serializeCondition(n.c)}>`; }
    const positive = n.items.map(nested).join(` ${n.op} `);
    if (!n.not.length) return positive;
    return (n.op === 'OR' && n.items.length > 1 ? `(${positive})` : positive) + n.not.map((x) => ` NOT ${nested(x)}`).join('');
  };
  return { text: ser(root), order };
}

// What keeps a tree from being a formula yet, or null.
export function formulaProblem(root) {
  const walk = (n) => {
    if (n.type === 'cond') return conditionProblem(n.c);
    if (!n.items.length) return n.not.length ? 'a group needs a condition that must hold besides those that must not' : 'a group is empty';
    for (const x of [...n.items, ...n.not]) { const p = walk(x); if (p) return p; }
    return null;
  };
  if (!root.items.length && !root.not.length) return 'the rule has no conditions yet';
  return walk(root);
}

// Whether the tree holds when `truth(cond)` gives the truth of each condition.
export function evalTree(n, truth) {
  if (n.type === 'cond') return truth(n);
  const pos = n.op === 'AND' ? n.items.every((x) => evalTree(x, truth)) : n.items.some((x) => evalTree(x, truth));
  return pos && !n.not.some((x) => evalTree(x, truth));
}

export function eachNode(root, fn, parent = null, list = null) {
  fn(root, parent, list);
  if (root.type === 'group') {
    for (const x of [...root.items]) eachNode(x, fn, root, 'items');
    for (const x of [...root.not]) eachNode(x, fn, root, 'not');
  }
}
export const conditions = (root) => { const out = []; eachNode(root, (n) => { if (n.type === 'cond') out.push(n); }); return out; };

// ---- The expert system ---------------------------------------------------------------
// model = {
//   metadata: { scheme, version, description },
//   synonyms: Map(canonical name -> [other names]),      the species list
//   groups:   [{ id, prefix, name, members: [species] }],
//   rules:    [{ id, priority, code, description, comment, expression, tree, order, problem }]
// }
// A rule keeps its formula as text (`expression`). `tree` is made from the text
// when the rule is first looked at (`undefined` before, `null` when the text is
// not a formula the page can show as blocks); a tree that is changed writes
// the text again. `order` holds the conditions of the tree in the order they
// stand in the text, and `problem` says why a changed tree is not written.

export const GROUP_PREFIXES = ['###', '##D', '##Q', '##C', '$$C', '$$N'];
export const PRIORITIES = [...'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'];
export const groupKey = (g) => `${g.prefix} ${g.name}`;

export const newModel = () => ({
  metadata: { scheme: '', version: new Date().toISOString().slice(0, 10), description: '' },
  synonyms: new Map(), groups: [], rules: [],
});
export const newGroup = (name = '') => ({ id: uid(), prefix: '###', name, members: [] });
export const newRule = () => ({
  id: uid(), priority: '5', code: '', description: '', comment: '', expression: '',
  tree: groupNode('AND'), order: [], problem: 'the rule has no conditions yet', inherit: false, overrides: {},
});

// The hierarchy of the types, made from their codes as resy_expert_tree() makes
// it: a type is a subtype of the type whose code is the longest proper prefix
// of its own code among the codes present (R12 under R1 under R). Returns the
// types in tree order, each as { rule, depth, parent, kids } with parent the
// id of the parent type (null for a top type) and kids its subtypes.
const codeIndex = (rules) => {
  const byCode = new Map();
  for (const r of rules) if (r.code && !byCode.has(r.code)) byCode.set(r.code, r);
  return byCode;
};
const parentIn = (byCode, r) => {
  for (let k = (r.code?.length ?? 0) - 1; k > 0; k--) {
    const p = byCode.get(r.code.slice(0, k));
    if (p) return p;
  }
  return null;
};
// The parent type of `rule` among `rules` (see typeTree()), or null.
export const parentOf = (rule, rules) => parentIn(codeIndex(rules), rule);
// With `fill`, as resy_expert_tree(fill = TRUE) does, the levels a code implies
// (one per character: Q11 under Q1 under Q) that no type defines are added as
// levels: { id: 'level:<code>', code, description: names[code], level: true },
// before the first type under them.
export const isLevel = (r) => Boolean(r?.level);
// The name of the type `code`: a code with several rules has one description
// per rule ("... trees 1", "... trees 2"), and the type's name is the words
// they share.
export function typeName(rules, code) {
  const words = rules.filter((r) => r.code === code).map((r) => (r.description ?? '').split(' '));
  if (!words.length) return '';
  let k = 0;
  while (k < Math.min(...words.map((w) => w.length)) && words.every((w) => w[k] === words[0][k])) k++;
  return k ? words[0].slice(0, k).join(' ') : words[0].join(' ');
}
export function typeTree(rules, { fill = false, names = {} } = {}) {
  let nodes = rules;
  if (fill) {
    const defined = codeIndex(rules), added = new Set();
    nodes = [];
    for (const r of rules) {
      for (let k = 1; k < (r.code?.length ?? 0); k++) {
        const code = r.code.slice(0, k);
        if (defined.has(code) || added.has(code)) continue;
        added.add(code);
        nodes.push({ id: `level:${code}`, code, description: names[code] ?? '', level: true });
      }
      nodes.push(r);
    }
  }
  const byCode = codeIndex(nodes);
  const kids = new Map(), parent = new Map();
  for (const r of nodes) {
    const p = parentIn(byCode, r)?.id ?? null;
    parent.set(r.id, p);
    if (!kids.has(p)) kids.set(p, []);
    kids.get(p).push(r);
  }
  const rows = [];
  const walk = (r, depth) => {
    const k = kids.get(r.id) ?? [];
    rows.push({ rule: r, depth, parent: parent.get(r.id), kids: k });
    for (const c of k) walk(c, depth + 1);
  };
  for (const r of kids.get(null) ?? []) walk(r, 0);
  return rows;
}

// ---- Inherited rules ----------------------------------------------------------------
// A type can inherit the rule of its parent type: its full rule is then the
// full rule of the parent AND its own conditions. The inherited conditions stay
// linked to the parent, so a change to the parent reaches the subtype, except
// where the subtype overrides one: `overrides` maps the id of a condition of the
// parent's full rule to { off: true } (the subtype leaves it out) or to
// { node } (the subtype's own version of it). An override of a condition the
// parent no longer has is left out of the rule.
//
// In a JSON file a subtype keeps its full formula as `expression`, so RESY
// reads it as any other rule, and the parts the page needs in `_inherit`:
// { from: parent code, own: its own formula, overrides: [{ at, was, set }] },
// where `at` is the place of the condition among the conditions of the
// parent's full formula, `was` its text and `set` the text of the override
// (null: left out).

const condText = (n) => serializeCondition(n.c);

// The tree `n` with the overrides applied: conditions left out or replaced, and
// groups left empty by that removed. Groups keep their ids.
function applyOverrides(n, overrides) {
  if (n.type === 'cond') {
    const o = overrides[n.id];
    return o?.off ? null : o?.node ?? n;
  }
  const items = n.items.map((x) => applyOverrides(x, overrides)).filter(Boolean);
  const not = n.not.map((x) => applyOverrides(x, overrides)).filter(Boolean);
  return items.length || not.length ? { ...n, items, not } : null;
}

// The groups inside a group of "all of these hold" joined into it as far as
// that does not change what the formula means: the conditions of a group of the
// same kind, and the exceptions of any group. A group left with one group
// inside is that group.
function joinAnd(root) {
  const items = [], not = [...root.not];
  for (const x of root.items) {
    if (x.type !== 'group') items.push(x);
    else if (x.op === 'AND') { items.push(...x.items); not.push(...x.not); }
    else { items.push(x.not.length ? { ...x, not: [] } : x); not.push(...x.not); }
  }
  return items.length === 1 && items[0].type === 'group' ? { ...items[0], not: [...items[0].not, ...not] } : { ...root, items, not };
}

// The overrides read from a file, matched to the conditions of the parent's
// full rule by place and text, or by text where the parent changed.
function settleOverrides(rule, fromOrder) {
  if (!rule.pending?.length) return;
  rule.overrides ??= {};
  for (const p of rule.pending) {
    const n = fromOrder[p.at] && condText(fromOrder[p.at]) === p.was ? fromOrder[p.at] : fromOrder.find((x) => condText(x) === p.was);
    if (n) rule.overrides[n.id] = p.set === null ? { off: true } : { node: condNode(parseCondition(p.set)) };
  }
  rule.pending = [];
}

// The full rule of a type: { tree, text, order, problem } with its conditions
// in `order` in the order they stand in `text`. For a type that inherits, also
// `parent`, the parent type, `from`, the full rule of the parent, and
// `orphans`, the number of overrides of conditions the parent no longer has.
export function fullRule(rule, rules) {
  const own = ruleTree(rule);
  if (!rule.inherit) return { tree: own, text: rule.expression, order: rule.order, problem: null };
  const parent = parentOf(rule, rules);
  const out = { tree: null, text: '', order: [], problem: null, parent, from: null, orphans: 0 };
  if (!parent) return { ...out, problem: 'it inherits the rule of the type above it, but no code is the start of its code' };
  const from = fullRule(parent, rules);
  out.from = from;
  if (ruleProblem(parent, rules) || !from.tree) return { ...out, problem: `the rule of ${parent.code}, which it inherits, is not finished` };
  if (!own) return { ...out, problem: 'its own conditions cannot be shown as blocks' };
  settleOverrides(rule, from.order);
  const overrides = rule.overrides ?? {}, ids = new Set(from.order.map((n) => n.id));
  out.orphans = Object.keys(overrides).filter((id) => !ids.has(id)).length;
  const kept = applyOverrides(from.tree, overrides);
  out.tree = joinAnd(groupNode('AND', [...(kept ? [kept] : []), ...(own.items.length || own.not.length ? [own] : [])]));
  out.problem = !kept && !own.items.length && !own.not.length ? 'every inherited condition is left out and it has none of its own' : formulaProblem(out.tree);
  if (!out.problem) ({ text: out.text, order: out.order } = serializeFormula(out.tree));
  return out;
}

// The conditions a type writes itself: those of its own tree and its versions
// of inherited conditions.
export const ownConditions = (rule) => [
  ...(ruleTree(rule) ? conditions(rule.tree) : []),
  ...Object.values(rule.overrides ?? {}).filter((o) => o.node).map((o) => o.node),
];

const strings = (v) => (v == null ? [] : Array.isArray(v) ? v.map(String) : [String(v)]);

export function modelFromJson(x) {
  if (!x || typeof x !== 'object' || Array.isArray(x)) throw new Error('The file does not hold an expert system.');
  for (const key of ['synonyms', 'groups', 'rules']) if (!(key in x)) throw new Error(`The file has no "${key}".`);
  if (!Array.isArray(x.rules)) throw new Error('"rules" must be a list of rules.');
  const meta = x.metadata ?? {};
  const model = {
    metadata: { ...meta, scheme: String(meta.scheme ?? ''), version: String(meta.version ?? ''), description: String(meta.description ?? '') },
    synonyms: new Map(Object.entries(x.synonyms).map(([name, v]) => [name, strings(v)])),
    groups: Object.entries(x.groups).map(([key, v]) => ({ id: uid(), prefix: key.slice(0, 3), name: key.slice(4), members: strings(v) })),
    rules: x.rules.map((r) => {
      const inh = r._inherit && typeof r._inherit === 'object' && !Array.isArray(r._inherit) ? r._inherit : null;
      return {
        id: uid(), priority: String(r.priority ?? ''), code: String(r.code ?? ''), description: String(r.description ?? ''),
        comment: String(r._comment ?? ''), expression: String(inh ? inh.own ?? '' : r.expression ?? ''), tree: undefined, order: [], problem: null,
        inherit: Boolean(inh), overrides: {},
        pending: inh && Array.isArray(inh.overrides) ? inh.overrides.filter((o) => o && Number.isInteger(o.at) && typeof o.was === 'string')
          .map((o) => ({ at: o.at, was: o.was, set: typeof o.set === 'string' ? o.set : null })) : [],
        file: inh ? String(r.expression ?? '') : null,
      };
    }),
  };
  // A subtype whose inherited rule and own conditions no longer make the
  // formula in the file (the file was edited elsewhere, or its parent changed
  // there) keeps the formula of the file, as its own rule.
  for (const r of model.rules) {
    if (!r.inherit) continue;
    if (!r.expression.trim()) Object.assign(r, { tree: groupNode('AND'), order: [] });
    const f = fullRule(r, model.rules);
    if (!f.problem && f.text !== r.file) {
      Object.assign(r, { inherit: false, overrides: {}, pending: [], expression: r.file, tree: undefined, order: [] });
      r.note = 'The file holds an inherited rule that no longer matches its formula; the type keeps the formula of the file as its own rule.';
    }
    delete r.file;
  }
  return model;
}

// The tree of a rule, made from its text when needed; null when the text
// cannot be shown as blocks.
export function ruleTree(rule) {
  if (rule.tree === undefined) {
    // A rule without a formula has the empty tree a new rule starts with.
    if (!rule.expression.trim()) {
      Object.assign(rule, { tree: groupNode('AND'), order: [], problem: 'the rule has no conditions yet' });
      return rule.tree;
    }
    try {
      ({ tree: rule.tree, order: rule.order } = parseFormula(rule.expression));
    } catch {
      rule.tree = null; rule.order = [];
    }
  }
  return rule.tree;
}

// Writes the text of a rule from its changed tree, or notes why it cannot.
// A type that inherits a rule needs no conditions of its own.
export function syncRule(rule) {
  const empty = !rule.tree.items.length && !rule.tree.not.length;
  rule.problem = empty && rule.inherit ? null : formulaProblem(rule.tree);
  if (!rule.problem) ({ text: rule.expression, order: rule.order } = empty ? { text: '', order: [] } : serializeFormula(rule.tree));
}

// Sets the text of a rule edited as text.
export function setRuleText(rule, text) {
  rule.expression = text.replace(/\s+/g, ' ').trim();
  rule.tree = undefined;
  rule.problem = null;
  ruleTree(rule);
  if (rule.tree === null) {
    try { parseFormula(rule.expression); } catch (e) { rule.problem = e.message; }
  } else rule.problem = rule.inherit && !rule.tree.items.length && !rule.tree.not.length ? null : formulaProblem(rule.tree);
}

// What keeps a rule from being tested and exported, or null. `rules`, all
// rules of the model, give a type that inherits the rule of its parent.
export function ruleProblem(rule, rules) {
  if (!rule.code.trim()) return 'the type has no code';
  if (/\s/.test(rule.code)) return 'the code contains a space';
  if (!PRIORITIES.includes(rule.priority)) return 'the priority is missing';
  if (rule.problem) return rule.problem;
  if (rule.inherit) return fullRule(rule, rules).problem;
  return rule.expression.trim() ? null : 'the rule has no conditions yet';
}

// The `_inherit` entry of a subtype in a JSON file (see fullRule()). Overrides
// read from a file and not yet matched to the parent's conditions stay as read.
function inheritJson(rule, f) {
  const overrides = rule.overrides ?? {};
  return {
    from: f.parent?.code ?? '', own: rule.expression,
    overrides: [...(f.from?.order ?? []).flatMap((n, at) => {
      const o = overrides[n.id];
      return o ? [{ at, was: condText(n), set: o.off ? null : condText(o.node) }] : [];
    }), ...(rule.pending ?? [])],
  };
}

// The JSON expert file of the model. `rules` picks the rules to write (those
// without a problem), `synonyms: false` leaves the species list empty.
export function modelToJson(model, { synonyms = true, rules = model.rules.filter((r) => !ruleProblem(r, model.rules)) } = {}) {
  return {
    metadata: model.metadata,
    synonyms: synonyms ? Object.fromEntries(model.synonyms) : {},
    groups: Object.fromEntries(model.groups.filter((g) => g.name.trim()).map((g) => [groupKey(g), g.members])),
    rules: rules.map((r) => {
      // An unfinished subtype, written only to a draft file, keeps its own formula.
      const f = r.inherit ? fullRule(r, model.rules) : null;
      return {
        ...(r.comment ? { _comment: r.comment } : {}),
        priority: r.priority, code: r.code, description: r.description, expression: f && !f.problem ? f.text : r.expression,
        ...(f ? { _inherit: inheritJson(r, f) } : {}),
      };
    }),
  };
}

// ---- References ----------------------------------------------------------------------

const operands = (c) => (c.raw !== undefined ? [] : [c.lhs, ...(c.rhs ? [c.rhs] : [])]);

// Names a rule uses: groups and site columns. A name that stands where a
// species or a group may stand counts when it is the name of a group.
export function ruleRefs(rule, groupNames) {
  const refs = { groups: new Set(), columns: new Set() };
  for (const n of ownConditions(rule)) {
    const c = n.c, header = c.raw === undefined && c.lhs.k === 'hcat';
    for (const o of operands(c)) {
      if (o.k === 'measure') o.groups.forEach((g) => refs.groups.add(g));
      if (o.k === 'hnum' || o.k === 'hcat') refs.columns.add(o.col);
      if (o.k === 'name' && !(header && o === c.rhs) && groupNames.has(o.text)) refs.groups.add(o.text);
      for (const e of o.except ?? []) {
        const name = exceptName(e);
        if (exceptIsGroup(e) || groupNames.has(name)) refs.groups.add(name);
      }
    }
  }
  return refs;
}

// Renames a group in every rule that uses it. Returns the number of rules changed.
export function renameGroup(model, from, to) {
  let changed = 0;
  for (const rule of model.rules) {
    let hit = false;
    for (const n of ownConditions(rule)) {
      for (const o of operands(n.c)) {
        if (o.k === 'measure' && o.groups.includes(from)) { o.groups = o.groups.map((g) => (g === from ? to : g)); hit = true; }
        if (o.except?.some((e) => exceptIsGroup(e) && exceptName(e) === from)) {
          o.except = o.except.map((e) => (exceptIsGroup(e) && exceptName(e) === from ? e.slice(0, 4) + to : e));
          hit = true;
        }
      }
    }
    if (hit) { if (rule.tree) syncRule(rule); changed++; }
  }
  return changed;
}

const NAME_BAD = /[<>|()[\]{}\t\n]|---| (GR|GE|EQ|EXCEPT|AND|OR|NOT) |^(AND|OR|NOT) | (AND|OR|NOT)$/;
// What is wrong with the name of a group, or null.
export function groupNameProblem(name) {
  if (!name.trim()) return 'the group has no name';
  if (name !== name.trim() || / {2}/.test(name)) return 'the name has spaces at an end or two spaces in a row';
  if (NAME_BAD.test(name)) return 'the name contains a character or word of the formula syntax (< > | ( ) GR GE EQ EXCEPT AND OR NOT)';
  if (/^-?\d+(\.\d+)?$/.test(name)) return 'the name is a number';
  return null;
}

// Everything worth a look before the system is used, as
// { level: 'error' | 'warning', kind: 'meta' | 'species' | 'group' | 'rule', id, text }.
// An error keeps the system or a rule from being written.
// A note that holds for several types or groups is written once and names the
// first of them; its `id` is that of the first.
const NAMED = 6;
const named = (names) => (names.length > NAMED ? `${names.slice(0, NAMED).join(', ')} and ${names.length - NAMED} more` : names.join(', '));
export function checkModel(model, data = null) {
  const out = [];
  const add = (level, kind, id, text) => out.push({ level, kind, id, text });
  // `one(name)` words the note for a single entry, `many(n)` opens it for several.
  const note = (kind, items, name, one, many) => {
    if (items.length === 1) add('warning', kind, items[0].id, one(name(items[0])));
    else if (items.length) add('warning', kind, items[0].id, `${many(items.length)}: ${named(items.map(name))}.`);
  };
  const groupName = (g) => `"${g.name}"`, typeName = (r) => r.code || 'a type without a code';
  if (!model.metadata.scheme.trim()) add('warning', 'meta', null, 'The system has no name.');
  if (!model.metadata.version.trim()) add('warning', 'meta', null, 'The system has no version.');

  const names = new Map();
  const empty = [], unnamed = [], reading = new Map();
  for (const g of model.groups) {
    const p = groupNameProblem(g.name);
    if (p) add('error', 'group', g.id, `Group "${g.name}": ${p}.`);
    else if (names.has(g.name)) add('error', 'group', g.id, `Two groups are named "${g.name}".`);
    names.set(g.name, g);
    if (!g.members.length && !g.prefix.startsWith('$')) empty.push(g);
  }
  note('group', empty, groupName, (n) => `Group ${n} has no species.`, (n) => `${n} groups have no species`);
  const groupNames = new Set(names.keys());
  const used = new Set();
  // The site columns are known once the first test has run.
  const columns = data?.columns.length ? new Set(data.columns.map((c) => c.name)) : null;
  if (!model.rules.length) add('warning', 'rule', null, 'The system has no types yet.');
  for (const r of model.rules) {
    const label = r.code ? `Type ${r.code}` : 'A type without a code';
    if (r.note) add('warning', 'rule', r.id, `${label}: ${r.note}`);
    const p = ruleProblem(r, model.rules);
    if (p) { add('error', 'rule', r.id, `${label}: ${p}.`); continue; }
    if (r.inherit) {
      // Where a subtype holds, the rule it inherits holds too, as long as it
      // leaves none of the inherited conditions out.
      const f = fullRule(r, model.rules), up = f.parent;
      const off = Object.values(r.overrides ?? {}).some((o) => o.off);
      if (!off && PRIORITIES.indexOf(r.priority) <= PRIORITIES.indexOf(up.priority)) {
        add('warning', 'rule', r.id, `${label} inherits the rule of ${up.code}, so every plot it takes also meets the rule of ${up.code}; with ${r.priority === up.priority ? 'the same' : 'a lower'} priority, ${r.priority === up.priority ? 'the two tie on these plots' : `${up.code} takes them`}. Give ${r.code} a higher priority than ${up.priority}.`);
      }
      if (f.orphans) add('warning', 'rule', r.id, `${label} changes ${f.orphans === 1 ? 'a condition' : `${f.orphans} conditions`} that the rule of ${up.code} no longer has; ${f.orphans === 1 ? 'the change is' : 'these changes are'} left out.`);
    }
    if (!r.description.trim()) unnamed.push(r);
    if (/[<>]|---/.test(r.description)) add('error', 'rule', r.id, `${label}: the name contains <, > or ---.`);
    const refs = ruleRefs(r, groupNames);
    refs.groups.forEach((g) => used.add(g));
    const undefinedGroups = [...refs.groups].filter((g) => !groupNames.has(g));
    if (undefinedGroups.length) add('error', 'rule', r.id, `${label} uses ${undefinedGroups.length > 1 ? 'groups that do' : 'a group that does'} not exist: ${undefinedGroups.join(', ')}.`);
    if (columns) {
      for (const c of refs.columns) if (!columns.has(c)) reading.set(c, [...(reading.get(c) ?? []), r]);
    }
  }
  note('rule', unnamed, typeName, (n) => `Type ${n} has no name.`, (n) => `${n} types have no name`);
  for (const [column, rules] of reading) {
    note('rule', rules, typeName, (n) => `Type ${n} reads the site column "${column}", which the test plots do not have.`,
      (n) => `${n} types read the site column "${column}", which the test plots do not have`);
  }
  const unused = model.rules.length ? model.groups.filter((g) => g.name && !used.has(g.name) && !g.prefix.startsWith('$')) : [];
  note('group', unused, groupName, (n) => `Group ${n} is not used by any type.`, (n) => `${n} groups are not used by any type`);
  return out;
}
