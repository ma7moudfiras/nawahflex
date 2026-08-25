#!/usr/bin/env bash
# ============================================================================
# سكربت البناء على Vercel
# ----------------------------------------------------------------------------
# الموقع التعريفي (site/) لا يحتاج بناءً إطلاقاً — يُخدَم كما هو.
# لوحة الإدارة (app/) تُبنى هنا وتُوضع في site/app/ لتُنشر على نفس النطاق.
#
# ⚠️ مبدأ أساسي: فشل بناء اللوحة **لا يجوز** أن يمنع نشر الموقع. الموقع هو
#    ما يراه الزوّار وجوجل، واللوحة أداة داخلية. لذلك ينتهي هذا السكربت
#    بنجاح دائماً؛ وإن تعذّر بناء اللوحة يظهر تحذير واضح في سجلّ البناء
#    ويعود المسار /app إلى 404 حتى يُصلَح.
# ============================================================================
set -uo pipefail

FLUTTER_DIR="${FLUTTER_DIR:-/tmp/flutter}"
FLUTTER_REF="${FLUTTER_REF:-stable}"
OUT="site/app"

warn() { echo "⚠️  $*" >&2; }
ok()   { echo "✅ $*"; }

build_dashboard() {
  command -v git >/dev/null 2>&1 || { warn "git غير متوفّر"; return 1; }

  if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
    echo "→ تنزيل Flutter ($FLUTTER_REF)…"
    git clone --depth 1 -b "$FLUTTER_REF" https://github.com/flutter/flutter.git "$FLUTTER_DIR" \
      >/dev/null 2>&1 || { warn "تعذّر تنزيل Flutter"; return 1; }
  fi

  export PATH="$FLUTTER_DIR/bin:$PATH"
  export PUB_CACHE="${PUB_CACHE:-/tmp/pub-cache}"
  git config --global --add safe.directory "$FLUTTER_DIR" >/dev/null 2>&1

  flutter --version >/dev/null 2>&1 || { warn "تعذّر تشغيل Flutter"; return 1; }

  # --no-web-resources-cdn إلزامي: بدونه يُحمَّل CanvasKit من gstatic.com
  # فتتوقّف اللوحة كلياً إن تعذّر الوصول إليه.
  ( cd app && flutter build web --release --base-href /app/ --no-web-resources-cdn ) \
    || { warn "فشل بناء اللوحة"; return 1; }

  rm -rf "$OUT" && mkdir -p "$OUT"
  cp -r app/build/web/. "$OUT/" || { warn "تعذّر نسخ المخرجات"; return 1; }

  # ملفات .symbols خرائط رموز للتنقيح لا يحتاجها المتصفح — نحو 8 ميجا.
  find "$OUT" -name "*.symbols" -delete 2>/dev/null

  ok "اللوحة جاهزة على /app ($(du -sh "$OUT" | cut -f1))"
}

echo "▸ الموقع التعريفي يُخدَم كما هو من site/ — بلا بناء."

if build_dashboard; then
  echo "▸ اكتمل البناء بالكامل."
else
  warn "نُشر الموقع بدون لوحة الإدارة. المسار /app سيعيد 404."
  rm -rf "$OUT"
fi

exit 0
