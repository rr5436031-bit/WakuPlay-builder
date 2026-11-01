#!/data/data/com.termux/files/usr/bin/bash
# Build APK debug. Seluruh keluaran disimpan ke build.log dan disalin ke /sdcard/Download/wakuplay-build.log
# (tetap ada walau Termux tertutup/force close). Kirim file itu jika gagal.
DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$DIR/build.log"; : > "$LOG"
copylog() { mkdir -p /sdcard/Download 2>/dev/null; cp "$LOG" /sdcard/Download/wakuplay-build.log 2>/dev/null && echo ">> log: /sdcard/Download/wakuplay-build.log"; }
trap copylog EXIT
termux-wake-lock 2>/dev/null
{
proot-distro login debian --shared-tmp --bind "$DIR:/work" -- bash -lc '
set -e
bash /work/scripts/bootstrap-android.sh
cd /work && source $HOME/.wp-env
echo "=== flutter analyze (hanya ERROR) ==="
flutter analyze --no-fatal-infos --no-fatal-warnings > analyze.log 2>&1 || true
grep -E " error " analyze.log | head -60 || true
echo "=== flutter build apk --debug (arm64) ==="
flutter build apk --debug --target-platform android-arm64 --dart-define-from-file=env.json
'
echo "KODE_KELUAR=$?"
} 2>&1 | tee -a "$LOG"
APK="$DIR/build/app/outputs/flutter-apk/app-debug.apk"
if [ -f "$APK" ]; then
  mkdir -p /sdcard/Download 2>/dev/null; cp "$APK" /sdcard/Download/WakuPlay-debug.apk && echo "BERHASIL -> /sdcard/Download/WakuPlay-debug.apk"
else
  echo "BUILD GAGAL. 40 baris terakhir:"; tail -n 40 "$LOG"
fi
