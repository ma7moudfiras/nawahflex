// ============================================================================
// send-push — يرسل إشعار البوابة إلى أجهزة صاحبه (Web Push).
// ----------------------------------------------------------------------------
// يستدعيها مُشغِّل `push_notification` في القاعدة (0017) عبر pg_net بعد إدراج
// إشعار لمستخدم له اشتراك — لا متصفح. لذلك verify_jwt مطفأ، ومكانه سرّ مشترك
// في ترويسة `x-push-secret` يُقارن بما في Vault (`push_config()`).
//
// المدخل: { id } — معرّف الإشعار وحده؛ النص والمستلم يُقرآن من القاعدة، فلا
// يستطيع حامل السرّ نفسه أن يرسل نصّاً من عنده.
//
// الحمولة للجهاز: { title, body, url } — url حسب دور المستلم: وليّ الأمر إلى
// ملف ابنه، والطالب إلى «ملفّي». الاشتراك الذي يجيب عنه خادم Push بـ 404/410
// (ألغى المستخدم أو اختفى الجهاز) يُحذف.
// ============================================================================

import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const APP = "https://www.nawahflex.org/app";

const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

type Config = { public_key: string; private_key: string; secret: string };
let config: Config | null = null;

async function loadConfig(): Promise<Config | null> {
  if (config) return config;
  const { data, error } = await db.rpc("push_config").single<Config>();
  if (error || !data?.public_key || !data.private_key || !data.secret) return null;
  webpush.setVapidDetails("mailto:info@nawahflex.org", data.public_key, data.private_key);
  return (config = data);
}

/** مقارنة ثابتة الزمن — لا يكشف توقيت الردّ كم حرفاً صحّ من السرّ. */
function sameSecret(given: string | null, expected: string): boolean {
  if (!given) return false;
  const a = new TextEncoder().encode(given);
  const b = new TextEncoder().encode(expected);
  let diff = a.length ^ b.length;
  for (let i = 0; i < b.length; i++) diff |= (a[i] ?? 0) ^ b[i];
  return diff === 0;
}

function targetUrl(role: string | null, studentId: string | null): string {
  if (role === "parent" && studentId) return `${APP}/kids/${studentId}`;
  if (role === "student") return `${APP}/me`;
  return `${APP}/`;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });

  const cfg = await loadConfig();
  if (!cfg) return new Response("not configured", { status: 503 });
  if (!sameSecret(req.headers.get("x-push-secret"), cfg.secret)) {
    return new Response("unauthorized", { status: 401 });
  }

  let id: unknown;
  try {
    id = (await req.json())?.id;
  } catch {
    // ليس JSON
  }
  if (typeof id !== "string" || !UUID.test(id)) return new Response("bad request", { status: 400 });

  const { data: n } = await db
    .from("notifications")
    .select("id, profile_id, title, body, student_id, read_at")
    .eq("id", id)
    .maybeSingle();
  if (!n) return new Response("ok — no notification");
  if (n.read_at) return new Response("ok — already read");

  const [{ data: profile }, { data: subs }] = await Promise.all([
    db.from("profiles").select("role").eq("id", n.profile_id).maybeSingle(),
    db.from("push_subscriptions").select("id, endpoint, p256dh, auth").eq("profile_id", n.profile_id),
  ]);
  if (!subs?.length) return new Response("ok — no subscriptions");

  const payload = JSON.stringify({
    title: n.title,
    body: n.body ?? "",
    url: targetUrl(profile?.role ?? null, n.student_id),
    tag: n.id,
  });

  // كل نتيجة تُسجَّل في سجلّ الدالة (المضيف فقط، لا الـ endpoint كاملاً):
  // «لم يصلني شيء» يُقرأ من السجلّ بدل أن يُخمَّن.
  const results = await Promise.all(
    subs.map(async (s) => {
      const host = new URL(s.endpoint).host;
      try {
        const res = await webpush.sendNotification(
          { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
          payload,
          { TTL: 60 * 60 * 24, urgency: "normal" },
        );
        await db.from("push_subscriptions").update({ last_used_at: new Date().toISOString() }).eq("id", s.id);
        return `${host} ${res.statusCode}`;
      } catch (e) {
        const status = (e as { statusCode?: number }).statusCode;
        if (status === 404 || status === 410) {
          await db.from("push_subscriptions").delete().eq("id", s.id);
          return `${host} ${status} removed`;
        }
        return `${host} error ${status ?? (e as Error).message}`;
      }
    }),
  );
  console.log(`send-push ${n.id}: ${results.join(", ")}`);
  return new Response(JSON.stringify({ sent: results }), { headers: { "content-type": "application/json" } });
});
