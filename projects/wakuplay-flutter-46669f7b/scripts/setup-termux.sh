#!/data/data/com.termux/files/usr/bin/bash
# Setup lingkungan build Flutter di Termux lewat proot-distro Debian ARM64.
# Flutter SDK resmi tidak berjalan native di Termux (bionic), jadi dijalankan di dalam Debian.
set -e
pkg update -y && pkg install -y proot-distro git curl unzip
proot-distro login debian -- true >/dev/null 2>&1 || proot-distro install debian
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
proot-distro login debian --shared-tmp --bind "$SCRIPT_DIR:/work" -- bash -lc '
set -e
apt-get update && apt-get install -y curl git unzip xz-utils zip aapt python3 openjdk-21-jdk-headless clang cmake ninja-build pkg-config libglu1-mesa
export ANDROID_HOME=$HOME/android-sdk
if [ ! -d $ANDROID_HOME/cmdline-tools/latest ]; then
  mkdir -p $ANDROID_HOME/cmdline-tools && cd /tmp
  curl -L -o clt.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
  unzip -q clt.zip && mv cmdline-tools $ANDROID_HOME/cmdline-tools/latest
fi
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH
yes | sdkmanager --licenses >/dev/null
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"
[ -d $HOME/flutter ] || git clone --depth 1 -b stable https://github.com/flutter/flutter.git $HOME/flutter
export PATH=$HOME/flutter/bin:$PATH
flutter config --android-sdk $ANDROID_HOME --no-analytics
flutter doctor -v
echo "export ANDROID_HOME=$ANDROID_HOME; export PATH=\$HOME/flutter/bin:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$PATH" > $HOME/.wp-env
'
echo "Selesai. Lanjut: bash scripts/build-debug.sh"
