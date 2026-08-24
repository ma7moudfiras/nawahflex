-- ============================================================================
-- نواة فليكس — المخطط الأولي لقاعدة البيانات
-- ----------------------------------------------------------------------------
-- المبدأ الأمني: الموقع ثابت ويتصل بالقاعدة بالمفتاح العلني (anon) مباشرة،
-- لذلك كل الحماية تقع على RLS. القاعدة هنا:
--   • الزائر المجهول  → INSERT فقط في (messages, subscribers)، بلا أي SELECT.
--   • الزائر المجهول  → SELECT فقط للمحتوى المنشور (is_published = true).
--   • الإدارة         → كل شيء، عبر الدالة public.is_admin().
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. الأدوار والصلاحيات
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  full_name  text,
  role       text not null default 'viewer'
             check (role in ('admin', 'editor', 'trainer', 'viewer')),
  created_at timestamptz not null default now()
);

comment on table public.profiles is 'ملف المستخدم وصلاحيته — يُنشأ تلقائياً عند التسجيل';

-- security definer كي تتمكن الدالة من قراءة profiles دون الوقوع في حلقة RLS
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('admin', 'editor')
  );
$$;

-- إنشاء ملف تلقائي لكل مستخدم جديد
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.email))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 2. الرسائل الواردة من نموذج التواصل
-- ---------------------------------------------------------------------------
create table if not exists public.messages (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (char_length(name) between 2 and 120),
  phone      text not null check (char_length(phone) between 6 and 32),
  email      text          check (email is null or char_length(email) <= 160),
  interest   text          check (interest is null or char_length(interest) <= 80),
  message    text not null check (char_length(message) between 2 and 4000),
  source     text not null default 'website',
  status     text not null default 'new'
             check (status in ('new', 'in_progress', 'done', 'spam')),
  notes      text,
  created_at timestamptz not null default now()
);

create index if not exists messages_created_idx on public.messages (created_at desc);
create index if not exists messages_status_idx  on public.messages (status);

