// Генератор иконок SVOI: два переплетённых кольца #FF5A36.
// Использование: node tools/gen_icons.js
const zlib = require('zlib');
const fs = require('fs');
const path = require('path');

// --- CRC32 ---
const crcTable = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();
function crc32(buf) {
  let c = 0xffffffff;
  for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}

function writePng(file, size, pixelAt) {
  const raw = Buffer.alloc((size * 4 + 1) * size);
  for (let y = 0; y < size; y++) {
    raw[y * (size * 4 + 1)] = 0; // filter: none
    for (let x = 0; x < size; x++) {
      const [r, g, b, a] = pixelAt(x + 0.5, y + 0.5);
      const o = y * (size * 4 + 1) + 1 + x * 4;
      raw[o] = r; raw[o + 1] = g; raw[o + 2] = b; raw[o + 3] = a;
    }
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8;  // bit depth
  ihdr[9] = 6;  // color type RGBA
  const png = Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, png);
  console.log('written', file, png.length, 'bytes');
}

// Параметры колец как в RingsPainter: radius 0.27w, stroke 0.075w,
// центры 0.37/0.63 по ширине.
const CORAL = [0xff, 0x5a, 0x36];
const BG = [0xfa, 0xf7, 0xf2];

function ringPixel(x, y, size, scale, cxOffset, withBg) {
  // cxOffset: 0 — центр холста
  const w = size * scale;
  const r = w * 0.27;
  const stroke = w * 0.075;
  const cy = size / 2;
  const c1x = size / 2 + cxOffset - w * 0.13;
  const c2x = size / 2 + cxOffset + w * 0.13;

  const d1 = Math.hypot(x - c1x, y - cy);
  const d2 = Math.hypot(x - c2x, y - cy);
  const half = stroke / 2;
  const on1 = Math.abs(d1 - r) <= half;
  const on2 = Math.abs(d2 - r) <= half;

  if (on1 || on2) return [...CORAL, 255];
  return withBg ? [...BG, 255] : [0, 0, 0, 0];
}

// Полная иконка 512×512 с фоном.
writePng('assets/icon/app_icon.png', 512, (x, y) =>
  ringPixel(x, y, 512, 1.0, 0, true));

// Адаптивный foreground 512×512: кольца меньше (safe zone ~66%), прозрачный фон.
writePng('assets/icon/app_icon_fg.png', 512, (x, y) =>
  ringPixel(x, y, 512, 0.62, 0, false));

// Логотип для splash 512×512 (прозрачный фон, кольца покрупнее).
writePng('assets/icon/splash_logo.png', 512, (x, y) =>
  ringPixel(x, y, 512, 0.8, 0, false));
