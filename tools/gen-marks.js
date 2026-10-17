// Draws the target and focus mark shapes as smooth, mipmapped BLP textures in Media/.
// node tools/gen-marks.js [previewDir]
//
// Each shape is drawn pointing down (toward a nameplate below it), white (the game tints it),
// with a soft one-texel edge from its signed distance, on a canvas that spans -0.6 to 0.6 of
// the mark's size, so an outline fits around it. Each also gets an -Edge texture: the same shape
// grown by EDGE, drawn behind it as the outline. Every mip level down to 1x1 is stored, so a
// small mark is drawn from a small, clean level instead of a thinned-out big one.
const fs = require('fs'), path = require('path');

const SIZE = 256;      // texels across
const SPAN = 1.2;      // the canvas, in mark sizes
const EDGE = 0.07;     // the outline, in mark sizes (RangeLens.lua's MARK_EDGE)
const T = 0.16;        // the chevron's arm thickness
const R2 = Math.SQRT2;

// The chevron: two arms at 45 degrees (a 90 degree V, the diamond's corner), square ends.
// Outer point O, inner point I = O + T * sqrt 2, arm ends half a size out each side.
function chevron() {
  const half = 0.5, top = half + T / R2;           // height above O of the arms' inner ends
  const low = -top / 2;                             // centered
  return [
    [0, low], [half, low + half], [half - T / R2, low + top], [0, low + T * R2],
    [-(half - T / R2), low + top], [-half, low + half],
  ];
}

const SHAPES = {
  // A 90 degree point, like the chevron's corner and the diamond's, so any of them fits another.
  Arrow: { poly: [[-0.5, 0.25], [0.5, 0.25], [0, -0.25]] },
  Chevron: { poly: chevron() },
  Diamond: { poly: [[0, 0.5], [0.5, 0], [0, -0.5], [-0.5, 0]] },
  Dot: { circle: 0.35 },
  // An arrowhead with a notched back, lit from the left: a lighter left half, a darker right.
  Dart: { poly: [[0, -0.48], [0.46, 0.42], [0, 0.2], [-0.46, 0.42]], bevel: true },
};

function segDist(px, py, ax, ay, bx, by) {
  const dx = bx - ax, dy = by - ay;
  const t = Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)));
  return Math.hypot(px - ax - t * dx, py - ay - t * dy);
}

// Signed distance: negative inside.
function sdf(shape, x, y) {
  if (shape.circle) return Math.hypot(x, y) - shape.circle;
  const p = shape.poly;
  let d = Infinity, inside = false;
  for (let i = 0, j = p.length - 1; i < p.length; j = i++) {
    const [ax, ay] = p[j], [bx, by] = p[i];
    d = Math.min(d, segDist(x, y, ax, ay, bx, by));
    if ((ay > y) !== (by > y) && x < ax + (y - ay) * (bx - ax) / (by - ay)) inside = !inside;
  }
  return inside ? -d : d;
}

// Level 0: gray (0-1) and alpha (0-1) per texel, rows top to bottom.
function draw(shape, grow, bevel) {
  const texel = SPAN / SIZE;
  const gray = new Float64Array(SIZE * SIZE), alpha = new Float64Array(SIZE * SIZE);
  for (let j = 0; j < SIZE; j++) for (let i = 0; i < SIZE; i++) {
    const x = -SPAN / 2 + (i + 0.5) * texel, y = SPAN / 2 - (j + 0.5) * texel;
    const a = Math.max(0, Math.min(1, 0.5 - (sdf(shape, x, y) - grow) / texel));
    const k = j * SIZE + i;
    alpha[k] = a;
    gray[k] = bevel ? 0.72 + 0.28 * Math.max(0, Math.min(1, 0.5 - x / texel)) : 1;
  }
  return { w: SIZE, h: SIZE, gray, alpha };
}

// Half size: alpha averaged, gray averaged by alpha (so no dark fringe).
function halve(m) {
  const w = Math.max(1, m.w >> 1), h = Math.max(1, m.h >> 1);
  const gray = new Float64Array(w * h), alpha = new Float64Array(w * h);
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
    let a = 0, g = 0, n = 0;
    for (let dj = 0; dj < 2; dj++) for (let di = 0; di < 2; di++) {
      const x = Math.min(m.w - 1, i * 2 + di), y = Math.min(m.h - 1, j * 2 + dj), k = y * m.w + x;
      a += m.alpha[k]; g += m.gray[k] * m.alpha[k]; n++;
    }
    alpha[j * w + i] = a / n;
    gray[j * w + i] = a > 0 ? g / a : 1;
  }
  return { w, h, gray, alpha };
}

