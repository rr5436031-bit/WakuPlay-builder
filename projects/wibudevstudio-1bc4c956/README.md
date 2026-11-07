# WibuDev Studio (Tahap 2)

IDE Android berbasis Termux. Termux dipakai sebagai backend eksekusi lewat RUN_COMMAND.

## Yang sudah berfungsi
- Deteksi Termux, tombol buka Termux, dan permintaan izin RUN_COMMAND saat runtime.
- Terminal: kirim perintah Bash, hasil stdout/stderr dan exit code diterima lewat PendingIntent.
- Status perintah jujur: "Menunggu hasil" sampai Termux mengirim hasil.
- Riwayat perintah di sesi aplikasi. Ketuk perintah lama untuk mengisi ulang kolom input.
- Drawer hamburger dengan 12 menu. Dashboard dan Terminal aktif; menu lain masih placeholder.

## Instalasi Termux
1. Pasang Termux dari F-Droid (versi Play Store sudah tidak diperbarui).
2. Di Termux jalankan: `echo "allow-external-apps = true" >> ~/.termux/termux.properties` lalu `termux-reload-settings`.
3. Pasang paket: `pkg install nodejs git python openjdk-17`.
4. Buka WibuDev Studio, lalu tekan "Beri Izin" di Dashboard.

## Build via GitHub Actions
Push repo ini ke GitHub. Workflow `.github/workflows/build.yml` menghasilkan artifact `app-debug` berisi `app-debug.apk`. Build debug tidak memerlukan secrets.

## Keterbatasan
- Riwayat hanya di memori. Hilang jika aplikasi ditutup paksa, belum disimpan ke Room/DataStore.
- Tombol Stop belum ada. RUN_COMMAND tidak menyediakan cara menghentikan proses secara langsung, jadi ini butuh mekanisme PID tersendiri.
- Nama extra RUN_COMMAND mengikuti dokumentasi Termux. Jika hasil tidak pernah muncul, periksa versi Termux dan allow-external-apps.
- Belum diuji kompilasi dari sini. Kirim log Gradle jika ada error.
