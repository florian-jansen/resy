// The map of plots shared by the RESY App and the RESY Maker: OpenStreetMap
// tiles (Leaflet, loaded by the page as the global L) with every plot as a dot
// on one canvas, so the map stays fast with millions of plots.

// A position in degrees as Web Mercator scaled to [0, 1]: x east, y south.
export const mercator = (lon, lat) => {
  const s = Math.sin(lat * Math.PI / 180);
  return [(lon + 180) / 360, 0.5 - Math.log((1 + s) / (1 - s)) / (4 * Math.PI)];
};
// The position of a plot from its longitude and latitude, or [NaN, NaN]
// when it has none that the map can show.
export const placeOf = (lon, lat) => (Number.isFinite(lon) && Number.isFinite(lat) && Math.abs(lat) < 85 ? mercator(lon, lat) : [NaN, NaN]);

const latLngOf = (x, y) => L.latLng(Math.atan(Math.sinh(Math.PI * (1 - 2 * y))) * 180 / Math.PI, x * 360 - 180);
const boundsOf = (box) => L.latLngBounds(latLngOf(box.x0, box.y1), latLngOf(box.x1, box.y0));

// A map in the element with the id `id`. `frame()` is called once for every
// drawing and every click and says what the map shows then:
//   n                 the number of plots
//   shown             how many of them are drawn (n when left out); the dots get smaller with it
//   x(i), y(i)        the position of plot i (see mercator()), NaN without one
//   state(i)          -1 not drawn, 0 drawn behind the other plots, 1 drawn in front
//   colour(i, front)  the colour of its dot, as #rrggbb
//   picks(i)          whether a click takes plot i (the plots in front when left out)
//   selected          the plot with a ring around it, or null
// `pick(i)` is called with the plot that was clicked. The map is made when it
// is first drawn.
export function createDotMap(id, frame, pick) {
  return {
    map: null, canvas: null, fitted: false, drawing: false, box: null,
    init() {
      this.map = L.map(id, { scrollWheelZoom: false, worldCopyJump: false }).setView([50, 10], 4);
      L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 18, attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      }).addTo(this.map);
      this.canvas = L.DomUtil.create('canvas', 'resy-dots leaflet-zoom-hide');
      this.map.getPanes().overlayPane.appendChild(this.canvas);
      this.map.on('moveend zoomend resize', () => this.draw());
      this.map.on('click', (e) => this.click(e));
      // A map made while its element is not shown has no size yet; it is drawn
      // again, and moved to its plots, when the element gets one.
      new ResizeObserver(() => this.redraw()).observe(this.map.getContainer());
    },
    // Draws the map again after its plots or its size changed; the view moves
    // to the plots when `fitted` is false.
    redraw() {
      if (!this.map) this.init();
      this.map.invalidateSize();
      const size = this.map.getSize();
      if (!this.fitted && size.x && size.y) this.fit();
      this.draw();
    },
    fit() {
      const f = frame();
      let x0 = Infinity, x1 = -Infinity, y0 = Infinity, y1 = -Infinity, any = false;
      for (let i = 0; i < f.n; i++) {
        const x = f.x(i), y = f.y(i);
        if (Number.isNaN(x) || f.state(i) < 0) continue;
        any = true;
        x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y);
      }
      if (!any) return;
      this.map.fitBounds(boundsOf({ x0, x1, y0, y1 }).pad(0.15));
      this.fitted = true;
    },
    view() {
      const size = this.map.getSize(), scale = 256 * 2 ** this.map.getZoom();
      const o = this.map.getPixelBounds().min;
      return { size, scale, ox: o.x, oy: o.y };
    },
    // Dot radius in CSS pixels: smaller as more plots are shown.
    radius(f = frame()) {
      const n = f.shown ?? f.n;
      return n > 200000 ? 1 : n > 20000 ? 1.5 : n > 2000 ? 2.5 : 4.5;
    },
    // Calls fn(x, y, i, front) for each plot drawn in the view, x and y in CSS
    // pixels of the map. The plots behind come first, so the others are drawn
    // on top of them.
    eachDot({ size, scale, ox, oy }, fn, f = frame()) {
      const pad = this.radius(f) + 1;
      for (const front of [false, true]) {
        const want = front ? 1 : 0;
        for (let i = 0; i < f.n; i++) {
          if (f.state(i) !== want) continue;
          const x = f.x(i);
          if (Number.isNaN(x)) continue;
          const px = x * scale - ox, py = f.y(i) * scale - oy;
          if (px > -pad && py > -pad && px < size.x + pad && py < size.y + pad) fn(px, py, i, front);
        }
      }
    },
    // The selected plot in CSS pixels of the view, or null when it has no position.
    selectedPixel({ scale, ox, oy }, f = frame()) {
      if (f.selected === null || f.selected === undefined) return null;
      const x = f.x(f.selected);
      return Number.isNaN(x) ? null : [x * scale - ox, f.y(f.selected) * scale - oy];
    },
    draw() {
      if (!this.map) return;
      const v = this.view(), { size } = v;
      if (!size.x || !size.y) return;
      const f = frame();
      const c = this.canvas, ratio = window.devicePixelRatio || 1;
      c.width = size.x * ratio; c.height = size.y * ratio;
      c.style.width = `${size.x}px`; c.style.height = `${size.y}px`;
      L.DomUtil.setPosition(c, this.map.containerPointToLayerPoint([0, 0]));
      const ctx = c.getContext('2d');
      const img = ctx.createImageData(c.width, c.height), px = new Uint32Array(img.data.buffer);
      const r = Math.max(1, Math.round(this.radius(f) * ratio));
      const disc = [];
      for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) if (dx * dx + dy * dy <= r * r + r) disc.push([dx, dy]);
      // The pixel value of a colour: the plots in front nearly opaque, those behind faint.
      const known = [new Map(), new Map()];
      const rgba = (hex, front) => {
        const of = known[front ? 1 : 0];
        if (!of.has(hex)) {
          const n = parseInt(hex.replace('#', ''), 16), a = front ? 235 : 110;
          of.set(hex, ((a << 24) | ((n & 255) << 16) | (((n >> 8) & 255) << 8) | (n >> 16)) >>> 0);
        }
        return of.get(hex);
      };
      const W = c.width, H = c.height;
      this.eachDot(v, (cx, cy, i, front) => {
        const x = Math.round(cx * ratio), y = Math.round(cy * ratio), colour = rgba(f.colour(i, front), front);
        for (const [dx, dy] of disc) {
          const xx = x + dx, yy = y + dy;
          if (xx >= 0 && yy >= 0 && xx < W && yy < H) px[yy * W + xx] = colour;
        }
      }, f);
      ctx.putImageData(img, 0, 0);
      const p = this.selectedPixel(v, f);
      if (p) {
        // The selected plot is drawn last, in its colour of a plot in front, so it
        // shows on top of any plots at the same place.
        ctx.beginPath(); ctx.arc(p[0] * ratio, p[1] * ratio, r + 0.5 * ratio, 0, 2 * Math.PI);
        ctx.fillStyle = f.colour(f.selected, true);
        ctx.fill();
        ctx.beginPath(); ctx.arc(p[0] * ratio, p[1] * ratio, r + 5 * ratio, 0, 2 * Math.PI);
        ctx.lineWidth = 2 * ratio;
        ctx.strokeStyle = getComputedStyle(c).getPropertyValue('--bs-emphasis-color').trim() || '#000';
        ctx.stroke();
      }
    },
    // The next drag on the map draws a rectangle in place of moving the map.
    // `done(box)` gets it as { x0, x1, y0, y1 } in the units of mercator(), or
    // null when Escape ends the drawing.
    drawBox(done) {
      const map = this.map, el = map.getContainer();
      let from = null, to = null, rect = null;
      const end = (box) => {
        map.off('mousedown', down); map.off('mousemove', move);
        document.removeEventListener('mouseup', up); document.removeEventListener('keydown', key);
        map.dragging.enable();
        el.classList.remove('drawing');
        if (rect) rect.remove();
        // The click that follows the drag is not a click on a plot.
        setTimeout(() => { this.drawing = false; }, 0);
        done(box);
      };
      const down = (e) => { from = e.latlng; to = null; e.originalEvent.preventDefault(); };
      const move = (e) => {
        if (!from) return;
        to = e.latlng;
        const b = L.latLngBounds(from, to);
        rect = rect ? rect.setBounds(b) : L.rectangle(b, { weight: 1, interactive: false }).addTo(map);
      };
      const up = () => {
        if (!from || !to) { from = null; return; }
        const a = mercator(from.lng, from.lat), b = mercator(to.lng, to.lat);
        end({ x0: Math.min(a[0], b[0]), x1: Math.max(a[0], b[0]), y0: Math.min(a[1], b[1]), y1: Math.max(a[1], b[1]) });
      };
      const key = (e) => { if (e.key === 'Escape') end(null); };
      this.drawing = true;
      map.dragging.disable();
      el.classList.add('drawing');
      map.on('mousedown', down); map.on('mousemove', move);
      document.addEventListener('mouseup', up); document.addEventListener('keydown', key);
    },
    // Shows `box` (see drawBox()) as a rectangle on the map; null removes it.
    showBox(box) {
      if (this.box) this.box.remove();
      this.box = box && this.map ? L.rectangle(boundsOf(box), { weight: 1.5, dashArray: '5 4', fill: false, interactive: false }).addTo(this.map) : null;
    },
    // A click takes a plot whose dot is under the pointer, those drawn in front
    // first, then the nearest; with none under it, the nearest plot within 8
    // pixels. Clicking again on the plot selected takes the next plot under the
    // pointer in plot order, so every plot of a stack of dots can be reached.
    click(e) {
      if (this.drawing) return;
      const { scale, ox, oy } = this.view(), f = frame();
      const picks = f.picks ?? ((i) => f.state(i) === 1);
      const onDot = (this.radius(f) + 1) ** 2;
      const under = [];
      let best = -1, bestD = 64;
      for (let i = 0; i < f.n; i++) {
        if (!picks(i)) continue;
        const x = f.x(i);
        if (Number.isNaN(x)) continue;
        const d = (x * scale - ox - e.containerPoint.x) ** 2 + (f.y(i) * scale - oy - e.containerPoint.y) ** 2;
        if (d <= onDot) under.push({ i, d, front: f.state(i) === 1 });
        if (d < bestD) { bestD = d; best = i; }
      }
      if (!under.length) { if (best >= 0) pick(best); return; }
      const k = under.findIndex((h) => h.i === f.selected);
      if (k >= 0) return pick(under[(k + 1) % under.length].i);
      under.sort((a, b) => b.front - a.front || a.d - b.d);
      pick(under[0].i);
    },
  };
}
