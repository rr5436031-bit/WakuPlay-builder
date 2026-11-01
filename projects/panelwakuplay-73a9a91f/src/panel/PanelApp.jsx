import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { App as CapApp } from '@capacitor/app'
import { supabase } from '../lib/supabase'
import { signInWithGoogle, signOut } from '../lib/auth'
import { AppCtx } from '../context'
import ErrorBoundary from '../components/ErrorBoundary'
import DevPanel from '../pages/DevPanel'
import { checkDevPanelStrict } from './access'

const RECHECK_MS = 60000

const shell = { minHeight: '100%', height: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 14, padding: 28, textAlign: 'center', color: '#fff', background: '#111214', boxSizing: 'border-box' }
const btn = { padding: '14px 22px', borderRadius: 14, border: 0, background: '#2f86ff', color: '#fff', fontWeight: 800, fontSize: 16, minWidth: 220 }
const btn2 = { ...btn, background: '#ffffff22', fontWeight: 700 }

function Centered({ title, text, children }) {
  return (
    <div style={shell}>
      <b style={{ fontSize: 22, fontFamily: 'var(--font-head, inherit)' }}>{title}</b>
      {text ? <span style={{ opacity: 0.72, fontSize: 14, maxWidth: 300, lineHeight: 1.45, wordBreak: 'break-word' }}>{text}</span> : null}
      {children}
    </div>
  )
}

export default function PanelApp() {
  const [ready, setReady] = useState(false)
  const [session, setSession] = useState(null)
  // 'checking' | 'ok' | 'denied' | 'error'
  const [access, setAccess] = useState('checking')
  const [err, setErr] = useState('')
  const [busy, setBusy] = useState(false)
  const [msg, setMsg] = useState('')
  const alive = useRef(true)
  const uid = session?.user?.id

  useEffect(() => { alive.current = true; return () => { alive.current = false } }, [])

  useEffect(() => {
    if (!supabase) { setReady(true); return }
    supabase.auth.getSession().then(({ data }) => { if (alive.current) { setSession(data.session); setReady(true) } }).catch(() => setReady(true))
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => setSession(s))
    return () => sub.subscription.unsubscribe()
  }, [])

  const leave = useCallback(async (why) => {
    await signOut().catch(() => {})
    if (alive.current) { setSession(null); setAccess('checking'); setMsg(why || '') }
  }, [])

  // Cek akses ke server. HANYA jawaban eksplisit "false" yang mengeluarkan akun.
  // Gangguan jaringan / server -> tetap di sesi, tampilkan "Coba lagi" (tidak membuat panel rusak).
  const check = useCallback(async (silent) => {
    if (!uid) return
    if (!silent) setAccess('checking')
    const r = await checkDevPanelStrict()
    if (!alive.current) return
    if (r === 'ok') { setAccess('ok'); setErr('') }
    else if (r === 'denied') {
      await leave('Akun ini tidak punya akses Panel WakuPlay. Panel hanya untuk developer.')
    } else if (!silent) { setAccess('error'); setErr('Tidak bisa memeriksa akses. Periksa koneksi internet lalu coba lagi.') }
  }, [uid, leave])

  useEffect(() => {
    if (!uid) { setAccess('checking'); return }
    check(false)
    const t = setInterval(() => check(true), RECHECK_MS)
    const onVis = () => { if (document.visibilityState === 'visible') check(true) }
    document.addEventListener('visibilitychange', onVis)
    return () => { clearInterval(t); document.removeEventListener('visibilitychange', onVis) }
  }, [uid, check])

  useEffect(() => {
    let h
    CapApp.addListener('backButton', () => { CapApp.exitApp() }).then((x) => { h = x }).catch(() => {})
    return () => { h && h.remove() }
  }, [])

  const nav = useMemo(() => ({
    back: () => { CapApp.exitApp().catch(() => {}) },
    push: () => {}, tab: () => {}, setGuard: () => {}, minimize: () => {}, closeMini: () => {},
  }), [])

  const login = async () => {
    if (busy) return
    setBusy(true); setMsg('')
    try { await signInWithGoogle() } catch (e) {
      const t = String(e?.message || e || '')
      if (!/cancel|dibatalkan|dismiss/i.test(t)) setMsg(t || 'Login gagal')
    }
    if (alive.current) setBusy(false)
  }

  if (!ready) return <div className="splash" />
  if (!supabase) return <Centered title="Panel WakuPlay" text="Supabase belum dikonfigurasi (.env)." />

  if (!session) {
    return (
      <Centered title="Panel WakuPlay" text="Khusus developer WakuPlay. Masuk dengan akun developer.">
        {msg ? <span style={{ color: '#ff8b95', fontSize: 14, maxWidth: 300, lineHeight: 1.4 }}>{msg}</span> : null}
        <button style={btn} disabled={busy} onClick={login}>{busy ? 'Memproses…' : 'Masuk dengan Google'}</button>
      </Centered>
    )
  }

  if (access === 'checking') return <Centered title="Panel WakuPlay" text="Memeriksa akses…" />
  if (access === 'error') {
    return (
      <Centered title="Panel WakuPlay" text={err}>
        <button style={btn} onClick={() => check(false)}>Coba lagi</button>
        <button style={btn2} onClick={() => leave('')}>Keluar akun</button>
      </Centered>
    )
  }

  return (
    <AppCtx.Provider value={{ user: session.user, nav, focusKey: 0, panel: { signOut: () => leave('') } }}>
      <div className="app">
        <div className="pages" style={{ display: 'flex' }}>
          <div className="tabpage" style={{ display: 'flex' }}>
            <ErrorBoundary><DevPanel /></ErrorBoundary>
          </div>
        </div>
      </div>
    </AppCtx.Provider>
  )
}
