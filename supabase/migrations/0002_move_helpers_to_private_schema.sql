-- ============================================================================
-- تحصين: نقل الدوال المساعدة خارج المخطط المكشوف
-- ----------------------------------------------------------------------------
-- المشكلة التي كشفها فاحص Supabase الأمني بعد تطبيق 0001:
--   PostgREST يكشف كل دوال مخطط public كنقاط /rest/v1/rpc/*، فكانت
--   is_admin() و handle_new_user() — وكلتاهما SECURITY DEFINER — قابلتين
--   للاستدعاء من أي زائر مجهول. و handle_new_user() دالة مُشغِّل (trigger)
--   لا يجوز استدعاؤها مباشرة أصلاً.
--
-- الحل: مخطط private لا يكشفه PostgREST. الاستدعاءات الداخلية تعمل كما هي.
--
-- ملاحظة مهمة: سياسات RLS تُقيَّم بصلاحيات الدور المستعلِم لا بصلاحيات مالك
-- الجدول، لذلك يجب منح anon و authenticated حق تنفيذ private.is_admin()
-- صراحةً وإلا فشلت كل السياسات التي تستدعيها.
-- ============================================================================

create schema if not exists private;
revoke all on schema private from anon, authenticated;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('admin', 'editor')
  );
$$;

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.email))
  on conflict (id) do nothing;
  return new;
end;
$$;

grant usage on schema private to anon, authenticated;
grant execute on function private.is_admin() to anon, authenticated;

-- ---- إعادة ربط المُشغِّل بالدالة الجديدة ----
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ---- إعادة بناء كل سياسة تستدعي is_admin ----
drop policy if exists "profiles: update own" on public.profiles;
drop policy if exists "profiles: admin all"  on public.profiles;
create policy "profiles: update own" on public.profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid() and role = (select role from public.profiles p where p.id = auth.uid()));
create policy "profiles: admin all" on public.profiles for all to authenticated
  using (private.is_admin()) with check (private.is_admin());

drop policy if exists "messages: admin can read" on public.messages;
create policy "messages: admin can read" on public.messages for all to authenticated
  using (private.is_admin()) with check (private.is_admin());

drop policy if exists "subscribers: admin can read" on public.subscribers;
create policy "subscribers: admin can read" on public.subscribers for all to authenticated
  using (private.is_admin()) with check (private.is_admin());

do $$
declare t text;
begin
  foreach t in array array['programs','events','news','achievements','partners','testimonials','gallery','stats','trainers']
  loop
    execute format('drop policy if exists "%1$s: public read" on public.%1$I', t);
    execute format('drop policy if exists "%1$s: admin write" on public.%1$I', t);
    execute format(
      'create policy "%1$s: public read" on public.%1$I for select to anon, authenticated using (is_published = true or private.is_admin())', t);
    execute format(
      'create policy "%1$s: admin write" on public.%1$I for all to authenticated using (private.is_admin()) with check (private.is_admin())', t);
  end loop;
end $$;

drop policy if exists "media: admin write" on storage.objects;
create policy "media: admin write" on storage.objects
  for all to authenticated
  using (bucket_id = 'media' and private.is_admin())
  with check (bucket_id = 'media' and private.is_admin());

-- ---- إزالة النسختين المكشوفتين ----
drop function if exists public.is_admin();
drop function if exists public.handle_new_user();
