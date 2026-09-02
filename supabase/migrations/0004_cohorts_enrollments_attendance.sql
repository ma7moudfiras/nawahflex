-- ============================================================================
-- الأفواج والتسجيل والحضور — مرحلة أولى: قاعدة بيانات فقط، بلا واجهة بعد
-- ----------------------------------------------------------------------------
-- الطالب يمكن أن يسجَّل بأكثر من برنامج بنفس الوقت، لذلك enrollments علاقة
-- متعددة-لمتعددة بين students و cohorts لا حقلاً واحداً على الطالب.
--
-- تصحيح لثغرة في سياسة 0003: كانت تمنح كل مدرّب قراءة كل الطلاب. الصحيح:
-- المدرّب يرى فقط طلاب الأفواج التي يدرّبها، عبر enrollments/cohorts.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. الأفواج
-- ---------------------------------------------------------------------------
create table if not exists public.cohorts (
  id             uuid primary key default gen_random_uuid(),
  name           text not null check (char_length(name) between 2 and 120),
  program_id     uuid references public.programs(id) on delete set null,
  trainer_id     uuid references public.profiles(id) on delete set null,
  schedule_label text,
  starts_at      date,
  ends_at        date,
  capacity       int,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now()
);

create index if not exists cohorts_trainer_idx on public.cohorts (trainer_id);

alter table public.cohorts enable row level security;

drop policy if exists "cohorts: staff can read"  on public.cohorts;
drop policy if exists "cohorts: admin can write" on public.cohorts;
create policy "cohorts: staff can read" on public.cohorts
  for select to authenticated
  using (private.is_admin() or trainer_id = auth.uid());
create policy "cohorts: admin can write" on public.cohorts
  for all to authenticated
  using (private.is_admin()) with check (private.is_admin());

-- ---------------------------------------------------------------------------
-- 2. التسجيل — علاقة متعددة-لمتعددة بين الطلاب والأفواج
-- ---------------------------------------------------------------------------
create table if not exists public.enrollments (
  id           uuid primary key default gen_random_uuid(),
  student_id   uuid not null references public.students(id) on delete cascade,
  cohort_id    uuid not null references public.cohorts(id) on delete cascade,
  status       text not null default 'active'
               check (status in ('active', 'paused', 'completed', 'withdrawn')),
  enrolled_at  timestamptz not null default now(),
  unique (student_id, cohort_id)
);

create index if not exists enrollments_student_idx on public.enrollments (student_id);
create index if not exists enrollments_cohort_idx  on public.enrollments (cohort_id);

alter table public.enrollments enable row level security;

drop policy if exists "enrollments: staff can read"  on public.enrollments;
drop policy if exists "enrollments: admin can write" on public.enrollments;
create policy "enrollments: staff can read" on public.enrollments
  for select to authenticated
  using (
    private.is_admin()
    or exists (select 1 from public.cohorts c where c.id = cohort_id and c.trainer_id = auth.uid())
  );
create policy "enrollments: admin can write" on public.enrollments
  for all to authenticated
  using (private.is_admin()) with check (private.is_admin());

-- ---------------------------------------------------------------------------
-- 3. الحضور — يسجّله مدرّب الفوج فقط، لطلاب مسجَّلين فعلاً في ذلك الفوج
-- ---------------------------------------------------------------------------
create table if not exists public.attendance (
  id           uuid primary key default gen_random_uuid(),
  cohort_id    uuid not null references public.cohorts(id) on delete cascade,
  student_id   uuid not null references public.students(id) on delete cascade,
  session_date date not null default current_date,
  status       text not null default 'present'
               check (status in ('present', 'absent', 'late', 'excused')),
  notes        text,
  marked_by    uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now(),
  unique (cohort_id, student_id, session_date)
);

create index if not exists attendance_cohort_date_idx on public.attendance (cohort_id, session_date);

alter table public.attendance enable row level security;

drop policy if exists "attendance: staff can read"   on public.attendance;
drop policy if exists "attendance: trainer can mark"  on public.attendance;

