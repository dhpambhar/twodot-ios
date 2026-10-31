// Renders the DotBloom app icon (1024x1024 PNG) with no dependencies.
// Flat, hand-drawn look: speckled paper, two ink-outlined dots joined by a drawn link.
// Usage: node render-icon.js <out.png> <light|dark|tinted>
const fs = require('fs');
const zlib = require('zlib');

const [, , out, variant = 'light'] = process.argv;
const S = 1024, SS = 3; // size, supersampling per axis

const hex = (h) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];
const gray = (c) => { const l = 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]; return [l, l, l]; };

const PALETTES = {
  light: { paper: hex('#EEE6FB'), speck: hex('#C9B6F0'), a: hex('#F4676B'), b: hex('#4E9EF8'), ink: hex('#241E38'), shine: 0.35 },
  dark: { paper: hex('#1D1830'), speck: hex('#3A2F5C'), a: hex('#F4676B'), b: hex('#4E9EF8'), ink: hex('#0D0A16'), shine: 0.25 },
  tinted: { paper: hex('#000000'), speck: hex('#1E1E1E'), a: gray(hex('#F4676B')), b: hex('#F2F2F2'), ink: hex('#000000'), shine: 0 },
};
const P = PALETTES[variant] || PALETTES.light;

// Composition: coral dot top-left, sky dot bottom-right, a thick link between them.
const R = 178;              // dot radius
const A = { x: 340, y: 350 };
const B = { x: 684, y: 674 };
const LINK = 44;            // half-width of the link band
const OUTLINE = 15;         // ink outline width

// Deterministic speckles.
let seed = 7;
const rnd = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296);
const specks = Array.from({ length: 90 }, () => ({ x: rnd() * S, y: rnd() * S, r: 4 + rnd() * 9 }));

const mix = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];

function segDist(px, py) {
  const vx = B.x - A.x, vy = B.y - A.y;
  const t = Math.max(0, Math.min(1, ((px - A.x) * vx + (py - A.y) * vy) / (vx * vx + vy * vy)));
  return Math.hypot(px - (A.x + vx * t), py - (A.y + vy * t));
}

function sample(x, y) {
  let c = P.paper;
  for (const s of specks) if (Math.hypot(x - s.x, y - s.y) < s.r) { c = P.speck; break; }

  const dA = Math.hypot(x - A.x, y - A.y) - R;
  const dB = Math.hypot(x - B.x, y - B.y) - R;
  const dL = segDist(x, y) - LINK;
  const sdf = Math.min(dA, dB, dL);   // union of both dots and the link

  // Soft offset shadow on the paper, like a sticker.
  if (variant !== 'tinted') {
    const sA = Math.hypot(x - A.x - 14, y - A.y - 18) - R;
    const sB = Math.hypot(x - B.x - 14, y - B.y - 18) - R;
    if (Math.min(sA, sB) < 0 && sdf > OUTLINE / 2) c = mix(c, P.ink, 0.12);
  }

  if (sdf < OUTLINE / 2) {
    if (sdf > -OUTLINE / 2) return P.ink;   // outline around the whole shape
    if (dA < 0) c = P.a;
    else if (dB < 0) c = P.b;
    else c = P.ink;                          // the drawn link
    // Small flat highlight arc on each dot.
    for (const [d, ctr] of [[dA, A], [dB, B]]) {
      if (d < 0 && P.shine > 0) {
        const hx = ctr.x - R * 0.42, hy = ctr.y - R * 0.42;
        if (Math.hypot((x - hx) * 0.9, (y - hy) * 1.25) < R * 0.17) c = mix(c, [255, 255, 255], P.shine * 2);
      }
    }
  }
  return c;
}

const raw = Buffer.alloc(S * (S * 3 + 1));
for (let y = 0; y < S; y++) {
  raw[y * (S * 3 + 1)] = 0;
  for (let x = 0; x < S; x++) {
    const acc = [0, 0, 0];
    for (let sy = 0; sy < SS; sy++) {
      for (let sx = 0; sx < SS; sx++) {
        const c = sample(x + (sx + 0.5) / SS, y + (sy + 0.5) / SS);
        acc[0] += c[0]; acc[1] += c[1]; acc[2] += c[2];
      }
    }
    const o = y * (S * 3 + 1) + 1 + x * 3;
    for (let k = 0; k < 3; k++) raw[o + k] = Math.max(0, Math.min(255, Math.round(acc[k] / (SS * SS))));
  }
}

const crcTable = new Int32Array(256).map((_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c;
});
const crc32 = (buf) => { let c = -1; for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8); return (c ^ -1) >>> 0; };
const chunk = (type, data) => {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
};
const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(S, 0); ihdr.writeUInt32BE(S, 4);
ihdr[8] = 8; ihdr[9] = 2; // 8-bit RGB, no alpha (App Store requirement)
const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk('IHDR', ihdr),
  chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
  chunk('IEND', Buffer.alloc(0)),
]);
fs.writeFileSync(out, png);
console.log(`wrote ${out} (${variant}, ${png.length} bytes)`);
