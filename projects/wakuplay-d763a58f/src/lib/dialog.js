// Dialog konfirmasi bergaya WakuPlay (pengganti window.confirm yang tampil sebagai kotak abu-abu Android).
// Pakai: if (!(await askConfirm('Teks', { title, yes, danger }))) return
// Tampilannya dirender oleh <DialogHost /> (components/DialogHost.jsx) yang dipasang sekali di App.jsx.
let queue = []
const subs = new Set()
let seq = 0
const emit = () => subs.forEach((f) => f(queue[0] || null))

const DANGER = /^(hapus|blokir|kurangi|reset|jual|matikan|kembalikan|keluar|tolak)\b/i
const YES = { hapus: 'Hapus', blokir: 'Blokir', kurangi: 'Kurangi', reset: 'Reset', jual: 'Jual', matikan: 'Matikan', kembalikan: 'Kembalikan', keluar: 'Keluar', tolak: 'Tolak', tambah: 'Tambah', simpan: 'Simpan', ubah: 'Ubah', ganti: 'Ganti', buka: 'Buka', tambahkan: 'Tambahkan' }

export function askConfirm(text, opts = {}) {
  return new Promise((resolve) => {
    const raw = String(text ?? '').trim()
    const first = (raw.match(/^[\p{L}]+/u) || [''])[0].toLowerCase()
    const danger = opts.danger ?? DANGER.test(raw)
    const item = {
      id: ++seq,
      title: opts.title || (danger ? 'Yakin?' : 'Konfirmasi'),
      body: opts.body ?? raw,
      yes: opts.yes || YES[first] || 'Ya',
      no: opts.no || 'Batal',
      danger,
      resolve: (v) => { if (item.done) return; item.done = true; queue = queue.filter((q) => q !== item); emit(); resolve(v) },
    }
    queue.push(item)
    emit()
  })
}

export const subscribeDialog = (fn) => { subs.add(fn); fn(queue[0] || null); return () => subs.delete(fn) }
export const dialogOpen = () => queue.length > 0
// Tombol Back Android: tutup dialog teratas sebagai "Batal". true = back sudah dipakai dialog.
export function dismissDialog() {
  if (!queue.length) return false
  queue[0].resolve(false)
  return true
}
