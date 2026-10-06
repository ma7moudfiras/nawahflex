-- ============================================================================
-- كم صفاً يرى كل دور في كل جدول — لقطة تُقارَن قبل أي تعديل على RLS وبعده.
-- ----------------------------------------------------------------------------
-- الاستعمال: شغّله كاملاً (محرّر SQL في Supabase أو execute_sql) قبل
-- الـ migration واحفظ الناتج، ثم شغّله بعدها. أي اختلاف في عدد = تغيّر في
-- الصلاحيات، وليس «تحسين أداء». تعديل أداء صحيح يُبقي الجدول متطابقاً حرفياً.
--
-- المستخدمون يُختارون تلقائياً: أول حساب لكل دور (admin, trainer, parent, viewer)
-- ومعهم الزائر المجهول (anon). لا يُعدَّل أي صف — قراءة فقط.
--
-- ⚠️ لا `truncate` هنا لو شغّلته عبر أداة Supabase في جلسة Claude: تعدّه هادماً
--    فتنتظر تأكيداً حتى المهلة. افتح جلسة جديدة بدل تفريغ الجدول المؤقّت.
-- ============================================================================
create temp table if not exists _rls_vis (who text, tbl text, n bigint);
truncate _rls_vis;

do $$
declare
  actor record;
  t record;
  n bigint;
  acc jsonb := '[]'::jsonb;
begin
  for actor in
    select 'anon' as who, null::uuid as uid
    union all
    select distinct on (role) role, id from public.profiles order by role, id
  loop
    if actor.uid is null then
      perform set_config('role', 'anon', true);
      perform set_config('request.jwt.claims', '{"role":"anon"}', true);
    else
      perform set_config('role', 'authenticated', true);
      perform set_config('request.jwt.claims',
        json_build_object('sub', actor.uid, 'role', 'authenticated')::text, true);
    end if;

    for t in
      select c.relname from pg_class c join pg_namespace s on s.oid = c.relnamespace
      where s.nspname = 'public' and c.relkind = 'r' order by 1
    loop
      begin
        execute format('select count(*) from public.%I', t.relname) into n;
      exception when insufficient_privilege then
        n := -1; -- لا صلاحية SELECT على الجدول إطلاقاً
      end;
      acc := acc || jsonb_build_object('who', actor.who, 'tbl', t.relname, 'n', n);
    end loop;

    perform set_config('role', 'postgres', true);
  end loop;

  insert into _rls_vis
  select e->>'who', e->>'tbl', (e->>'n')::bigint from jsonb_array_elements(acc) e;
end $$;

select tbl,
       max(n) filter (where who = 'anon')    as anon,
       max(n) filter (where who = 'viewer')  as viewer,
       max(n) filter (where who = 'trainer') as trainer,
       max(n) filter (where who = 'parent')  as parent,
       max(n) filter (where who = 'admin')   as admin
from _rls_vis group by tbl order by tbl;
