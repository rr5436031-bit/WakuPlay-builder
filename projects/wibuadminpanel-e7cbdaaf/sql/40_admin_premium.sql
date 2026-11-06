-- ===== 40: PANEL PREMIUM (Developer & Admin) =====
-- Jalankan di Supabase SQL Editor SETELAH 28 dan 29 (panel) dan SETELAH WibuPlay 38. Aman diulang.
-- Tidak ada tabel/kolom baru. Hanya menambah fungsi dan memperbarui admin_search_users (menambah premium_until).
--
-- Aturan sama dengan fungsi panel lain (ditegakkan di server):
--   * Hanya Developer/Admin (admin_require), tidak bisa mengubah akun sendiri, target harus berprioritas lebih rendah.
--   * Alasan wajib (min 3 karakter), semua aksi tercatat di admin_log.
--   * Batas per aksi: 1..3650 hari.

create or replace function public.admin_set_premium(p_number bigint, p_op text, p_days int, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare
  uid uuid; rs text := public.admin_reason(p_reason);
  cur timestamptz; was boolean; nw timestamptz;
begin
  perform public.admin_require();
  uid := public.admin_target(p_number);

  select coalesce(premium_status and premium_expired_at > now(), false), premium_expired_at
    into was, cur from public.profiles where id = uid for update;

  if p_op = 'cabut' then
    update public.profiles set premium_status = false, premium_expired_at = null where id = uid;
    perform public.admin_audit('premium_cabut', uid, rs);
    return format('Premium #%s dicabut', p_number);
  end if;

  if p_op not in ('tambah', 'kurangi') then raise exception 'Aksi premium tidak dikenal'; end if;
  if p_days is null or p_days < 1 or p_days > 3650 then raise exception 'Jumlah hari harus 1..3650'; end if;

  if p_op = 'tambah' then
    perform public.grant_premium(uid, p_days);     -- sama seperti pembelian: ditambah dari tanggal berakhir (atau dari sekarang)
    select premium_expired_at into nw from public.profiles where id = uid;
    perform public.admin_audit('premium_tambah', uid, '+' || p_days || ' hari | ' || rs);
    return format('#%s premium sampai %s', p_number, to_char(nw at time zone 'Asia/Jakarta', 'DD Mon YYYY HH24:MI'));
  end if;

  -- kurangi
  if not was then raise exception 'Pengguna tidak sedang premium'; end if;
  nw := cur - make_interval(days => p_days);
  if nw <= now() then
    update public.profiles set premium_status = false, premium_expired_at = null where id = uid;
    perform public.admin_audit('premium_kurangi', uid, '-' || p_days || ' hari (habis, dicabut) | ' || rs);
    return format('Premium #%s habis dan dicabut', p_number);
  end if;
  update public.profiles set premium_expired_at = nw where id = uid;
  perform public.admin_audit('premium_kurangi', uid, '-' || p_days || ' hari | ' || rs);
  return format('#%s premium sampai %s', p_number, to_char(nw at time zone 'Asia/Jakarta', 'DD Mon YYYY HH24:MI'));
end $$;

create or replace function public.admin_list_premium() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare res jsonb;
begin
  perform public.admin_require();
  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into res from (
    select p.user_number as number, p.username, p.email, p.premium_expired_at as until
    from public.profiles p
    where p.premium_status and p.premium_expired_at > now()
    order by p.premium_expired_at
    limit 200
  ) x;
  return res;
end $$;

-- Pencarian pengguna: kolom "premium" kini memperhitungkan tanggal berakhir, dan ada premium_until.
create or replace function public.admin_search_users(p_q text default '') returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare res jsonb; q text := trim(coalesce(p_q, ''));
begin
  perform public.admin_require();
  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into res from (
    select p.user_number as number, p.username, p.email, p.role, p.level, p.xp, p.wbm,
           coalesce(p.premium_status and p.premium_expired_at > now(), false) as premium,
           p.premium_expired_at as premium_until,
           (select c.name from public.clan_members m join public.clans c on c.id = m.clan_id
             where m.user_id = p.id) as clan,
           exists (select 1 from public.user_blocks b
                   where b.user_id = p.id and (b.expires_at is null or b.expires_at > now())) as blocked
    from public.profiles p
    where q = '' or p.user_number::text = q or p.username ilike '%' || q || '%' or p.email ilike '%' || q || '%'
    order by p.user_number
    limit 50
  ) x;
  return res;
end $$;

revoke all on function public.admin_set_premium(bigint, text, int, text), public.admin_list_premium() from public, anon;
grant execute on function public.admin_set_premium(bigint, text, int, text), public.admin_list_premium() to authenticated;