-- ---------------------------------------------------------------------------
-- 3. المشتركون في النشرة
-- ---------------------------------------------------------------------------
create table if not exists public.subscribers (
  id         uuid primary key default gen_random_uuid(),
  email      text not null unique check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 4. جداول المحتوى — تعكس بنية site/js/content.js حرفياً
--    حالياً المحتوى في ملف JS؛ عند التحويل تُقرأ هذه الجداول عبر site/js/api.js
--    دون أي تغيير في main.js لأن أسماء الحقول متطابقة.
-- ---------------------------------------------------------------------------
create table if not exists public.programs (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  text         text not null,
  icon         text,
  tone         text,
  tags         text[] not null default '{}',
  age_min      int,
  age_max      int,
  sort_order   int  not null default 0,
  is_published boolean not null default true,
  created_at   timestamptz not null default now()
);

create table if not exists public.events (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  description  text,
  starts_at    timestamptz not null,
  place        text,
  time_label   text,
  capacity     int,
  is_free      boolean not null default false,
  is_published boolean not null default true,
  created_at   timestamptz not null default now()
);
create index if not exists events_starts_idx on public.events (starts_at);

create table if not exists public.news (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  excerpt      text,
  body         text,
  category     text,
  cover_url    text,
  published_at date not null default current_date,
  is_published boolean not null default true,
  created_at   timestamptz not null default now()
);
create index if not exists news_published_idx on public.news (published_at desc);

create table if not exists public.achievements (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  text         text,
  year         text,
  image_url    text,
  size         text check (size is null or size in ('hero', 'wide', '')),
  sort_order   int not null default 0,
  is_published boolean not null default true
);

create table if not exists public.partners (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  type         text,
  logo_url     text,
  website      text,
  tone         text,
  sort_order   int not null default 0,
  is_published boolean not null default true
);

create table if not exists public.testimonials (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  role         text,
  text         text not null,
  stars        int  not null default 5 check (stars between 1 and 5),
  tone         text,
  sort_order   int not null default 0,
  is_published boolean not null default true
);

create table if not exists public.gallery (
  id           uuid primary key default gen_random_uuid(),
  caption      text,
  media_url    text not null,
  is_video     boolean not null default false,
  sort_order   int not null default 0,
  is_published boolean not null default true
);

create table if not exists public.stats (
  id           uuid primary key default gen_random_uuid(),
  label        text not null,
  value        int  not null default 0,
  suffix       text default '',
  icon         text,
  sort_order   int not null default 0,
  is_published boolean not null default true
);

-- المدرّبون — تمهيد للوحة التحكم لاحقاً
create table if not exists public.trainers (
  id           uuid primary key default gen_random_uuid(),
  profile_id   uuid references public.profiles(id) on delete set null,
  full_name    text not null,
  title        text,
  bio          text,
  photo_url    text,
  specialties  text[] not null default '{}',
  sort_order   int not null default 0,
  is_published boolean not null default true,
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 5. تفعيل RLS على كل الجداول
-- ---------------------------------------------------------------------------
alter table public.profiles     enable row level security;
alter table public.messages     enable row level security;
alter table public.subscribers  enable row level security;
alter table public.programs     enable row level security;
alter table public.events       enable row level security;
alter table public.news         enable row level security;
alter table public.achievements enable row level security;
alter table public.partners     enable row level security;
alter table public.testimonials enable row level security;
alter table public.gallery      enable row level security;
alter table public.stats        enable row level security;
alter table public.trainers     enable row level security;

-- ---- profiles ----
drop policy if exists "profiles: read own"    on public.profiles;
drop policy if exists "profiles: update own"  on public.profiles;
drop policy if exists "profiles: admin all"   on public.profiles;
create policy "profiles: read own"   on public.profiles for select to authenticated using (id = auth.uid());
create policy "profiles: update own" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid() and role = (select role from public.profiles p where p.id = auth.uid()));
create policy "profiles: admin all"  on public.profiles for all    to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---- messages: الزائر يُرسل فقط، ولا يقرأ شيئاً ----
drop policy if exists "messages: anyone can insert" on public.messages;
drop policy if exists "messages: admin can read"    on public.messages;
create policy "messages: anyone can insert" on public.messages for insert to anon, authenticated with check (true);
create policy "messages: admin can read"    on public.messages for all    to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---- subscribers ----
drop policy if exists "subscribers: anyone can insert" on public.subscribers;
drop policy if exists "subscribers: admin can read"    on public.subscribers;
create policy "subscribers: anyone can insert" on public.subscribers for insert to anon, authenticated with check (true);
create policy "subscribers: admin can read"    on public.subscribers for all    to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---- جداول المحتوى: قراءة عامة للمنشور، وكتابة للإدارة فقط ----
do $$
declare t text;
begin
  foreach t in array array['programs','events','news','achievements','partners','testimonials','gallery','stats','trainers']
  loop
    execute format('drop policy if exists "%1$s: public read" on public.%1$I', t);
    execute format('drop policy if exists "%1$s: admin write" on public.%1$I', t);
    execute format(
      'create policy "%1$s: public read" on public.%1$I for select to anon, authenticated using (is_published = true or public.is_admin())', t);
    execute format(
      'create policy "%1$s: admin write" on public.%1$I for all to authenticated using (public.is_admin()) with check (public.is_admin())', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 6. تخزين الملفات — حاوية عامة للصور
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('media', 'media', true)
on conflict (id) do nothing;

drop policy if exists "media: public read"  on storage.objects;
drop policy if exists "media: admin write"  on storage.objects;
create policy "media: public read" on storage.objects
  for select to anon, authenticated using (bucket_id = 'media');
create policy "media: admin write" on storage.objects
  for all to authenticated
  using (bucket_id = 'media' and public.is_admin())
  with check (bucket_id = 'media' and public.is_admin());
