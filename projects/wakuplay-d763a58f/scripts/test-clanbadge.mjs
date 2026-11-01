import { layoutBadge, clampTier, MAX_TIER, TIER_NAMES, inPoly, minEdgeDist, boxInside, textWidth, EX, TOP, BOT } from '../src/lib/clanbadgeGeom.js'

let fail = 0
const bad = (m) => { fail++; if (fail <= 40) console.log('GAGAL:', m) }

for (const v of [undefined, null, NaN, 'abc', -5, 0, 1.9, 999, '7', Infinity]) { const t = clampTier(v); if (!(t >= 1 && t <= MAX_TIER && Number.isInteger(t))) bad('clampTier ' + v) }
if (TIER_NAMES.length !== MAX_TIER) bad('TIER_NAMES.length != MAX_TIER')

const TAGS = ['AB', 'STARK', 'WWWWWW', 'IIIIII', 'MMMMMM', 'A1B2C3', 'XY', '00', 'WAKU', 'ROR']
const RATIOS = [0.34, 0.5, 0.75, 1, 1.5, 2, 3]

for (let t = 1; t <= MAX_TIER; t++) for (const tag of TAGS) for (const r of RATIOS) {
  const L = layoutBadge(t, tag, r, true)
  const where = `tier ${t} tag ${tag} rasio ${r}`
  if (!(L.W > 20 && L.W < 400)) bad(`${where}: lebar W aneh ${L.W}`)
  if (L.t >= 3) {
    const m = L.stroke / 2 + 1
    if (!boxInside(L.body, L.embX, 14 - L.embH / 2, L.bw, L.embH, m)) bad(`${where}: EMBLEM keluar badan`)
  } else if (!boxInside(L.body, L.embX, 14 - L.embH / 2, L.bw, L.embH, 0.5)) bad(`${where}: emblem keluar badan`)
  const tx0 = L.tx - L.tw / 2, tx1 = L.tx + L.tw / 2
  if (!boxInside(L.body, tx0, 14 - 4.8, tx1 - tx0, 9.6, 0.8)) bad(`${where}: TEKS keluar badan (tx ${tx0.toFixed(1)}..${tx1.toFixed(1)}, W ${L.W})`)
  if (L.embX + L.bw > tx0 - 1) bad(`${where}: emblem menabrak teks (emblem sampai ${(L.embX + L.bw).toFixed(1)}, teks mulai ${tx0.toFixed(1)})`)
}
for (let t = 1; t <= MAX_TIER; t++) for (const tag of TAGS) {
  const L = layoutBadge(t, tag, 1, false)
  const tx0 = L.tx - L.tw / 2, tx1 = L.tx + L.tw / 2
  if (!boxInside(L.body, tx0, 14 - 4.8, tx1 - tx0, 9.6, 0.8)) bad(`tier ${t} tag ${tag} tanpa emblem: TEKS keluar badan`)
}
for (const tag of [undefined, null, '', 12345, 'ABCDEFGHIJKLMNOP']) for (const r of [NaN, 0, -1, undefined, Infinity]) for (const t of [undefined, 0, 21, 'x']) {
  try { const L = layoutBadge(t, tag, r, true); if (!Number.isFinite(L.W) || !Number.isFinite(L.H)) bad('NaN pada input aneh') } catch (e) { bad('error pada input aneh: ' + e.message) }
}
const sig = (t) => { const L = layoutBadge(t, 'STARK', 1, false); const W = L.W; return JSON.stringify(L.body.map(([x, y]) => [Math.round((x / W) * 20), Math.round(y)])) }
const old = new Set(Array.from({ length: 15 }, (_, i) => sig(i + 1)))
const seen = new Set()
for (let t = 16; t <= 20; t++) { const s = sig(t); if (old.has(s)) bad(`tier ${t} bentuknya sama dengan tier lama`); if (seen.has(s)) bad(`tier ${t} kembar dengan tier baru lain`); seen.add(s) }
const octSig = sig(4)
for (let t = 16; t <= 20; t++) if (sig(t) === octSig) bad(`tier ${t} = oktagon`)
for (let t = 16; t <= 20; t++) if (!(EX[t] > 0 && TOP[t] >= 0)) bad(`EX/TOP tier ${t} belum diisi`)
if (!(textWidth('W') > textWidth('I'))) bad('textWidth W <= I')

console.log(fail ? `\n${fail} pelanggaran` : `OK: ${MAX_TIER} tier x ${TAGS.length} tag x ${RATIOS.length} rasio, semua aturan lolos`)
process.exit(fail ? 1 : 0)
