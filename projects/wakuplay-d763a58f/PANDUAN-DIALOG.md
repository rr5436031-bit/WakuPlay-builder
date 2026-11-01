# Dialog konfirmasi WakuPlay (v1.6.1)

Semua kotak abu-abu bawaan Android (`window.confirm`) diganti dialog bergaya WakuPlay (kartu gelap biru, ikon bulat, tombol Batal / aksi).

- Pakai: `if (!(await askConfirm('Teks', { title: 'Hapus pesan?', yes: 'Hapus', danger: true }))) return` (fungsi pemanggil harus `async`).
- `danger` (merah + ikon tempat sampah) otomatis kalau teks diawali Hapus/Blokir/Kurangi/Reset/Jual/Matikan/Kembalikan/Keluar/Tolak. Tanpa opsi, judul = "Yakin?" / "Konfirmasi" dan label tombol diambil dari kata pertama.
- Baris baru (`\n`) di teks tampil sebagai baris baru. Ketuk area gelap atau tombol Back Android = Batal.
- Beberapa dialog sekaligus diantre, tampil satu per satu.
- Kode: `src/lib/dialog.js`, `src/components/DialogHost.jsx` (dipasang di `App.jsx`), CSS `.wp-dlg` di akhir `index.css`.
- Aturan D1/D2 di `npm run check`: dilarang `window.confirm/alert/prompt`; `App.jsx` wajib memasang `<DialogHost />` dan `dismissDialog()` untuk tombol Back.
