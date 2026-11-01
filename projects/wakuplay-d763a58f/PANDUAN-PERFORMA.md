# Performa (efek & animasi tetap, cara menggambarnya lebih murah)

- **Cahaya badge clan**: tidak lagi pakai CSS `filter: drop-shadow` (digambar ulang tiap frame kilau, berat kalau banyak badge). Sekarang gradien radial statis di dalam SVG
  (`.cb-halo` di `ClanBadge.jsx`), lebih lembut. Atur kekuatan di variabel `haloA` (rare .16, legend .22, mythic .30, tier 4-10 .16, 11-14 .20, 15+ .24).
- **ClanBadge** dibungkus `React.memo`: tidak digambar ulang kalau datanya sama.
- **Animasi dijeda otomatis** saat aplikasi di latar belakang / layar mati (kelas `app-bg`, `lib/perf.js`).
- **Pesan chat** di luar layar tidak digambar (`content-visibility`), kilau badge hanya jalan di pesan terakhir.
- **Kode dipecah**: halaman Jadwal, Riwayat, Favorit, Akun, Cari, Detail, Player ikut dimuat malas (lazy) dan disiapkan saat aplikasi tenang; pustaka besar (react, supabase, capacitor) dipisah jadi chunk sendiri
  (`vite.config.js`). Awal buka aplikasi lebih cepat karena JavaScript yang harus diproses di awal lebih sedikit.

## v1.6.0 - lebih ringan & lancar (scroll, pindah halaman, tampilan penuh)
- **Pindah tab (Home/Jadwal)**: tab yang tidak aktif tidak lagi `display:none`. Dipakai `content-visibility:hidden` + `position:absolute` (kelas `.tabpage.off`),
  jadi hasil layout halaman besar disimpan dan posisi scroll tidak hilang; pindah balik tidak menghitung ulang seluruh halaman. Animasi geser dipersingkat .26s → .2s.
  Browser lama tanpa `content-visibility` otomatis kembali ke `display:none`.
- **Home**: daftar anime, hero, dan "New Eps" dihitung sekali (`useMemo`) bukan setiap render; `AnimeCard`/`Grid`/`Row` dibungkus `memo` dengan callback stabil,
  jadi perubahan XP/gold/notifikasi tidak menggambar ulang ratusan kartu.
- **Chat**: `will-change` permanen di `.gc-new` dihapus (dulu tiap pesan baru menahan satu layer GPU selamanya); jam pesan dihitung tanpa `toLocaleTimeString` (lambat di Android);
  `MutationObserver` di `stickbottom` hanya mengamati anak langsung (bukan seluruh isi bubble).
- **Tampilan penuh (immersive)** tidak diubah; semua perubahan di atas bekerja sama baiknya dengan atau tanpa tampilan penuh.
- Pemeriksa aturan: `npm run check` (lihat `scripts/check-rules.mjs`). Aturan P1-P5 menjaga agar optimasi di atas tidak dibatalkan tanpa sengaja:
  P1 tanpa `will-change` di `.gc-new`, P2 tanpa `contain:layout` di `.tabpage` (merusak `position:fixed`), P3 tab disembunyikan lewat kelas, P4 observer tanpa subtree, P5 tanpa `toLocaleTimeString` per bubble.

