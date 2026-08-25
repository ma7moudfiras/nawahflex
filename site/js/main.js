/* ==========================================================================
   نواة فليكس — منطق الواجهة
   لا اعتماديات، لا خطوة بناء. يعمل بفتح index.html مباشرة.
   ========================================================================== */
(function () {
  "use strict";

  const S = window.SITE;
  const $  = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];

  /** تهريب النص لمنع حقن HTML عند وضع محتوى من مصدر خارجي */
  const esc = (str) => String(str ?? "").replace(/[&<>"']/g,
    (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

  /* ======================================================================
     1. صور بديلة مولّدة — SVG بلا ملفات ولا طلبات شبكة
     ====================================================================== */
  const PALETTES = [
    ["#1E3A8A", "#2563EB", "#06B6D4"],
    ["#4C1D95", "#7C3AED", "#A78BFA"],
    ["#064E3B", "#10B981", "#6EE7B7"],
    ["#7C2D12", "#F59E0B", "#FCD34D"],
    ["#0C4A6E", "#0891B2", "#67E8F9"],
    ["#831843", "#F43F5E", "#FDA4AF"]
  ];

  /** مولّد أرقام شبه عشوائي ثابت النتيجة لنفس البذرة */
  function rng(seed) {
    let s = seed * 9301 + 49297;
    return () => { s = (s * 9301 + 49297) % 233280; return s / 233280; };
  }

  let artId = 0;   // يضمن تفرّد معرّفات التدرّج داخل الصفحة كلها

  /** يبني لوحة SVG هندسية بروح الدوائر الإلكترونية */
  function artwork(seed) {
    const r = rng(seed || 1);
    const p = PALETTES[(seed || 1) % PALETTES.length];
    const id = "art" + (++artId);
    let shapes = "";

    // خطوط دوائر إلكترونية
    for (let i = 0; i < 7; i++) {
      const x = r() * 400, y = r() * 300;
      const x2 = x + (r() - .5) * 190, y2 = y + (r() - .5) * 150;
      shapes += `<path d="M${x.toFixed(0)} ${y.toFixed(0)} L${((x + x2) / 2).toFixed(0)} ${y.toFixed(0)} L${x2.toFixed(0)} ${y2.toFixed(0)}"
        stroke="${p[2]}" stroke-opacity=".26" stroke-width="1.6" fill="none"/>`;
      shapes += `<circle cx="${x2.toFixed(0)}" cy="${y2.toFixed(0)}" r="3" fill="${p[2]}" fill-opacity=".55"/>`;
    }
    // أشكال هندسية طافية
    for (let i = 0; i < 4; i++) {
      const cx = r() * 400, cy = r() * 300, rad = 22 + r() * 62;
      shapes += `<circle cx="${cx.toFixed(0)}" cy="${cy.toFixed(0)}" r="${rad.toFixed(0)}"
        fill="none" stroke="#fff" stroke-opacity=".10" stroke-width="1.4"/>`;
    }

    return `<svg viewBox="0 0 400 300" preserveAspectRatio="xMidYMid slice" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
      <defs><linearGradient id="${id}" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="${p[0]}"/><stop offset="1" stop-color="${p[1]}"/>
      </linearGradient></defs>
      <rect width="400" height="300" fill="url(#${id})"/>${shapes}
    </svg>`;
  }

  /* ======================================================================
     2. التنقّل والترويسة
     ====================================================================== */
  function buildNav() {
    const items = S.nav.map((n) => `<li><a href="${esc(n.href)}">${esc(n.label)}</a></li>`).join("");
    $("#mainNav ul").innerHTML = items;
    $("#mobileNav ul").innerHTML = items;
    $("#footerNav").innerHTML = S.nav.slice(0, 6)
      .map((n) => `<li><a href="${esc(n.href)}">${esc(n.label)}</a></li>`).join("");
    $("#footerPrograms").innerHTML = S.programs.slice(0, 6)
      .map((p) => `<li><a href="#programs">${esc(p.title)}</a></li>`).join("");
  }

  function initHeader() {
    const header = $("#header");
    const burger = $("#burger");
    const mnav   = $("#mobileNav");

    const onScroll = () => header.classList.toggle("is-scrolled", window.scrollY > 40);
    onScroll();
    addEventListener("scroll", onScroll, { passive: true });

    burger.addEventListener("click", () => {
      const open = mnav.classList.toggle("is-open");
      burger.classList.toggle("is-open", open);
      burger.setAttribute("aria-expanded", String(open));
    });
    // إغلاق القائمة عند اختيار رابط
    mnav.addEventListener("click", (e) => {
      if (e.target.closest("a")) {
        mnav.classList.remove("is-open");
        burger.classList.remove("is-open");
        burger.setAttribute("aria-expanded", "false");
      }
    });

    // إبراز القسم الحالي في شريط التنقّل
    const links = $$("#mainNav a");
    const spy = new IntersectionObserver((entries) => {
      entries.forEach((en) => {
        if (!en.isIntersecting) return;
        links.forEach((a) => a.classList.toggle("is-active", a.getAttribute("href") === "#" + en.target.id));
      });
    }, { rootMargin: "-45% 0px -50% 0px" });
    S.nav.forEach((n) => { const sec = $(n.href); if (sec) spy.observe(sec); });
  }

  /* ======================================================================
     3. شبكة الهيرو المتحركة (canvas)
     ====================================================================== */
  function initHeroCanvas() {
    const cv = $("#heroCanvas");
    if (!cv || matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const ctx = cv.getContext("2d");
    let w, h, dots = [], raf;
    const DPR = Math.min(devicePixelRatio || 1, 2);

    function size() {
      const rect = cv.getBoundingClientRect();
      w = rect.width; h = rect.height;
      cv.width = w * DPR; cv.height = h * DPR;
      ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
      // كثافة النقاط تتبع مساحة الشاشة — أقل على الجوال
      const count = Math.min(90, Math.round((w * h) / 15000));
      dots = Array.from({ length: count }, () => ({
        x: Math.random() * w,
        y: Math.random() * h,
        vx: (Math.random() - .5) * .28,
        vy: (Math.random() - .5) * .28,
        r: Math.random() * 1.7 + .7
      }));
    }

    function frame() {
      ctx.clearRect(0, 0, w, h);
      for (const d of dots) {
        d.x += d.vx; d.y += d.vy;
        if (d.x < 0 || d.x > w) d.vx *= -1;
        if (d.y < 0 || d.y > h) d.vy *= -1;
      }
      // وصلات بين النقاط المتقاربة
      ctx.lineWidth = 1;
      for (let i = 0; i < dots.length; i++) {
        for (let j = i + 1; j < dots.length; j++) {
          const dx = dots[i].x - dots[j].x, dy = dots[i].y - dots[j].y;
          const dist = Math.hypot(dx, dy);
          if (dist < 128) {
            ctx.strokeStyle = `rgba(96,165,250,${(1 - dist / 128) * 0.22})`;
            ctx.beginPath();
            ctx.moveTo(dots[i].x, dots[i].y);
            ctx.lineTo(dots[j].x, dots[j].y);
            ctx.stroke();
          }
        }
      }
      for (const d of dots) {
        ctx.fillStyle = "rgba(147,197,253,.55)";
        ctx.beginPath();
        ctx.arc(d.x, d.y, d.r, 0, Math.PI * 2);
        ctx.fill();
      }
      raf = requestAnimationFrame(frame);
    }

    size();
    frame();
    addEventListener("resize", () => { cancelAnimationFrame(raf); size(); frame(); });

    // إيقاف الرسم عندما يخرج الهيرو من الشاشة — توفير في البطارية
    new IntersectionObserver(([en]) => {
      cancelAnimationFrame(raf);
      if (en.isIntersecting) frame();
    }, { threshold: 0 }).observe(cv);
  }

  /* ======================================================================
     4. الإحصائيات بعدّاد متحرك
     ====================================================================== */
  function buildStats() {
    $("#statsGrid").innerHTML = S.stats.map((s) => `
      <div class="stat">
        <div class="stat__icon">${esc(s.icon)}</div>
        <div class="stat__num" data-to="${Number(s.value)}"><span>0</span><i>${esc(s.suffix)}</i></div>
        <div class="stat__label">${esc(s.label)}</div>
      </div>`).join("");

    const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
    const io = new IntersectionObserver((entries) => {
      entries.forEach((en) => {
        if (!en.isIntersecting) return;
        io.unobserve(en.target);
        const target = Number(en.target.dataset.to);
        const out = $("span", en.target);
        if (reduce) { out.textContent = target.toLocaleString("en-US"); return; }

        const dur = 1500, t0 = performance.now();
        (function tick(now) {
          const p = Math.min((now - t0) / dur, 1);
          const eased = 1 - Math.pow(1 - p, 3);     // تباطؤ تدريجي
          out.textContent = Math.round(target * eased).toLocaleString("en-US");
          if (p < 1) requestAnimationFrame(tick);
        })(t0);
      });
    }, { threshold: .5 });
    $$(".stat__num").forEach((n) => io.observe(n));
  }

  /* ======================================================================
     5. الأقسام المبنية من content.js
     ====================================================================== */
  function buildAbout() {
    $("#aboutLead").textContent = S.about.lead;
    $("#aboutBody").innerHTML = S.about.body.map((p) => `<p>${esc(p)}</p>`).join("");
    $("#pillars").innerHTML = S.about.pillars.map((p) => `
      <div class="pillar" style="--tone:${esc(p.tone)}">
        <div class="pillar__ico">${esc(p.icon)}</div>
        <div><h4>${esc(p.title)}</h4><p>${esc(p.text)}</p></div>
      </div>`).join("");
  }

  function buildPrograms() {
    $("#programsGrid").innerHTML = S.programs.map((p) => `
      <article class="prog" style="--tone:${esc(p.tone)}">
        <div class="prog__icon">${esc(p.icon)}</div>
        <h3>${esc(p.title)}</h3>
        <p>${esc(p.text)}</p>
        <div class="prog__meta">
          ${p.tags.map((t, i) => `<span class="tag ${i === 0 ? "tag--tone" : ""}">${esc(t)}</span>`).join("")}
        </div>
      </article>`).join("");
  }

  /** FlexMind — العلامة الفرعية. تعرض الشعار الرسمي إن وُجد، وإلا شعاراً نصّياً. */
  function buildFlexMind() {
    const f = S.flexmind;
    if (!f) return;

    $("#fmMark").innerHTML = f.logo
      ? `<img src="${esc(f.logo)}" alt="${esc(f.name)} — ${esc(f.tagline)}">`
      : `<div class="fm__wordmark">Flex<b>Mind</b></div>
         <div class="fm__tagline">${esc(f.tagline)}</div>`;

    $("#fmLead").textContent = f.lead;
    $("#fmBody").textContent = f.body;

    $("#fmFacts").innerHTML = f.facts.map((x) => `
      <div class="fm__fact"><b>${esc(x.value)}</b><span>${esc(x.label)}</span></div>`).join("");

    $("#fmPillars").innerHTML = f.pillars.map((p) => `
      <article class="fm__pillar">
        <div class="fm__pillar-ico">${esc(p.icon)}</div>
        <div><h3>${esc(p.title)}</h3><p>${esc(p.text)}</p></div>
      </article>`).join("");
  }

  function buildEvents() {
    $("#eventsGrid").innerHTML = S.events.map((e) => `
      <article class="event">
        <div class="event__date">
          <div class="event__day">${esc(e.day)}</div>
          <div class="event__mon">${esc(e.month)}</div>
        </div>
        <div class="event__body">
          <h3>${esc(e.title)}</h3>
          <div class="event__info">
            <span><svg><use href="#i-pin"/></svg>${esc(e.place)}</span>
            <span><svg><use href="#i-clock"/></svg>${esc(e.time)}</span>
          </div>
          <p style="font-size:var(--t-sm);color:var(--c-text-soft);line-height:1.75">${esc(e.desc)}</p>
          <a href="#contact" class="link-arrow" style="margin-top:.8rem">التسجيل في المناسبة<svg><use href="#i-arrow"/></svg></a>
        </div>
      </article>`).join("");
  }

  function buildAchievements() {
    $("#achGrid").innerHTML = S.achievements.map((a) => `
      <article class="ach ${a.size ? "ach--" + esc(a.size) : ""}">
        <div class="ach__bg">${artwork(a.seed)}</div>
        <div class="ach__body">
          <span class="ach__year">${esc(a.year)}</span>
          <h3>${esc(a.title)}</h3>
          <p>${esc(a.text)}</p>
        </div>
      </article>`).join("");
  }

  function buildPartners() {
    const one = S.partners.map((p) => `
      <div class="partner">
        <div class="partner__logo" style="background:${esc(p.tone)}">${esc(p.name.trim()[0])}</div>
        <div>
          <div class="partner__name">${esc(p.name)}</div>
          <div class="partner__type">${esc(p.type)}</div>
        </div>
      </div>`).join("");
    // نسختان متطابقتان ليبدو الشريط لانهائياً
    $("#partnersTrack").innerHTML = one + one;
  }

  function buildNews() {
    $("#newsGrid").innerHTML = S.news.slice(0, 5).map((n, i) => `
      <article class="post ${i === 0 ? "post--lead" : ""}">
        <div class="post__thumb">
          ${artwork(n.seed)}
          <span class="post__cat">${esc(n.cat)}</span>
        </div>
        <div class="post__body">
          <div class="post__date">${esc(n.date)}</div>
          <h3>${esc(n.title)}</h3>
          <p>${esc(n.text)}</p>
          <a href="#" class="link-arrow">اقرأ المزيد<svg><use href="#i-arrow"/></svg></a>
        </div>
      </article>`).join("");
  }

  function buildGallery() {
    $("#galleryGrid").innerHTML = S.gallery.map((g, i) => `
      <figure class="shot" data-i="${i}" tabindex="0" role="button" aria-label="${esc(g.cap)}">
        ${g.src ? `<img src="${esc(g.src)}" alt="${esc(g.cap)}" loading="lazy">` : artwork(g.seed)}
        ${g.video ? `<span class="shot__play"><svg><use href="#i-play"/></svg></span>` : ""}
        <figcaption class="shot__cap">${esc(g.cap)}</figcaption>
      </figure>`).join("");

    const box = $("#lightbox");
    const open = (i) => {
      const g = S.gallery[i];
      if (!g) return;
      $("#lightboxFigure").innerHTML = g.src
        ? `<img src="${esc(g.src)}" alt="${esc(g.cap)}">`
        : artwork(g.seed);
      $("#lightboxCap").textContent = g.cap;
      box.classList.add("is-open");
      document.body.style.overflow = "hidden";
      $("#lightboxClose").focus();
    };
    const close = () => { box.classList.remove("is-open"); document.body.style.overflow = ""; };

    $("#galleryGrid").addEventListener("click", (e) => {
      const shot = e.target.closest(".shot");
      if (shot) open(Number(shot.dataset.i));
    });
    $("#galleryGrid").addEventListener("keydown", (e) => {
      if (e.key !== "Enter" && e.key !== " ") return;
      const shot = e.target.closest(".shot");
      if (shot) { e.preventDefault(); open(Number(shot.dataset.i)); }
    });
    $("#lightboxClose").addEventListener("click", close);
    box.addEventListener("click", (e) => { if (e.target === box) close(); });
    addEventListener("keydown", (e) => { if (e.key === "Escape") close(); });
  }

  function buildTestimonials() {
    const star = `<svg><use href="#i-star"/></svg>`;
    $("#quotesGrid").innerHTML = S.testimonials.map((t) => `
      <article class="quote">
        <div class="quote__stars">${star.repeat(t.stars)}</div>
        <p>${esc(t.text)}</p>
        <div class="quote__who">
          <div class="quote__ava" style="background:${esc(t.tone)}">${esc(t.name.trim()[0])}</div>
          <div><div class="quote__name">${esc(t.name)}</div><div class="quote__role">${esc(t.role)}</div></div>
        </div>
      </article>`).join("");
  }

  /* ======================================================================
     6. التواصل
     ====================================================================== */
  const waLink = (text) =>
    `https://wa.me/${S.academy.whatsapp}?text=${encodeURIComponent(text)}`;

  function buildContact() {
    const a = S.academy;

    $("#f-interest").innerHTML = S.interests
      .map((i) => `<option value="${esc(i)}">${esc(i)}</option>`).join("");

    $("#reachList").innerHTML = `
      <a class="reach__item" style="--tone:#25D366" href="${esc(waLink("مرحباً، أود الاستفسار عن برامج أكاديمية نواة فليكس."))}" target="_blank" rel="noopener">
        <div class="reach__ico"><svg><use href="#i-wa"/></svg></div>
        <div><div class="reach__label">واتساب — الأسرع للرد</div><div class="reach__value">${esc(a.phone)}</div></div>
      </a>
      <a class="reach__item" href="tel:${esc(a.phone.replace(/\s/g, ""))}">
        <div class="reach__ico"><svg><use href="#i-phone"/></svg></div>
        <div><div class="reach__label">هاتف الأكاديمية</div><div class="reach__value">${esc(a.phone)}</div></div>
      </a>
      <a class="reach__item" style="--tone:#7C3AED" href="mailto:${esc(a.email)}">
        <div class="reach__ico"><svg><use href="#i-mail"/></svg></div>
        <div><div class="reach__label">البريد الإلكتروني</div><div class="reach__value">${esc(a.email)}</div></div>
      </a>
      <div class="reach__item" style="--tone:#F59E0B">
        <div class="reach__ico"><svg><use href="#i-pin"/></svg></div>
        <div><div class="reach__label">العنوان · ${esc(a.hours)}</div><div class="reach__value" style="direction:rtl">${esc(a.address)}</div></div>
      </div>`;

    const socials = [
      { key: "facebook",  icon: "i-fb", tone: "#1877F2", label: "فيسبوك" },
      { key: "instagram", icon: "i-ig", tone: "#E1306C", label: "إنستغرام" },
      { key: "youtube",   icon: "i-yt", tone: "#FF0000", label: "يوتيوب" },
      { key: "linkedin",  icon: "i-li", tone: "#0A66C2", label: "لينكدإن" }
    ].filter((s) => a.social[s.key]);

    const socialHTML = socials.map((s) => `
      <a class="social" style="--tone:${s.tone}" href="${esc(a.social[s.key])}"
         target="_blank" rel="noopener" aria-label="${s.label}"><svg><use href="#${s.icon}"/></svg></a>`).join("");
    $("#socialList").innerHTML = socialHTML;
    $("#footerSocials").innerHTML = socialHTML;

    // الخريطة — تُعرض فقط إذا وُضع رابط التضمين
    $("#mapBox").innerHTML = a.mapEmbed
      ? `<iframe src="${esc(a.mapEmbed)}" loading="lazy" referrerpolicy="no-referrer-when-downgrade" title="موقع الأكاديمية على الخريطة"></iframe>`
      : `<div style="display:grid;place-items:center;height:100%;color:var(--c-text-muted);font-size:var(--t-sm);text-align:center;padding:1rem">
           <div><svg style="width:26px;height:26px;margin:0 auto .5rem;display:block"><use href="#i-pin"/></svg>
           ${esc(a.address)}</div></div>`;

    const wa = waLink("مرحباً، أود الاستفسار عن برامج أكاديمية نواة فليكس.");
    $("#waFloat").href = wa;
    $("#ctaWhatsapp").href = wa;
  }

  function initForm() {
    const form   = $("#contactForm");
    const status = $("#formStatus");
    const btn    = $("#formSubmit");

    const invalid = (field, on) => field.closest(".field").classList.toggle("is-invalid", on);

    form.addEventListener("submit", async (e) => {
      e.preventDefault();
      status.className = "form__status";

      // فخ البوتات: إذا امتلأ الحقل المخفي فهو إرسال آلي — نتجاهله بصمت
      if (form.company.value) return;

      const name    = form.name.value.trim();
      const phone   = form.phone.value.trim();
      const email   = form.email.value.trim();
      const message = form.message.value.trim();

      let ok = true;
      invalid(form.name,  !name);            ok = ok && !!name;
      invalid(form.phone, phone.length < 7); ok = ok && phone.length >= 7;
      invalid(form.message, !message);       ok = ok && !!message;
      const emailBad = email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
      invalid(form.email, emailBad);         ok = ok && !emailBad;
      if (!ok) return;

      const payload = {
        name, phone,
        email: email || null,
        interest: form.interest.value,
        message,
        source: "website"
      };

      btn.disabled = true;
      const original = btn.innerHTML;
      btn.textContent = "جارٍ الإرسال…";

      try {
        await window.API.sendMessage(payload);
        status.className = "form__status is-ok";
        status.textContent = "وصلتنا رسالتك ✅ سنعاود التواصل معك خلال يوم عمل واحد.";
        form.reset();
      } catch (err) {
        // بدون قاعدة بيانات (أو عند تعذّر الاتصال) نحوّل الرسالة إلى واتساب
        const text =
          `رسالة من موقع نواة فليكس\n` +
          `الاسم: ${name}\nالهاتف: ${phone}\n` +
          (email ? `البريد: ${email}\n` : "") +
          `البرنامج: ${form.interest.value}\n\n${message}`;
        // ملاحظة: لا نستدعي window.open هنا — المتصفحات تحجب النوافذ المنبثقة
        // التي تُفتح بعد await لانقطاع سلسلة تفاعل المستخدم. نعرض رابطاً يضغطه بنفسه.
        status.className = "form__status is-ok";
        status.innerHTML =
          `بقيت خطوة واحدة — <a href="${waLink(text)}" target="_blank" rel="noopener" ` +
          `style="font-weight:800;text-decoration:underline">اضغط هنا لإرسال رسالتك عبر واتساب</a> ` +
          `(بياناتك محفوظة في الرسالة، ما عليك سوى الضغط على إرسال).`;
        console.warn("[contact] تعذّر الإرسال إلى Supabase:", err.message);
      } finally {
        btn.disabled = false;
        btn.innerHTML = original;
      }
    });

    // النشرة البريدية
    const nForm = $("#newsletterForm");
    const nStat = $("#newsStatus");
    nForm.addEventListener("submit", async (e) => {
      e.preventDefault();
      const email = nForm.querySelector("input").value.trim();
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        nStat.className = "form__status is-err";
        nStat.textContent = "صيغة البريد غير صحيحة.";
        return;
      }
      try {
        await window.API.subscribe(email);
        nStat.className = "form__status is-ok";
        nStat.textContent = "تم الاشتراك ✅";
        nForm.reset();
      } catch (err) {
        nStat.className = "form__status is-err";
        nStat.textContent = "تعذّر الاشتراك حالياً، جرّب لاحقاً.";
        console.warn("[newsletter]", err.message);
      }
    });
  }

  /* ======================================================================
     7. الظهور عند التمرير
     ====================================================================== */
  function initReveal() {
    const io = new IntersectionObserver((entries) => {
      entries.forEach((en) => {
        if (!en.isIntersecting) return;
        en.target.classList.add("is-in");
        io.unobserve(en.target);
      });
    }, { threshold: .12, rootMargin: "0px 0px -8% 0px" });
    $$(".reveal, .reveal-stagger").forEach((el) => io.observe(el));
  }

  /* ======================================================================
     8. الإقلاع
     ====================================================================== */
  buildNav();
  buildStats();
  buildAbout();
  buildPrograms();
  buildFlexMind();
  buildEvents();
  buildAchievements();
  buildPartners();
  buildNews();
  buildGallery();
  buildTestimonials();
  buildContact();
  initHeader();
  initHeroCanvas();
  initForm();
  initReveal();

  $("#year").textContent = new Date().getFullYear();
})();
