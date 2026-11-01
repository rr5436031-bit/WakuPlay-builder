# Google Login
- Gunakan OAuth client yang SAMA. `GOOGLE_WEB_CLIENT_ID` = Web Client ID lama (sudah di env.json).
- Di Google Cloud Console pastikan ada client **Android** untuk `com.wakuplay.app` dengan SHA-1 (dan SHA-256) dari keystore rilis lama `~/.wakuplay/wakuplay.jks`, serta SHA-1 debug bila ingin tes APK debug.
- Di Supabase: Auth -> Providers -> Google aktif dan Web Client ID tercantum (sudah, karena app lama jalan).
- Alur: google_sign_in -> idToken -> `signInWithIdToken` -> UUID sama -> RPC `ensure_profile`.
