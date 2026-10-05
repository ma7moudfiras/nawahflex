# يبني «قفل» الشعار: الشعار + NAWAH ACADEMY تحته، النص محوَّل إلى مسارات
# (لا يحتاج الخط عند من يفتح الملف).
# الاستعمال (القيم المعتمدة): python3 brand/src/make_lockup.py brand Bold 0.10 280
# ثم PNG بعرض 2000px من كل SVG.
import sys
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

out, weight, track, gap = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4])
font = TTFont(f'/home/user/nawahflex/app/assets/fonts/Alexandria-{weight}.ttf')
gs, cmap, upm = font.getGlyphSet(), font.getBestCmap(), font['head'].unitsPerEm
cap = font['OS/2'].sCapHeight

TEXT = 'NAWAH ACADEMY'
# عرض النص بوحدات الخط، مع تتبّع بين الحروف (لا بعد الأخير)
names = [cmap[ord(c)] for c in TEXT]
adv = [gs[n].width for n in names]
trackU = track * upm
raw_w = sum(adv) + trackU * (len(names) - 1)

# الإطار الخارجي للشعار: من -484.5 إلى 2040.5، وقاعه عند 741
FL, FR, FB = -484.5, 2040.5, 741
scale = (FR - FL) / raw_w
cap_px = cap * scale
baseline = FB + gap + cap_px

def text_path():
    d = []
    x = 0
    for n, a in zip(names, adv):
        pen = SVGPathPen(gs)
        # الخط: y للأعلى؛ SVG: y للأسفل → قلب المحور
        tp = TransformPen(pen, (scale, 0, 0, -scale, FL + x * scale, baseline))
        gs[n].draw(tp)
        d.append(pen.getCommands())
        x += a + trackU
    return ' '.join(d)

TP = text_path()

def logo(ink, dot):
    return f'''<path d="M955 -1192 L1653.5 -1192 A300 300 0 0 1 1953.5 -892" fill="none" stroke="{ink}" stroke-width="174"/><path d="M1953.5 90 L1953.5 354 A300 300 0 0 1 1653.5 654 L-97.5 654 A300 300 0 0 1 -397.5 354 L-397.5 -892 A300 300 0 0 1 -97.5 -1192 L601 -1192" fill="none" stroke="{ink}" stroke-width="174"/><rect x="691" y="-1539" width="174" height="1539" fill="{ink}"/><path d="M21 -290 A290 290 0 1 0 601 -290 A290 290 0 1 0 21 -290 Z M193 -290 A118 118 0 1 1 429 -290 A118 118 0 1 1 193 -290 Z" fill="{ink}" fill-rule="evenodd"/><circle cx="226" cy="-726" r="76" fill="{dot}"/><circle cx="396" cy="-726" r="76" fill="{dot}"/><path d="M955 -290 A290 290 0 1 0 1535 -290 A290 290 0 1 0 955 -290 Z M1127 -290 A118 118 0 1 1 1363 -290 A118 118 0 1 1 1127 -290 Z" fill="{ink}" fill-rule="evenodd"/><path d="M1953.5 -560 L1953.5 -307 A220 220 0 0 1 1733.5 -87 L1361 -87" fill="none" stroke="{ink}" stroke-width="174"/><path d="M1448 -290 L1448 90 A220 220 0 0 1 1228 310 L409.2 310 A220 220 0 0 1 189.2 90 L189.2 87.9" fill="none" stroke="{ink}" stroke-width="174" stroke-linejoin="round"/><circle cx="1953.5" cy="-726" r="76" fill="{dot}"/>'''

NAVY, ACC, PAPER, WHITE = '#1B2A41', '#E2552B', '#F7F5F0', '#FFFFFF'
top, bottom = -1539, baseline
# نفس الهامش حول المجموعة: ٨٠ وحدة للشفاف، ٤٠٠ للمربّع
def svg(ink, bg=None):
    m = 400 if bg else 80
    x0, y0 = FL - m, top - m
    w, h = (FR - FL) + 2 * m, (bottom - top) + 2 * m
    rect = f'<rect x="{x0}" y="{y0}" width="{w}" height="{h}" rx="{480 if bg else 0}" fill="{bg}"/>' if bg else ''
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x0:.1f} {y0:.1f} {w:.1f} {h:.1f}" '
            f'width="{w:.0f}" height="{h:.0f}">{rect}{logo(ink, ACC)}<path d="{TP}" fill="{ink}"/></svg>\n')

files = {
  'nawah-lockup-navy.svg': svg(NAVY),
  'nawah-lockup-white.svg': svg(WHITE),
  'nawah-lockup-on-navy.svg': svg(WHITE, NAVY),
  'nawah-lockup-on-paper.svg': svg(NAVY, PAPER),
}
for n, c in files.items():
    open(f'{out}/{n}', 'w').write(c)
print(f'scale={scale:.3f} cap={cap_px:.0f} baseline={baseline:.0f}')
