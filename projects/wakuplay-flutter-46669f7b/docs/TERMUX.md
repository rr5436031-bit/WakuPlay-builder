# Build di Termux (tanpa laptop)
1. `bash scripts/setup-termux.sh` (sekali, unduhan besar; WiFi + baterai cukup).
2. `bash scripts/build-debug.sh`  -> `/sdcard/Download/WakuPlay-debug.apk`
3. Rilis: salin `~/.wakuplay` (kunci lama) lalu `bash scripts/build-release.sh` -> `/sdcard/Download/WakuPlay.apk`
Log SELALU disalin ke `/sdcard/Download/wakuplay-build.log` (juga saat gagal / Termux tertutup). Kirim file itu bila ada masalah.

## Jika Termux tertutup sendiri / force close saat build
- Android 12+: Opsi Pengembang -> aktifkan "Nonaktifkan batasan proses turunan" (Disable child process restrictions). Tanpa ini Android mematikan proses Gradle/Java.
- Jalankan `termux-wake-lock`, jangan buka aplikasi berat lain, tutup aplikasi latar belakang. RAM disarankan >= 4 GB bebas.
- Skrip sudah membatasi memori Gradle (1,5 GB), mematikan daemon, hanya membangun arm64, dan memakai aapt2 ARM64 dari Debian.
## Catatan
- Build rilis di Linux ARM64 memerlukan gen_snapshot untuk ARM64; jika Flutter Anda belum menyediakan, build debug tetap bisa dipakai.
