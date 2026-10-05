-- ============================================================================
-- 0010 — أداء RLS بلا تغيير في الصلاحيات، فهارس المفاتيح الأجنبية، وجدول
--        أخطاء اللوحة (client_errors).
-- ----------------------------------------------------------------------------
-- ⚠️ هذا الملف لا يغيّر «من يرى ماذا» ولا «من يكتب ماذا». التحقّق: شغّل
--    supabase/tests/rls_visibility.sql قبل الترحيل وبعده — يجب أن تتطابق
--    الأعداد حرفياً لكل دور.
--
-- ما الذي تغيّر ولماذا:
--
-- ١. auth.uid() صارت (select auth.uid()) داخل السياسات. مكتوبةً مباشرة
--    تُنفَّذ مرة لكل صف؛ داخل select يحسبها Postgres مرة واحدة للاستعلام
--    (initplan). النتيجة نفسها، والكلفة ثابتة لا خطية.
-- ٢. فهارس للمفاتيح الأجنبية الأربعة عشر.
-- ٣. search_path فارغ لدالة المدرّب العامة.
-- ٤. جدول client_errors.
--
-- تقسيم سياسات «for all» (تحذيرات multiple_permissive_policies) في 0011.
--
-- طُبِّق على القاعدة على ثلاث دفعات (0010b/0010d/0010e) — المحتوى هنا مطابق.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- auth.uid() داخل (select …) في السياسات الأربع عشرة التي أشار إليها الفاحص.
-- ALTER POLICY لا DROP: التعبير نفسه حرفياً، فقط يُحسب مرة للاستعلام.
-- ---------------------------------------------------------------------------
alter policy "profiles: read own" on public.profiles using (id = (select auth.uid()));
alter policy "profiles: update own" on public.profiles
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()) and role = (select p.role from public.profiles p where p.id = (select auth.uid())));
alter policy "enrollments: staff can read" on public.enrollments
  using (private.is_admin() or exists (select 1 from public.cohorts c where c.id = enrollments.cohort_id and c.trainer_id = (select auth.uid())));
alter policy "enrollments: trainer can move own student" on public.enrollments
  with check (exists (select 1 from public.cohorts c where c.id = enrollments.cohort_id and c.trainer_id = (select auth.uid())) and private.student_enrolled_in_my_cohort(student_id));
alter policy "attendance: trainer can mark" on public.attendance
  using (private.is_admin() or exists (select 1 from public.cohorts c where c.id = attendance.cohort_id and c.trainer_id = (select auth.uid())))
  with check (private.is_admin() or (exists (select 1 from public.cohorts c where c.id = attendance.cohort_id and c.trainer_id = (select auth.uid())) and exists (select 1 from public.enrollments e where e.cohort_id = attendance.cohort_id and e.student_id = attendance.student_id)));
alter policy "attendance: staff can read" on public.attendance
  using (private.is_admin() or exists (select 1 from public.cohorts c where c.id = attendance.cohort_id and c.trainer_id = (select auth.uid())) or private.is_session_co_trainer(session_id));
alter policy "students: staff can read" on public.students
  using (private.is_admin() or exists (select 1 from public.enrollments e join public.cohorts c on c.id = e.cohort_id where e.student_id = students.id and c.trainer_id = (select auth.uid())));
alter policy "student_programs: staff can read" on public.student_programs
  using (private.is_admin() or exists (select 1 from public.enrollments e join public.cohorts c on c.id = e.cohort_id where e.student_id = student_programs.student_id and c.trainer_id = (select auth.uid())));
alter policy "guardian_students: own links" on public.guardian_students
  using (private.is_admin() or guardian_id = (select auth.uid()));
alter policy "class_sessions: trainer logs own cohort" on public.class_sessions
  using (private.is_admin() or exists (select 1 from public.cohorts c where c.id = class_sessions.cohort_id and c.trainer_id = (select auth.uid())))
  with check (private.is_admin() or exists (select 1 from public.cohorts c where c.id = class_sessions.cohort_id and c.trainer_id = (select auth.uid())));
