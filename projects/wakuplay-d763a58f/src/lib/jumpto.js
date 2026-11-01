import { useCallback, useEffect, useRef } from 'react'
import { fxLow } from './perf'

// Lompat ke pesan yang di-reply (Chat Global, Chat Clan, Lapor/Req).
// Aturan lengkap: PANDUAN-LOMPAT-REPLY.md. Singkatnya:
//  - cari baris lewat atribut data-mid (DOM), bukan lewat state -> tidak memicu render ulang
//  - tidak pernah melempar error; kalau pesan tidak ada -> panggil onMissing()
//  - lepas "lengket ke bawah" dulu (stick.release) supaya scroll tidak ditarik balik
//  - highlight lewat atribut data-flash (React tidak mengelola atribut ini)

const FLASH_MS = 1500
const HOP_VIEWPORTS = 3
const WAIT_MS = 1200

const esc = (s) => {
  try { if (window.CSS && CSS.escape) return CSS.escape(s) } catch { }
  return s.replace(/["\\\]]/g, '')
}
const calm = () => {
  try { return fxLow() || window.matchMedia('(prefers-reduced-motion: reduce)').matches } catch { return false }
}

export function useJumpTo(list, stick, onMissing) {
  const st = useRef({ run: 0, wait: 0, flash: 0, el: null, off: null })
  const miss = useRef(onMissing)
  miss.current = onMissing

  const clearFlash = useCallback(() => {
    const t = st.current
    clearTimeout(t.flash)
    if (t.el) { try { t.el.removeAttribute('data-flash') } catch { } t.el = null }
  }, [])

  const cancelPending = useCallback(() => {
    const t = st.current
    t.run++
    clearTimeout(t.wait)
    if (t.off) { t.off(); t.off = null }
  }, [])

  useEffect(() => () => { cancelPending(); clearFlash() }, [cancelPending, clearFlash])

  return useCallback((id) => {
    try {
      const box = list.current
      if (!box || id == null || id === '') return false
      const el = box.querySelector(`[data-mid="${esc(String(id))}"]`)
      if (!el) { if (miss.current) miss.current(); return false }
      const room = box.clientHeight
      if (room <= 0) return false

      cancelPending()
      clearFlash()
      const t = st.current
      const run = t.run

      const showFlash = () => {
        if (run !== t.run || !el.isConnected) return
        t.off && t.off(); t.off = null
        clearTimeout(t.wait)
        el.removeAttribute('data-flash')
        void el.offsetWidth
        el.setAttribute('data-flash', '1')
        t.el = el
        t.flash = setTimeout(() => { el.removeAttribute('data-flash'); if (t.el === el) t.el = null }, FLASH_MS)
      }

      const b = box.getBoundingClientRect(), r = el.getBoundingClientRect()
      const offset = r.height >= room - 24 ? 12 : (room - r.height) / 2
      const max = Math.max(0, box.scrollHeight - room)
      const top = Math.max(0, Math.min(box.scrollTop + (r.top - b.top) - offset, max))
      const dist = top - box.scrollTop

      if (stick && stick.release) stick.release()

      if (Math.abs(dist) < 2) { showFlash(); return true }

      const smooth = !calm()
      if (smooth && Math.abs(dist) > room * HOP_VIEWPORTS) box.scrollTop = top - Math.sign(dist) * room * HOP_VIEWPORTS
      if (smooth && typeof box.scrollTo === 'function') box.scrollTo({ top, behavior: 'smooth' })
      else box.scrollTop = top

      if (!smooth) { showFlash(); return true }
      // scrollend juga ditembakkan oleh lompatan instan di atas -> abaikan sampai posisi benar-benar sampai.
      const done = () => { if (Math.abs(box.scrollTop - top) <= 3) showFlash() }
      box.addEventListener('scrollend', done)
      t.off = () => box.removeEventListener('scrollend', done)
      t.wait = setTimeout(showFlash, WAIT_MS)
      return true
    } catch { return false }
  }, [list, stick, cancelPending, clearFlash])
}
