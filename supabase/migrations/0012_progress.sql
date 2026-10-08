-- ============================================================================
-- 0012 — محرّك التقدّم: المستويات، المهارات، الشارات، المشاريع، ملاحظات المدرّب.
-- ----------------------------------------------------------------------------
-- إضافي بالكامل: جداول ودوال جديدة، لا تعديل على أي سياسة قائمة.
--
-- المستوى (الإطار حول صورة الطالب) يُحسب من النقاط في القاعدة — مصدر حقيقة
-- واحد للّوحة وبوابة الأهل والشهادات لاحقاً. النقاط:
--   حضور ١٠ · تأخّر ٥ · شارة = نقاطها · مشروع ٣٠ · كل درجة مهارة فوق الأولى ١٥
-- عتبات المستويات في جدول `levels` — تعدّلها الإدارة دون كود.
--
-- من يرى ماذا:
--   الإدارة/المحرّر: الكل · المدرّب: طلاب أفواجه · ولي الأمر: أبناؤه فقط
--   (ملاحظات المدرّب المعلَّمة «للأهل» فقط). الكتالوجات (levels/skills/badges)
--   يقرؤها كل مسجَّل — ليست بيانات شخصية.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- دوال الصلاحية — في private (لا تُكشف كـ RPC)، تُستدعى من السياسات.
-- ---------------------------------------------------------------------------
create or replace function private.is_guardian_of(p_student_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.guardian_students g
    where g.student_id = p_student_id and g.guardian_id = (select auth.uid())
  );
$$;

