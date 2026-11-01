-- OPSIONAL. Tabel `reports` sengaja tidak bisa dibaca klien (RLS/revoke di keamanan-8-audit.sql).
-- RPC ini hanya mengembalikan data jika pemanggil punya akses developer panel (has_dev_panel()).
-- Pasang manual di Supabase SQL Editor bila ingin melihat laporan dari Developer Panel Flutter.
create or replace function public.dev_reports_list(p_limit int default 100)
returns table (id bigint, user_id uuid, user_name text, anime_id text, episode_id text, reason text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select r.id, r.user_id, public.wp_name(r.user_id), r.anime_id, r.episode_id, r.reason, r.created_at
  from public.reports r
  where public.has_dev_panel()
  order by r.created_at desc
  limit least(greatest(coalesce(p_limit, 100), 1), 200);
$$;
revoke all on function public.dev_reports_list(int) from public, anon;
grant execute on function public.dev_reports_list(int) to authenticated;
