#!/data/data/com.termux/files/usr/bin/bash
# Cek cara pencarian mana yang benar-benar jalan di API (butuh: pkg install curl)
B=https://animeinweb-api.vercel.app/api
for p in "/search?q=otome" "/search?q=otome%20game" "/search?q=otome+game" "/search?keyword=otome%20game" "/search?query=otome%20game" "/search?search=otome%20game"; do
  echo "=============== $p"
  curl -s -m 25 -w "\n[HTTP %{http_code}]\n" "$B$p" | head -c 700
  echo
done