-- يدرّس الطالب: الإدارة، أو مدرّب فوج مسجَّل فيه، أو مدرّب مشارك في فوجه.
create or replace function private.teaches_student(p_student_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select private.is_admin() or exists (
    select 1 from public.enrollments e
    join public.cohorts c on c.id = e.cohort_id
    where e.student_id = p_student_id
      and (c.trainer_id = (select auth.uid()) or private.is_cohort_co_trainer(c.id))
  );
$$;

revoke all on function private.is_guardian_of(uuid)  from public;
revoke all on function private.teaches_student(uuid) from public;
grant execute on function private.is_guardian_of(uuid)  to anon, authenticated;
grant execute on function private.teaches_student(uuid) to anon, authenticated;


-- ---------------------------------------------------------------------------
-- levels — المستويات الخمسة وعتباتها (تُرسم إطاراً حول الصورة).
-- ---------------------------------------------------------------------------
create table if not exists public.levels (
  level      smallint primary key check (level between 1 and 10),
  title      text not null check (char_length(title) between 1 and 40),
  min_points integer not null unique check (min_points >= 0)
);

insert into public.levels (level, title, min_points) values
  (1, 'نواة',   0),
  (2, 'شرارة',  150),
  (3, 'دائرة',  400),
  (4, 'آلة',    800),
  (5, 'مخترع',  1400)
on conflict (level) do nothing;


-- ---------------------------------------------------------------------------
-- skills — مهارات كل برنامج (تضيفها الإدارة)، ودرجة كل طالب فيها (١–٤).
-- ---------------------------------------------------------------------------
create table if not exists public.skills (
  id          uuid primary key default gen_random_uuid(),
  program_id  uuid not null references public.programs (id) on delete cascade,
  title       text not null check (char_length(title) between 1 and 80),
  description text check (char_length(description) <= 300),
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now()
);
create index if not exists skills_program_id_idx on public.skills (program_id);

-- ١ مبتدئ · ٢ متقدّم · ٣ متمكّن · ٤ خبير
create table if not exists public.student_skill_levels (
  student_id uuid not null references public.students (id) on delete cascade,
  skill_id   uuid not null references public.skills (id) on delete cascade,
  level      smallint not null check (level between 1 and 4),
  updated_by uuid references public.profiles (id) on delete set null default auth.uid(),
  updated_at timestamptz not null default now(),
  primary key (student_id, skill_id)
);
create index if not exists student_skill_levels_skill_id_idx   on public.student_skill_levels (skill_id);
create index if not exists student_skill_levels_updated_by_idx on public.student_skill_levels (updated_by);


-- ---------------------------------------------------------------------------
-- badges — كتالوج الشارات (عامة، أو خاصة ببرنامج) · student_badges — المنح.
-- ---------------------------------------------------------------------------
create table if not exists public.badges (
  id          uuid primary key default gen_random_uuid(),
  key         text not null unique check (key ~ '^[a-z0-9_]{2,40}$'),
  title       text not null check (char_length(title) between 1 and 40),
  description text not null check (char_length(description) between 1 and 200),
  icon        text not null default 'star' check (char_length(icon) <= 40),
  points      integer not null default 20 check (points between 0 and 200),
  program_id  uuid references public.programs (id) on delete cascade,
  is_active   boolean not null default true,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now()
);
create index if not exists badges_program_id_idx on public.badges (program_id);

-- كتالوج ابتدائي عام — تعدّله الإدارة أو تضيف إليه. الأيقونة مفتاح يقابله
-- رسم في التطبيق (app/lib/features/progress/badge_icons.dart).
insert into public.badges (key, title, description, icon, points, sort_order) values
  ('first_build',    'أول نموذج',     'أنهى أول نموذج أو روبوت يعمل.',              'build',    20, 1),
  ('problem_solver', 'حلّال المشكلات', 'وجد بنفسه حلاً لعطل أو خطأ في مشروعه.',      'bug',      20, 2),
  ('team_player',    'روح الفريق',    'ساعد زملاءه وقاد عمل مجموعته.',              'team',     20, 3),
  ('presenter',      'المقدِّم',       'عرض مشروعه أمام المجموعة بوضوح وثقة.',        'mic',      20, 4),
  ('persistence',    'المثابرة',      'حضر شهراً كاملاً دون غياب.',                  'calendar', 30, 5),
  ('inventor',       'المبتكر',       'أضاف إلى مشروعه فكرة أصلية لم تُطلب منه.',     'bulb',     30, 6)
on conflict (key) do nothing;

create table if not exists public.student_badges (
  id         uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students (id) on delete cascade,
  badge_id   uuid not null references public.badges (id) on delete cascade,
  awarded_by uuid references public.profiles (id) on delete set null default auth.uid(),
  note       text check (char_length(note) <= 300),
  awarded_at timestamptz not null default now(),
  unique (student_id, badge_id)
);
create index if not exists student_badges_badge_id_idx   on public.student_badges (badge_id);
create index if not exists student_badges_awarded_by_idx on public.student_badges (awarded_by);


-- ---------------------------------------------------------------------------
-- student_projects — ما بناه الطالب · student_notes — ملاحظات المدرّب.
-- ---------------------------------------------------------------------------
create table if not exists public.student_projects (
  id          uuid primary key default gen_random_uuid(),
  student_id  uuid not null references public.students (id) on delete cascade,
  program_id  uuid references public.programs (id) on delete set null,
  title       text not null check (char_length(title) between 1 and 120),
  description text check (char_length(description) <= 1000),
  photo_path  text check (char_length(photo_path) <= 300),
  rating      smallint check (rating between 1 and 5),
  created_by  uuid references public.profiles (id) on delete set null default auth.uid(),
  created_at  timestamptz not null default now()
);
create index if not exists student_projects_student_id_idx on public.student_projects (student_id);
create index if not exists student_projects_program_id_idx on public.student_projects (program_id);
create index if not exists student_projects_created_by_idx on public.student_projects (created_by);

create table if not exists public.student_notes (
  id                  uuid primary key default gen_random_uuid(),
  student_id          uuid not null references public.students (id) on delete cascade,
  author_id           uuid references public.profiles (id) on delete set null default auth.uid(),
  body                text not null check (char_length(body) between 1 and 2000),
  visible_to_guardian boolean not null default true,
  created_at          timestamptz not null default now()
);
create index if not exists student_notes_student_id_idx on public.student_notes (student_id, created_at desc);
create index if not exists student_notes_author_id_idx  on public.student_notes (author_id);


-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.levels               enable row level security;
alter table public.skills               enable row level security;
alter table public.student_skill_levels enable row level security;
alter table public.badges               enable row level security;
alter table public.student_badges       enable row level security;
alter table public.student_projects     enable row level security;
alter table public.student_notes        enable row level security;

-- الكتالوجات: قراءة لكل مسجَّل، كتابة للإدارة.
create policy "levels: read"   on public.levels for select to authenticated using (true);
create policy "levels: admin insert" on public.levels for insert to authenticated with check ((select private.is_admin()));
create policy "levels: admin update" on public.levels for update to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));

