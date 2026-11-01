# Audit WakuPlay v185 -> Flutter (Fase 0)

Hasil pemeriksaan `WakuPlay-v185.zip` (331 file) dan `refrensi.zip` (16 screenshot).

## Temuan penting
1. **Package ID lama: `com.wakuplay.app`** (capacitor.config.json). Dipertahankan.
2. **Backend = Supabase**, dipakai lewat 11 tabel langsung + **176 RPC** (docs/rpc-list.txt). Logika aman (role, XP, gold, premium) ada di RPC/RLS server, jadi Flutter cukup memanggil RPC yang sama.
3. **Login Google lama**: `@capgo/capacitor-social-login` -> idToken -> `supabase.auth.signInWithIdToken`. Flutter memakai alur yang sama (`google_sign_in` + `serverClientId` = Web Client ID yang sama) sehingga UUID sama.
4. **API anime lama BUKAN sankavollerei**: Edge Function `anime-api` -> `animeinweb-api.vercel.app` (env `ANIME_API_BASE`), dengan whitelist path dan wajib login. Lima sumber sankavollerei adalah sumber BARU; belum ada di source lama.
5. **Edge Functions**: anime-api, episode-watch, premium, premium-webhook, border-gif. Rahasia (GITHUB_TOKEN, PUSH_SECRET, SOCIABUZZ_WEBHOOK_KEY, service role) hanya di server. Aman, tidak masuk APK.
6. **Plugin native Capacitor (Java)** yang harus jadi Kotlin/platform channel: `wp-pip` (PiP, landscape, immersive, insets), `wp-notify` (poll service, boot receiver, notifikasi), `wp-pay` (pembayaran/autofill), `wp-gifurl`.
7. **Kunci tanda tangan rilis**: `~/.wakuplay/wakuplay.jks`. APK Flutter HARUS memakai kunci yang sama (update di tempat + SHA-1 OAuth tetap cocok).
8. **Screenshot referensi** menampilkan aplikasi lain (merek "WIBUKU"). Tata letak dan gaya dipakai sebagai acuan, nama/logo diganti WakuPlay.
9. Kode terbesar: `DevPanel.jsx` (2075 baris), `Player.jsx` (593), `Chat.jsx` (529), `Pet.jsx` (447).

