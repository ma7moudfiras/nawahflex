-- ============================================================================
-- ربط الطالب بالبرنامج — تسجيل "عريض" من شاشة الطلاب مباشرة
-- ----------------------------------------------------------------------------
-- تمييز متعمَّد عن enrollments/cohorts (0004): تلك تربط الطالب بفوج محدَّد
-- (مدرّب + جدول زمني) لغرض الحضور، وهي طبقة أدقّ لم تُبنَ واجهتها بعد.
-- هذا الجدول أبسط: "الطالب مسجَّل ببرنامج X" بلا حاجة لوجود فوج أصلاً —
-- يُستعمل مباشرة من نموذج إضافة/تعديل الطالب (اختيار متعدد).
-- ============================================================================

alter table public.programs
  add constraint programs_age_range_check
  check (age_min is null or age_max is null or age_max >= age_min);

create table if not exists public.student_programs (
  student_id  uuid not null references public.students(id) on delete cascade,
  program_id  uuid not null references public.programs(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (student_id, program_id)
);

create index if not exists student_programs_program_idx on public.student_programs (program_id);

alter table public.student_programs enable row level security;

drop policy if exists "student_programs: staff can read"  on public.student_programs;
drop policy if exists "student_programs: admin can write" on public.student_programs;

-- نفس نطاق رؤية الطالب نفسه: الإدارة تشوف الكل، والمدرّب يشوف فقط طلاب أفواجه.
create policy "student_programs: staff can read" on public.student_programs
  for select to authenticated
  using (
    private.is_admin()
    or exists (
      select 1 from public.enrollments e
      join public.cohorts c on c.id = e.cohort_id
      where e.student_id = student_programs.student_id and c.trainer_id = auth.uid()
    )
  );

-- الكتابة إدارة فقط — تسجيل الطالب ببرنامج يبقى قراراً إدارياً لا صلاحية مدرّب
-- (المدرّب صلاحيته محصورة بالحضور وملاحظة الطالب فقط، حسب القرار المتَّخذ).
create policy "student_programs: admin can write" on public.student_programs
  for all to authenticated
  using (private.is_admin()) with check (private.is_admin());
