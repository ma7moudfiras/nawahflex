/* ==========================================================================
   أكاديمية نواة — منطق الواجهة
   لا اعتماديات، لا خطوة بناء. يعمل بفتح index.html مباشرة.
   ========================================================================== */
(function () {
  "use strict";

  const S = window.SITE;
  const $  = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];

  /* ======================================================================
     1. أدوات النص
     ====================================================================== */

  /** تهريب النص لمنع حقن HTML عند وضع محتوى من مصدر خارجي */
  const esc = (str) => String(str ?? "").replace(/[&<>"']/g,
    (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

  /** قيمة مكتوبة بين قوسين مربّعين في content.js = بيانات لم تصل بعد */
  const isPh = (v) => typeof v === "string" && /^\[.*\]$/.test(v.trim());

  /** يعرض القيمة: نصاً عادياً، أو خانة فارغة منسّقة إن كانت بين قوسين */
  const val = (v) => isPh(v)
    ? `<span class="ph">${esc(v.trim().slice(1, -1))}</span>`
    : esc(v);

  /** ترقيم البطاقات: 01، 02… — بالأرقام نفسها المستعملة في باقي النصوص */
  const num2 = (n) => String(n).padStart(2, "0");

  /** إطار صورة لم تصل بعد — يحمل شعاراً باهتاً لا رمزاً عامّاً */
  const emptyFrame = (cls = "") =>
    `<div class="frame-empty ${cls}"><svg aria-hidden="true"><use href="#logo-s"/></svg>صورة</div>`;

  /* ======================================================================
     2. التنقّل والترويسة
     ====================================================================== */
  function buildNav() {
    const items = S.nav.map((n) => `<li><a href="${esc(n.href)}">${esc(n.label)}</a></li>`).join("");
    $("#mainNav ul").innerHTML = items;
    $("#mobileNav ul").innerHTML = items;
    $("#footerNav").innerHTML = items;
    $("#footerPrograms").innerHTML = S.programs
      .map((p) => `<li><a href="#programs">${esc(p.title)}</a></li>`).join("");
  }

  function initHeader() {
    const header = $("#header");
    const burger = $("#burger");
    const mnav   = $("#mobileNav");

    const onScroll = () => header.classList.toggle("is-scrolled", window.scrollY > 8);
    onScroll();
    addEventListener("scroll", onScroll, { passive: true });

    const setOpen = (open) => {
      mnav.classList.toggle("is-open", open);
      burger.classList.toggle("is-open", open);
      burger.setAttribute("aria-expanded", String(open));
      document.body.style.overflow = open ? "hidden" : "";
    };
    burger.addEventListener("click", () => setOpen(!mnav.classList.contains("is-open")));
    // إغلاق القائمة عند اختيار رابط، أو بزر Escape
    mnav.addEventListener("click", (e) => { if (e.target.closest("a")) setOpen(false); });
    addEventListener("keydown", (e) => {
      if (e.key === "Escape" && mnav.classList.contains("is-open")) { setOpen(false); burger.focus(); }
    });
    // القائمة لا تبقى مفتوحة إن اتّسعت الشاشة وظهر شريط التنقّل
    matchMedia("(min-width: 1061px)").addEventListener("change", (m) => { if (m.matches) setOpen(false); });

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
     3. أرقام الأكاديمية
     ====================================================================== */
  function buildStats() {
    const value = (v) => v === "auto:programs" ? esc(S.programs.length) : val(v);
    $("#statsGrid").innerHTML = S.stats.map((s) => `
      <div class="fact"><dt>${esc(s.label)}</dt><dd>${value(s.value)}</dd></div>`).join("");
  }

  /* ======================================================================
     4. الأقسام المبنية من content.js
     ====================================================================== */
  function buildAbout() {
    $("#aboutLead").textContent = S.about.lead;
    $("#aboutBody").innerHTML = S.about.body.map((p) => `<p>${esc(p)}</p>`).join("");
    $("#pillars").innerHTML = S.about.pillars.map((p) => `
      <li class="pillar"><h3>${esc(p.title)}</h3><p>${esc(p.text)}</p></li>`).join("");
  }

  function buildPrograms() {
    $("#programsGrid").innerHTML = S.programs.map((p, i) => `
      <article class="prog">
        <span class="prog__num">${num2(i + 1)}</span>
        <h3>${esc(p.title)}</h3>
        <p>${esc(p.text)}</p>
        <div class="prog__meta">${(p.tags || []).map((t) => `<span class="tag">${val(t)}</span>`).join("")}</div>
      </article>`).join("") + `
      <a class="prog prog--ask" href="#contact">
        <span class="prog__num">؟</span>
        <h3>لا تعرف أي مسار يناسب طفلك؟</h3>
        <p>في الجلسة التعريفية نتعرّف على اهتماماته ونقترح المسار الأنسب لعمره.</p>
        <span class="link-arrow">احجز جلسة تعريفية<svg aria-hidden="true"><use href="#i-arrow"/></svg></span>
      </a>`;
  }

  function buildEvents() {
    $("#eventsGrid").innerHTML = S.events.map((e) => `
      <li class="event">
        <div class="event__date">
          <span class="event__day">${val(e.day)}</span>
          <span class="event__mon">${val(e.month)}</span>
        </div>
        <div>
          <h3>${val(e.title)}</h3>
          <div class="event__info">
            <span><svg aria-hidden="true"><use href="#i-pin"/></svg>${val(e.place)}</span>
            <span><svg aria-hidden="true"><use href="#i-clock"/></svg>${val(e.time)}</span>
          </div>
          <p>${val(e.desc)}</p>
        </div>
        <a href="#contact" class="link-arrow">سجّل اهتمامك<svg aria-hidden="true"><use href="#i-arrow"/></svg></a>
      </li>`).join("");
  }

  function buildAchievements() {
    $("#achGrid").innerHTML = S.achievements.map((a) => `
      <article class="ach__item">
        <span class="ach__year">${val(a.year)}</span>
        <h3>${val(a.title)}</h3>
        <p>${val(a.text)}</p>
      </article>`).join("");
  }

  function buildGallery() {
    $("#galleryGrid").innerHTML = S.gallery.map((g, i) => {
      const media = g.src
        ? `<button type="button" class="shot__media" data-i="${i}" aria-label="عرض: ${esc(isPh(g.cap) ? "صورة" : g.cap)}">
             <img src="${esc(g.src)}" alt="${esc(isPh(g.cap) ? "" : g.cap)}" loading="lazy">
             ${g.video ? `<span class="shot__play"><svg aria-hidden="true"><use href="#i-play"/></svg></span>` : ""}
           </button>`
        : `<div class="shot__media">${emptyFrame()}</div>`;
      return `<figure class="shot">${media}<figcaption>${val(g.cap)}</figcaption></figure>`;
    }).join("");

    const box = $("#lightbox");
    let opener = null;
    const open = (i, from) => {
      const g = S.gallery[i];
      if (!g || !g.src) return;
      opener = from;
      $("#lightboxFigure").innerHTML = `<img src="${esc(g.src)}" alt="${esc(isPh(g.cap) ? "" : g.cap)}">`;
      $("#lightboxCap").innerHTML = val(g.cap);
      box.classList.add("is-open");
      document.body.style.overflow = "hidden";
      $("#lightboxClose").focus();
    };
    const close = () => {
      if (!box.classList.contains("is-open")) return;
      box.classList.remove("is-open");
      document.body.style.overflow = "";
      if (opener) opener.focus();
    };

    $("#galleryGrid").addEventListener("click", (e) => {
      const btn = e.target.closest("button.shot__media");
      if (btn) open(Number(btn.dataset.i), btn);
    });
    $("#lightboxClose").addEventListener("click", close);
    box.addEventListener("click", (e) => { if (e.target === box) close(); });
    addEventListener("keydown", (e) => { if (e.key === "Escape") close(); });
  }

  function buildTestimonials() {
    $("#quotesGrid").innerHTML = S.testimonials.map((t) => `
      <figure class="quote">
        <blockquote>${val(t.text)}</blockquote>
        <figcaption><b>${val(t.name)}</b><span>${val(t.role)}</span></figcaption>
      </figure>`).join("");
  }

  function buildNews() {
    $("#newsGrid").innerHTML = S.news.map((n, i) => `
      <article class="post ${i === 0 ? "post--lead" : ""}">
        <div class="post__thumb">${n.src
          ? `<img src="${esc(n.src)}" alt="" loading="lazy">`
          : emptyFrame()}</div>
        <div>
          <div class="post__meta"><span class="post__cat">${val(n.cat)}</span><span>${val(n.date)}</span></div>
          <h3>${val(n.title)}</h3>
          <p>${val(n.text)}</p>
        </div>
      </article>`).join("");
  }

  function buildPartners() {
    $("#partnersGrid").innerHTML = S.partners.map((p) => `
      <li class="partner">
        ${p.logo
          ? `<img src="${esc(p.logo)}" alt="${esc(isPh(p.name) ? "شريك" : p.name)}" loading="lazy">`
          : `<span>${val(p.name)}</span>`}
        <span class="partner__type">${val(p.type)}</span>
      </li>`).join("");
  }

  /* ======================================================================
     5. التواصل
     ====================================================================== */
  const hasWhatsapp = () => /^\d{8,15}$/.test(String(S.academy.whatsapp || ""));
  const waLink = (text) =>
    `https://wa.me/${S.academy.whatsapp}?text=${encodeURIComponent(text)}`;

  function buildContact() {
    const a = S.academy;

    $("#f-interest").innerHTML = S.interests
      .map((i) => `<option value="${esc(i)}">${esc(i)}</option>`).join("");

    // كل وسيلة تواصل رابطٌ حين تكون حقيقية، وخانةٌ فارغة حين تكون بين قوسين
    const item = (icon, label, value, href, ltr) => {
      const inner = `
        <span class="reach__ico"><svg aria-hidden="true"><use href="#${icon}"/></svg></span>
        <span><span class="reach__label">${esc(label)}</span><br>
        <span class="reach__value"${ltr && !isPh(value) ? ' dir="ltr"' : ""}>${val(value)}</span></span>`;
      return href && !isPh(value)
        ? `<li><a class="reach__item" href="${esc(href)}"${href.startsWith("http") ? ' target="_blank" rel="noopener"' : ""}>${inner}</a></li>`
        : `<li><div class="reach__item">${inner}</div></li>`;
    };

    $("#reachList").innerHTML = [
      hasWhatsapp() ? item("i-wa", "واتساب — الأسرع للرد", a.phone, waLink("مرحباً، أود الاستفسار عن مسارات أكاديمية نواة."), true) : "",
      item("i-phone", "الهاتف", a.phone, "tel:" + String(a.phone).replace(/\s/g, ""), true),
      item("i-mail", "البريد الإلكتروني", a.email, "mailto:" + a.email, true),
      item("i-pin", "العنوان", a.address, ""),
      item("i-clock", "ساعات الدوام", a.hours, "")
    ].join("");

    const socials = [
      { key: "facebook",  icon: "i-fb", label: "فيسبوك" },
      { key: "instagram", icon: "i-ig", label: "إنستغرام" },
      { key: "youtube",   icon: "i-yt", label: "يوتيوب" },
      { key: "linkedin",  icon: "i-li", label: "لينكدإن" }
    ].filter((s) => a.social[s.key]);

    const socialHTML = socials.map((s) => `
      <a class="social" href="${esc(a.social[s.key])}" target="_blank" rel="noopener" aria-label="${s.label}">
        <svg aria-hidden="true"><use href="#${s.icon}"/></svg></a>`).join("");
    $("#socialList").innerHTML = socialHTML;
    $("#footerSocials").innerHTML = socialHTML;

    // الخريطة — تُعرض فقط إذا وُضع رابط التضمين
    $("#mapBox").innerHTML = a.mapEmbed
      ? `<iframe src="${esc(a.mapEmbed)}" loading="lazy" referrerpolicy="no-referrer-when-downgrade" title="موقع الأكاديمية على الخريطة"></iframe>`
      : `<div class="frame-empty" style="height:100%"><svg aria-hidden="true"><use href="#i-pin"/></svg>الخريطة</div>`;

    // روابط واتساب تظهر فقط حين يكون الرقم حقيقياً
    if (hasWhatsapp()) {
      const wa = waLink("مرحباً، أود الاستفسار عن مسارات أكاديمية نواة.");
      $("#waFloat").href = wa;      $("#waFloat").hidden = false;
      $("#ctaWhatsapp").href = wa;  $("#ctaWhatsapp").hidden = false;
    }
  }

  function initForm() {
    const form   = $("#contactForm");
    const status = $("#formStatus");
    const btn    = $("#formSubmit");

    const invalid = (field, on) => field.closest(".field").classList.toggle("is-invalid", on);

    form.addEventListener("submit", async (e) => {
      e.preventDefault();
      status.className = "form__status";
      status.textContent = "";

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
      if (!ok) { $(".is-invalid input, .is-invalid textarea", form)?.focus(); return; }

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
        status.textContent = "وصلتنا رسالتك. سنعاود التواصل معك خلال يوم عمل واحد.";
        form.reset();
      } catch (err) {
        console.warn("[contact] تعذّر الإرسال إلى Supabase:", err.message);
        if (hasWhatsapp()) {
          // بدون قاعدة بيانات (أو عند تعذّر الاتصال) نحوّل الرسالة إلى واتساب.
          // لا نستدعي window.open هنا — المتصفحات تحجب النوافذ المنبثقة التي
          // تُفتح بعد await. نعرض رابطاً يضغطه الزائر بنفسه.
          const text =
            `رسالة من موقع أكاديمية نواة\n` +
            `الاسم: ${name}\nالهاتف: ${phone}\n` +
            (email ? `البريد: ${email}\n` : "") +
            `المسار: ${form.interest.value}\n\n${message}`;
          status.className = "form__status is-ok";
          status.innerHTML =
            `بقيت خطوة واحدة — <a href="${esc(waLink(text))}" target="_blank" rel="noopener" ` +
            `style="font-weight:700;text-decoration:underline">اضغط هنا لإرسال رسالتك عبر واتساب</a>.`;
        } else {
          status.className = "form__status is-err";
          status.textContent = "تعذّر إرسال الرسالة الآن. حاول بعد قليل من فضلك.";
        }
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
        nStat.textContent = "تم الاشتراك.";
        nForm.reset();
      } catch (err) {
        nStat.className = "form__status is-err";
        nStat.textContent = "تعذّر الاشتراك حالياً، جرّب لاحقاً.";
        console.warn("[newsletter]", err.message);
      }
    });
  }

  /* ======================================================================
     6. الإقلاع
     ====================================================================== */
  buildNav();
  buildStats();
  buildAbout();
  buildPrograms();
  buildEvents();
  buildAchievements();
  buildGallery();
  buildTestimonials();
  buildNews();
  buildPartners();
  buildContact();
  initHeader();
  initForm();

  $("#year").textContent = new Date().getFullYear();
})();
