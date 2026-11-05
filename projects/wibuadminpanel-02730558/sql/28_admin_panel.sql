-- ===== 28: PANEL ADMIN (Developer & Admin) =====
-- Jalankan di Supabase SQL Editor SETELAH file 27 WibuPlay. Aman diulang.
--
-- ATURAN STAFF (ditegakkan di server, bukan di APK):
--   * Hanya role can_manage dengan prioritas >= 90 (Developer 100, Admin 90) yang boleh.
--   * Tidak boleh mengubah / memblokir diri sendiri.
--   * Target harus berprioritas LEBIH RENDAH dari pelaku (Developer tidak bisa menyentuh Developer lain).
--   * Role yang bisa diberikan harus berprioritas LEBIH RENDAH dari pelaku.
--   * Batas per aksi: Admin 10.000.000 | Developer 1.000.000.000.000 (WBM). XP maks 2.000.000.000.
--   * Setiap aksi wajib alasan (min 3 karakter) dan tercatat di admin_log (tidak bisa dihapus dari panel).
--   * Tidak ada fungsi yang bisa dihapus lewat panel.

-- ---------- Tabel ----------
create table if not exists public.user_blocks (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  blocked_by uuid references auth.users(id) on delete set null,
  reason     text not null default '' check (char_length(reason) <= 200),
  expires_at timestamptz,                        -- null = permanen
  created_at timestamptz not null default now()
);
alter table public.user_blocks enable row level security;
revoke all on public.user_blocks from anon, authenticated;

