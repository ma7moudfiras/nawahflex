-- ============================================================================
-- 0017 — الإشعارات: داخل البوابة + Web Push للجوال.
-- ----------------------------------------------------------------------------
-- - الإشعار صفّ في notifications يُنشئه مُشغِّل في القاعدة لا التطبيق: شارة،
--   ملاحظة «للأهل»، غياب، شهادة، مشروع. فلا يُنسى إشعار لأن شاشةً ما لم ترسله.
-- - المستلمون: أولياء الطالب (guardian_students) والطالب نفسه (student_accounts)
--   حيث يناسب — الغياب والملاحظات للأهل وحدهم.
-- - صاحب الإشعار يقرؤه ويعلّمه مقروءاً (عمود read_at وحده)؛ لا إنشاء ولا حذف
--   من التطبيق.
-- - Push: بعد إدراج إشعار لمستخدم له اشتراك، يستدعي pg_net الدالة send-push
--   بسرّ مشترك. الأسرار (مفاتيح VAPID والسرّ) في Supabase Vault — لا في git ولا
--   في إعدادات يدوية؛ أُنشئت مرة واحدة بـ vault.create_secret (انظر آخر الملف).
-- ============================================================================

create extension if not exists pg_net with schema extensions;

-- ---------------------------------------------------------------------------
-- ١. الإشعارات
-- ---------------------------------------------------------------------------
create table if not exists public.notifications (
  id         uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  kind       text not null check (kind in ('badge', 'note', 'absence', 'certificate', 'project')),
  title      text not null check (char_length(title) between 1 and 120),
  body       text check (char_length(body) <= 300),
  student_id uuid references public.students (id) on delete cascade,
  -- السجلّ المصدر (صفّ الحضور مثلاً) — لسحب إشعار غيابٍ صُحِّح.
  source_id  uuid,
  read_at    timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists notifications_profile_idx on public.notifications (profile_id, created_at desc);
create index if not exists notifications_student_idx on public.notifications (student_id);
create index if not exists notifications_source_idx  on public.notifications (source_id) where source_id is not null;

alter table public.notifications enable row level security;

create policy "notifications: own read" on public.notifications for select to authenticated
  using (profile_id = (select auth.uid()));
create policy "notifications: own mark read" on public.notifications for update to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

-- التعديل على read_at وحده: لا يغيّر أحد نص إشعاره أو صاحبه.
revoke all on public.notifications from anon, authenticated;
grant select on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;


-- ---------------------------------------------------------------------------
-- ٢. اشتراكات Push — جهاز لكل صفّ
-- ---------------------------------------------------------------------------
create table if not exists public.push_subscriptions (
  id           uuid primary key default gen_random_uuid(),
  profile_id   uuid not null references public.profiles (id) on delete cascade,
  endpoint     text not null unique check (endpoint ~ '^https://'),
  p256dh       text not null,
  auth         text not null,
  user_agent   text,
  created_at   timestamptz not null default now(),
  last_used_at timestamptz
);
create index if not exists push_subscriptions_profile_idx on public.push_subscriptions (profile_id);

alter table public.push_subscriptions enable row level security;

create policy "push_subscriptions: own read" on public.push_subscriptions for select to authenticated
  using (profile_id = (select auth.uid()));
-- عند تسجيل الخروج يحذف الجهاز اشتراكه — فلا تصل إشعارات المستخدم السابق لمن بعده.
create policy "push_subscriptions: own delete" on public.push_subscriptions for delete to authenticated
  using (profile_id = (select auth.uid()));

revoke all on public.push_subscriptions from anon, authenticated;
grant select, delete on public.push_subscriptions to authenticated;

-- الحفظ عبر دالة لا insert مباشر: الجهاز نفسه قد ينتقل بين حسابين (أب ثم ابنه)،
-- والـ endpoint فريد — فيُنقل للمستخدم الحالي بدل أن يبقى للسابق.
create or replace function public.save_push_subscription(p_endpoint text, p_p256dh text, p_auth text, p_user_agent text)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  insert into public.push_subscriptions (profile_id, endpoint, p256dh, auth, user_agent)
  values ((select auth.uid()), p_endpoint, p_p256dh, p_auth, left(p_user_agent, 300))
  on conflict (endpoint) do update
    set profile_id = excluded.profile_id, p256dh = excluded.p256dh, auth = excluded.auth,
        user_agent = excluded.user_agent, created_at = now();
end;
$$;
revoke all on function public.save_push_subscription(text, text, text, text) from public, anon;
grant execute on function public.save_push_subscription(text, text, text, text) to authenticated;


-- ---------------------------------------------------------------------------
-- ٣. الأسرار: المفتاح العلني للمتصفح، والكامل لدالة send-push
-- ---------------------------------------------------------------------------
create or replace function public.push_public_key()
returns text language sql stable security definer set search_path = ''
as $$
  select decrypted_secret from vault.decrypted_secrets where name = 'vapid_public_key';
$$;
revoke all on function public.push_public_key() from public, anon;
grant execute on function public.push_public_key() to authenticated;

-- لدالة send-push وحدها (service_role) — لا anon ولا authenticated.
create or replace function public.push_config()
returns table (public_key text, private_key text, secret text)
language sql stable security definer set search_path = ''
as $$
  select
    (select decrypted_secret from vault.decrypted_secrets where name = 'vapid_public_key'),
    (select decrypted_secret from vault.decrypted_secrets where name = 'vapid_private_key'),
    (select decrypted_secret from vault.decrypted_secrets where name = 'push_webhook_secret');
$$;
revoke all on function public.push_config() from public, anon, authenticated;
grant execute on function public.push_config() to service_role;


-- ---------------------------------------------------------------------------
-- ٤. الإنشاء والإرسال
-- ---------------------------------------------------------------------------
-- «7 تشرين الأول» — نفس أسماء الأشهر في التطبيق والشهادة.
create or replace function private.ar_day(p date)
returns text language sql immutable set search_path = ''
as $$
  select extract(day from p)::int || ' ' || (array['كانون الثاني','شباط','آذار','نيسان','أيار','حزيران',
    'تموز','آب','أيلول','تشرين الأول','تشرين الثاني','كانون الأول'])[extract(month from p)::int];
$$;

-- يُنشئ الإشعار لأولياء الطالب، وللطالب نفسه إن أُعطي عنوانٌ له.
create or replace function private.notify_family(
  p_student uuid, p_kind text, p_family_title text, p_self_title text, p_body text, p_source uuid default null)
returns void language sql security definer set search_path = ''
as $$
  insert into public.notifications (profile_id, kind, title, body, student_id, source_id)
  select g.guardian_id, p_kind, p_family_title, p_body, p_student, p_source
  from public.guardian_students g where g.student_id = p_student
  union all
  select a.profile_id, p_kind, p_self_title, p_body, p_student, p_source
  from public.student_accounts a where p_self_title is not null and a.student_id = p_student;
$$;

create or replace function private.first_name(p_student uuid)
returns text language sql stable security definer set search_path = ''
as $$
  select split_part(trim(full_name), ' ', 1) from public.students where id = p_student;
$$;

create or replace function private.on_badge_awarded()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  perform private.notify_family(new.student_id, 'badge',
    'شارة جديدة لـ' || private.first_name(new.student_id), 'نلت شارة جديدة',
    '«' || (select title from public.badges where id = new.badge_id) || '»', new.id);
  return null;
end;
$$;

create or replace function private.on_note_added()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if new.visible_to_guardian then
    perform private.notify_family(new.student_id, 'note',
      'ملاحظة من المدرّب عن ' || private.first_name(new.student_id), null, left(new.body, 280), new.id);
  end if;
  return null;
end;
$$;

-- الغياب: إشعار عند التسجيل؛ ويُسحب إن صُحِّح السجلّ إلى غير «غائب».
create or replace function private.on_attendance_marked()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and old.status = 'absent' and new.status <> 'absent' then
    delete from public.notifications where kind = 'absence' and source_id = new.id;
  elsif new.status = 'absent' and (tg_op = 'INSERT' or old.status is distinct from 'absent') then
    perform private.notify_family(new.student_id, 'absence',
      'غياب ' || private.first_name(new.student_id), null,
      'سُجّل غياب عن حصة ' || private.ar_day(new.session_date) || '.', new.id);
  end if;
  return null;
end;
$$;

create or replace function private.on_certificate_issued()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  perform private.notify_family(new.student_id, 'certificate',
    'شهادة جديدة لـ' || private.first_name(new.student_id), 'صدرت لك شهادة جديدة', new.title, new.id);
  return null;
end;
$$;

create or replace function private.on_project_added()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  perform private.notify_family(new.student_id, 'project',
    'مشروع جديد لـ' || private.first_name(new.student_id), 'أُضيف مشروعك إلى ملفّك', new.title, new.id);
  return null;
end;
$$;

-- Push: طلب HTTP غير متزامن (pg_net) — لا يؤخّر حفظ الشارة أو الحضور، ولا
-- يُفشلها إن تعطّلت الدالة. يُرسل المعرّف وحده؛ الدالة تقرأ الباقي بنفسها.
create or replace function private.on_notification_push()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  v_secret text;
begin
  if not exists (select 1 from public.push_subscriptions where profile_id = new.profile_id) then
    return null;
  end if;
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'push_webhook_secret';
  if v_secret is null then
    return null;
  end if;
  perform net.http_post(
    url := 'https://zhpnqtwegulqhalfvvoj.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object('content-type', 'application/json', 'x-push-secret', v_secret),
    body := jsonb_build_object('id', new.id)
  );
  return null;
end;
$$;

revoke all on function private.ar_day(date) from public;
revoke all on function private.notify_family(uuid, text, text, text, text, uuid) from public;
revoke all on function private.first_name(uuid) from public;
revoke all on function private.on_badge_awarded() from public;
revoke all on function private.on_note_added() from public;
revoke all on function private.on_attendance_marked() from public;
revoke all on function private.on_certificate_issued() from public;
revoke all on function private.on_project_added() from public;
revoke all on function private.on_notification_push() from public;

create trigger notify_badge after insert on public.student_badges
  for each row execute function private.on_badge_awarded();
create trigger notify_note after insert on public.student_notes
  for each row execute function private.on_note_added();
create trigger notify_absence after insert or update of status on public.attendance
  for each row execute function private.on_attendance_marked();
create trigger notify_certificate after insert on public.certificates
  for each row execute function private.on_certificate_issued();
create trigger notify_project after insert on public.student_projects
  for each row execute function private.on_project_added();
create trigger push_notification after insert on public.notifications
  for each row execute function private.on_notification_push();

-- ---------------------------------------------------------------------------
-- الأسرار — أُنشئت مرة واحدة خارج هذا الملف (لا تُحفظ قيمها في git):
--   select vault.create_secret(encode(extensions.gen_random_bytes(32), 'hex'), 'push_webhook_secret');
--   select vault.create_secret('<VAPID public, base64url>',  'vapid_public_key');
--   select vault.create_secret('<VAPID private, base64url>', 'vapid_private_key');
-- السرّ يولَّد داخل القاعدة ولا يغادرها إلا إلى send-push. تدوير المفاتيح:
-- vault.update_secret ثم يعيد كل جهاز الاشتراك (المفتاح العلني تغيّر).
-- ---------------------------------------------------------------------------
