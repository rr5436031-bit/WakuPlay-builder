#!/data/data/com.termux/files/usr/bin/bash
# Menguji endpoint 5 sumber satu per satu dan menyimpan contoh JSON ke probe-out/.
# Jalankan SEBELUM menyesuaikan sanka_adapter.dart. Kirim isi probe-out/*.txt ke Claude.
B=https://www.sankavollerei.web.id
mkdir -p probe-out
for u in "anime/animekompi/home" "anime/winbu/home" "anime/alqanime/home?page=1" "anime/donghub/home?page=1" "anime/nimegami/home?page=1"; do
  n=$(echo "$u" | tr '/?=' '___')
  code=$(curl -s -m 25 -o "probe-out/$n.json" -w '%{http_code}' "$B/$u")
  echo "$code  $u  ($(wc -c < probe-out/$n.json) bytes)"
  head -c 1500 "probe-out/$n.json" > "probe-out/$n.txt"
done
curl -s -m 25 "$B/anime" | head -c 6000 > probe-out/docs-anime.txt && echo "docs -> probe-out/docs-anime.txt"