create table if not exists public.admin_log (
  id         bigint generated always as identity primary key,
  actor_id   uuid references auth.users(id) on delete set null,
  action     text not null,
  target_id  uuid references auth.users(id) on delete set null,
  detail     text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists admin_log_idx on public.admin_log (id desc);
alter table public.admin_log enable row level security;
revoke all on public.admin_log from anon, authenticated;

-- ---------- Helper internal ----------
create or replace function public.admin_prio(p_uid uuid) returns int
language sql stable security definer set search_path = public as $$
  select coalesce((select r.priority from public.profiles p
                   join public.roles r on r.key = p.role
                   where p.id = p_uid and r.can_manage and r.priority >= 90), 0)
$$;

create or replace function public.admin_require() returns int
language plpgsql stable security definer set search_path = public as $$
declare p int;
begin
  p := public.admin_prio(auth.uid());
  if p < 90 then raise exception 'Akses ditolak: hanya Developer/Admin'; end if;
  return p;
end $$;

create or replace function public.admin_cap(p_prio int) returns bigint
language sql immutable as $$
  select case when p_prio >= 100 then 1000000000000::bigint else 10000000::bigint end
$$;

create or replace function public.admin_reason(p_reason text) returns text
language plpgsql immutable as $$
declare r text := trim(coalesce(p_reason, ''));
begin
  if char_length(r) < 3 then raise exception 'Alasan wajib diisi minimal 3 karakter'; end if;
  return left(r, 200);
end $$;

-- Cari user berdasarkan #ID dan pastikan pelaku boleh menyentuhnya.
create or replace function public.admin_target(p_number bigint) returns uuid
language plpgsql stable security definer set search_path = public as $$
declare uid uuid;
begin
  select id into uid from public.profiles where user_number = p_number;
  if uid is null then raise exception 'ID #% tidak ditemukan', p_number; end if;
  if uid = auth.uid() then raise exception 'Tidak bisa mengubah akun sendiri lewat panel'; end if;
  if public.admin_prio(uid) >= public.admin_prio(auth.uid()) then
    raise exception 'Target setara atau lebih tinggi dari kamu';
  end if;
  return uid;
end $$;

-- Clan milik staff yang setara/lebih tinggi tidak boleh diubah.
create or replace function public.admin_guard_leader(p_leader uuid) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if p_leader <> auth.uid() and public.admin_prio(p_leader) >= public.admin_prio(auth.uid()) then
    raise exception 'Clan dipimpin staff setara atau lebih tinggi';
  end if;
end $$;

create or replace function public.admin_audit(p_action text, p_target uuid, p_detail text) returns void
language sql security definer set search_path = public as $$
  insert into public.admin_log (actor_id, action, target_id, detail)
  values (auth.uid(), p_action, p_target, left(coalesce(p_detail, ''), 300))
$$;

-- Kurva level sama dengan server: XP untuk level L = 25 x (L-1) x (L+8)
create or replace function public.admin_level_for_xp(p_xp bigint) returns int
language plpgsql immutable as $$
declare l int := 1;
begin
  while 25 * l * (l + 9) <= p_xp loop
    l := l + 1;
  end loop;
  return l;
end $$;

-- ---------- Fungsi panel (dipanggil dari APK) ----------
create or replace function public.admin_me() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare p int := public.admin_require(); n bigint; u text; rk text; lb text; cl text;
begin
  select pr.user_number, pr.username, r.key, r.label, r.color into n, u, rk, lb, cl
  from public.profiles pr left join public.roles r on r.key = pr.role
  where pr.id = auth.uid();
  return jsonb_build_object('number', n, 'username', u, 'role', rk, 'label', lb, 'color', cl, 'priority', p);
end $$;

create or replace function public.admin_roles() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare p int := public.admin_require();
begin
  return coalesce((select jsonb_agg(jsonb_build_object('key', key, 'label', label, 'color', color, 'priority', priority)
                                    order by priority desc)
                   from public.roles where priority < p), '[]'::jsonb);
end $$;

create or replace function public.admin_search_users(p_q text default '') returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare res jsonb; q text := trim(coalesce(p_q, ''));
begin
  perform public.admin_require();
  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into res from (
    select p.user_number as number, p.username, p.email, p.role, p.level, p.xp, p.wbm,
           p.premium_status as premium,
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

create or replace function public.admin_set_role(p_number bigint, p_role text, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare me int := public.admin_require(); uid uuid := public.admin_target(p_number); np int; rs text := public.admin_reason(p_reason);
begin
  if p_role is not null then
    select priority into np from public.roles where key = p_role;
    if np is null then raise exception 'Role tidak dikenal'; end if;
    if np >= me then raise exception 'Kamu tidak bisa memberi role setara atau lebih tinggi dari role kamu'; end if;
  end if;
  update public.profiles set role = p_role where id = uid;
  perform public.admin_audit('set_role', uid, coalesce(p_role, 'dicabut') || ' | ' || rs);
  return format('#%s sekarang role: %s', p_number, coalesce(p_role, 'tanpa role'));
end $$;

create or replace function public.admin_grant_wbm(p_number bigint, p_amount bigint, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare me int := public.admin_require(); uid uuid := public.admin_target(p_number); nb bigint; rs text := public.admin_reason(p_reason);
begin
  if p_amount is null or p_amount = 0 then raise exception 'Jumlah WBM tidak boleh 0'; end if;
  if abs(p_amount) > public.admin_cap(me) then raise exception 'Melebihi batas per aksi (%)', public.admin_cap(me); end if;
  nb := public.wbm_adjust(uid, p_amount, 'Admin: ' || rs);   -- gagal bila saldo tidak cukup
  perform public.admin_audit('wbm', uid, p_amount || ' WBM | ' || rs);
  return format('#%s sekarang punya %s WBM', p_number, nb);
end $$;

create or replace function public.admin_set_xp(p_number bigint, p_xp bigint, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare me int := public.admin_require(); uid uuid := public.admin_target(p_number); lv int; rs text := public.admin_reason(p_reason);
        cap bigint := least(public.admin_cap(me), 2000000000);
begin
  if p_xp is null or p_xp < 0 or p_xp > cap then raise exception 'XP harus 0..%', cap; end if;
  lv := public.admin_level_for_xp(p_xp);
  update public.profiles set xp = p_xp::int, level = lv where id = uid;
  perform public.admin_audit('set_xp', uid, 'XP=' || p_xp || ' LV=' || lv || ' | ' || rs);
  return format('#%s sekarang XP %s, Level %s', p_number, p_xp, lv);
end $$;

create or replace function public.admin_block(p_number bigint, p_hours int, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare uid uuid; rs text := public.admin_reason(p_reason); ex timestamptz; dur text;
begin
  perform public.admin_require();
  uid := public.admin_target(p_number);
  if p_hours is not null and (p_hours < 1 or p_hours > 87600) then
    raise exception 'Durasi harus 1..87600 jam (kosong = permanen)';
  end if;
  ex := case when p_hours is null then null else now() + make_interval(hours => p_hours) end;
  dur := case when p_hours is null then 'permanen' else p_hours || ' jam' end;
  insert into public.user_blocks (user_id, blocked_by, reason, expires_at)
  values (uid, auth.uid(), rs, ex)
  on conflict (user_id) do update
    set blocked_by = excluded.blocked_by, reason = excluded.reason,
        expires_at = excluded.expires_at, created_at = now();
  perform public.admin_audit('block', uid, dur || ' | ' || rs);
  return format('#%s diblokir (%s)', p_number, dur);
end $$;

create or replace function public.admin_unblock(p_number bigint, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare uid uuid; rs text;
begin
  perform public.admin_require();
  uid := public.admin_target(p_number);
  rs := public.admin_reason(p_reason);
  delete from public.user_blocks where user_id = uid;
  perform public.admin_audit('unblock', uid, rs);
  return format('#%s dibuka blokirnya', p_number);
end $$;

create or replace function public.admin_list_blocks() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare res jsonb;
begin
  perform public.admin_require();
  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into res from (
    select p.user_number as number, p.username, b.reason, b.expires_at, b.created_at,
           bp.username as blocked_by
    from public.user_blocks b
    join public.profiles p on p.id = b.user_id
    left join public.profiles bp on bp.id = b.blocked_by
    where b.expires_at is null or b.expires_at > now()
    order by b.created_at desc
    limit 200
  ) x;
  return res;
end $$;

create or replace function public.admin_list_clans(p_q text default '') returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare res jsonb; q text := trim(coalesce(p_q, ''));
begin
  perform public.admin_require();
  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into res from (
    select c.id, c.name, c.tag, c.tier, c.wbm_clan, c.xp, c.slots, c.join_mode,
           (select count(*) from public.clan_members m where m.clan_id = c.id) as members,
           p.user_number as leader_number, p.username as leader_name
    from public.clans c
    join public.profiles p on p.id = c.leader_id
    where not c.archived
      and (q = '' or c.name ilike '%' || q || '%' or c.tag ilike '%' || q || '%' or p.user_number::text = q)
    order by c.xp desc
    limit 100
  ) x;
  return res;
end $$;

create or replace function public.admin_set_clan_wbm(p_clan bigint, p_amount bigint, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare me int := public.admin_require(); c public.clans%rowtype; rs text := public.admin_reason(p_reason);
begin
  select * into c from public.clans where id = p_clan and not archived for update;
  if not found then raise exception 'Clan tidak ditemukan'; end if;
  perform public.admin_guard_leader(c.leader_id);
  if p_amount is null or p_amount < 0 or p_amount > public.admin_cap(me) then
    raise exception 'WBM Clan harus 0..%', public.admin_cap(me);
  end if;
  update public.clans set wbm_clan = p_amount where id = p_clan;   -- tanpa setor, langsung set saldo
  perform public.admin_audit('clan_wbm', c.leader_id, c.name || ': ' || c.wbm_clan || ' -> ' || p_amount || ' | ' || rs);
  return format('WBM Clan %s sekarang %s', c.name, p_amount);
end $$;

create or replace function public.admin_set_clan_tier(p_clan bigint, p_tier int, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare c public.clans%rowtype; rs text;
begin
  perform public.admin_require();
  rs := public.admin_reason(p_reason);
  select * into c from public.clans where id = p_clan and not archived for update;
  if not found then raise exception 'Clan tidak ditemukan'; end if;
  perform public.admin_guard_leader(c.leader_id);
  if p_tier is null or p_tier < 1 or p_tier > 30 then raise exception 'Tier harus 1..30'; end if;
  update public.clans set tier = p_tier where id = p_clan;
  perform public.admin_audit('clan_tier', c.leader_id, c.name || ': tier ' || c.tier || ' -> ' || p_tier || ' | ' || rs);
  return format('Tier %s sekarang %s', c.name, p_tier);
end $$;

create or replace function public.admin_rename_clan(p_clan bigint, p_name text, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare c public.clans%rowtype; n text := trim(coalesce(p_name, '')); rs text;
begin
  perform public.admin_require();
  rs := public.admin_reason(p_reason);
  if char_length(n) < 3 or char_length(n) > 24 then raise exception 'Nama clan harus 3-24 karakter'; end if;
  select * into c from public.clans where id = p_clan and not archived for update;
  if not found then raise exception 'Clan tidak ditemukan'; end if;
  perform public.admin_guard_leader(c.leader_id);
  if exists (select 1 from public.clans where lower(name) = lower(n) and not archived and id <> p_clan) then
    raise exception 'Nama itu sudah dipakai clan lain';
  end if;
  update public.clans set name = n where id = p_clan;
  perform public.admin_audit('clan_rename', c.leader_id, c.name || ' -> ' || n || ' | ' || rs);
  return format('Nama clan diganti jadi %s', n);
end $$;

create or replace function public.admin_server_info() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare res jsonb; st jsonb := jsonb_build_object('objects', null, 'bytes', null);
begin
  perform public.admin_require();
  begin
    select jsonb_build_object('objects', count(*), 'bytes', coalesce(sum((metadata->>'size')::bigint), 0))
      into st from storage.objects;
  exception when others then
    st := jsonb_build_object('objects', null, 'bytes', null);
  end;
  select jsonb_build_object(
    'server_time', now(),
    'pg_version', current_setting('server_version'),
    'db_bytes', pg_database_size(current_database()),
    'storage', st,
    'users', (select count(*) from public.profiles),
    'new_users_7d', (select count(*) from public.profiles where created_at > now() - interval '7 days'),
    'premium_active', (select count(*) from public.profiles
                       where premium_status and (premium_expired_at is null or premium_expired_at > now())),
    'clans', (select count(*) from public.clans where not archived),
    'clan_members', (select count(*) from public.clan_members),
    'chat_messages', (select count(*) from public.chat_messages),
    'comments', (select count(*) from public.comments),
    'watch_rows', (select count(*) from public.watch_history),
    'wbm_total', (select coalesce(sum(wbm), 0) from public.profiles),
    'blocks_active', (select count(*) from public.user_blocks where expires_at is null or expires_at > now()),
    'admin_actions_24h', (select count(*) from public.admin_log where created_at > now() - interval '1 day'),
    'tables', (select coalesce(jsonb_agg(to_jsonb(t) order by t.bytes desc), '[]'::jsonb) from (
                 select s.relname as name, pg_total_relation_size(s.relid) as bytes, s.n_live_tup as row_count
                 from pg_stat_user_tables s
                 where s.schemaname = 'public'
                 order by 2 desc
                 limit 12) t)
  ) into res;
  return res;
end $$;

create or replace function public.admin_logs(p_limit int default 50) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare res jsonb;
begin
  perform public.admin_require();
  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into res from (
    select l.id, l.created_at, a.user_number as actor_number, a.username as actor, l.action,
           t.user_number as target_number, t.username as target, l.detail
    from public.admin_log l
    left join public.profiles a on a.id = l.actor_id
    left join public.profiles t on t.id = l.target_id
    order by l.id desc
    limit least(greatest(coalesce(p_limit, 50), 1), 200)
  ) x;
  return res;
end $$;

-- Dipakai aplikasi WibuPlay untuk tahu apakah akun sedang diblokir (semua user boleh memanggil untuk dirinya sendiri).
create or replace function public.my_block_status() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r text; e timestamptz;
begin
  select b.reason, b.expires_at into r, e from public.user_blocks b
  where b.user_id = auth.uid() and (b.expires_at is null or b.expires_at > now());
  if not found then return jsonb_build_object('blocked', false); end if;
  return jsonb_build_object('blocked', true, 'reason', r, 'expires_at', e);
end $$;

-- ---------- Blokir benar-benar berlaku di database ----------
create or replace function public.guard_blocked() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from public.user_blocks b
             where b.user_id = new.user_id and (b.expires_at is null or b.expires_at > now())) then
    raise exception 'Akunmu sedang diblokir, aksi ini tidak bisa dilakukan';
  end if;
  return new;
end $$;

drop trigger if exists chat_guard_blocked on public.chat_messages;
create trigger chat_guard_blocked before insert on public.chat_messages
  for each row execute function public.guard_blocked();

drop trigger if exists comments_guard_blocked on public.comments;
create trigger comments_guard_blocked before insert on public.comments
  for each row execute function public.guard_blocked();

drop trigger if exists clan_members_guard_blocked on public.clan_members;
create trigger clan_members_guard_blocked before insert on public.clan_members
  for each row execute function public.guard_blocked();

-- ---------- Hak akses ----------
revoke all on function public.admin_prio(uuid), public.admin_require(), public.admin_cap(int),
  public.admin_reason(text), public.admin_target(bigint), public.admin_guard_leader(uuid),
  public.admin_audit(text, uuid, text), public.admin_level_for_xp(bigint)
  from public, anon, authenticated;

revoke all on function
  public.admin_me(), public.admin_roles(), public.admin_search_users(text),
  public.admin_set_role(bigint, text, text), public.admin_grant_wbm(bigint, bigint, text),
  public.admin_set_xp(bigint, bigint, text), public.admin_block(bigint, int, text),
  public.admin_unblock(bigint, text), public.admin_list_blocks(), public.admin_list_clans(text),
  public.admin_set_clan_wbm(bigint, bigint, text), public.admin_set_clan_tier(bigint, int, text),
  public.admin_rename_clan(bigint, text, text), public.admin_server_info(), public.admin_logs(int),
  public.my_block_status()
  from public, anon;

grant execute on function
  public.admin_me(), public.admin_roles(), public.admin_search_users(text),
  public.admin_set_role(bigint, text, text), public.admin_grant_wbm(bigint, bigint, text),
  public.admin_set_xp(bigint, bigint, text), public.admin_block(bigint, int, text),
  public.admin_unblock(bigint, text), public.admin_list_blocks(), public.admin_list_clans(text),
  public.admin_set_clan_wbm(bigint, bigint, text), public.admin_set_clan_tier(bigint, int, text),
  public.admin_rename_clan(bigint, text, text), public.admin_server_info(), public.admin_logs(int),
  public.my_block_status()
  to authenticated;
