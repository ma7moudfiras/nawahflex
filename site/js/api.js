/* ==========================================================================
   طبقة الاتصال بقاعدة البيانات — Supabase REST مباشرة (بدون مكتبات)
   --------------------------------------------------------------------------
   نستخدم fetch مباشرة بدلاً من supabase-js لسببين:
   1. صفر اعتماديات وصفر خطوة بناء — يبقى الموقع HTML/CSS/JS خالص.
   2. حجم أقل بكثير (نحتاج INSERT فقط في هذه المرحلة).

   عند التوسّع لاحقاً (قراءة الأخبار والمناسبات من القاعدة) تُضاف دوال
   القراءة هنا وحدها، دون لمس main.js.
   ========================================================================== */

window.API = (function () {
  const cfg = window.CONFIG || {};
  const ready = Boolean(cfg.SUPABASE_URL && cfg.SUPABASE_KEY);

  /** إدراج صف في جدول عبر PostgREST */
  async function insert(table, row) {
    if (!ready) throw new Error("SUPABASE_NOT_CONFIGURED");

    const res = await fetch(`${cfg.SUPABASE_URL}/rest/v1/${table}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "apikey": cfg.SUPABASE_KEY,
        "Authorization": `Bearer ${cfg.SUPABASE_KEY}`,
        "Prefer": "return=minimal"
      },
      body: JSON.stringify(row)
    });

    if (!res.ok) {
      const detail = await res.text().catch(() => "");
      throw new Error(`SUPABASE_${res.status}: ${detail.slice(0, 200)}`);
    }
    return true;
  }

  /** قراءة صفوف من جدول (تُستخدم لاحقاً عند نقل المحتوى للقاعدة) */
  async function select(table, query = "select=*") {
    if (!ready) throw new Error("SUPABASE_NOT_CONFIGURED");
    const res = await fetch(`${cfg.SUPABASE_URL}/rest/v1/${table}?${query}`, {
      headers: { "apikey": cfg.SUPABASE_KEY, "Authorization": `Bearer ${cfg.SUPABASE_KEY}` }
    });
    if (!res.ok) throw new Error(`SUPABASE_${res.status}`);
    return res.json();
  }

  return {
    isReady: () => ready,
    insert,
    select,
    sendMessage: (row) => insert("messages", row),
    subscribe:   (email) => insert("subscribers", { email })
  };
})();