create policy "attendance: staff can read" on public.attendance
  for select to authenticated
  using (
    private.is_admin()
    or exists (select 1 from public.cohorts c where c.id = cohort_id and c.trainer_id = auth.uid())
  );

-- المدرّب يسجّل الحضور فقط لفوجه، ولطالب مسجَّل فعلاً في ذلك الفوج —
-- لا يستطيع اختلاق حضور لطالب غير مسجَّل أو لفوج غيره.
create policy "attendance: trainer can mark" on public.attendance
  for all to authenticated
  using (
    private.is_admin()
    or exists (select 1 from public.cohorts c where c.id = cohort_id and c.trainer_id = auth.uid())
  )
  with check (
    private.is_admin()
    or (
      exists (select 1 from public.cohorts c where c.id = cohort_id and c.trainer_id = auth.uid())
      and exists (select 1 from public.enrollments e where e.cohort_id = attendance.cohort_id and e.student_id = attendance.student_id)
    )
  );

-- ---------------------------------------------------------------------------
-- 4. تصحيح سياسة الطلاب من 0003: المدرّب يرى طلاب أفواجه فقط لا كل الطلاب
-- ---------------------------------------------------------------------------
drop policy if exists "students: staff can read" on public.students;
create policy "students: staff can read" on public.students
  for select to authenticated
  using (
    private.is_admin()
    or exists (
      select 1 from public.enrollments e
      join public.cohorts c on c.id = e.cohort_id
      where e.student_id = students.id and c.trainer_id = auth.uid()
    )
  );

-- دالة عامة (لا خاصة): الغرض منها أن يستدعيها التطبيق مباشرة عبر RPC،
-- خلافاً لـ private.is_admin() التي لا يستدعيها أحد سوى السياسات نفسها.
-- تسمح للمدرّب بتعديل ملاحظات طالبه فقط، دون فتح باقي أعمدة الصف
-- (اسم، بيانات ولي الأمر) التي تبقى بيد الإدارة حصراً.
create or replace function public.trainer_update_student_note(p_student_id uuid, p_note text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not (
    private.is_admin() or exists (
      select 1 from public.enrollments e
      join public.cohorts c on c.id = e.cohort_id
      where e.student_id = p_student_id and c.trainer_id = auth.uid()
    )
  ) then
    raise exception 'not authorized to edit this student';
  end if;

  update public.students set notes = p_note where id = p_student_id;
end;
$$;

-- Supabase يمنح anon تنفيذ الدوال الجديدة في public تلقائياً عبر
-- ALTER DEFAULT PRIVILEGES — REVOKE FROM PUBLIC وحده لا يزيلها، فهي منحة
-- مباشرة للدور anon نفسه ويجب سحبها صراحةً.
revoke all on function public.trainer_update_student_note(uuid, text) from public;
revoke execute on function public.trainer_update_student_note(uuid, text) from anon;
grant execute on function public.trainer_update_student_note(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. أساس حسابات العائلة — جدول ووصف الدور فقط، بلا واجهة أو سياسات قراءة
--    للحضور/الطلاب بعد. تُبنى حين تُبنى واجهة بوابة الأهل، لا قبلها.
-- ---------------------------------------------------------------------------
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('admin', 'editor', 'trainer', 'parent', 'viewer'));

create table if not exists public.guardian_students (
  guardian_id  uuid not null references public.profiles(id) on delete cascade,
  student_id   uuid not null references public.students(id) on delete cascade,
  relationship text,
  created_at   timestamptz not null default now(),
  primary key (guardian_id, student_id)
);

alter table public.guardian_students enable row level security;

drop policy if exists "guardian_students: own links"   on public.guardian_students;
drop policy if exists "guardian_students: admin write" on public.guardian_students;
create policy "guardian_students: own links" on public.guardian_students
  for select to authenticated
  using (private.is_admin() or guardian_id = auth.uid());
create policy "guardian_students: admin write" on public.guardian_students
  for insert to authenticated with check (private.is_admin());
create policy "guardian_students: admin update" on public.guardian_students
  for update to authenticated using (private.is_admin()) with check (private.is_admin());
create policy "guardian_students: admin delete" on public.guardian_students
  for delete to authenticated using (private.is_admin());
