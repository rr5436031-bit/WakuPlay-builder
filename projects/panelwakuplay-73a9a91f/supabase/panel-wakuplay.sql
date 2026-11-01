-- Panel WakuPlay (APK terpisah) - OPSIONAL tapi disarankan. Jalankan di Supabase -> SQL Editor -> Run (aman diulang).
-- Prasyarat: keamanan-6-panel-developer.sql dan keamanan-7-akses-panel.sql sudah pernah dijalankan (sudah, karena panel di WakuPlay sudah dipakai).
--
-- ATURAN AKSES (semua dicek di SERVER, bukan di aplikasi):
--   1) role di database = 'developer'  DAN
--   2) user_id terdaftar di tabel dev_panel_access (hanya bisa diisi lewat SQL Editor).
-- Akun lain yang login di Panel WakuPlay langsung dikeluarkan oleh aplikasi, dan kalaupun APK dibongkar,
-- semua fungsi dev_* / *_dev_* tetap menolak karena memanggil is_developer() = has_dev_panel() di server.
--
-- File ini hanya menambah satu hal: catatan login panel (siapa & kapan) di tabel dev_audit.
-- Aplikasi tetap jalan walau file ini belum dijalankan (pencatatan gagal diam-diam, akses TIDAK bergantung padanya).

create or replace function public.panel_ping() returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if not public.has_dev_panel() then
    return false;
  end if;
  -- maksimal 1 catatan per 10 menit per akun supaya tabel tidak penuh
  if to_regclass('public.dev_audit') is not null
     and not exists (select 1 from public.dev_audit
                      where actor = auth.uid() and field = 'panel_login' and created_at > now() - interval '10 minutes') then
    insert into public.dev_audit (actor, target, field, old_value, new_value)
    values (auth.uid(), auth.uid(), 'panel_login', null, 'Panel WakuPlay');
  end if;
  return true;
end; $$;
revoke all on function public.panel_ping() from public, anon;
grant execute on function public.panel_ping() to authenticated;

-- Lihat riwayat login panel:
--   select a.created_at, p.seq, p.role from public.dev_audit a left join public.profiles p on p.user_id = a.actor
--    where a.field = 'panel_login' order by a.id desc limit 50;
--
-- Cek siapa saja yang punya akses panel:
--   select a.user_id, p.seq, p.role, a.note, a.granted_at
--     from public.dev_panel_access a left join public.profiles p on p.user_id = a.user_id order by a.granted_at;
