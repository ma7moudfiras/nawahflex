// ============================================================================
// invite-guardian — رابط دخول لولي الأمر وربطه بالطالب.
// ----------------------------------------------------------------------------
// تحمل service_role من بيئة الدالة وحدها — لا يقترب المفتاح من site/ ولا app/.
//
// لماذا «رابط» لا «بريد»؟ الخطة المجانية في Supabase لا ترسل بريداً إلا لفريق
// المشروع. فتولّد الدالة الرابط (generateLink لا يرسل شيئاً) وترجعه للإدارة،
// فترسله بواتساب لهاتف ولي الأمر أو تنسخه.
//
// المدخل (JSON):
//   دعوة:        { student_id, email, full_name?, relationship? }
//   رابط جديد:   { student_id, guardian_id }
// المخرج: { link, existing }
//
// الأمان:
//   - السائل يجب أن يكون admin/editor (من profiles، لا من بيانات JWT).
//   - لا رابط لحساب موظّف أبداً (admin/editor/trainer): وإلا أخذ «محرّر» رابط
//     دخول باسم المدير بدعوته «ولي أمر». يُفحص الدور قبل توليد أي رابط.
//   - الدور يُرفع إلى parent فقط من viewer أو لحساب جديد.
//   - رابط جديد لحساب موجود فقط إن كان مربوطاً بهذا الطالب أصلاً.
// ============================================================================

import { createClient } from "npm:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const PRODUCTION = "https://www.nawahflex.org/app/";

// أصول مسموح أن يعود إليها الرابط (المعاينة والتطوير). أي أصل آخر → الإنتاج.
function redirectFor(origin: string | null): string {
  if (!origin) return PRODUCTION;
  try {
    const u = new URL(origin);
    const ok =
      u.hostname === "www.nawahflex.org" ||
      u.hostname === "nawahflex.org" ||
      (u.hostname.endsWith(".vercel.app") && u.hostname.startsWith("nawahflex-")) ||
      u.hostname === "localhost";
    return ok ? `${u.origin}/app/` : PRODUCTION;
  } catch {
    return PRODUCTION;
  }
}

function reply(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

const GUARDIAN_ROLES = ["viewer", "parent"];

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const UUID = /^[0-9a-f-]{36}$/i;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method" });

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  // ---- من السائل؟ ----
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: who } = await admin.auth.getUser(token);
  if (!who?.user) return reply(401, { error: "unauthenticated" });
  const { data: caller } = await admin.from("profiles").select("role").eq("id", who.user.id).maybeSingle();
  if (!caller || !["admin", "editor"].includes(caller.role)) {
    return reply(403, { error: "forbidden" });
  }

  // ---- المدخل ----
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return reply(400, { error: "bad_json" });
  }
  const studentId = String(body.student_id ?? "");
  if (!UUID.test(studentId)) return reply(400, { error: "student_id" });
  const { data: student } = await admin.from("students").select("id").eq("id", studentId).maybeSingle();
  if (!student) return reply(404, { error: "student_not_found" });

  const redirectTo = redirectFor(req.headers.get("Origin"));

  // ---- رابط جديد لولي أمر مربوط ----
  if (body.guardian_id) {
    const guardianId = String(body.guardian_id);
    if (!UUID.test(guardianId)) return reply(400, { error: "guardian_id" });
    const { data: link } = await admin.from("guardian_students")
      .select("guardian_id").eq("guardian_id", guardianId).eq("student_id", studentId).maybeSingle();
    if (!link) return reply(404, { error: "not_linked" });
    const { data: gp } = await admin.from("profiles").select("role").eq("id", guardianId).maybeSingle();
    if (!gp || !GUARDIAN_ROLES.includes(gp.role)) return reply(409, { error: "staff_account" });
    const { data: u, error: ue } = await admin.auth.admin.getUserById(guardianId);
    if (ue || !u?.user?.email) return reply(404, { error: "no_email" });
    const { data, error } = await admin.auth.admin.generateLink({
      type: "magiclink",
      email: u.user.email,
      options: { redirectTo },
    });
    if (error) return reply(400, { error: "link_failed", detail: error.message });
    return reply(200, { link: data.properties.action_link, existing: true });
  }

  // ---- دعوة ----
  const email = String(body.email ?? "").trim().toLowerCase();
  if (!EMAIL.test(email)) return reply(400, { error: "email" });
  const fullName = String(body.full_name ?? "").trim().slice(0, 120) || null;
  const relationship = String(body.relationship ?? "").trim().slice(0, 40) || null;

  const { data: found, error: fe } = await admin.rpc("guardian_account_by_email", { p_email: email });
  if (fe) return reply(500, { error: "lookup_failed", detail: fe.message });
  const account = (found as { id: string; role: string }[] | null)?.[0];
  if (account && !GUARDIAN_ROLES.includes(account.role)) return reply(409, { error: "staff_account" });

  // جديد → دعوة (تُنشئ الحساب)؛ موجود (ولي أمر لطالب آخر) → رابط دخول عادي.
  const existing = !!account;
  const gen = existing
    ? await admin.auth.admin.generateLink({ type: "magiclink", email, options: { redirectTo } })
    : await admin.auth.admin.generateLink({
      type: "invite",
      email,
      options: { redirectTo, data: fullName ? { full_name: fullName } : undefined },
    });
  if (gen.error) return reply(400, { error: "link_failed", detail: gen.error.message });
  const userId = gen.data.user!.id;

  // الدور: parent لحساب جديد أو «مشاهد» — لا يُمسّ دور موظّف.
  const { data: prof } = await admin.from("profiles").select("role, full_name").eq("id", userId).maybeSingle();
  if (!prof) {
    await admin.from("profiles").insert({ id: userId, full_name: fullName ?? email, role: "parent" });
  } else if (prof.role === "viewer") {
    await admin.from("profiles").update({
      role: "parent",
      ...(fullName && (!prof.full_name || prof.full_name === email) ? { full_name: fullName } : {}),
    }).eq("id", userId);
  }

  const { error: le } = await admin.from("guardian_students").upsert(
    { guardian_id: userId, student_id: studentId, relationship },
    { onConflict: "guardian_id,student_id", ignoreDuplicates: false },
  );
  if (le) return reply(500, { error: "link_save_failed", detail: le.message });

  // الدور بعد الترقية: الحساب الجديد يُنشئه المُشغِّل «مشاهداً» ثم يُرفع أعلاه.
  return reply(200, { link: gen.data.properties.action_link, existing, role: "parent" });
});
