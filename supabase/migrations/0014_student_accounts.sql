-- ============================================================================
-- 0014 — حساب الطالب: يدخل باسم مستخدم ويرى تقدّمه هو وحده.
-- ----------------------------------------------------------------------------
-- - دور `student` في profiles.
-- - student_accounts: ربط حساب الدخول بسجلّ الطالب (يُنشئه Edge Function
--   «student-account» بـ service_role؛ لا كتابة من العميل إطلاقاً).
-- - الطالب يقرأ: شاراته، مهاراته، مشاريعه، ونقاطه (student_progress)،
--   وبياناته التعريفية (my_student). لا ملاحظات المدرّب (للأهل والفريق)،
--   ولا الحضور التفصيلي، ولا المستحقات.
-- - سياسات 0012 تُوسَّع بـ ALTER POLICY (التعبير نفسه + «أو الطالب نفسه»).
-- ============================================================================

-- ⚠️ drop constraint: إن أوقفته أداة Supabase يُشغَّل من محرّر SQL.
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('admin', 'editor', 'trainer', 'parent', 'student', 'viewer'));


create table if not exists public.student_accounts (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  student_id uuid not null unique references public.students (id) on delete cascade,
  username   text not null unique check (username ~ '^[a-z0-9._]{3,20}$'),
  created_at timestamptz not null default now()
);

alter table public.student_accounts enable row level security;

create policy "student_accounts: admin or self read" on public.student_accounts
  for select to authenticated
  using ((select private.is_admin()) or profile_id = (select auth.uid()));

revoke all on public.student_accounts from anon;


-- السائل هو هذا الطالب نفسه.
create or replace function private.is_self_student(p_student_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.student_accounts a
    where a.student_id = p_student_id and a.profile_id = (select auth.uid())
  );
$$;

revoke all on function private.is_self_student(uuid) from public;
grant execute on function private.is_self_student(uuid) to anon, authenticated;


alter policy "student_badges: read" on public.student_badges
  using (private.teaches_student(student_id) or private.is_guardian_of(student_id) or private.is_self_student(student_id));
alter policy "student_skill_levels: read" on public.student_skill_levels
  using (private.teaches_student(student_id) or private.is_guardian_of(student_id) or private.is_self_student(student_id));
alter policy "student_projects: read" on public.student_projects
  using (private.teaches_student(student_id) or private.is_guardian_of(student_id) or private.is_self_student(student_id));


-- بيانات الطالب التعريفية لنفسه — نفس أعمدة my_children.
create or replace function public.my_student()
returns table (
  id             uuid,
  full_name      text,
  birth_date     date,
  gender         text,
  photo_url      text,
  is_active      boolean,
  created_at     timestamptz,
  program_ids    uuid[],
  program_titles text[]
)
language sql stable security definer set search_path = ''
as $$
  select s.id, s.full_name, s.birth_date, s.gender, s.photo_url, s.is_active, s.created_at,
         coalesce(array_agg(p.id order by p.title) filter (where p.id is not null), '{}'),
         coalesce(array_agg(p.title order by p.title) filter (where p.id is not null), '{}')
  from public.student_accounts a
  join public.students s on s.id = a.student_id
  left join public.student_programs sp on sp.student_id = s.id
  left join public.programs p on p.id = sp.program_id
  where a.profile_id = (select auth.uid())
  group by s.id;
$$;

revoke all on function public.my_student() from public, anon;
grant execute on function public.my_student() to authenticated;


-- النقاط والمستوى: الطالب يرى نفسه أيضاً (التعريف كما في 0012 + is_self_student).
create or replace function public.student_progress(p_student_ids uuid[])
returns table (
  student_id        uuid,
  points            integer,
  level             smallint,
  level_title       text,
  level_min_points  integer,
  next_level_points integer,
  sessions_attended integer,
  sessions_total    integer,
  badges_count      integer,
  projects_count    integer
)
language sql stable security definer set search_path = ''
as $$
  with allowed as (
    select s.id from public.students s
    where s.id = any (p_student_ids)
      and (private.teaches_student(s.id) or private.is_guardian_of(s.id) or private.is_self_student(s.id))
  ),
  att as (
    select a.student_id,
           count(*) filter (where a.status = 'present')::int as present,
           count(*) filter (where a.status = 'late')::int    as late,
           count(*)::int                                     as total
    from public.attendance a join allowed on allowed.id = a.student_id
    group by a.student_id
  ),
  bdg as (
    select sb.student_id, count(*)::int as n, coalesce(sum(b.points), 0)::int as pts
    from public.student_badges sb
    join public.badges b on b.id = sb.badge_id
    join allowed on allowed.id = sb.student_id
    group by sb.student_id
  ),
  prj as (
    select p.student_id, count(*)::int as n
    from public.student_projects p join allowed on allowed.id = p.student_id
    group by p.student_id
  ),
  skl as (
    select l.student_id, coalesce(sum(l.level - 1), 0)::int as steps
    from public.student_skill_levels l join allowed on allowed.id = l.student_id
    group by l.student_id
  ),
  pts as (
    select allowed.id as student_id,
           coalesce(att.present, 0) * 10 + coalesce(att.late, 0) * 5
           + coalesce(bdg.pts, 0) + coalesce(prj.n, 0) * 30 + coalesce(skl.steps, 0) * 15 as points,
           coalesce(att.present, 0) + coalesce(att.late, 0) as attended,
           coalesce(att.total, 0) as total,
           coalesce(bdg.n, 0) as badges,
           coalesce(prj.n, 0) as projects
    from allowed
    left join att on att.student_id = allowed.id
    left join bdg on bdg.student_id = allowed.id
    left join prj on prj.student_id = allowed.id
    left join skl on skl.student_id = allowed.id
  )
  select pts.student_id,
         pts.points,
         cur.level,
         cur.title,
         cur.min_points,
         nxt.min_points,
         pts.attended,
         pts.total,
         pts.badges,
         pts.projects
  from pts
  cross join lateral (
    select l.level, l.title, l.min_points from public.levels l
    where l.min_points <= pts.points order by l.min_points desc limit 1
  ) cur
  left join lateral (
    select l.min_points from public.levels l
    where l.min_points > pts.points order by l.min_points limit 1
  ) nxt on true;
$$;

revoke all on function public.student_progress(uuid[]) from public, anon;
grant execute on function public.student_progress(uuid[]) to authenticated;


-- ---------------------------------------------------------------------------
-- إصلاح قديم وُجد أثناء اختبار الطالب: سياسة «profiles: update» كانت تقرأ
-- profiles من داخل سياسة profiles → «infinite recursion detected» لكل تعديل
-- يقوم به غير المدير على ملفه (حتى تغيير الاسم). القاعدة نفسها لا تتغيّر —
-- لا يغيّر أحد دوره بنفسه — لكن الدور الحالي يُقرأ عبر دالة private تتجاوز RLS.
-- ---------------------------------------------------------------------------
create or replace function private.my_role()
returns text language sql stable security definer set search_path = ''
as $$
  select p.role from public.profiles p where p.id = (select auth.uid());
$$;

revoke all on function private.my_role() from public;
grant execute on function private.my_role() to authenticated;

alter policy "profiles: update" on public.profiles
  using ((select private.is_admin()) or id = (select auth.uid()))
  with check ((select private.is_admin()) or (id = (select auth.uid()) and role = (select private.my_role())));