## Pemetaan halaman -> Flutter
| Halaman lama | Folder Flutter | Status |
|---|---|---|
| Login / Welcome | features/login | kerangka + Google login ditulis, belum diuji |
| Home | features/home | grid dari engine 6 sumber, belum hero/genre/ranking |
| Search, Detail, Player | features/anime, player | belum |
| Schedule, History, Favorites | features/* | placeholder |
| Account, UserProfile, Settings, Connections, FindFriend | features/account | belum |
| Chat, DirectChat, Notifications, Feedback | features/chat, notifications | belum |
| Leaderboard, TopLevel, TopGiver | features/leaderboard | belum |
| Premium, GiveawayCreate | features/premium | belum |
| WakuGames, GameInfo | features/wakugames | kerangka menu + saldo `wp_gold` |
| Farm | features/farm | belum |
| Clans, ClanDetail, ClanGacha, ClanEmblemGacha | features/clan | belum |
| Gacha, BannerPick, AvatarBorders, Pet | features/gacha, pet | belum |
| DevPanel | features/developer | belum (izin via RPC `has_dev_panel`) |

Daftar fitur lengkap tetap sesuai permintaan Anda (Bagian 9).

## Pemetaan komponen
CosmicBg.jsx / PetSkyBg / SkyIsland -> `CustomPainter` + `AnimationController` (pause saat app background via `WidgetsBindingObserver`). GameIcons.jsx / FarmArt.jsx / ClanBadge (SVG) -> `flutter_svg` atau `CustomPainter`. BorderFrame/borders.css -> widget bertumpuk + gambar. hls.js -> `video_player` (HLS native ExoPlayer) + `chewie`.

## Risiko / keterbatasan
- Sesi lingkungan ini tanpa internet: **tidak bisa mengunduh Flutter SDK, tidak bisa build APK, tidak bisa menguji endpoint sankavollerei**.
- Skema JSON 5 sumber belum diketahui. Adapter memakai parsing defensif; wajib dijalankan `scripts/probe-sources.sh` lalu adapter disesuaikan.
- Path search/detail/episode/stream sankavollerei belum diverifikasi (tidak dikarang; ditandai TODO).
- Build Flutter di Termux butuh proot Debian, ±6-8 GB penyimpanan dan RAM cukup; build pertama lambat.

## Rencana fase berikutnya
2. probe-sources -> sesuaikan adapter, tambah detail/episode/stream. 3. Search, Detail, Player (HLS), History/Favorites. 4. Account/Profile/Settings/Notifikasi. 5. Chat + komentar. 6. WakuGames penuh (Farm, Clan, Gacha, Border, Pet). 7. Premium + Developer Panel. 8. Notifikasi native (Kotlin), update app. 9. Uji di perangkat + bandingkan dengan referensi.

## Status Fase 2
Selesai ditulis (belum dikompilasi/diuji): Search (debounce, 6 sumber), Detail + daftar episode (hanya sumber legacy), Favorit & Riwayat (tabel lama), Player (HLS/MP4 via video_player+chewie, kecepatan, kualitas, auto-next, simpan progres tiap 15 dtk, PiP via Kotlin).
Belum: Skip Intro, komentar episode, pilih server, hero/genre/ranking, detail sumber sankavollerei (butuh hasil probe-sources).

## Status Fase 3
Ditulis (belum dikompilasi): Home dengan slider/hot/terbaru/populer dari API lama + katalog 6 sumber, Jadwal (7 hari, API lama), Akun (profil+XP+gold dari RPC, logout), Global Chat (realtime, tabel lama, hapus lewat tekan lama), perbaikan signing rilis untuk build.gradle(.kts).
Belum: Skip Intro, komentar episode, genre/ranking, level/XP otomatis nonton, Direct Chat, Notifikasi, Settings, Leaderboard, Premium, Clan, Pet, Farm, Gacha, Border, Developer, WakuGames visual penuh, dan semua detail/stream sumber sankavollerei.

## Status Fase 4 (belum dikompilasi/diuji)
Ditulis: Skip Intro (+85 dtk, aturan lama), komentar episode (tanpa balasan), XP nonton (xp_start/xp_beat), view counter, genre, peringkat (top_anime_by_views), Leaderboard (XP/Level/Giver), Notifikasi (dalam app), Teman + Direct Chat (polling 4 dtk), Settings (lokal), Premium (lihat paket & riwayat saja), Clan (lihat/gabung/buat/keluar/klaim harian), Gacha & Pet (summon generik), Avatar Border (beli/pakai), Kebun Waku (panen/upgrade/beli/pakai, tanpa adegan SVG), Developer Panel (cari user, role, gold, blokir), WakuGames dengan latar kosmik.
Belum / terbatas: detail & stream 5 sumber sankavollerei (tunggu probe-sources), balasan komentar, push notification native (Kotlin), pembelian Premium (QRIS), Clan Gacha/Emblem/Detail lengkap, ikon & ilustrasi SVG game (GameIcons/FarmArt/Pet art), banner/giveaway/laporan/mute/level-config di DevPanel, Top bar level/XP popup, update aplikasi. Bentuk JSON RPC jsonb (farm_state, clan_*, pet_info, border_shop) dipetakan dari kode lama; jika field berbeda, tampilan kosong sebagian dan perlu penyesuaian setelah diuji di perangkat.

## Status Fase 5 (belum dikompilasi/diuji)
Ditulis: Premium QRIS penuh (Edge Function `premium`; WebView Sociabuzz + isi otomatis wp-pay-fill.js, tangkap QRIS, cek status tiap 6 dtk), balasan komentar + laporkan komentar, notifikasi latar belakang tanpa Firebase (PollService/NotifyCore Java asli dipakai ulang + NotifyBridge + MainActivity.kt; manifest dipatch oleh bootstrap-android.sh), Settings kecepatan cek (default Normal 30 dtk; versi lama default 5 dtk), Clan Gacha (Spin Warna) & Emblem Clan, 7 ikon SVG asli GameIcons.jsx lewat flutter_svg, Developer: banner, XP giveaway, bisukan user, laporan. Banner aktif ditampilkan sekali per sesi.
Catatan: laporan pengguna tidak bisa dibaca klien menurut RLS lama; Developer Panel memakai RPC opsional `dev_reports_list` (supabase_additions/optional_dev_reports.sql) yang harus dipasang manual.
Belum: ketukan notifikasi membuka halaman tujuan, ilustrasi Kebun/Pet (FarmArt), Info game, Clan Detail lengkap (donasi, log, kick, peran, permintaan), banner profil, update aplikasi, detail & stream 5 sumber sankavollerei.

## Status Fase 6 (belum dikompilasi/diuji)
Ditulis: ilustrasi Kebun Waku (pohon/lampu/pet/orang) hasil render FarmArt.jsx asli ke SVG statis + adegan di Kebun; halaman Info! (data gameInfo.js asli); pengecekan update aplikasi (get_app_update, bisa dipaksa) + banner dengan tombol tautan; pilih Banner Profil (wallpaper gacha / URL .gif); Kelola Clan (permintaan, donasi, riwayat, mode gabung, tier, slot, bubarkan) + aksi anggota (peran, keluarkan, serahkan pemimpin); ketukan notifikasi membuka halaman tujuan.
Tambahan dependency: url_launcher. Konstanta versi di lib/core/config/env.dart (appVersion) harus disamakan dengan pubspec saat rilis.
Belum: detail/stream 5 sumber sankavollerei (menunggu endpoint), animasi goyang pada ilustrasi Kebun, Clan banner/profil clan, profil publik pengguna lain, Top bar level/XP popup, Gacha: animasi, Pet: habitat & klaim hasil, WakuGames: animasi kartu.

## Status Fase 7 (belum dikompilasi/diuji)
Ditulis: Profil publik pengguna (banner, avatar, #ID, peran, level & progres XP, komentar, bergabung, tambah teman, pesan, lihat pet) dapat dibuka dari Leaderboard, Teman, anggota Clan, komentar, dan Global Chat; popup +XP dan LEVEL UP (setelan "Tampilkan EXP Popup"; level dihitung dari level_config_get seperti levelcurve.js); detak XP kini dikirim tiap 2 menit penuh menonton (sama seperti xp.js, sebelumnya 30 dtk); habitat Pet (pasang/simpan, klaim satu/semua, jual dengan konfirmasi, hitung mundur memakai jam server) + lihat habitat pemain lain; animasi gacha (orb berdenyut lalu kartu hasil muncul bertahap, bersinar untuk epic ke atas); kartu menu WakuGames (masuk bertahap, menyusut saat ditekan, ikon melayang).
Belum: detail & stream 5 sumber sankavollerei; border avatar & badge pada profil publik; banner clan; animasi goyang pada ilustrasi Kebun.

## Status Fase 8 (belum dikompilasi/diuji)
Ditulis: detail, episode, dan stream 5 sumber sankavollerei berdasarkan docs/sanka-endpoints.json (path home/search/detail/episode sudah sesuai daftar; BENTUK JSON respons belum diketahui sehingga parser heuristik). Player memutar stream HLS/MP4 langsung dan membuka embed/iframe di WebView (navigasi frame utama ke domain lain diblokir). XP hanya untuk pemutaran langsung (embed tidak punya posisi). Winbu: coba /anime, /series, /film bergantian + /server untuk embed; Alqanime & Nimegami tidak punya endpoint episode: tautan diambil dari data detail. Halaman Settings > Diagnosa Sumber Anime menguji home -> detail -> stream tiap sumber dan menampilkan JSON mentah.
Favorit/Riwayat/Komentar sumber baru memakai kunci "sumber:slug" di kolom anime_id/episode_id (sumber lama tetap polos agar data lama utuh).
Juga: border avatar (gambar border server, skala 1.2) + lencana peran/Premium di profil publik; banner clan (tampil + ubah oleh Leader/Vice, clan_set_banner); animasi goyang ilustrasi Kebun (pohon, orang, pet, lampu).
Belum: border bergaya SVG bawaan (non-gambar) pada profil, lencana Top Level/Top Giver, fullscreen embed WebView.

## Status Fase 9 (belum dikompilasi/diuji)
Ditulis: 50 border SVG bawaan (render borderArt.js asli, statis) + border gambar pada profil publik lewat BorderFrame; lencana Top LB bulanan / Top Giver bulanan / Top Level (monthly_top_of, monthly_giver_of, top_level_of).
Perbaikan build Termux: log otomatis ke /sdcard/Download/wakuplay-build.log, memori Gradle dibatasi 1,5 GB (default Flutter 8 GB memicu Android mematikan Termux), daemon dimatikan, hanya arm64, aapt2 ARM64 dari Debian, NDK/strip x86 dinonaktifkan, flutter analyze menampilkan error Dart sebelum build.
