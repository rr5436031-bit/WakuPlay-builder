#!/data/data/com.termux/files/usr/bin/bash
# cek-sha.sh - Ambil SHA-1 & SHA-256 sertifikat penanda tangan APK (untuk Google OAuth / Supabase)
# Pemakaian:
#   bash cek-sha.sh                      -> APK terbaru di folder Download
#   bash cek-sha.sh nama-file.apk        -> file tertentu di folder Download
#   bash cek-sha.sh /path/lengkap/app.apk
#   bash cek-sha.sh --ks file.keystore alias storepass   -> cek keystore langsung
set -u

# 1. Akses storage
if [ ! -d "$HOME/storage/downloads" ]; then
  echo "[*] Minta izin storage, tekan Allow..."
  termux-setup-storage
  sleep 6
fi
DL="$HOME/storage/downloads"
[ -d "$DL" ] || DL="/sdcard/Download"

# 2. Pasang dependensi bila belum ada
need=()
command -v keytool   >/dev/null 2>&1 || need+=(openjdk-17)
command -v apksigner >/dev/null 2>&1 || need+=(apksigner)
command -v unzip     >/dev/null 2>&1 || need+=(unzip)
if [ ${#need[@]} -gt 0 ]; then
  echo "[*] Memasang: ${need[*]}"
  pkg update -y && pkg install -y "${need[@]}" || { echo "[!] Gagal memasang paket"; exit 1; }
fi

# format "ab12..." -> "AB:12:..."
fmt() { printf '%s' "$1" | tr 'a-f' 'A-F' | sed 's/../&:/g; s/:$//'; }

show() {
  echo
  echo "================ HASIL ================"
  echo "SHA-1   : $(fmt "$1")"
  echo "SHA-256 : $(fmt "$2")"
  echo "======================================="
  echo "Salin SHA-1 ke Google Cloud Console > OAuth Client (Android)."
  {
    echo "File    : $3"
    echo "SHA-1   : $(fmt "$1")"
    echo "SHA-256 : $(fmt "$2")"
  } > "$DL/sha-result.txt" 2>/dev/null && echo "Disimpan juga di: $DL/sha-result.txt"
}

# Mode keystore
if [ "${1:-}" = "--ks" ]; then
  KS="${2:?isi path keystore}"; AL="${3:?isi alias}"; PW="${4:-android}"
  OUT=$(keytool -list -v -keystore "$KS" -alias "$AL" -storepass "$PW" 2>&1) || { echo "$OUT"; exit 1; }
  S1=$(echo "$OUT"   | grep -m1 'SHA1:'   | awk '{print $2}' | tr -d ':')
  S256=$(echo "$OUT" | grep -m1 'SHA256:' | awk '{print $2}' | tr -d ':')
  show "$S1" "$S256" "$KS"; exit 0
fi

# 3. Pilih APK
if [ $# -ge 1 ]; then
  case "$1" in /*) APK="$1" ;; *) APK="$DL/$1" ;; esac
else
  APK=$(ls -t "$DL"/*.apk 2>/dev/null | head -n1)
fi
if [ -z "${APK:-}" ] || [ ! -f "$APK" ]; then
  echo "[!] APK tidak ditemukan di $DL"; exit 1
fi
echo "[*] APK : $APK"
echo "[*] SHA-1 file APK (bukan untuk Google, hanya checksum file): $(sha1sum "$APK" | cut -d' ' -f1)"

# 4. Baca sertifikat penanda tangan (cara utama: apksigner, mendukung v1/v2/v3)
OUT=$(apksigner verify --print-certs "$APK" 2>&1)
S1=$(echo "$OUT"   | grep -m1 'certificate SHA-1 digest'   | awk '{print $NF}')
S256=$(echo "$OUT" | grep -m1 'certificate SHA-256 digest' | awk '{print $NF}')

# 5. Cadangan: baca META-INF/*.RSA bila apksigner gagal
if [ -z "$S1" ]; then
  echo "[!] apksigner gagal, coba cadangan via META-INF..."
  TMP=$(mktemp -d)
  unzip -qo "$APK" 'META-INF/*.RSA' 'META-INF/*.DSA' 'META-INF/*.EC' -d "$TMP" 2>/dev/null
  CERT=$(ls "$TMP"/META-INF/*.RSA "$TMP"/META-INF/*.DSA "$TMP"/META-INF/*.EC 2>/dev/null | head -n1)
  if [ -n "$CERT" ]; then
    O2=$(keytool -printcert -file "$CERT" 2>&1)
    S1=$(echo "$O2"   | grep -m1 'SHA1:'   | awk '{print $2}' | tr -d ':')
    S256=$(echo "$O2" | grep -m1 'SHA256:' | awk '{print $2}' | tr -d ':')
  fi
  rm -rf "$TMP"
fi

if [ -z "$S1" ]; then
  echo "[!] Gagal membaca sertifikat. Output apksigner:"; echo "$OUT"; exit 1
fi
show "$S1" "$S256" "$APK"
