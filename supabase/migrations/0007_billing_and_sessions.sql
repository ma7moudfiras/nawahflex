-- ============================================================================
-- تسجيل الحصص (وقت + ملاحظات) ومستحقات المدرّبين والطلاب — قاعدة بيانات فقط
-- ----------------------------------------------------------------------------
-- أربعة مفاهيم منفصلة عمداً:
--   ١. class_sessions   — "حصة" فعلية لفوج بتاريخ معيّن: من/إلى، ملاحظات،
--                          ولقطة سعر ساعة المدرّب وقتها (لا تتغيّر لاحقاً).
--   ٢. trainer_pay_rates + trainer_payout_events — سعر الساعة الحالي للمدرّب
--                          (خاص، لا يُعرض بالموقع أبداً) وسجلّ تسديد شهري.
--   ٣. programs.price/sibling_price — سعر كل برنامج، وسعره بخصم الإخوة.
--   ٤. student_dues + student_payments + student_discount_log — مستحقات
--      الطالب الشهرية ودفعاتها (قد تكون على أكثر من دفعة) وسجلّ تفعيل/
--      إلغاء خصم الإخوة.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- ١. حصص الأفواج — وقت + ملاحظات + لقطة سعر ساعة المدرّب
-- ---------------------------------------------------------------------------
create table if not exists public.class_sessions (
  id                   uuid primary key default gen_random_uuid(),
  cohort_id            uuid not null references public.cohorts(id) on delete cascade,
  session_date         date not null default current_date,
  starts_at            time,
  ends_at              time,
  notes                text,
  -- سعر ساعة المدرّب وقت تسجيل الحصة تحديداً — لقطة ثابتة. تغيير السعر
  -- لاحقاً في trainer_pay_rates لا يمسّ هذا العمود إطلاقاً، فمستحقات
  -- الأشهر الماضية تبقى كما احتُسبت وقتها بالضبط.
  trainer_hourly_rate  numeric(10,2),
  created_by           uuid references public.profiles(id) on delete set null,
  created_at           timestamptz not null default now(),
  check (starts_at is null or ends_at is null or ends_at > starts_at),
  unique (cohort_id, session_date)
);

alter table public.class_sessions enable row level security;

drop policy if exists "class_sessions: staff can read"        on public.class_sessions;
drop policy if exists "class_sessions: trainer logs own cohort" on public.class_sessions;

create policy "class_sessions: staff can read" on public.class_sessions
  for select to authenticated
  using (
    private.is_admin()
    or exists (select 1 from public.cohorts c where c.id = cohort_id and c.trainer_id = auth.uid())
  );

-- المدرّب يسجّل حصص فوجه فقط (نفس نطاق قراءته) — الإدارة بلا قيد.
create policy "class_sessions: trainer logs own cohort" on public.class_sessions
  for all to authenticated
  using (
    private.is_admin()
    or exists (select 1 from public.cohorts c where c.id = cohort_id and c.trainer_id = auth.uid())
  )
  with check (
    private.is_admin()
    or exists (select 1 from public.cohorts c where c.id = cohort_id and c.trainer_id = auth.uid())
  );

-- ربط اختياري بالحصة — إضافي لا يُغيّر شيئاً في attendance الموجودة
-- (cohort_id/student_id/session_date تبقى كما هي، لا كسر لأي كود شاحن).
alter table public.attendance
  add column if not exists session_id uuid references public.class_sessions(id) on delete set null;

create index if not exists attendance_session_idx on public.attendance (session_id);

-- ---------------------------------------------------------------------------
-- ٢. سعر ساعة المدرّب (خاص تماماً) + سجلّ تسديد مستحقاته الشهرية
-- ---------------------------------------------------------------------------
-- ⚠️ عمداً NOT في public.trainers — ذاك الجدول سيرة تسويقية تُقرأ علناً
-- إن كانت منشورة (is_published)، وأي عمود راتب فيه يُسرَّب للزوّار.
create table if not exists public.trainer_pay_rates (
  profile_id   uuid primary key references public.profiles(id) on delete cascade,
  hourly_rate  numeric(10,2) not null check (hourly_rate >= 0),
  updated_at   timestamptz not null default now(),
  updated_by   uuid references public.profiles(id) on delete set null
);

alter table public.trainer_pay_rates enable row level security;

drop policy if exists "trainer_pay_rates: admin only" on public.trainer_pay_rates;
drop policy if exists "trainer_pay_rates: admin write" on public.trainer_pay_rates;
drop policy if exists "trainer_pay_rates: trainer reads own rate" on public.trainer_pay_rates;

create policy "trainer_pay_rates: admin write" on public.trainer_pay_rates
  for all to authenticated using (private.is_admin()) with check (private.is_admin());

