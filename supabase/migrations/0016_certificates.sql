-- ============================================================================
-- 0016 — الشهادات: تصدرها الإدارة، ويتحقّق منها أيّ أحد برقمها.
-- ----------------------------------------------------------------------------
-- - رقم الشهادة `NW-XXXX-XXXX` عشوائي من مصدر تشفيري (٣١^٨ ≈ ٨٥٠ مليار
--   احتمال) — لا تُخمَّن أرقام شهادات الآخرين فتُعرض أسماء أطفال.
-- - الشهادة لا تُحذف؛ تُلغى (revoked_at) فتظهر «ملغاة» في صفحة التحقّق.
-- - من يقرأ: من يدرّس الطالب، وليّه، والطالب نفسه. الإصدار والإلغاء للإدارة.
-- - verify_certificate(code) لـ anon عمداً — صفحة site/verify.html يفتحها رمز QR
--   على الشهادة. ترجع الاسم والعنوان والتاريخ والحالة فقط.
-- ============================================================================

create or replace function private.new_certificate_code()
returns text language plpgsql volatile set search_path = ''
as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; -- بلا O/0 ولا I/1/L
  bytes bytea := extensions.gen_random_bytes(8);
  out text := '';
begin
  for i in 0..7 loop
    out := out || substr(alphabet, (get_byte(bytes, i) % length(alphabet)) + 1, 1);
  end loop;
  return 'NW-' || substr(out, 1, 4) || '-' || substr(out, 5, 4);
end;
$$;

revoke all on function private.new_certificate_code() from public;
grant execute on function private.new_certificate_code() to authenticated;


create table if not exists public.certificates (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique default private.new_certificate_code()
             check (code ~ '^NW-[A-Z0-9]{4}-[A-Z0-9]{4}$'),
  student_id uuid not null references public.students (id) on delete cascade,
  kind       text not null check (kind in ('program', 'level', 'other')),
  title      text not null check (char_length(title) between 1 and 160),
  program_id uuid references public.programs (id) on delete set null,
  level      smallint check (level between 1 and 10),
  issued_by  uuid references public.profiles (id) on delete set null default auth.uid(),
  issued_at  timestamptz not null default now(),
  revoked_at timestamptz
);
create index if not exists certificates_student_id_idx on public.certificates (student_id, issued_at desc);
create index if not exists certificates_program_id_idx on public.certificates (program_id);
create index if not exists certificates_issued_by_idx  on public.certificates (issued_by);

alter table public.certificates enable row level security;

create policy "certificates: read" on public.certificates for select to authenticated
  using (private.teaches_student(student_id) or private.is_guardian_of(student_id) or private.is_self_student(student_id));
create policy "certificates: admin issue" on public.certificates for insert to authenticated
  with check ((select private.is_admin()) and issued_by = (select auth.uid()));
-- الإلغاء فقط: الإدارة تضبط revoked_at؛ لا حذف لأحد.
create policy "certificates: admin revoke" on public.certificates for update to authenticated
  using ((select private.is_admin()))
  with check ((select private.is_admin()));

revoke all on public.certificates from anon;


-- التحقّق العلني: الرقم وحده يكفي، ويرجع أقلّ ما يلزم.
create or replace function public.verify_certificate(p_code text)
returns table (student_name text, title text, issued_at timestamptz, revoked boolean)
language sql stable security definer set search_path = ''
as $$
  select s.full_name, c.title, c.issued_at, c.revoked_at is not null
  from public.certificates c
  join public.students s on s.id = c.student_id
  where c.code = upper(trim(p_code))
  limit 1;
$$;

revoke all on function public.verify_certificate(text) from public;
grant execute on function public.verify_certificate(text) to anon, authenticated;
