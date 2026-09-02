-- ============================================================================
-- الطلاب — سجل بيانات أساسي، بلا ربط بأفواج أو برامج بعد
-- ----------------------------------------------------------------------------
-- عمداً بلا enrollments/cohorts في هذه الدفعة: هذا الجدول أساس مستقل، وربطه
-- بالأفواج والحضور والشهادات يأتي لاحقاً بجداول منفصلة دون تعديل هذا الجدول.
--
-- خصوصية: بيانات الطالب وولي الأمر ليست محتوى عاماً — لا سياسة قراءة عامة
-- هنا إطلاقاً (خلافاً لجداول programs/news وغيرها). القراءة والكتابة
-- للإدارة والمدرّبين فقط عبر private.is_admin() أو private.is_trainer().
-- ============================================================================

create extension if not exists pg_trgm with schema extensions;

create table if not exists public.students (
  id             uuid primary key default gen_random_uuid(),
  full_name      text not null check (char_length(full_name) between 2 and 120),
  birth_date     date,
  gender         text check (gender is null or gender in ('m', 'f')),
  guardian_name  text,
  guardian_phone text,
  guardian_email text,
  notes          text,
  photo_url      text,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index if not exists students_name_idx   on public.students using gin (full_name extensions.gin_trgm_ops);
create index if not exists students_active_idx on public.students (is_active);

-- search_path صريح: بدونه يحذّر فاحص الأمان لأن الدالة قابلة للخداع
-- بتغيير المخطط النشط وقت التنفيذ.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists students_set_updated_at on public.students;
create trigger students_set_updated_at
  before update on public.students
  for each row execute function public.set_updated_at();

alter table public.students enable row level security;

-- دالة مساعدة ثانية إلى جانب private.is_admin() — نفس مبدأ 0002:
-- خارج مخطط public كي لا يكشفها PostgREST كنقطة /rest/v1/rpc/*.
create or replace function private.is_trainer()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'trainer'
  );
$$;
grant execute on function private.is_trainer() to anon, authenticated;

drop policy if exists "students: staff can read"  on public.students;
drop policy if exists "students: admin can write" on public.students;
create policy "students: staff can read" on public.students
  for select to authenticated
  using (private.is_admin() or private.is_trainer());
create policy "students: admin can write" on public.students
  for all to authenticated
  using (private.is_admin()) with check (private.is_admin());
