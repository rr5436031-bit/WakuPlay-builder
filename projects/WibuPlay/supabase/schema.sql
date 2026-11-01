-- ============================================================================
-- WibuPlay - skema Supabase (jalankan sekali di SQL Editor)
-- Semua tabel memakai Row Level Security. Tulis ke data sensitif (XP, level,
-- premium, statistik, riwayat) HANYA lewat fungsi server (SECURITY DEFINER).
-- ============================================================================

-- ---------- TABEL ----------

create table if not exists public.profiles (
  id                 uuid primary key references auth.users(id) on delete cascade,
  email              text,
  username           text,
  avatar_url         text,
  level              int    not null default 1,
  xp                 int    not null default 0,
  total_watch_time   bigint not null default 0,   -- detik
  premium_status     boolean not null default false,
  premium_expired_at timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create table if not exists public.watch_history (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null default auth.uid() references auth.users(id) on delete cascade,
  anime_id         text not null,                -- format "sumber:slug"
  anime_title      text not null default '',
  anime_cover      text,
  episode_id       text not null,                -- format "sumber:slug#episode"
  episode_title    text,
  episode_number   text,
  last_position    int  not null default 0,      -- detik
  duration         int  not null default 0,      -- detik
  watched_seconds  int  not null default 0,      -- waktu tonton nyata (dihitung server)
  xp_awarded       boolean not null default false,
  first_watched_at timestamptz not null default now(),
  watched_at       timestamptz not null default now(),
  unique (user_id, episode_id)
);
create index if not exists watch_history_user_time on public.watch_history (user_id, watched_at desc);

create table if not exists public.favorites (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  anime_id    text not null,
  anime_title text not null default '',
  anime_cover text,
  created_at  timestamptz not null default now(),
  unique (user_id, anime_id)
);

create table if not exists public.user_stats (
  user_id                uuid primary key references auth.users(id) on delete cascade,
  total_anime_watched    int    not null default 0,
  total_episodes_watched int    not null default 0,
  total_watch_time       bigint not null default 0,
  total_xp               int    not null default 0,
  updated_at             timestamptz not null default now()
);

create table if not exists public.xp_events (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  source       text not null,
  amount       int  not null,
  reference_id text not null,
  created_at   timestamptz not null default now(),
  unique (user_id, source, reference_id)          -- XP tidak bisa diberikan dua kali
);

create table if not exists public.app_settings (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.premium_packages (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  description   text,
  price_idr     bigint not null default 0,
  duration_days int not null default 30,
  is_active     boolean not null default true,
  sort_order    int not null default 0,
  created_at    timestamptz not null default now()
);

-- token serah-terima APK -> website (hanya hash yang disimpan, berlaku 2 menit, sekali pakai)
create table if not exists public.web_handoff_tokens (
  token_hash text primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  used_at    timestamptz
);

-- ---------- FUNGSI ----------

-- Level dari XP: XP kumulatif untuk level L = 250 * L * (L-1)  (L2=500, L3=1500, L4=3000 ...)
create or replace function public.calc_level(p_xp int) returns int
language sql immutable as $$
  select floor((1 + sqrt(1 + 4.0 * greatest(p_xp, 0) / 250)) / 2)::int
$$;

-- Profil dibuat otomatis saat pengguna pertama kali mendaftar (email dari identitas terverifikasi)
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, username)
  values (new.id, new.email, split_part(coalesce(new.email, 'user'), '@', 1))
  on conflict (id) do nothing;
  insert into public.user_stats (user_id) values (new.id) on conflict (user_id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Cadangan untuk akun lama / jika trigger belum terpasang saat pendaftaran
create or replace function public.ensure_profile() returns void
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  em  text := auth.jwt() ->> 'email';
begin
  if uid is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  insert into public.profiles (id, email, username)
  values (uid, em, split_part(coalesce(em, 'user'), '@', 1))
  on conflict (id) do nothing;
  insert into public.user_stats (user_id) values (uid) on conflict (user_id) do nothing;
end $$;

-- Simpan progres tonton + beri XP. Seluruh validasi di server:
--  * waktu tonton yang dihitung tidak bisa melebihi waktu nyata sejak update terakhir (+5 dtk toleransi)
--  * XP 20 diberikan SEKALI per episode setelah >= 300 detik waktu tonton tercatat
--  * unique (user_id, source, reference_id) mencegah XP ganda
create or replace function public.save_progress(
  p_anime_id text, p_anime_title text, p_anime_cover text,
  p_episode_id text, p_episode_title text, p_episode_number text,
  p_position int, p_duration int, p_delta int
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid      uuid := auth.uid();
  h        public.watch_history%rowtype;
  add_s    int;
  new_ws   int;
  awarded  int := 0;
  n_ins    int;
begin
  if uid is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if p_anime_id is null or p_episode_id is null or length(p_episode_id) > 500 or length(p_anime_id) > 300 then
    raise exception 'invalid input';
  end if;

  insert into public.watch_history (user_id, anime_id, anime_title, anime_cover, episode_id, episode_title, episode_number)
  values (uid, p_anime_id, coalesce(p_anime_title, ''), p_anime_cover, p_episode_id, p_episode_title, p_episode_number)
  on conflict (user_id, episode_id) do nothing;

  select * into h from public.watch_history where user_id = uid and episode_id = p_episode_id for update;

  add_s  := greatest(0, least(coalesce(p_delta, 0), floor(extract(epoch from (now() - h.watched_at)))::int + 5));
  new_ws := h.watched_seconds + add_s;

  update public.watch_history set
    anime_title     = coalesce(nullif(p_anime_title, ''), anime_title),
    anime_cover     = coalesce(p_anime_cover, anime_cover),
    episode_title   = coalesce(p_episode_title, episode_title),
    episode_number  = coalesce(p_episode_number, episode_number),
    last_position   = case when coalesce(p_position, 0) > 0 then p_position else last_position end,
    duration        = case when coalesce(p_duration, 0) > 0 then p_duration else duration end,
    watched_seconds = new_ws,
    watched_at      = now()
  where id = h.id;

  if add_s > 0 then
    update public.profiles set total_watch_time = total_watch_time + add_s, updated_at = now() where id = uid;
    insert into public.user_stats (user_id, total_watch_time) values (uid, add_s)
    on conflict (user_id) do update
      set total_watch_time = public.user_stats.total_watch_time + add_s, updated_at = now();
  end if;

  if not h.xp_awarded and new_ws >= 300 then
    insert into public.xp_events (user_id, source, amount, reference_id)
    values (uid, 'watch_episode', 20, p_episode_id)
    on conflict (user_id, source, reference_id) do nothing;
    get diagnostics n_ins = row_count;

    if n_ins = 1 then
      awarded := 20;
      update public.watch_history set xp_awarded = true where id = h.id;
      update public.profiles
        set xp = xp + 20, level = public.calc_level(xp + 20), updated_at = now()
        where id = uid;
      insert into public.user_stats (user_id) values (uid) on conflict (user_id) do nothing;
      update public.user_stats set
        total_xp = total_xp + 20,
        total_episodes_watched = total_episodes_watched + 1,
        total_anime_watched = (select count(distinct anime_id) from public.watch_history where user_id = uid and xp_awarded),
        updated_at = now()
      where user_id = uid;
    end if;
  end if;

  return jsonb_build_object('xp_awarded', awarded, 'watched_seconds', new_ws);
end $$;

-- Token serah-terima untuk WebView premium (berlaku 2 menit, sekali pakai)
create or replace function public.create_web_handoff() returns text
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  tok text;
begin
  if uid is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  delete from public.web_handoff_tokens where expires_at < now() or user_id = uid;
  tok := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  insert into public.web_handoff_tokens (token_hash, user_id, expires_at)
  values (encode(sha256(convert_to(tok, 'utf8')), 'hex'), uid, now() + interval '2 minutes');
  return tok;
end $$;

-- Dipanggil BACKEND WEBSITE (service_role) untuk menukar token dengan user_id
create or replace function public.consume_web_handoff(p_token text) returns uuid
language plpgsql security definer set search_path = public as $$
declare uid uuid;
begin
  update public.web_handoff_tokens set used_at = now()
  where token_hash = encode(sha256(convert_to(p_token, 'utf8')), 'hex')
    and used_at is null and expires_at > now()
  returning user_id into uid;
  return uid;
end $$;

-- ---------- RLS ----------

alter table public.profiles           enable row level security;
alter table public.watch_history      enable row level security;
alter table public.favorites          enable row level security;
alter table public.user_stats         enable row level security;
alter table public.xp_events          enable row level security;
alter table public.app_settings       enable row level security;
alter table public.premium_packages   enable row level security;
alter table public.web_handoff_tokens enable row level security;

revoke all on public.profiles, public.watch_history, public.favorites, public.user_stats,
              public.xp_events, public.app_settings, public.premium_packages,
              public.web_handoff_tokens from anon, authenticated;

-- profiles: baca milik sendiri; ubah hanya username & avatar (level/xp/premium tidak bisa diubah klien)
grant select on public.profiles to authenticated;
grant update (username, avatar_url) on public.profiles to authenticated;
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles for select to authenticated using (id = auth.uid());
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- watch_history: baca & hapus milik sendiri; tulis hanya lewat save_progress()
grant select, delete on public.watch_history to authenticated;
drop policy if exists wh_select_own on public.watch_history;
create policy wh_select_own on public.watch_history for select to authenticated using (user_id = auth.uid());
drop policy if exists wh_delete_own on public.watch_history;
create policy wh_delete_own on public.watch_history for delete to authenticated using (user_id = auth.uid());

-- favorites
grant select, insert, delete on public.favorites to authenticated;
drop policy if exists fav_select_own on public.favorites;
create policy fav_select_own on public.favorites for select to authenticated using (user_id = auth.uid());
drop policy if exists fav_insert_own on public.favorites;
create policy fav_insert_own on public.favorites for insert to authenticated with check (user_id = auth.uid());
drop policy if exists fav_delete_own on public.favorites;
create policy fav_delete_own on public.favorites for delete to authenticated using (user_id = auth.uid());

-- user_stats & xp_events: hanya baca milik sendiri
grant select on public.user_stats to authenticated;
drop policy if exists us_select_own on public.user_stats;
create policy us_select_own on public.user_stats for select to authenticated using (user_id = auth.uid());
grant select on public.xp_events to authenticated;
drop policy if exists xe_select_own on public.xp_events;
create policy xe_select_own on public.xp_events for select to authenticated using (user_id = auth.uid());

-- app_settings & premium_packages: baca saja
grant select on public.app_settings to anon, authenticated;
drop policy if exists as_read on public.app_settings;
create policy as_read on public.app_settings for select to anon, authenticated using (true);
grant select on public.premium_packages to authenticated;
drop policy if exists pp_read on public.premium_packages;
create policy pp_read on public.premium_packages for select to authenticated using (is_active);

-- web_handoff_tokens: tanpa policy & tanpa grant => hanya fungsi SECURITY DEFINER yang bisa menyentuh

-- ---------- IZIN FUNGSI ----------
revoke execute on function public.ensure_profile() from public, anon;
grant  execute on function public.ensure_profile() to authenticated;

revoke execute on function public.save_progress(text,text,text,text,text,text,int,int,int) from public, anon;
grant  execute on function public.save_progress(text,text,text,text,text,text,int,int,int) to authenticated;

revoke execute on function public.create_web_handoff() from public, anon;
grant  execute on function public.create_web_handoff() to authenticated;

revoke execute on function public.consume_web_handoff(text) from public, anon, authenticated;
grant  execute on function public.consume_web_handoff(text) to service_role;

-- ---------- DATA AWAL ----------
insert into public.app_settings (key, value) values ('min_app_version', '"1.0.0"')
on conflict (key) do nothing;

-- Paket premium: isi sendiri setelah sistem pembelian di website siap, contoh:
-- insert into public.premium_packages (name, description, price_idr, duration_days, sort_order)
-- values ('Premium 30 Hari', 'Tanpa iklan', 12000, 30, 1);
