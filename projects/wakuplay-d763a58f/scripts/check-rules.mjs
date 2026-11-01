// Pemeriksa aturan WakuPlay (tanpa dependensi). Jalankan: npm run check
// Tujuan: menangkap kesalahan umum SEBELUM build, tanpa pernah memblokir build (tidak dipanggil otomatis).
// Aturan lengkap + alasannya: PANDUAN-LOMPAT-REPLY.md dan PANDUAN-PERFORMA.md
import fs from 'node:fs'

const read = (f) => fs.readFileSync(f, 'utf8')
const fails = []
const rule = (ok, msg) => { if (!ok) fails.push(msg) }

const chat = read('src/pages/Chat.jsx')
const jump = read('src/lib/jumpto.js')
const stick = read('src/lib/stickbottom.js')
const css = read('src/index.css')
const app = read('src/App.jsx')
const pkg = JSON.parse(read('package.json'))

// --- Lompat ke reply ---
rule(/data-mid=\{m\.id\}/.test(chat), 'R1: baris pesan di Chat.jsx wajib punya data-mid={m.id}')
rule(/useJumpTo\(list,\s*stick/.test(chat), 'R2: Room wajib memakai useJumpTo(list, stick, ...)')
rule(/onJump=\{jump\}/.test(chat), 'R3: Bubble wajib menerima onJump={jump} (callback stabil dari useJumpTo)')
rule(/closest\('\.gc-quote'\)/.test(chat), 'R4: ketuk kutipan harus dicek lewat closest(.gc-quote) di onClick bubble (agar lolos penjaga held/swiped)')
rule(!/useState|useReducer/.test(jump), 'R5: jumpto.js tidak boleh memakai state React (tidak boleh memicu render ulang)')
rule(/try\s*\{/.test(jump) && /catch/.test(jump), 'R6: jumpto.js wajib dibungkus try/catch (tidak boleh melempar error)')
rule(/stick\.release/.test(jump) && /stick\.release\s*=/.test(stick), 'R7: lompat wajib memanggil stick.release() dan stickbottom wajib menyediakannya')
rule(/data-flash/.test(jump) && /\[data-flash\]/.test(css), 'R8: sorotan memakai atribut data-flash + aturan CSS-nya')
rule(!/(^|\n)\s*[^\n]*\.gc-row\[data-flash\][^\n]*(box-shadow|filter|backdrop)/.test(css), 'R9: sorotan hanya boleh animasi opacity (tanpa shadow/filter/backdrop)')

// --- Performa ---
const gcNew = css.split('\n').filter((l) => /^\.gc-new/.test(l))
rule(gcNew.every((l) => !/will-change/.test(l)), 'P1: .gc-new tidak boleh will-change (membuat layer permanen per pesan)')
rule(!/\.tabpage\s*\{[^}]*contain\s*:[^}]*layout/.test(css), 'P2: .tabpage tidak boleh contain:layout (merusak position:fixed di dalam halaman tab)')
rule(/\.tabpage\.off/.test(css) && /tabpage \$\{id === tab/.test(app) && !/display:\s*id === tab/.test(app), 'P3: tab disembunyikan lewat kelas .off (content-visibility), bukan style display inline')
rule(!/subtree:\s*true/.test(stick), 'P4: MutationObserver stickbottom hanya childList (tanpa subtree)')
rule(!/toLocaleTimeString/.test(chat), 'P5: jangan format jam per bubble dengan toLocaleTimeString (lambat di Android)')

// --- Dialog ---
const walk = (d) => fs.readdirSync(d, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? walk(`${d}/${e.name}`) : [`${d}/${e.name}`]))
const srcFiles = walk('src').filter((f) => /\.jsx?$/.test(f) && !f.endsWith('lib/dialog.js'))
const native = srcFiles.filter((f) => /window\.(confirm|alert|prompt)\(|(^|[^.\w])(confirm|alert|prompt)\(/.test(read(f).replace(/\/\/[^\n]*/g, '')))
rule(!native.length, 'D1: dilarang window.confirm/alert/prompt (kotak abu-abu bawaan Android). Pakai askConfirm() dari lib/dialog.js. Ditemukan di: ' + native.join(', '))
rule(/<DialogHost\s*\/>/.test(app) && /dismissDialog\(\)/.test(app), 'D2: App.jsx wajib memasang <DialogHost /> dan menutup dialog dengan tombol Back (dismissDialog)')

// --- Versi ---
rule(/^\d+\.\d+\.\d+$/.test(pkg.version), 'V1: version di package.json harus x.y.z (dipakai untuk versionName/versionCode APK)')

if (fails.length) { console.error('GAGAL:\n- ' + fails.join('\n- ')); process.exit(1) }
console.log(`OK: semua aturan terpenuhi (versi ${pkg.version})`)
