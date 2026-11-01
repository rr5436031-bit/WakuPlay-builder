# Panel WakuPlay (APK terpisah, khusus developer)

Nama aplikasi: **Panel WakuPlay**. Isinya sama dengan Panel Developer di WakuPlay (Tabel, Banner, Blokir, Gold, Clan, Top LB, Premium, Gift Premium, XP Giveaway, Level, Wallpaper, Border, Emblem, Pet, Anime Baru, Upload Anime, Update).
Pakai Supabase & akun yang sama dengan WakuPlay, jadi data yang diubah langsung berlaku di WakuPlay.
Kamu **tidak perlu logout** dari WakuPlay lagi: buka WakuPlay dengan akun biasa, buka Panel WakuPlay dengan akun developer, keduanya terpasang bersamaan.

## Nama paket
`com.wakuplay.panel` (WakuPlay = `com.wakuplay.app`). Harus beda: kalau sama persis, memasang Panel akan MENIMPA WakuPlay dan keduanya tidak bisa terpasang bersamaan.

## Langkah (urut)
1. **Google Cloud Console** (project yang sama dengan Web client ID WakuPlay) > APIs & Services > Credentials > Create credentials > OAuth client ID > **Android**:
   - Package name: `com.wakuplay.panel`
   - SHA-1: tampil di ringkasan akhir `setup.sh` (sama dengan SHA-1 WakuPlay kalau memakai keystore yang sama).
   Tanpa langkah ini tombol "Masuk dengan Google" gagal. Cukup sekali.
2. (Disarankan) Jalankan `supabase/panel-wakuplay.sql` di Supabase SQL Editor. Hanya menambah catatan login panel di `dev_audit`. Panel tetap jalan walau ini belum dijalankan.
3. Build di Termux dari folder home (bukan /storage/emulated/0): `bash setup.sh`. Hasil: `PanelWakuPlay.apk`. Update berikutnya: `bash update.sh`.

## Aturan akses (ketat, tapi tidak membuat aplikasi error)
Dicek di SERVER oleh fungsi `has_dev_panel()`: role di database = `developer` DAN akun terdaftar di tabel `dev_panel_access`. Aplikasi hanya menampilkan hasilnya.
- Akun yang tidak punya akses: dikeluarkan otomatis dan kembali ke layar login dengan pesan.
- Semua fungsi `dev_*`, `*_dev_*`, dan Edge Function `border-gif` menolak non-developer di server, jadi walau APK dibongkar orang lain tidak bisa mengubah data.
- Akses dicek ulang tiap 60 detik dan saat aplikasi dibuka kembali. Kalau akses dicabut, akun langsung dikeluarkan.
- Hanya jawaban "TIDAK" dari server yang mengeluarkan akun. Kalau internet putus atau server error, muncul tombol "Coba lagi" dan kamu tetap login (tidak ada logout palsu).
- Tombol Kembali di HP menutup aplikasi. Tombol "Keluar" di kanan atas panel untuk logout.

## Pembaruan v1.0.1
* Isi Panel disamakan dengan WakuPlay v1.5.9: Impor Border (GIF diunggah ke `Border/<rarity>/`, harga otomatis sesuai rarity), **Sinkronkan dari GitHub**, **Harga rarity**, nama file rapi untuk Clan, Gacha, dan Pet.
* Perbaikan error `column reference "found" is ambiguous` di Panel > Border: jalankan **`supabase/border-fix-found.sql`** sekali di Supabase SQL Editor (aman diulang). Prasyarat: `avatar-border-github.sql` dari proyek WakuPlay sudah dijalankan.
* Edge Function `border-gif` memakai versi dari proyek WakuPlay v177 (`supabase functions deploy border-gif --project-ref <ref>`, tanpa `--no-verify-jwt`).
* Update APK: `bash update.sh`.
