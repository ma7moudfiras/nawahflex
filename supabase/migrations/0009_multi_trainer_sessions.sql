-- ============================================================================
-- مدرّب مساعد باللقاء (co-trainer) + نقل طالب بين أفواج المدرّب نفسه
-- ----------------------------------------------------------------------------
-- ١. مدرّب مساعد: قد يحضر مدرّب آخر لقاءً بفوج ليس فوجه — يجب أن يُحتسب له
--    الوقت أجراً، وأن يظهر اللقاء في سجلّ لقاءاته هو أيضاً. class_session_trainers
--    جدول ربط لهذا وحده — لا يُغيّر "مدرّب الفوج" الأساسي في cohorts.trainer_id.
--    سعر ساعة المدرّب المساعد يُلتقَط تلقائياً (trigger) لا من العميل مباشرة،
--    لأن trainer_rate_history يسمح لكل مدرّب بقراءة سعره هو فقط — مسجّل
--    اللقاء (مدرّب الفوج أو الإدارة) لا يملك صلاحية قراءة سعر زميله أصلاً.
-- ٢. رؤية دقيقة: مدرّب مساعد يرى الفوج نفسه (ليقدر يختاره من القائمة)،
--    لكن لا يرى من لقاءات ذلك الفوج وحضورها إلا ما شارك هو به تحديداً —
--    "يرى حصصه فقط لا حصص غيره" حرفياً كما طُلب.
-- ٣. نقل طالب: مدرّب يقدر يضيف لفوجه طالباً موجوداً أصلاً بأحد أفواجه
--    الأخرى (تقوية طالب بجانب معيّن) — لا يقدر يجلب طالباً غريباً كلياً
--    عنه؛ ذاك يبقى عملاً إدارياً بحتاً.
--
-- ⚠️ ملاحظة تصميم مهمّة: أي فحص "هل أنا مدرّب مساعد/شريك بهذا الفوج/اللقاء"
-- يمرّ عبر دالة security definer (مخطط private) تتجاوز RLS داخلياً، ولا
-- يُكتب أبداً كـ EXISTS مباشر بين class_sessions↔class_session_trainers أو
-- enrollments↔enrollments (نفس الجدول) — كلاهما يسبّب infinite recursion
-- لأن كل جدول يستدعي سياسة الآخر أثناء تقييم سياسته هو، بلا نهاية.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- ١. جدول المدرّبين المساعدين لكل لقاء
-- ---------------------------------------------------------------------------
create table if not exists public.class_session_trainers (
  session_id   uuid not null references public.class_sessions(id) on delete cascade,
  trainer_id   uuid not null references public.profiles(id) on delete cascade,
  hourly_rate  numeric(10,2),
  created_at   timestamptz not null default now(),
  primary key (session_id, trainer_id)
);

create or replace function private.snapshot_class_session_trainer_rate()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.hourly_rate is null then
    select hourly_rate into new.hourly_rate
    from public.trainer_rate_history
    where profile_id = new.trainer_id
    order by changed_at desc
    limit 1;
  end if;
  return new;
end;
$$;

drop trigger if exists class_session_trainers_snapshot_rate on public.class_session_trainers;
create trigger class_session_trainers_snapshot_rate
  before insert on public.class_session_trainers
  for each row execute function private.snapshot_class_session_trainer_rate();

alter table public.class_session_trainers enable row level security;

-- ---------------------------------------------------------------------------
-- دوال مساعدة (private) — كل فحص عابر بين الجداول المتشابكة يمرّ من هنا
-- ---------------------------------------------------------------------------
create or replace function private.class_session_cohort_owner(p_session_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.class_sessions cs
    join public.cohorts c on c.id = cs.cohort_id
    where cs.id = p_session_id and c.trainer_id = auth.uid()
  );
$$;
grant execute on function private.class_session_cohort_owner(uuid) to authenticated;

