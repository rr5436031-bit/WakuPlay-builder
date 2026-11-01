#!/data/data/com.termux/files/usr/bin/bash
# WakuPlay - setup + build debug APK di Termux (ARM64)
set -e
cd "$(dirname "$0")"
ROOT="$(pwd)"

echo "==> [1/9] Pasang paket Termux"
pkg install -y nodejs openjdk-17 aapt2 unzip wget

export JAVA_HOME="$PREFIX/lib/jvm/java-17-openjdk"
export ANDROID_HOME="$HOME/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

echo "==> [2/9] Android SDK"
if [ ! -d "$ANDROID_HOME/cmdline-tools/latest" ]; then
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  wget -O "$TMPDIR/cmdtools.zip" https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
  unzip -q "$TMPDIR/cmdtools.zip" -d "$ANDROID_HOME/cmdline-tools"
  mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
fi
yes | sdkmanager --sdk_root="$ANDROID_HOME" --licenses >/dev/null || true
sdkmanager --sdk_root="$ANDROID_HOME" "platforms;android-34" "build-tools;34.0.0"

echo "==> [3/9] npm install"
npm install

echo "==> [4/9] Build web (Vite)"
npm run build

echo "==> [5/9] Android platform (Capacitor)"
[ -d android ] || npx cap add android
npx cap sync android
node scripts/slim-android.mjs || true   # R8 default mati (berat di HP); membersihkan patch lama
node scripts/push-android.mjs || true    # notifikasi tanpa Firebase: ikon notifikasi, izin, bersihkan sisa Firebase (lihat PANDUAN-NOTIFIKASI.md)

echo "==> [6/9] Icon + versi 1.0.1"
RES=android/app/src/main/res
for d in icons/mipmap-*; do
  n=$(basename "$d"); mkdir -p "$RES/$n"; cp "$d"/*.png "$RES/$n/"
done
cat > "$RES/values/ic_launcher_background.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#000000</color>
</resources>
XML
sed -i 's/versionName ".*"/versionName "1.0.5"/; s/versionCode [0-9]*/versionCode 10005/' android/app/build.gradle

echo "==> [7/9] Konfigurasi Gradle untuk Termux"
echo "sdk.dir=$ANDROID_HOME" > android/local.properties
grep -q aapt2FromMavenOverride android/gradle.properties || cat >> android/gradle.properties <<PROP

# Termux ARM64: pakai aapt2 native Termux
android.aapt2FromMavenOverride=$PREFIX/bin/aapt2
org.gradle.jvmargs=-Xmx1536m -Dfile.encoding=UTF-8
PROP

echo "==> [8/9] Debug keystore + SHA-1"
mkdir -p ~/.android
if [ ! -f ~/.android/debug.keystore ]; then
  keytool -genkeypair -v -keystore ~/.android/debug.keystore \
    -alias androiddebugkey -storepass android -keypass android \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=Android Debug,O=Android,C=US"
fi
SHA1=$(keytool -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android | grep "SHA1:" | sed 's/^ *//')

echo "==> [9/9] Build APK debug"
cd android
chmod +x gradlew
./gradlew assembleDebug --no-daemon
cd "$ROOT"
cp android/app/build/outputs/apk/debug/app-debug.apk WakuPlay.apk

echo
echo "================ RINGKASAN ================"
echo "PROJECT: WakuPlay (v1.0.1)"
echo "PACKAGE: com.wakuplay.app"
echo "$SHA1"
echo "APK: $ROOT/android/app/build/outputs/apk/debug/app-debug.apk"
echo "SALINAN: $ROOT/WakuPlay.apk"
echo "STATUS BUILD: SUKSES"
echo "SUPABASE CONFIG: URL + Publishable Key di .env (tidak tampil di UI)"
echo "==========================================="
