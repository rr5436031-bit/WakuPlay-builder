#!/data/data/com.termux/files/usr/bin/bash
# APK rilis HARUS ditandatangani dengan keystore LAMA (~/.wakuplay) agar menimpa aplikasi lama & SHA-1 OAuth cocok.
DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$DIR/build.log"; : > "$LOG"
copylog() { mkdir -p /sdcard/Download 2>/dev/null; cp "$LOG" /sdcard/Download/wakuplay-build.log 2>/dev/null && echo ">> log: /sdcard/Download/wakuplay-build.log"; }
trap copylog EXIT
[ -f ~/.wakuplay/sign.properties ] || { echo "Tidak ada ~/.wakuplay/sign.properties (kunci rilis lama)."; exit 1; }
termux-wake-lock 2>/dev/null
{
proot-distro login debian --shared-tmp --bind "$DIR:/work" --bind "$HOME/.wakuplay:/root/.wakuplay" -- bash -lc '
set -e
bash /work/scripts/bootstrap-android.sh
python3 /work/scripts/patch-signing.py
cd /work && source $HOME/.wp-env
flutter build apk --release --target-platform android-arm64 --dart-define-from-file=env.json
'
echo "KODE_KELUAR=$?"
} 2>&1 | tee -a "$LOG"
APK="$DIR/build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK" ]; then
  mkdir -p /sdcard/Download 2>/dev/null; cp "$APK" /sdcard/Download/WakuPlay.apk && echo "BERHASIL -> /sdcard/Download/WakuPlay.apk"
else
  echo "BUILD GAGAL. 40 baris terakhir:"; tail -n 40 "$LOG"
fi
