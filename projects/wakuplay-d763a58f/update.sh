#!/data/data/com.termux/files/usr/bin/bash
# WakuPlay - update UI + API, lalu build ulang APK debug
set -e
cd "$(dirname "$0")"
ROOT="$(pwd)"
export JAVA_HOME="$PREFIX/lib/jvm/java-17-openjdk"
export ANDROID_HOME="$HOME/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

rm -f src/pages/Profile.jsx
echo "==> [1/4] npm install"
npm install
echo "==> [2/4] Build web"
npm run build
echo "==> [3/4] Sync Capacitor"
npx cap sync android
node scripts/patch-android.mjs || true   # warna layar awal Android = warna splash (tanpa layar hitam)
node scripts/slim-android.mjs || true    # R8 default MATI (berat di HP) dan membersihkan patch R8 lama; aktifkan: WP_SLIM=1 bash update.sh
node scripts/push-android.mjs || true    # notifikasi tanpa Firebase: ikon notifikasi, izin, bersihkan sisa Firebase (lihat PANDUAN-NOTIFIKASI.md)
# versi APK = "version" di package.json (contoh 1.1.0 -> versionName 1.1.0, versionCode 10100)
VER=$(node -p "require('./package.json').version")
VCODE=$(node -p "const [a,b,c]=require('./package.json').version.split('.').map(Number); (a||0)*10000+(b||0)*100+(c||0)")
sed -i "s/versionName \".*\"/versionName \"$VER\"/; s/versionCode [0-9]*/versionCode $VCODE/" android/app/build.gradle
echo "==> [4/4] Build APK debug (versi $VER)"
if [ -n "$WP_SIGN" ]; then
  # APK release bertanda tangan kunci tetap (~/.wakuplay) -> dasar untuk verifikasi developer Google (lihat PANDUAN-APK-AMAN.md)
  node scripts/sign-android.mjs
  cd android && chmod +x gradlew && ./gradlew assembleRelease --no-daemon
  cd "$ROOT"
  cp android/app/build/outputs/apk/release/app-release.apk WakuPlay.apk
else
  cd android && chmod +x gradlew && ./gradlew assembleDebug --no-daemon
  cd "$ROOT"
  cp android/app/build/outputs/apk/debug/app-debug.apk WakuPlay.apk
fi
cp WakuPlay.apk ~/storage/downloads/WakuPlay.apk 2>/dev/null && echo "APK juga disalin ke Downloads" || true
echo "SELESAI: $ROOT/WakuPlay.apk"
