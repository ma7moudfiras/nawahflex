# صورة الملف الشخصي (فيسبوك/إنستغرام/واتساب): المنصّات تقصّ الصورة دائرةً،
# فيوضع «القفل» (الشعار + NAWAH ACADEMY) في مركزها البصري، وكل نقطة منه داخل
# ٨٢٪ من نصف قطرها (المنصّات ترسم حلقة فوق الحافة). مربّع كحلي كامل، 2048px.
# الاستعمال: python3 brand/src/make_profile.py   ← يقرأ brand/nawah-lockup-white.svg
import math

SAFE = 0.82          # نسبة نصف قطر المحتوى إلى نصف قطر الدائرة المقصوصة
NAVY = '#1B2A41'

src = open('brand/nawah-lockup-white.svg').read()
inner = src[src.index('>') + 1: src.rindex('</svg>')]

# نقاط حدود الشكل: الإطار الخارجي بزواياه المستديرة، الألف، وصندوق النص
pts = []
L, T, R, B, r = -484.5, -1279, 2040.5, 741, 387
for cx, cy, a0 in [(L + r, T + r, 180), (R - r, T + r, 270), (R - r, B - r, 0), (L + r, B - r, 90)]:
    for k in range(0, 91, 5):
        a = math.radians(a0 + k)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
pts += [(691, -1539), (865, -1539)]
pts += [(-484.5, 1021), (2040.5, 1021), (-484.5, 1182), (2040.5, 1182)]

# المركز البصري: منتصف الإطار والاسم أفقياً وعمودياً — لا مركز أصغر دائرة
# محيطة، الذي يسحبه الألف الطويل للأعلى فيبقى فراغ كبير تحت الاسم.
def rad(c): return max(math.hypot(x - c[0], y - c[1]) for x, y in pts)
cx, cy = (L + R) / 2, (T + 1182) / 2
best = (cx, cy)
Rc = rad(best) / SAFE
side = 2 * Rc
x0, y0 = cx - Rc, cy - Rc
svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x0:.1f} {y0:.1f} {side:.1f} {side:.1f}" '
       f'width="2048" height="2048"><rect x="{x0:.1f}" y="{y0:.1f}" width="{side:.1f}" height="{side:.1f}" fill="{NAVY}"/>{inner}</svg>\n')
open('brand/nawah-profile-picture.svg', 'w').write(svg)
print(f'center=({cx:.1f},{cy:.1f}) content_r={rad(best):.0f} side={side:.0f}')
