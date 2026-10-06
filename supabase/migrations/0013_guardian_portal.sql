-- ============================================================================
-- 0013 — بوابة ولي الأمر: ما يقرؤه ولي الأمر عن أبنائه، وعبر ماذا.
-- ----------------------------------------------------------------------------
-- إضافي بالكامل: ثلاث دوال، لا تعديل على أي سياسة قائمة.
--
-- لماذا دوال لا سياسات قراءة على الجداول؟ RLS تحمي الصف لا العمود:
--   - students فيه ملاحظات داخلية (notes) وبيانات تواصل ولي الأمر نفسه.
--   - attendance فيه ملاحظات المدرّب (notes) ومن سجّل (marked_by).
--   - student_dues/student_payments فيهما من أنشأ وسجّل.
-- سياسة قراءة لولي الأمر كانت ستكشف كل عمود. الدوال ترجع الأعمدة المقصودة
-- فقط، وتُسقط كل طالب ليس السائل وليّه (private.is_guardian_of).
--
-- التقدّم (شارات، مهارات، ملاحظات «للأهل»، student_progress) يقرؤه ولي الأمر
-- أصلاً عبر سياسات 0012 — لا شيء هنا له.
--
-- الدعوة: Edge Function «invite-guardian» (supabase/functions/) — تحمل
-- service_role على الخادم وحده، تتحقّق أن السائل إدارة، تولّد رابط الدعوة
-- (لا ترسل بريداً: الخطة المجانية لا تراسل إلا فريق المشروع) وتربط الحساب
-- بالطالب في guardian_students.
-- ============================================================================


-- أبناء السائل: البيانات التعريفية فقط، وبرامجهم.
create or replace function public.my_children()
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
  from public.guardian_students g
  join public.students s on s.id = g.student_id
  left join public.student_programs sp on sp.student_id = s.id
  left join public.programs p on p.id = sp.program_id
  where g.guardian_id = (select auth.uid())
  group by s.id
  order by s.full_name;
$$;

-- حضور ابنٍ: التاريخ والحالة فقط (بلا ملاحظات المدرّب ولا من سجّل).
create or replace function public.child_attendance(p_student_id uuid)
returns table (session_date date, status text)
language sql stable security definer set search_path = ''
as $$
  select a.session_date, a.status
  from public.attendance a
  where a.student_id = p_student_id
    and private.is_guardian_of(p_student_id)
  order by a.session_date desc
  limit 200;
$$;

-- مستحقات ابنٍ: الشهر، المطلوب، والمدفوع منه.
create or replace function public.child_dues(p_student_id uuid)
returns table (period_month date, amount_due numeric, amount_paid numeric)
language sql stable security definer set search_path = ''
as $$
  select d.period_month, d.amount_due, coalesce(sum(pay.amount), 0)
  from public.student_dues d
  left join public.student_payments pay on pay.due_id = d.id
  where d.student_id = p_student_id
    and private.is_guardian_of(p_student_id)
  group by d.id
  order by d.period_month desc
  limit 24;
$$;

revoke all on function public.my_children()              from public, anon;
revoke all on function public.child_attendance(uuid)     from public, anon;
revoke all on function public.child_dues(uuid)           from public, anon;
grant execute on function public.my_children()           to authenticated;
grant execute on function public.child_attendance(uuid)  to authenticated;
grant execute on function public.child_dues(uuid)        to authenticated;


-- ---------------------------------------------------------------------------
-- حساب بالبريد ودوره — للدالة invite-guardian وحدها (service_role).
-- تمنعها من توليد رابط دخول لحساب موظّف: لولا هذا الفحص لاستطاع «محرّر»
-- أن يدعو بريد المدير «كولي أمر» فيأخذ رابط دخول باسمه.
-- لا تنفيذ لـ anon ولا authenticated — فلا تُستعمل للتحقّق من وجود بريد.
-- ---------------------------------------------------------------------------
create or replace function public.guardian_account_by_email(p_email text)
returns table (id uuid, role text)
language sql stable security definer set search_path = ''
as $$
  select u.id, coalesce(p.role, 'viewer')
  from auth.users u
  left join public.profiles p on p.id = u.id
  where lower(u.email) = lower(p_email)
  limit 1;
$$;

revoke all on function public.guardian_account_by_email(text) from public, anon, authenticated;
grant execute on function public.guardian_account_by_email(text) to service_role;
