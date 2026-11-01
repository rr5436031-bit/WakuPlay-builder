#!/data/data/com.termux/files/usr/bin/bash
# Cek response asli AnimeInWeb (butuh: pkg install curl)
B=https://animeinweb-api.vercel.app/api
for p in "/homepage" "/search?q=one%20piece" "/genres" "/schedule?day=MONDAY" "/anime/426" "/anime/426/episodes" "/episode/317534/stream"; do
  echo "=============== $p"
  curl -s -m 25 -w "\n[HTTP %{http_code}]\n" "$B$p" | head -c 1800
  echo
done
