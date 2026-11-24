// The colours of types, shared by the RESY App and the RESY Maker. The colours
// themselves are the --lv-* variables of page.css.

// The EUNIS habitat groups with a colour of their own, in the order in which
// the types of other systems get them.
export const PALETTE = ['T', 'N', 'M', 'R', 'S', 'P', 'Q', 'U', 'V'];

// The EUNIS habitat group of a type: the first letter of its code.
export const level = (code) => (code && /^[A-Z]/.test(code) ? code[0] : 'none');

// The variable that colours type `code`. Plots no type takes ('?') and those
// tied between types ('+') are grey. With `order`, a list of codes, the first
// PALETTE.length codes in it get a colour each and the others share one;
// without it, a type has the colour of its EUNIS habitat group.
export function colourVar(code, order = null) {
  if (code === undefined || code === null || code === '?' || code === '+') return '--lv-none';
  if (order) {
    const k = order.indexOf(code);
    return k >= 0 && k < PALETTE.length ? `--lv-${PALETTE[k]}` : '--lv-other';
  }
  const l = level(code);
  return PALETTE.includes(l) ? `--lv-${l}` : '--lv-other';
}

// The value of the CSS variable `name` on element `el`.
export const cssValue = (el, name) => getComputedStyle(el).getPropertyValue(name).trim();
