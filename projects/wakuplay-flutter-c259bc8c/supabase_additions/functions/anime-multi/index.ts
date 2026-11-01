// Edge Function BARU (tidak mengganti anime-api). Proxy ke API eksternal sankavollerei.
// Deploy: supabase functions deploy anime-multi ; set secret: supabase secrets set MULTI_API_BASE=https://www.sankavollerei.web.id
const BASE = (Deno.env.get('MULTI_API_BASE') || '').replace(/\/+$/, '')
const SOURCES = ['animekompi', 'winbu', 'alqanime', 'donghub', 'nimegami']
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Content-Type': 'application/json',
}
const deny = (s: number, e: string) => new Response(JSON.stringify({ error: e }), { status: s, headers: cors })
const cache = new Map<string, { t: number; body: string }>()

function loggedIn(req: Request) {
  try {
    const tok = (req.headers.get('authorization') || '').replace(/^Bearer\s+/i, '')
    const b64 = tok.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')
    const p = JSON.parse(atob(b64 + '='.repeat((4 - (b64.length % 4)) % 4)))
    return p.role === 'authenticated' && !!p.sub
  } catch { return false }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (!BASE) return deny(500, 'MULTI_API_BASE belum diset')
  if (!loggedIn(req)) return deny(401, 'login diperlukan')
  try {
    const { path } = await req.json()
    if (typeof path !== 'string' || path.length > 400 || /[\u0000-\u001f\\#]|\.\./.test(path)) return deny(400, 'path tidak valid')
    const m = path.match(/^\/anime\/([a-z]+)\//)
    if (!m || !SOURCES.includes(m[1])) return deny(400, 'sumber tidak diizinkan')
    const hit = cache.get(path)
    if (hit && Date.now() - hit.t < 60_000) return new Response(hit.body, { status: 200, headers: cors })
    const r = await fetch(BASE + path, { headers: { accept: 'application/json' }, signal: AbortSignal.timeout(20_000) })
    if (!r.ok) return deny(r.status === 404 ? 404 : 502, 'sumber error ' + r.status)
    const body = await r.text()
    if (cache.size > 200) cache.clear()
    cache.set(path, { t: Date.now(), body })
    return new Response(body, { status: 200, headers: cors })
  } catch { return deny(502, 'gagal mengambil sumber') }
})
