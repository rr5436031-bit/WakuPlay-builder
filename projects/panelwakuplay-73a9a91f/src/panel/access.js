import { supabase } from '../lib/supabase'

// Pemeriksa akses panel (aturan sebenarnya ada di server: fungsi has_dev_panel()).
// Hasil: 'ok' (boleh) | 'denied' (server menjawab TIDAK) | 'error' (tidak bisa memastikan: jaringan/server).
export async function checkDevPanelStrict() {
  if (!supabase) return 'error'
  try {
    const { data, error } = await supabase.rpc('has_dev_panel')
    if (error) {
      const code = String(error.code || '')
      const status = Number(error.status || 0)
      // sesi/token tidak lagi berlaku -> sama dengan tidak punya akses
      if (status === 401 || status === 403 || code === 'PGRST301' || /jwt|not authenticated|permission denied/i.test(String(error.message || ''))) return 'denied'
      return 'error'
    }
    if (data === true) {
      // catatan login panel (opsional; gagal tidak mengganggu apa pun)
      try { if (!window.__wpPanelPing) { window.__wpPanelPing = 1; supabase.rpc('panel_ping').then(() => {}, () => {}) } } catch { }
      return 'ok'
    }
    return 'denied'
  } catch { return 'error' }
}
