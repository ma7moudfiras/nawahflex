-- ============================================================================
-- بوابة أشهر الاحتساب للطالب + سجلّ تاريخي لسعر ساعة المدرّب
-- ----------------------------------------------------------------------------
-- ١. مشكلة حقيقية: شاشة المستحقات كانت تعرض كل الطلاب النشطين لأي شهر
--    يُختار، حتى لو التحق الطالب لاحقاً — فيظهر "غير مسدَّد" لأشهر سابقة
--    لالتحاقه فعلياً. billing_start_month يحدّد أول شهر يُحتسب من أجله،
--    و student_billing_months استثناء صريح لأي شهر بعينه (إجازة طالب
--    ضمن مدى اشتراكه، أو تفعيل شهر قديم قبل بداية الاشتراك لتسجيل دين
--    سابق قبل استعمال النظام).
-- ٢. سعر ساعة المدرّب كان صفاً واحداً قابلاً للاستبدال بلا أثر — يفقد من
--    غيّره ومتى وأي سبب. صار سجلّاً تاريخياً بنفس منطق trainer_payout_events:
--    كل تعديل صفّ جديد، والسعر الحالي هو آخر صفّ.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- ١. بوابة أشهر الاحتساب
-- ---------------------------------------------------------------------------
alter table public.students
  add column if not exists billing_start_month date;

-- الطلاب الحاليون: افتراض معقول هو شهر إنشاء سجلّهم — الإدارة تُصحّحه لاحقاً
-- لتاريخ الالتحاق الحقيقي من نموذج تعديل الطالب.
update public.students
set billing_start_month = date_trunc('month', created_at)::date
where billing_start_month is null;

alter table public.students
  alter column billing_start_month set default date_trunc('month', now())::date;
alter table public.students
  alter column billing_start_month set not null;

-- استثناء صريح لشهر بعينه — يتفوّق على القاعدة الافتراضية (>= billing_start_month)
-- سواء بالتفعيل (دين قديم قبل بداية الاشتراك) أو بالإلغاء (إجازة ضمن مدى الاشتراك).
create table if not exists public.student_billing_months (
  student_id   uuid not null references public.students(id) on delete cascade,
  period_month date not null,
  is_enrolled  boolean not null,
  changed_by   uuid references public.profiles(id) on delete set null,
  changed_at   timestamptz not null default now(),
  primary key (student_id, period_month)
);

alter table public.student_billing_months enable row level security;
drop policy if exists "student_billing_months: admin only" on public.student_billing_months;
create policy "student_billing_months: admin only" on public.student_billing_months
  for all to authenticated using (private.is_admin()) with check (private.is_admin());

-- ---------------------------------------------------------------------------
-- ٢. سجلّ تاريخي لسعر ساعة المدرّب — يحلّ محلّ trainer_pay_rates كصفّ وحيد
-- ---------------------------------------------------------------------------
create table if not exists public.trainer_rate_history (
  id           uuid primary key default gen_random_uuid(),
  profile_id   uuid not null references public.profiles(id) on delete cascade,
  hourly_rate  numeric(10,2) not null check (hourly_rate >= 0),
  reason       text,
  changed_by   uuid references public.profiles(id) on delete set null,
  changed_at   timestamptz not null default now()
);

create index if not exists trainer_rate_history_lookup_idx
  on public.trainer_rate_history (profile_id, changed_at desc);

-- ترحيل أي سعر حالي مضبوط مسبقاً إلى أول صفّ بالسجلّ الجديد.
insert into public.trainer_rate_history (profile_id, hourly_rate, changed_at)
select profile_id, hourly_rate, updated_at from public.trainer_pay_rates;

alter table public.trainer_rate_history enable row level security;

drop policy if exists "trainer_rate_history: admin write" on public.trainer_rate_history;
create policy "trainer_rate_history: admin write" on public.trainer_rate_history
  for all to authenticated using (private.is_admin()) with check (private.is_admin());

-- المدرّب يقرأ سجلّ سعره هو فقط (نفس مبدأ trainer_pay_rates القديم).
drop policy if exists "trainer_rate_history: trainer reads own" on public.trainer_rate_history;
create policy "trainer_rate_history: trainer reads own" on public.trainer_rate_history
  for select to authenticated using (profile_id = auth.uid());

drop table if exists public.trainer_pay_rates;
