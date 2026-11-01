# Supabase
- Tidak ada tabel/migration baru, RLS tidak diubah.
- Satu tambahan opsional: Edge Function `anime-multi` (supabase_additions/functions/anime-multi/index.ts).
  `supabase functions deploy anime-multi` lalu `supabase secrets set MULTI_API_BASE=https://www.sankavollerei.web.id`.
- `anime-api` lama tetap dipakai oleh LegacyAdapter.
