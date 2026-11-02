// Edge Function "app-config": memberi aplikasi Web Client ID Google (disimpan sebagai secret).
// Client ID bersifat publik (bukan rahasia kriptografis), tetapi dikelola terpusat di sini.
// Secret: GOOGLE_WEB_CLIENT_ID.  Deploy dengan verify_jwt = false (dipanggil sebelum login).

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};

Deno.serve((req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  const id = Deno.env.get("GOOGLE_WEB_CLIENT_ID") ?? "";
  if (!id) {
    return new Response(JSON.stringify({ error: "GOOGLE_WEB_CLIENT_ID belum diatur" }), {
      status: 500,
      headers: { ...CORS, "Content-Type": "application/json" },
    });
  }
  return new Response(JSON.stringify({ google_web_client_id: id }), {
    headers: { ...CORS, "Content-Type": "application/json", "Cache-Control": "public, max-age=300" },
  });
});
