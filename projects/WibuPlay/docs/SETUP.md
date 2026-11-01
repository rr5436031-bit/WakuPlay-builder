# Konfigurasi

## 1. Database Supabase
1. Dashboard Supabase -> **SQL Editor** -> tempel seluruh `supabase/schema.sql` -> **Run**.
2. Cek **Table Editor**: `profiles`, `watch_history`, `favorites`, `user_stats`, `xp_events`, `app_settings`, `premium_packages` harus berstatus *RLS enabled*.
3. Jangan pernah memasukkan Service Role Key ke aplikasi. Kunci di APK hanyalah Publishable Key.

## 2. Google OAuth (tanpa SHA-1)
1. Google Cloud Console -> **APIs & Services -> Credentials -> Create OAuth client ID -> Web application**.
   - Authorized redirect URI: `https://fdbwrqmtewoymugfssjk.supabase.co/auth/v1/callback`
2. Salin Client ID & Secret ke Supabase -> **Authentication -> Providers -> Google** -> aktifkan.
3. Supabase -> **Authentication -> URL Configuration -> Redirect URLs**: tambahkan `wibuplay://auth-callback`.
4. Alur di aplikasi: tombol login membuka browser (Custom Tab) -> Google -> Supabase -> kembali ke `wibuplay://auth-callback?code=...` (deep link di AndroidManifest) -> aplikasi menukar kode (PKCE) menjadi sesi.

SHA-1/SHA-256 **tidak diperlukan** untuk alur ini. Jika nanti memakai Google Sign-In native (Credential Manager), buat OAuth client tipe *Android* dengan package `com.wibuplay.app` dan SHA-1 dari `bash tools/cek-sha.sh` (jalankan di Termux; APK ada di folder Download). Catatan: keystore debug GitHub Actions berubah di tiap build kecuali keystore tetap dipakai.

## 3. APK release bertanda tangan (opsional)
Buat keystore, lalu tambahkan GitHub Secrets: `KEYSTORE_BASE64` (hasil `base64 -w0 release.jks`), `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`. Workflow otomatis membuat artifact `WibuPlay-release-apk`.

## 4. Premium + WebView
- Tombol *Beli Premium* membuka `https://wibuplay.vercel.app/premium#wp_token=<token>`.
- Token dibuat oleh RPC `create_web_handoff()` (sekali pakai, 2 menit, hanya hash yang disimpan).
- Backend website (pakai Service Role Key, di server, bukan di APK) menukar token: `POST /rest/v1/rpc/consume_web_handoff {"p_token": "..."}` -> mengembalikan `user_id`. Token di fragment URL tidak ikut terkirim ke server, jadi baca dengan JavaScript lalu kirim ke backend.
- Jika fungsi belum dipasang, aplikasi membuka halaman tanpa token dan menampilkan peringatan (tidak ada verifikasi palsu).
- Pembelian, konfirmasi admin, dan pengaktifan premium dikerjakan di tahap website berikutnya.

## 5. Uji manual setelah build
Login -> profil muncul di tab Profil -> buka anime -> putar episode ≥5 menit -> cek XP bertambah (+20 sekali per episode) -> logout & login lagi -> riwayat/favorit tetap ada -> uji dari perangkat lain.
