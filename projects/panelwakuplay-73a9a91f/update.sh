#!/data/data/com.termux/files/usr/bin/bash
# Panel WakuPlay - update source, lalu build ulang APK debug
set -e
cd "$(dirname "$0")"
ROOT="$(pwd)"
export JAVA_HOME="$PREFIX/lib/jvm/java-17-openjdk"
export ANDROID_HOME="$HOME/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

echo "==> [1/4] npm install"
npm install
echo "==> [2/4] Build web"
npm run build
echo "==> [3/4] Sync Capacitor"
npx cap sync android
node scripts/patch-android.mjs || true
node scripts/slim-android.mjs || true
VER=$(node -p "require('./package.json').version")
VCODE=$(node -p "const [a,b,c]=require('./package.json').version.split('.').map(Number); (a||0)*10000+(b||0)*100+(c||0)")
sed -i "s/versionName \".*\"/versionName \"$VER\"/; s/versionCode [0-9]*/versionCode $VCODE/" android/app/build.gradle
echo "==> [4/4] Build APK debug (versi $VER)"
if [ -n "$WP_SIGN" ]; then
  node scripts/sign-android.mjs
  cd android && chmod +x gradlew && ./gradlew assembleRelease --no-daemon
  cd "$ROOT"
  cp android/app/build/outputs/apk/release/app-release.apk PanelWakuPlay.apk
else
  cd android && chmod +x gradlew && ./gradlew assembleDebug --no-daemon
  cd "$ROOT"
  cp android/app/build/outputs/apk/debug/app-debug.apk PanelWakuPlay.apk
fi
cp PanelWakuPlay.apk ~/storage/downloads/PanelWakuPlay.apk 2>/dev/null && echo "APK juga disalin ke Downloads" || true
echo "SELESAI: $ROOT/PanelWakuPlay.apk"
