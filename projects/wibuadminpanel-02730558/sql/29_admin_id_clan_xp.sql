-- ===== 29: Ubah ID user & XP clan (Developer / Admin) =====
-- Jalankan di Supabase SQL Editor SETELAH 28. Aman diulang.
-- Ubah ID # hanya boleh Developer. ID baru harus 1..2.000.000.000 dan belum dipakai.

create or replace function public.admin_change_user_id(p_old bigint, p_new bigint, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare me int := public.admin_require(); uid uuid; rs text := public.admin_reason(p_reason);
begin
  if me < 100 then raise exception 'Hanya Developer yang bisa mengubah ID'; end if;
  uid := public.admin_target(p_old);
  if p_new is null or p_new < 1 or p_new > 2000000000 then raise exception 'ID baru harus 1..2000000000'; end if;
  if p_new = p_old then raise exception 'ID baru sama dengan ID lama'; end if;
  if exists (select 1 from public.profiles where user_number = p_new) then
    raise exception 'ID #% sudah dipakai', p_new;
  end if;
  update public.profiles set user_number = p_new where id = uid;
  update public.chat_messages set sender_number = p_new where user_id = uid;
  perform public.admin_audit('change_id', uid, '#' || p_old || ' -> #' || p_new || ' | ' || rs);
  return format('ID #%s diganti jadi #%s', p_old, p_new);
end $$;

create or replace function public.admin_set_clan_xp(p_clan bigint, p_xp bigint, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare me int := public.admin_require(); c public.clans%rowtype; rs text := public.admin_reason(p_reason);
begin
  select * into c from public.clans where id = p_clan and not archived for update;
  if not found then raise exception 'Clan tidak ditemukan'; end if;
  perform public.admin_guard_leader(c.leader_id);
  if p_xp is null or p_xp < 0 or p_xp > public.admin_cap(me) then
    raise exception 'XP clan harus 0..%', public.admin_cap(me);
  end if;
  update public.clans set xp = p_xp where id = p_clan;
  perform public.admin_audit('clan_xp', c.leader_id, c.name || ': ' || c.xp || ' -> ' || p_xp || ' | ' || rs);
  return format('XP clan %s sekarang %s', c.name, p_xp);
end $$;

revoke all on function public.admin_change_user_id(bigint, bigint, text), public.admin_set_clan_xp(bigint, bigint, text)
  from public, anon;
grant execute on function public.admin_change_user_id(bigint, bigint, text), public.admin_set_clan_xp(bigint, bigint, text)
  to authenticated;
