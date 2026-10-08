-- ============================================================================
-- 0015 — صور مشاريع الطلاب: bucket خاص وسياساته.
-- ----------------------------------------------------------------------------
-- المسار: <student_id>/<uuid>.jpg — أول جزء يحدّد الطالب، فتُبنى عليه الصلاحية
-- بنفس دوال الجداول: من يدرّسه يرفع ويحذف؛ من يدرّسه أو وليّه أو هو نفسه يقرأ.
-- خاص (public=false): كل عرض برابط موقّع قصير العمر، لا رابط دائم يُتداول.
-- التطبيق يصغّر الصورة (≤1600px، JPEG) قبل الرفع؛ الحدّ هنا ٥ ميجا احتياطاً.
-- ============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('student-projects', 'student-projects', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

-- معرّف الطالب من مسار الملف، أو null لمسار لا يبدأ بـ uuid — كي لا يرمي
-- التحويل خطأً داخل السياسة لاسم ملف مشوّه.
create or replace function private.project_file_student(p_name text)
returns uuid language sql immutable set search_path = ''
as $$
  select case
    when split_part(p_name, '/', 1) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then split_part(p_name, '/', 1)::uuid
  end;
$$;

revoke all on function private.project_file_student(text) from public;
grant execute on function private.project_file_student(text) to anon, authenticated;

create policy "student-projects: read" on storage.objects for select to authenticated
  using (
    bucket_id = 'student-projects'
    and (private.teaches_student(private.project_file_student(name))
      or private.is_guardian_of(private.project_file_student(name))
      or private.is_self_student(private.project_file_student(name)))
  );

create policy "student-projects: teacher upload" on storage.objects for insert to authenticated
  with check (
    bucket_id = 'student-projects'
    and private.teaches_student(private.project_file_student(name))
  );

create policy "student-projects: teacher delete" on storage.objects for delete to authenticated
  using (
    bucket_id = 'student-projects'
    and private.teaches_student(private.project_file_student(name))
  );

-- 0015b: مسار بلا معرّف طالب صالح يُرفض حتى للإدارة (teaches_student(null)
-- كانت تساوي is_admin() فتقبل «notauuid/x.jpg»).
alter policy "student-projects: teacher upload" on storage.objects
  with check (
    bucket_id = 'student-projects'
    and private.project_file_student(name) is not null
    and private.teaches_student(private.project_file_student(name))
  );

alter policy "student-projects: teacher delete" on storage.objects
  using (
    bucket_id = 'student-projects'
    and private.project_file_student(name) is not null
    and private.teaches_student(private.project_file_student(name))
  );
