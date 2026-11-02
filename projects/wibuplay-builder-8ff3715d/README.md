# WibuPlay

Aplikasi Android **native Kotlin** (Jetpack Compose) untuk menonton anime, dengan akun Google + database online **Supabase**.
Dibuild di server GitHub Actions - tidak perlu Termux / Android Studio.

## Cara mendapatkan APK
1. Upload isi folder ini ke repo GitHub (branch `main`).
2. Tab **Actions** -> workflow **Build APK** -> **Run workflow**.
3. Selesai (±5-10 menit) -> buka run-nya -> **Artifacts** -> unduh `WibuPlay-debug-apk`.

Sebelum login dan data anime berfungsi, ikuti `docs/SETUP.md` (keystore tetap, Google Cloud, SQL, Edge Function + secret).

## Status jujur (belum diuji)
Kode ini ditulis tanpa bisa dikompilasi atau dijalankan di lingkungan pembuatnya (tanpa akses ke Android SDK, repo Gradle, maupun API Sanka).
Artinya **belum ada satu fitur pun yang teruji**. Perkirakan perlu 1-3 putaran perbaikan setelah build pertama:
- Jika build GitHub Actions gagal: kirim log error-nya, biasanya perbaikannya kecil.
- Format respons tiap sumber API (Winbu/Animekompi/Donghub/Alqanime/Nimegami) dibaca secara toleran, bukan dari contoh respons asli.
  Buka **Pengaturan -> Diagnostik API** di aplikasi dan kirim hasilnya agar adapter bisa dipertajam.
- Login Google, RLS, XP, dan sinkronisasi baru bisa diuji setelah `docs/SETUP.md` dijalankan.

## Fitur
Splash, onboarding + login Google native, Chat Global (Channel 1-3), Home (profil/level, hero, terakhir ditonton, update terbaru, genre, populer, tamat), pencarian + hasil (paginasi),
detail + daftar episode, player (ExoPlayer untuk tautan langsung, WebView hanya untuk embed), riwayat, favorit, profil, level & XP, premium (WebView + token serah-terima),
pengaturan, jadwal, genre, daftar (terbaru/populer/ongoing/tamat/movie/donghua/live action/A-Z), diagnostik API.

## Keputusan desain
- UI memakai identitas WibuPlay sendiri (nama, logo, warna). Struktur alur mengikuti referensi, tetapi bukan salinan piksel aplikasi lain.
- Login Google native: popup pilih akun (Credential Manager) -> ID token ditukar ke Supabase Auth. Butuh OAuth client Android (SHA-1 dari `tools/buat-keystore.sh`) dan Web client ID.
- Web Client ID dan alamat API anime disimpan sebagai secret Edge Function (`app-config`, `anime`); APK tidak memuat alamat API anime.
- Chat Global: 3 channel, polling 3 detik, validasi & batas kecepatan di server.
- Tidak memakai Room: cache offline (riwayat, favorit, antrean progres) disimpan di DataStore. Antrean progres dikirim ulang saat online.
- XP, level, statistik dan riwayat hanya bisa ditulis lewat fungsi server `save_progress` (klien tidak bisa menulis langsung).
- Favorit offline: hanya baca dari cache; tambah/hapus butuh internet.
- XP dari embed WebView tetap dihitung dari waktu aplikasi terbuka di player (tidak bisa tahu apakah video benar-benar diputar), dibatasi server sebatas waktu nyata.
