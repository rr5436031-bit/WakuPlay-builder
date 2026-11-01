#!/bin/bash
# Dijalankan DI DALAM proot Debian (dipanggil build-*.sh). Membuat folder android/ sekali saja,
# mempertahankan applicationId com.wakuplay.app, dan memasang MainActivity.kt + izin + kunci rilis.
set -e
cd /work
source $HOME/.wp-env
if [ ! -d android ]; then
  flutter create --org com.wakuplay --project-name wakuplay --platforms android .
fi
# application id lama
sed -i 's/applicationId = ".*"/applicationId = "com.wakuplay.app"/; s/namespace = ".*"/namespace = "com.wakuplay.app"/; s/minSdk = flutter.minSdkVersion/minSdk = 24/; s/minSdkVersion flutter.minSdkVersion/minSdkVersion 24/' android/app/build.gradle* || true
grep -q 'com.wakuplay.app' android/app/build.gradle* || echo 'PERINGATAN: applicationId belum com.wakuplay.app, cek android/app/build.gradle'
mkdir -p android/app/src/main/kotlin/com/wakuplay/app
rm -f android/app/src/main/kotlin/com/wakuplay/wakuplay/MainActivity.kt
cp native/MainActivity.kt android/app/src/main/kotlin/com/wakuplay/app/MainActivity.kt
M=android/app/src/main/AndroidManifest.xml
grep -q 'android:label="WakuPlay"' $M || sed -i 's/android:label="[^"]*"/android:label="WakuPlay"/' $M
grep -q supportsPictureInPicture $M || sed -i 's/<activity/<activity android:supportsPictureInPicture="true"/' $M
grep -q POST_NOTIFICATIONS $M || sed -i 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <application#' $M
# ikon lama: salin dari src lama jika ada (icons/mipmap-*)
[ -d icons ] && for d in icons/mipmap-*; do mkdir -p android/app/src/main/res/$(basename $d); cp -r $d/* android/app/src/main/res/$(basename $d)/; done || true
command -v python3 >/dev/null || { apt-get update && apt-get install -y python3; }
mkdir -p android/app/src/main/java/com/wakuplay/notify
cp native/java/com/wakuplay/notify/*.java android/app/src/main/java/com/wakuplay/notify/
python3 - <<'PY'
p = '/work/android/app/src/main/AndroidManifest.xml'
s = open(p).read()
if 'com.wakuplay.notify.PollService' not in s:
    perms = ''.join('    <uses-permission android:name="android.permission.%s"/>\n' % x for x in
        ['RECEIVE_BOOT_COMPLETED', 'FOREGROUND_SERVICE', 'FOREGROUND_SERVICE_SPECIAL_USE', 'WAKE_LOCK', 'REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'])
    comps = ('        <service android:name="com.wakuplay.notify.PollService" android:exported="false" android:foregroundServiceType="specialUse">\n'
             '            <property android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE" android:value="Notifikasi chat, tag, dan episode baru tanpa Firebase"/>\n'
             '        </service>\n'
             '        <receiver android:name="com.wakuplay.notify.PollReceiver" android:exported="false"/>\n'
             '        <receiver android:name="com.wakuplay.notify.BootReceiver" android:exported="true">\n'
             '            <intent-filter><action android:name="android.intent.action.BOOT_COMPLETED"/><action android:name="android.intent.action.MY_PACKAGE_REPLACED"/></intent-filter>\n'
             '        </receiver>\n')
    s = s.replace('<application', perms + '    <application', 1)
    s = s.replace('</application>', comps + '    </application>', 1)
    open(p, 'w').write(s)
PY

# ---- penyesuaian ARM64/proot: cegah OOM (Termux force close), aapt2 x86, NDK x86 ----
free -m | head -2 || true
GP=android/gradle.properties; touch $GP
sed -i '/^org.gradle.jvmargs/d;/^org.gradle.daemon/d;/^org.gradle.workers.max/d;/^org.gradle.parallel/d;/^kotlin.compiler.execution.strategy/d;/^kotlin.daemon.jvm.options/d;/^android.aapt2FromMavenOverride/d' $GP
cat >> $GP <<'PROPS'
org.gradle.jvmargs=-Xmx1536m -XX:MaxMetaspaceSize=512m -XX:+UseSerialGC
org.gradle.daemon=false
org.gradle.workers.max=1
org.gradle.parallel=false
kotlin.compiler.execution.strategy=in-process
kotlin.daemon.jvm.options=-Xmx768m
PROPS
command -v aapt2 >/dev/null 2>&1 || { apt-get update >/dev/null 2>&1; apt-get install -y aapt >/dev/null 2>&1 || true; }
A2=$(command -v aapt2 || true)
if [ -n "$A2" ]; then echo "android.aapt2FromMavenOverride=$A2" >> $GP; echo "aapt2 ARM64: $A2"; else echo "PERINGATAN: aapt2 untuk ARM64 tidak ditemukan (apt install aapt gagal). Build resource bisa gagal."; fi
sed -i '/ndkVersion/d' android/app/build.gradle* 2>/dev/null || true
python3 - <<'PY'
import glob,re
for p in glob.glob('/work/android/app/build.gradle*'):
    s=open(p).read()
    if 'wp-nostrip' in s: continue
    kts=p.endswith('.kts')
    blk=('\n    // wp-nostrip: tool strip NDK x86 tidak jalan di ARM\n    packaging { jniLibs { keepDebugSymbols.add("**/*.so") } }\n' if kts else
         '\n    // wp-nostrip\n    packagingOptions { jniLibs { keepDebugSymbols += ["**/*.so"] } }\n')
    s=re.sub(r'android\s*\{',lambda m:m.group(0)+blk,s,1)
    open(p,'w').write(s)
PY
flutter pub get
