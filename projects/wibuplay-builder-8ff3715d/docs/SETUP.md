# Konfigurasi WibuPlay

Urutan yang disarankan: **A. keystore -> B. Google Cloud -> C. Supabase (SQL, Google, Edge Function, secret) -> D. build**.

## A. Keystore tetap + SHA-1 (di Termux, tanpa build APK)
SHA-1 yang dibutuhkan Google adalah milik **keystore penanda tangan**, jadi cukup membuat keystore, bukan membangun seluruh APK di HP.
1. Salin `tools/buat-keystore.sh` ke HP, lalu di Termux: `bash buat-keystore.sh` (izinkan akses storage).
2. Hasil: SHA-1 & SHA-256 tampil, dan file ada di `Download/wibuplay-keystore/` (`wibuplay.jks`, `keystore-base64.txt`, `github-secrets.txt`).
3. GitHub repo -> Settings -> Secrets and variables -> Actions, isi: `KEYSTORE_BASE64` (isi `keystore-base64.txt`), `KEYSTORE_PASSWORD`, `KEY_ALIAS` (= `wibuplay`), `KEY_PASSWORD`.
4. Workflow memakai keystore ini untuk APK debug DAN release, sehingga SHA-1 selalu sama. Ringkasan run menampilkan SHA-1 APK sebagai pembanding.
5. Simpan cadangan `wibuplay.jks`; kalau hilang, SHA-1 berubah. Hapus `github-secrets.txt` setelah dipakai.
Cek SHA-1 APK yang sudah jadi: `bash tools/cek-sha.sh` (APK di folder Download).

## B. Google Cloud (Credentials)
1. OAuth consent screen: isi nama app; bila masih *Testing*, tambahkan email Google yang akan login sebagai Test user.
2. Buat **OAuth client ID tipe Web application** -> catat Client ID & Secret. (Tidak perlu redirect URI khusus untuk login native.)
3. Buat **OAuth client ID tipe Android**: package `com.wibuplay.app`, SHA-1 dari langkah A. (ID Android ini tidak dimasukkan ke aplikasi; hanya perlu ada.)

## C. Supabase
1. **SQL Editor**: jalankan seluruh `supabase/schema.sql`.
2. **Authentication -> Providers -> Google**: aktifkan, isi *Client ID* (Web) dan *Client Secret*. Kolom Client IDs boleh berisi Web ID (tambahkan ID Android dipisah koma bila diminta). Jangan aktifkan "Skip nonce check".
3. **Edge Functions** (Dashboard -> Edge Functions -> Deploy a new function / via editor):
   - `anime` <- isi `supabase/functions/anime/index.ts`
   - `app-config` <- isi `supabase/functions/app-config/index.ts`
   - Matikan **Verify JWT** pada keduanya (token pengguna diperiksa di dalam function `anime`; `app-config` dipanggil sebelum login).
4. **Edge Functions -> Secrets** (atau `supabase secrets set NAMA=nilai`):
   | Secret | Isi |
   |---|---|
   | `GOOGLE_WEB_CLIENT_ID` | Client ID tipe Web dari langkah B.2 |
   | `ANIME_API_BASE` | alamat dasar API anime, tanpa garis miring di akhir |
   | `ANIME_API_KEY` | (opsional) bila API butuh kunci; dikirim sebagai header `x-api-key` |
   Nilai secret tidak ada di APK. Aplikasi hanya memanggil `.../functions/v1/anime?path=/anime/...` dengan token login dan `.../functions/v1/app-config`.
5. Uji cepat: buka `https://fdbwrqmtewoymugfssjk.supabase.co/functions/v1/app-config` -> harus mengembalikan `{"google_web_client_id": "..."}`.

## D. Build
GitHub -> Actions -> **Build APK** -> Run workflow -> unduh artifact `WibuPlay-debug-apk`.

## E. Chat Global
Tiga channel (Channel 1-3). Pesan diambil berkala tiap 3 detik selama layar chat terbuka (bukan realtime websocket). Server membatasi 255 karakter dan 1 pesan per 2 detik. Aturan "dilarang jual premium" hanya peringatan teks; moderasi belum otomatis.

## F. Premium + WebView
Tombol *Beli Premium* membuka `https://wibuplay.vercel.app/premium#wp_token=<token>`. Token dari RPC `create_web_handoff()` (sekali pakai, 2 menit, hanya hash disimpan). Backend website (Service Role Key di server) menukar lewat `POST /rest/v1/rpc/consume_web_handoff {"p_token": "..."}` -> `user_id`. Jika fungsi belum ada, halaman dibuka tanpa token dengan peringatan (tidak ada verifikasi palsu).

## G. Uji manual
Login (popup pilih akun) -> tab Profil terisi -> Diagnostik API (Pengaturan) -> putar episode ≥5 menit, XP +20 sekali -> logout/login lagi, riwayat & favorit tetap -> buka Chat Global di 2 akun.