// BLP2, palette (256 grays) with 8-bit alpha, every mip level.
function blp(level0) {
  const levels = [level0];
  while (levels[levels.length - 1].w > 1) levels.push(halve(levels[levels.length - 1]));
  const head = Buffer.alloc(1172);
  head.write('BLP2', 0, 'ascii');
  head.writeUInt32LE(1, 4);      // BLP
  head[8] = 1;                   // palette
  head[9] = 8;                   // 8-bit alpha
  head[10] = 8;
  head[11] = 1;                  // has mips
  head.writeUInt32LE(level0.w, 12);
  head.writeUInt32LE(level0.h, 16);
  for (let i = 0; i < 256; i++) head.writeUInt32LE(((255 << 24) | (i << 16) | (i << 8) | i) >>> 0, 148 + i * 4);
  const bodies = [];
  let offset = head.length;
  levels.forEach((m, n) => {
    const b = Buffer.alloc(m.w * m.h * 2);
    for (let k = 0; k < m.w * m.h; k++) {
      b[k] = Math.round(m.gray[k] * 255);
      b[m.w * m.h + k] = Math.round(m.alpha[k] * 255);
    }
    head.writeUInt32LE(offset, 20 + n * 4);
    head.writeUInt32LE(b.length, 84 + n * 4);
    offset += b.length;
    bodies.push(b);
  });
  return Buffer.concat([head, ...bodies]);
}

const media = path.join(__dirname, '..', 'Media');
fs.mkdirSync(media, { recursive: true });
const preview = process.argv[2];
const made = [];
for (const [name, shape] of Object.entries(SHAPES)) {
  for (const edge of [false, true]) {
    const file = `Mark-${name}${edge ? '-Edge' : ''}.blp`;
    const level0 = draw(shape, edge ? EDGE : 0, shape.bevel && !edge);
    fs.writeFileSync(path.join(media, file), blp(level0));
    made.push(file);
  }
}
console.log('wrote', made.join(', '));

// Previews: each mark (outline black, fill orange) on a dark plate color, at the full level and
// at the 32 texel level blown up, as the game would pick for a small mark.
if (preview) {
  const { decodeBLP, png } = require('C:/Users/jonli/wow-forever-addon-creations/blp-lib.js');
  const names = Object.keys(SHAPES);
  const cell = 256, W = cell * names.length, H = cell * 2, out = Buffer.alloc(W * H * 4);
  for (let i = 0; i < W * H; i++) out.set([38, 34, 30, 255], i * 4);
  const levelOf = (buf, n) => {
    const w = buf.readUInt32LE(12) >> n, h = buf.readUInt32LE(16) >> n;
    const off = buf.readUInt32LE(20 + n * 4), size = buf.readUInt32LE(84 + n * 4);
    const copy = Buffer.from(buf);
    copy.writeUInt32LE(w, 12); copy.writeUInt32LE(h, 16); copy.writeUInt32LE(off, 20); copy.writeUInt32LE(size, 84);
    return decodeBLP(copy);
  };
  names.forEach((name, c) => {
    const fill = fs.readFileSync(path.join(media, `Mark-${name}.blp`)), edge = fs.readFileSync(path.join(media, `Mark-${name}-Edge.blp`));
    for (const [row, n] of [[0, 0], [1, 3]]) {
      const f = levelOf(fill, n), e = levelOf(edge, n), scale = cell / f.w;
      for (let y = 0; y < cell; y++) for (let x = 0; x < cell; x++) {
        const k = (Math.floor(y / scale) * f.w + Math.floor(x / scale)) * 4, o = ((row * cell + y) * W + c * cell + x) * 4;
        let r = out[o], g = out[o + 1], b = out[o + 2];
        const ea = e.px[k + 3] / 255; r *= 1 - ea; g *= 1 - ea; b *= 1 - ea;
        const fa = f.px[k + 3] / 255, shade = f.px[k] / 255;
        r = r * (1 - fa) + 255 * shade * fa; g = g * (1 - fa) + 120 * shade * fa; b = b * (1 - fa) + 20 * shade * fa;
        out.set([r, g, b, 255], o);
      }
    }
  });
  fs.writeFileSync(path.join(preview, 'marks-preview.png'), png(W, H, out));
  console.log('preview', path.join(preview, 'marks-preview.png'));
}