create policy "skills: read" on public.skills for select to authenticated using (true);
create policy "skills: admin insert" on public.skills for insert to authenticated with check ((select private.is_admin()));
create policy "skills: admin update" on public.skills for update to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "skills: admin delete" on public.skills for delete to authenticated using ((select private.is_admin()));

create policy "badges: read" on public.badges for select to authenticated using (true);
create policy "badges: admin insert" on public.badges for insert to authenticated with check ((select private.is_admin()));
create policy "badges: admin update" on public.badges for update to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "badges: admin delete" on public.badges for delete to authenticated using ((select private.is_admin()));

-- بيانات الطالب: من يدرّسه يكتب، ومن يدرّسه أو وليّه يقرأ.
create policy "student_skill_levels: read" on public.student_skill_levels for select to authenticated
  using (private.teaches_student(student_id) or private.is_guardian_of(student_id));
create policy "student_skill_levels: teacher insert" on public.student_skill_levels for insert to authenticated
  with check (private.teaches_student(student_id) and updated_by = (select auth.uid()));
create policy "student_skill_levels: teacher update" on public.student_skill_levels for update to authenticated
  using (private.teaches_student(student_id))
  with check (private.teaches_student(student_id) and updated_by = (select auth.uid()));
create policy "student_skill_levels: admin delete" on public.student_skill_levels for delete to authenticated
  using ((select private.is_admin()));

create policy "student_badges: read" on public.student_badges for select to authenticated
  using (private.teaches_student(student_id) or private.is_guardian_of(student_id));
create policy "student_badges: teacher insert" on public.student_badges for insert to authenticated
  with check (private.teaches_student(student_id) and awarded_by = (select auth.uid()));
-- سحب شارة: الإدارة، أو من منحها (تصحيح خطأ).
create policy "student_badges: revoke" on public.student_badges for delete to authenticated
  using ((select private.is_admin()) or (awarded_by = (select auth.uid()) and private.teaches_student(student_id)));

create policy "student_projects: read" on public.student_projects for select to authenticated
  using (private.teaches_student(student_id) or private.is_guardian_of(student_id));
create policy "student_projects: teacher insert" on public.student_projects for insert to authenticated
  with check (private.teaches_student(student_id) and created_by = (select auth.uid()));
create policy "student_projects: author update" on public.student_projects for update to authenticated
  using ((select private.is_admin()) or (created_by = (select auth.uid()) and private.teaches_student(student_id)))
  with check (private.teaches_student(student_id));
create policy "student_projects: author delete" on public.student_projects for delete to authenticated
  using ((select private.is_admin()) or (created_by = (select auth.uid()) and private.teaches_student(student_id)));

create policy "student_notes: read" on public.student_notes for select to authenticated
  using (private.teaches_student(student_id) or (visible_to_guardian and private.is_guardian_of(student_id)));
create policy "student_notes: teacher insert" on public.student_notes for insert to authenticated
  with check (private.teaches_student(student_id) and author_id = (select auth.uid()));
create policy "student_notes: author update" on public.student_notes for update to authenticated
  using ((select private.is_admin()) or (author_id = (select auth.uid()) and private.teaches_student(student_id)))
  with check (private.teaches_student(student_id));
create policy "student_notes: author delete" on public.student_notes for delete to authenticated
  using ((select private.is_admin()) or (author_id = (select auth.uid()) and private.teaches_student(student_id)));

revoke all on public.levels, public.skills, public.student_skill_levels, public.badges,
              public.student_badges, public.student_projects, public.student_notes from anon;


-- ---------------------------------------------------------------------------
-- student_progress(ids) — النقاط والمستوى لعدّة طلاب في طلب واحد.
--
-- SECURITY DEFINER لأن النقاط تجمع الحضور، وولي الأمر لا يقرأ جدول الحضور
-- مباشرة. لذلك تفحص الدالة الصلاحية بنفسها: كل طالب لا يدرّسه السائل ولا هو
-- وليّه يُسقَط من النتيجة بصمت. مكشوفة كـ RPC عمداً (مثل
-- trainer_update_student_note) — للمسجَّلين فقط.
-- ---------------------------------------------------------------------------
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
      and (private.teaches_student(s.id) or private.is_guardian_of(s.id))
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
