# Build lewat GitHub Actions (cadangan jika Termux gagal)
Build jalan di server GitHub (gratis untuk repo privat dalam kuota), hasil APK + log diunduh dari HP. Termux hanya dipakai untuk mengirim kode.
1. Buat repo PRIVAT di github.com (browser HP), misal `wakuplay-flutter`.
2. Termux: `cd ~/WakuPlay-Flutter && git init && git add . && git commit -m "WakuPlay Flutter" && git branch -M main && git remote add origin https://github.com/USERNAME/wakuplay-flutter.git && git push -u origin main`
   (username = akun GitHub, password = Personal Access Token dengan izin `repo`).
3. GitHub > tab Actions > "Build APK WakuPlay" > Run workflow. Tunggu ±10-15 menit.
4. Buka run yang selesai > Artifacts > unduh `WakuPlay-APK-dan-log`. Isinya app-debug.apk (+ app-release.apk bila secret ada) dan log.
Rilis bertanda tangan kunci lama: Settings > Secrets and variables > Actions, isi `WP_KEYSTORE_B64` (base64 wakuplay.jks), `WP_KEYSTORE_PASSWORD`, `WP_KEY_ALIAS`, `WP_KEY_PASSWORD`.
CATATAN: APK debug memakai kunci debug acak sehingga Google Login TIDAK cocok dengan OAuth client lama. Untuk tes login Google gunakan build rilis dengan kunci lama.
