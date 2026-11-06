# WibuPlay Panel (Developer & Admin)

APK panel terpisah untuk Developer dan Admin WibuPlay. Memakai database Supabase yang sama dengan WibuPlay,
jadi akun dan ID # yang dipakai sama. Wrapper APK memakai Java (tanpa Kotlin/Flutter), tampilan memakai HTML, CSS, dan JavaScript.

## Langkah pemasangan

1. **Jalankan SQL** di Supabase SQL Editor, berurutan: `sql/28_admin_panel.sql`, `sql/29_admin_id_clan_xp.sql`, lalu `sql/40_admin_premium.sql` (Panel Premium; butuh SQL WibuPlay sampai 38).
2. **Tambah redirect URL** di Supabase: Authentication → URL Configuration → Redirect URLs →
   tambahkan `wibuadmin://auth-callback`.
3. **Beri role Developer** ke akunmu (contoh ID #1):
   `select public.set_role(1, 'developer');`
4. **Build APK**: buka proyek ini di Android Studio atau jalankan `gradle assembleDebug`
   (atau pakai Universal APK Builder / GitHub Actions seperti biasa).
5. Buka APK → **Masuk dengan Google** → hanya akun role `developer`/`admin` yang bisa masuk.

## Menu
- **Dashboard**: ringkasan pengguna, premium, clan, WBM, blokir, dan pemakaian database.
- **Panel ID**: cari pengguna berdasarkan ID #, nama, atau email.
- **Panel Clan**: set WBM Clan langsung (tanpa setor), set tier 1-30, ganti nama clan.
- **Panel Role**: beri atau cabut role. Lihat daftar role yang boleh kamu berikan.
- **Panel WBM**: tambah atau kurangi WBM pengguna (saldo tidak bisa minus).
- **Panel Premium**: lihat premium aktif, tambah atau kurangi hari (1-3650 per aksi), atau cabut premium. Wajib alasan, tercatat di log.
- **Panel XP/LVL**: atur XP, level dihitung otomatis sesuai kurva server.
- **Panel Blokir**: blokir 1 jam, 1 hari, 7 hari, 30 hari, atau permanen. Buka blokir.
- **Info Server**: pemakaian database, storage file, dan tabel terbesar.
- **Log Admin**: 100 aksi terakhir. Log tidak bisa dihapus dari panel.

## Aturan keamanan (ditegakkan di database)
- Hanya role `can_manage` dengan prioritas ≥ 90 (Developer, Admin) yang bisa memakai fungsi panel.
- Tidak bisa mengubah atau memblokir diri sendiri.
- Hanya bisa menyentuh target dengan prioritas lebih rendah dari dirimu.
- Admin tidak bisa memberi role Developer/Admin. Developer tidak bisa memberi role Developer.
- Batas per aksi: Admin 10.000.000 WBM, Developer 1.000.000.000.000 WBM. XP maks 2.000.000.000.
- Setiap aksi wajib alasan minimal 3 karakter dan tercatat di `admin_log`.
- Blokir berlaku di database: chat, komentar, dan join clan ditolak untuk akun yang diblokir.

## Catatan
- Blokir tidak otomatis mengeluarkan akun dari WibuPlay. Agar aplikasi WibuPlay juga menampilkan status blokir,
  panggil `rpc('my_block_status')` saat aplikasi dibuka dan tampilkan pesan bila `blocked` bernilai `true`.
- Batas kuota di `app/src/main/assets/app.js` (`LIMITS`) harus disesuaikan dengan paket Supabase kamu.
- Fungsi clan lain di WibuPlay tetap dipakai apa adanya. Panel hanya menambah fungsi admin.