-- المدرّب يقرأ سعره الخاص فقط (لا يكتبه) — لازم لتطبيقه نفسه ليلقط سعره
-- الحالي عند تسجيل حصة (class_sessions.trainer_hourly_rate)، وليس تسريباً
-- حقيقياً: هو أصلاً يرى نفس الرقم لاحقاً مضمَّناً بحصصه التي يقرأها.
create policy "trainer_pay_rates: trainer reads own rate" on public.trainer_pay_rates
  for select to authenticated using (profile_id = auth.uid());

-- سجلّ إضافة لا استبدال (audit): كل صفّ حدث "وُسم مسدَّد" أو "أُلغي التسديد"
-- لشهر معيّن لمدرّب معيّن. الحالة الحالية = آخر صفّ لنفس (trainer_id, period_month).
create table if not exists public.trainer_payout_events (
  id            uuid primary key default gen_random_uuid(),
  trainer_id    uuid not null references public.profiles(id) on delete cascade,
  period_month  date not null,
  is_paid       boolean not null,
  changed_by    uuid references public.profiles(id) on delete set null,
  changed_at    timestamptz not null default now()
);

create index if not exists trainer_payout_events_lookup_idx
  on public.trainer_payout_events (trainer_id, period_month, changed_at desc);

alter table public.trainer_payout_events enable row level security;

drop policy if exists "trainer_payout_events: admin only" on public.trainer_payout_events;
create policy "trainer_payout_events: admin only" on public.trainer_payout_events
  for all to authenticated using (private.is_admin()) with check (private.is_admin());

-- ---------------------------------------------------------------------------
-- ٣. سعر كل برنامج + سعره بخصم الإخوة
-- ---------------------------------------------------------------------------
alter table public.programs
  add column if not exists price int not null default 0,
  add column if not exists sibling_price int;

alter table public.programs
  drop constraint if exists programs_sibling_price_check;
alter table public.programs
  add constraint programs_sibling_price_check
  check (sibling_price is null or sibling_price <= price);

-- ---------------------------------------------------------------------------
-- ٤. مستحقات الطالب الشهرية — بالجملة (كل برامجه)، بدفعات، بخصم إخوة اختياري
-- ---------------------------------------------------------------------------
alter table public.students
  add column if not exists sibling_discount boolean not null default false;

-- سجلّ إضافة لتفعيل/إلغاء خصم الإخوة — نفس منطق trainer_payout_events.
create table if not exists public.student_discount_log (
  id            uuid primary key default gen_random_uuid(),
  student_id    uuid not null references public.students(id) on delete cascade,
  enabled       boolean not null,
  changed_by    uuid references public.profiles(id) on delete set null,
  changed_at    timestamptz not null default now()
);

alter table public.student_discount_log enable row level security;
drop policy if exists "student_discount_log: admin only" on public.student_discount_log;
create policy "student_discount_log: admin only" on public.student_discount_log
  for all to authenticated using (private.is_admin()) with check (private.is_admin());

-- صفّ واحد لكل (طالب، شهر) — المبلغ المستحَق لقطة محسوبة وقت الإنشاء
-- (مجموع أسعار برامجه المسجَّل بها وقتها، بعد خصم الإخوة إن كان مفعَّلاً
-- تلك اللحظة). تغيير سعر برنامج لاحقاً لا يمسّ صفوفاً منشأة مسبقاً —
-- نفس مبدأ لقطة سعر ساعة المدرّب أعلاه، لصالح دقّة السجلّ التاريخي.
create table if not exists public.student_dues (
  id                        uuid primary key default gen_random_uuid(),
  student_id                uuid not null references public.students(id) on delete cascade,
  period_month              date not null,
  amount_due                numeric(10,2) not null check (amount_due >= 0),
  sibling_discount_applied  boolean not null default false,
  created_by                uuid references public.profiles(id) on delete set null,
  created_at                timestamptz not null default now(),
  unique (student_id, period_month)
);

alter table public.student_dues enable row level security;
drop policy if exists "student_dues: admin only" on public.student_dues;
create policy "student_dues: admin only" on public.student_dues
  for all to authenticated using (private.is_admin()) with check (private.is_admin());

-- دفعات على صفّ استحقاق — قد تكون أكثر من دفعة لنفس الشهر. كل صفّ هنا
-- هو نفسه سجلّ الحركة المطلوب (متى، مين ضغط زر التسديد عبر recorded_by).
create table if not exists public.student_payments (
  id            uuid primary key default gen_random_uuid(),
  due_id        uuid not null references public.student_dues(id) on delete cascade,
  amount        numeric(10,2) not null check (amount > 0),
  paid_at       timestamptz not null default now(),
  recorded_by   uuid references public.profiles(id) on delete set null,
  note          text,
  created_at    timestamptz not null default now()
);

create index if not exists student_payments_due_idx on public.student_payments (due_id);

alter table public.student_payments enable row level security;
drop policy if exists "student_payments: admin only" on public.student_payments;
create policy "student_payments: admin only" on public.student_payments
  for all to authenticated using (private.is_admin()) with check (private.is_admin());
