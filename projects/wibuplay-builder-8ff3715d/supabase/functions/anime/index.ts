// Edge Function "anime": proxy ke API anime. Alamat API disimpan di secret, bukan di APK.
// Secret yang dipakai:  ANIME_API_BASE (wajib)   ANIME_API_KEY (opsional, dikirim sebagai header x-api-key)
// Deploy dengan verify_jwt = false (token pengguna diperiksa manual di bawah).

const BASE = (Deno.env.get("ANIME_API_BASE") ?? "").replace(/\/+$/, "");
const API_KEY = Deno.env.get("ANIME_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const ANON = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

// Hanya jalur /anime/<sumber>/... yang diizinkan (cegah penyalahgunaan sebagai proxy bebas)
const ALLOW = /^\/anime\/(winbu|animekompi|donghub|alqanime|nimegami)\/[A-Za-z0-9._~\-\/%?=&+\[\]:,*]*$/;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};

const cache = new Map<string, { t: number; status: number; body: string }>();
const TTL_MS = 60_000;

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

async function isLoggedIn(req: Request): Promise<boolean> {
  const auth = req.headers.get("authorization") ?? "";
  if (!auth.toLowerCase().startsWith("bearer ")) return false;
  const r = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { Authorization: auth, apikey: ANON },
  });
  await r.body?.cancel();
  return r.ok;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "GET") return json(405, { error: "method not allowed" });
  if (!BASE) return json(500, { error: "ANIME_API_BASE belum diatur" });
  if (!(await isLoggedIn(req))) return json(401, { error: "login diperlukan" });

  const path = new URL(req.url).searchParams.get("path") ?? "";
  if (!ALLOW.test(path) || path.includes("..")) return json(400, { error: "path tidak diizinkan" });

  const hit = cache.get(path);
  if (hit && Date.now() - hit.t < TTL_MS) {
    return new Response(hit.body, {
      status: hit.status,
      headers: { ...CORS, "Content-Type": "application/json", "X-Cache": "HIT" },
    });
  }

  try {
    const headers: Record<string, string> = { Accept: "application/json", "User-Agent": "WibuPlay-Edge/1.0" };
    if (API_KEY) headers["x-api-key"] = API_KEY;
    const up = await fetch(BASE + path, { headers, signal: AbortSignal.timeout(20_000) });
    const body = await up.text();
    if (up.ok) {
      if (cache.size > 200) cache.clear();
      cache.set(path, { t: Date.now(), status: up.status, body });
    }
    return new Response(body, {
      status: up.status,
      headers: { ...CORS, "Content-Type": up.headers.get("content-type") ?? "application/json", "X-Cache": "MISS" },
    });
  } catch (e) {
    return json(502, { error: "upstream gagal: " + (e instanceof Error ? e.message : String(e)) });
  }
});
