# Lompat ke pesan yang di-reply (v1.6.0)

Berlaku di semua chat yang memakai `Room` di `src/pages/Chat.jsx`: **Chat Global, Chat Clan, Lapor/Req**.
(Chat pribadi/DM tidak punya fitur reply, jadi tidak ikut.)

## Cara kerja
1. Di dalam bubble yang membalas ada kutipan (kotak kecil berisi nama + isi pesan asli).
2. Ketuk kutipan itu → daftar chat bergulir **halus** ke pesan asli, pesan itu ditaruh di tengah layar, lalu **berkedip biru** sebentar.
3. Ketuk bagian lain bubble tetap = balas, tekan lama = menu, geser kanan = balas (tidak berubah).
4. Kalau pesan asli tidak ada di daftar (sudah dihapus, atau lebih lama dari 60 pesan terakhir yang dimuat) → muncul toast
   "Pesan asli sudah dihapus atau terlalu lama". Tidak ada error, tidak ada lompatan aneh.

Kode: `src/lib/jumpto.js` (hook `useJumpTo`), `Chat.jsx` (`data-mid`, `onJump`), `src/lib/stickbottom.js` (`stick.release`), CSS di akhir `src/index.css`.

## Aturan (jalankan `npm run check` sebelum build; semuanya otomatis diperiksa)
| # | Aturan | Alasan (bug yang dicegah) |
|---|--------|---------------------------|
| R1 | Baris pesan wajib `data-mid={m.id}` | Pencarian target lewat DOM; tanpa ini lompat selalu "tidak ditemukan" |
| R2 | `Room` memakai `useJumpTo(list, stick, onMissing)` | Satu implementasi untuk semua chat |
| R3 | `Bubble` menerima `onJump={jump}`; `jump` harus callback **stabil** | `Bubble` adalah `memo`; callback baru tiap render = 150 bubble render ulang → lag |
| R4 | Ketuk kutipan diperiksa di `onClick` bubble lewat `closest('.gc-quote')` | Ikut penjaga `held`/`swiped`; tanpa itu tekan-lama / geser bisa ikut memicu lompat |
| R5 | `jumpto.js` tanpa state React | Lompat tidak boleh memicu render ulang |
| R6 | `jumpto.js` dibungkus `try/catch` | Fitur sekunder tidak boleh membuat layar chat crash |
| R7 | Sebelum scroll, panggil `stick.release()` | Tanpa ini `useStickBottom` menarik balik ke dasar saat ada pesan baru |
| R8 | Sorotan = atribut `data-flash` | React tidak mengelola atribut ini → tidak terhapus saat bubble render ulang |
| R9 | Sorotan hanya animasi `opacity` | Murah di HP lemah; jangan pakai shadow/filter/backdrop |

### Perilaku yang sengaja dijaga
- **Tidak ada polling / timer terus-menerus.** Timer hanya hidup selama lompat berlangsung dan dibersihkan saat keluar halaman.
- **Lompat baru membatalkan lompat lama** (ketuk dua kutipan cepat-cepat → mendarat di yang terakhir, hanya satu sorotan).
- **Jarak sangat jauh**: loncat instan sampai 3 layar dari target, lalu geser halus (tidak menggulir ribuan piksel).
- **Mode hemat/animasi dikurangi** (`lowfx` atau `prefers-reduced-motion`): pindah langsung tanpa animasi gulir, sorotan tetap tampil.
- **Pesan baru masuk setelah lompat**: tampilan tetap di tempat (tidak ditarik ke bawah). Kembali ke dasar → otomatis lengket lagi.
- Pesan yang masih `pending` (belum terkirim) bisa jadi target; setelah terkirim `data-mid` ikut diganti ke id asli.

### Supaya aturan tidak menimbulkan bug
- `npm run check` **hanya memeriksa**, tidak dipanggil otomatis oleh `build`/`update.sh` — jadi salah deteksi tidak akan memblokir pembuatan APK.
- Setiap aturan mengikat ke satu hal konkret yang mudah dicari (`data-mid`, `useJumpTo`, …); tidak ada aturan berbasis perkiraan.
- Mengubah perilaku fitur? Ubah **aturan dan kode bersamaan** dalam satu perubahan, lalu jalankan `npm run check`.

## Batas yang diketahui
- Hanya pesan yang sedang dimuat (60 terakhir, maksimal 150 di layar) yang bisa dituju. Memuat pesan lebih lama butuh pagination di `services/db.js`; belum ada.
