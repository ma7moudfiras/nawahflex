// ============================================================================
// student-account — حساب دخول للطالب باسم مستخدم وكلمة مرور.
// ----------------------------------------------------------------------------
// معظم الطلاب بلا بريد. فالحساب بريد داخلي `<username>@students.nawahflex.org`
// (النطاق لنا فلا يملكه غيرنا، ولا يستقبل بريداً) وكلمة مرور تولّدها الدالة.
// شاشة الدخول تُلحق النطاق حين يكتب الطالب اسم المستخدم وحده.
//
// المدخل (JSON):
//   إنشاء:          { student_id, username }
//   كلمة مرور جديدة: { student_id, reset: true }
// المخرج: { username, password } — كلمة المرور تُعرض مرة واحدة ولا تُخزَّن نصّاً.
//
// الأمان (نفس دروس invite-guardian):
//   - السائل admin/editor من profiles، لا من بيانات JWT.
//   - إعادة كلمة المرور لحساب دوره student فقط — لا يُلمس حساب موظّف أو وليّ أمر.
//   - service_role من بيئة الدالة وحدها.
// ============================================================================

import { createClient } from "npm:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export const STUDENT_DOMAIN = "students.nawahflex.org";
const USERNAME = /^[a-z0-9._]{3,20}$/;
const UUID = /^[0-9a-f-]{36}$/i;

// بلا أحرف ملتبسة (0/o، 1/l/i) — تُملى بالهاتف أو تُكتب من ورقة.
const ALPHABET = "abcdefghjkmnpqrstuvwxyz23456789";

function newPassword(length = 10): string {
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  return Array.from(bytes, (b) => ALPHABET[b % ALPHABET.length]).join("");
}

function reply(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

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
  if (!caller || !["admin", "editor"].includes(caller.role)) return reply(403, { error: "forbidden" });

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return reply(400, { error: "bad_json" });
  }
  const studentId = String(body.student_id ?? "");
  if (!UUID.test(studentId)) return reply(400, { error: "student_id" });
  const { data: student } = await admin.from("students").select("id, full_name").eq("id", studentId).maybeSingle();
  if (!student) return reply(404, { error: "student_not_found" });

  const { data: existing } = await admin.from("student_accounts")
    .select("profile_id, username").eq("student_id", studentId).maybeSingle();

  // ---- كلمة مرور جديدة ----
  if (body.reset) {
    if (!existing) return reply(404, { error: "no_account" });
    const { data: p } = await admin.from("profiles").select("role").eq("id", existing.profile_id).maybeSingle();
    if (p?.role !== "student") return reply(409, { error: "not_student_account" });
    const password = newPassword();
    const { error } = await admin.auth.admin.updateUserById(existing.profile_id, { password });
    if (error) return reply(400, { error: "reset_failed", detail: error.message });
    return reply(200, { username: existing.username, password });
  }

  // ---- إنشاء ----
  if (existing) return reply(409, { error: "has_account", username: existing.username });
  const username = String(body.username ?? "").trim().toLowerCase();
  if (!USERNAME.test(username)) return reply(400, { error: "username" });
  const { data: taken } = await admin.from("student_accounts").select("profile_id").eq("username", username).maybeSingle();
  if (taken) return reply(409, { error: "username_taken" });

  const password = newPassword();
  const { data: created, error: ce } = await admin.auth.admin.createUser({
    email: `${username}@${STUDENT_DOMAIN}`,
    password,
    email_confirm: true,
    user_metadata: { full_name: student.full_name },
  });
  if (ce || !created?.user) {
    const taken = (ce?.message ?? "").toLowerCase().includes("already");
    return reply(taken ? 409 : 400, { error: taken ? "username_taken" : "create_failed", detail: ce?.message });
  }
  const userId = created.user.id;

  // المُشغِّل handle_new_user أنشأ ملفاً «مشاهداً»؛ يُرفع إلى student ويُربط.
  const { error: pe } = await admin.from("profiles").upsert(
    { id: userId, full_name: student.full_name, role: "student" },
    { onConflict: "id" },
  );
  const { error: le } = pe
    ? { error: pe }
    : await admin.from("student_accounts").insert({ profile_id: userId, student_id: studentId, username });
  if (le) {
    // لا حساب يتيم بلا ربط: يُحذف ما أُنشئ للتوّ.
    await admin.auth.admin.deleteUser(userId);
    return reply(500, { error: "link_failed", detail: le.message });
  }

  return reply(200, { username, password });
});
