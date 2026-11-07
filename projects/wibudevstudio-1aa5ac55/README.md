# WibuDev Studio (Tahap 3)

IDE Android berbasis Termux. Termux dipakai sebagai backend eksekusi lewat RUN_COMMAND.

## Yang sudah berfungsi
- Deteksi Termux, buka Termux, dan izin RUN_COMMAND saat runtime.
- Terminal: kirim perintah Bash, hasil stdout/stderr dan exit code diterima lewat PendingIntent.
- Riwayat perintah tersimpan di perangkat (maks. 200 entri) dan tetap ada setelah aplikasi ditutup.
- Hentikan: mengirim SIGTERM ke shell perintah lewat PID yang disimpan.
- Terminal Appearance: preset prompt (Linux Classic, Kali, Ubuntu, Minimal, Custom), username dan hostname tampilan.
- Drawer hamburger dengan 12 menu. Dashboard, Terminal, dan Terminal Appearance aktif; menu lain masih placeholder.

## Instalasi Termux
1. Pasang Termux dari F-Droid.
2. Jalankan di Termux: `echo "allow-external-apps = true" >> ~/.termux/termux.properties` lalu `termux-reload-settings`.
3. Pasang paket: `pkg install nodejs git python openjdk-17`.
4. Buka WibuDev Studio, lalu tekan "Beri Izin" di Dashboard.

## Build via GitHub Actions
Push repo ke GitHub. Workflow `.github/workflows/build.yml` menghasilkan artifact `app-debug` berisi `app-debug.apk`.

## Keterbatasan
- Hentikan hanya mengirim SIGTERM ke shell. Proses anak yang sudah berjalan bisa tetap hidup.
- Perintah yang hasilnya tidak pernah datang (misalnya Termux ditutup paksa) tetap "Menunggu hasil". Hapus riwayat dengan Clear.
- Prompt hanya tampilan. Username dan hostname di Termux tidak berubah.
- Belum diuji kompilasi dari sini. Kirim log Gradle jika ada error.
- Menu yang belum ada: File Manager, Code Editor, Project Manager, Localhost Manager, Package Manager, APK Builder, Build History, Settings, About.