alter policy "class_sessions: staff can read" on public.class_sessions
  using (private.is_admin() or exists (select 1 from public.cohorts c where c.id = class_sessions.cohort_id and c.trainer_id = (select auth.uid())) or private.is_session_co_trainer(id));
alter policy "class_session_trainers: read" on public.class_session_trainers
  using (private.is_admin() or trainer_id = (select auth.uid()) or private.class_session_cohort_owner(session_id));
alter policy "cohorts: staff can read" on public.cohorts
  using (private.is_admin() or trainer_id = (select auth.uid()) or private.is_cohort_co_trainer(id));
alter policy "trainer_rate_history: trainer reads own" on public.trainer_rate_history
  using (profile_id = (select auth.uid()));


-- ---------------------------------------------------------------------------
-- فهارس المفاتيح الأجنبية — حذف صف أب (ملف شخصي، طالب) كان يمسح الجدول
-- الابن كاملاً بحثاً عن الصفوف المرتبطة.
-- ---------------------------------------------------------------------------
create index if not exists attendance_marked_by_idx              on public.attendance (marked_by);
create index if not exists attendance_student_id_idx             on public.attendance (student_id);
create index if not exists class_session_trainers_trainer_idx    on public.class_session_trainers (trainer_id);
create index if not exists class_sessions_created_by_idx         on public.class_sessions (created_by);
create index if not exists cohorts_program_id_idx                on public.cohorts (program_id);
create index if not exists guardian_students_student_id_idx      on public.guardian_students (student_id);
create index if not exists student_billing_months_changed_by_idx on public.student_billing_months (changed_by);
create index if not exists student_discount_log_changed_by_idx   on public.student_discount_log (changed_by);
create index if not exists student_discount_log_student_id_idx   on public.student_discount_log (student_id);
create index if not exists student_dues_created_by_idx           on public.student_dues (created_by);
create index if not exists student_payments_recorded_by_idx      on public.student_payments (recorded_by);
create index if not exists trainer_payout_events_changed_by_idx  on public.trainer_payout_events (changed_by);
create index if not exists trainer_rate_history_changed_by_idx   on public.trainer_rate_history (changed_by);
create index if not exists trainers_profile_id_idx               on public.trainers (profile_id);


-- ---------------------------------------------------------------------------
-- دالة المدرّب العامة: search_path فارغ — كل الأسماء داخلها مؤهَّلة بمخططها،
-- فلا يمكن لجدول باسم مشابه في مخطط آخر أن يحلّ محلّ public.students.
-- ---------------------------------------------------------------------------
alter function public.trainer_update_student_note(uuid, text) set search_path = '';


-- ---------------------------------------------------------------------------
-- client_errors — أخطاء اللوحة الحيّة (app/lib/core/error_reporter.dart).
-- كل مسجَّل دخول يكتب تقاريره هو فقط؛ الإدارة وحدها تقرأ. لا تعديل ولا
-- حذف لأحد: التقرير سطر سجلّ. الأطوال مقيّدة كي لا يُستعمل الجدول مخزناً.
-- ---------------------------------------------------------------------------
create table if not exists public.client_errors (
  id bigint generated always as identity primary key,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  message text not null check (char_length(message) <= 500),
  stack text check (char_length(stack) <= 4000),
  url text check (char_length(url) <= 500),
  platform text check (char_length(platform) <= 40),
  created_at timestamptz not null default now()
);

create index if not exists client_errors_created_at_idx on public.client_errors (created_at desc);
create index if not exists client_errors_profile_id_idx on public.client_errors (profile_id);

alter table public.client_errors enable row level security;

create policy "client_errors: insert own" on public.client_errors for insert to authenticated
  with check (profile_id = (select auth.uid()));
create policy "client_errors: admin read" on public.client_errors for select to authenticated
  using ((select private.is_admin()));

revoke all on public.client_errors from anon;
