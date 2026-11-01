#!/data/data/com.termux/files/usr/bin/bash
# Tes variasi header untuk gambar animein (cari yang menghasilkan 200)
P="assets/images/movie/cover/73f33e42be21d8bcdf8e45f544aea7a0.jpg"
UA="Mozilla/5.0 (Linux; Android 13; SM-A525F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
t() { printf "%-34s -> " "$1"; shift; curl -s -o /dev/null -m 20 -w "%{http_code}\n" "$@"; }
t "polos" "https://api.animein.net/$P"
t "UA browser" -A "$UA" "https://api.animein.net/$P"
t "UA + referer animein.net" -A "$UA" -H "Referer: https://animein.net/" "https://api.animein.net/$P"
t "UA + referer www.animein.net" -A "$UA" -H "Referer: https://www.animein.net/" "https://api.animein.net/$P"
t "UA + referer + origin" -A "$UA" -H "Referer: https://animein.net/" -H "Origin: https://animein.net" "https://api.animein.net/$P"
t "UA + Accept image" -A "$UA" -H "Accept: image/webp,image/*,*/*" "https://api.animein.net/$P"
t "xyz-api assets_xyz" -A "$UA" "https://xyz-api.animein.net/assets_xyz/images/movie/cover/44c73f7442fc918860f9c298967584e4.jpg"
t "xyz-api + referer" -A "$UA" -H "Referer: https://animein.net/" "https://xyz-api.animein.net/assets_xyz/images/movie/cover/44c73f7442fc918860f9c298967584e4.jpg"
echo "---- header respons (polos):"
curl -s -I -m 20 "https://api.animein.net/$P" | head -15
echo "---- body (UA browser):"
curl -s -m 20 -A "$UA" "https://api.animein.net/$P" | head -c 400; echo