create or replace function private.is_session_co_trainer(p_session_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.class_session_trainers cst
    where cst.session_id = p_session_id and cst.trainer_id = auth.uid()
  );
$$;
grant execute on function private.is_session_co_trainer(uuid) to authenticated;

create or replace function private.is_cohort_co_trainer(p_cohort_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.class_session_trainers cst
    join public.class_sessions cs on cs.id = cst.session_id
    where cs.cohort_id = p_cohort_id and cst.trainer_id = auth.uid()
  );
$$;
grant execute on function private.is_cohort_co_trainer(uuid) to authenticated;

create or replace function private.student_enrolled_in_my_cohort(p_student_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.enrollments e2
    join public.cohorts c2 on c2.id = e2.cohort_id
    where e2.student_id = p_student_id and c2.trainer_id = auth.uid()
  );
$$;
grant execute on function private.student_enrolled_in_my_cohort(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- سياسات class_session_trainers
-- ---------------------------------------------------------------------------
drop policy if exists "class_session_trainers: read" on public.class_session_trainers;
create policy "class_session_trainers: read" on public.class_session_trainers
  for select to authenticated
  using (
    private.is_admin()
    or trainer_id = auth.uid()
    or private.class_session_cohort_owner(session_id)
  );

-- الكتابة: الإدارة، أو مدرّب الفوج الأساسي لتلك الحصة (هو من يقرّر شركاءه).
drop policy if exists "class_session_trainers: write" on public.class_session_trainers;
create policy "class_session_trainers: write" on public.class_session_trainers
  for all to authenticated
  using (private.is_admin() or private.class_session_cohort_owner(session_id))
  with check (private.is_admin() or private.class_session_cohort_owner(session_id));

-- ---------------------------------------------------------------------------
-- ٢. توسيع رؤية الفوج/اللقاءات/الحضور للمدرّب المساعد
-- ---------------------------------------------------------------------------
drop policy if exists "cohorts: staff can read" on public.cohorts;
create policy "cohorts: staff can read" on public.cohorts
  for select to authenticated
  using (
    private.is_admin()
    or trainer_id = auth.uid()
    or private.is_cohort_co_trainer(id)
  );

drop policy if exists "class_sessions: staff can read" on public.class_sessions;
create policy "class_sessions: staff can read" on public.class_sessions
  for select to authenticated
  using (
    private.is_admin()
    or exists (select 1 from public.cohorts c where c.id = class_sessions.cohort_id and c.trainer_id = auth.uid())
    or private.is_session_co_trainer(id)
  );

-- الحضور: دقّة على مستوى اللقاء نفسه (session_id) لا الفوج كاملاً — مدرّب
-- مساعد بلقاء واحد لا يرى حضور بقيّة لقاءات ذلك الفوج.
drop policy if exists "attendance: staff can read" on public.attendance;
create policy "attendance: staff can read" on public.attendance
  for select to authenticated
  using (
    private.is_admin()
    or exists (select 1 from public.cohorts c where c.id = attendance.cohort_id and c.trainer_id = auth.uid())
    or private.is_session_co_trainer(attendance.session_id)
  );

-- ---------------------------------------------------------------------------
-- ٣. نقل طالب: مدرّب يضيف لفوجه طالباً مسجَّلاً أصلاً بأحد أفواجه الأخرى.
--    الإدارة وحدها (السياسة القديمة) تقدر تُدرج أي طالب بأي فوج، وتُبقى
--    قادرة أيضاً على الحذف — هذه سياسة INSERT إضافية للمدرّب فقط.
-- ---------------------------------------------------------------------------
drop policy if exists "enrollments: trainer can move own student" on public.enrollments;
create policy "enrollments: trainer can move own student" on public.enrollments
  for insert to authenticated
  with check (
    exists (select 1 from public.cohorts c where c.id = enrollments.cohort_id and c.trainer_id = auth.uid())
    and private.student_enrolled_in_my_cohort(enrollments.student_id)
  );
