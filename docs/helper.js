// Mosque timetable helper: 100% client-side. No API, no fetch, no scraping.
// Tool 1 builds a public DuckDuckGo hyperlink; tool 2 regexes a pasted URL;
// tool 3 concatenates the /calendar/ID/choice link the user clicks themselves.
// Tool 2b is a bookmarklet the USER runs on the mosque page: it reads the
// ID from that page's own HTML (footer #256 / manifest / data-remote).
(function () {
  "use strict";
  function $(id) { return document.getElementById(id); }
  function copyText(text, btn) {
    var done = function () {
      var old = btn.textContent;
      btn.textContent = "Copied \u2713";
      setTimeout(function () { btn.textContent = old; }, 1600);
    };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(done, done);
    } else {
      var ta = document.createElement("textarea");
      ta.value = text; ta.style.position = "absolute"; ta.style.left = "-9999px";
      document.body.appendChild(ta); ta.select();
      try { document.execCommand("copy"); } catch (e) {}
      ta.remove(); done();
    }
  }
  var searchInput = $("mosque-search"), searchBtn = $("mosque-search-btn"), searchPreview = $("search-preview");
  function searchURL() {
    var q = (searchInput.value || "").trim() || "mosquee";
    return "https://html.duckduckgo.com/html/?q=" + encodeURIComponent("site:mawaqit.net " + q);
  }
  if (searchInput && searchBtn) {
    if (searchPreview) { searchInput.addEventListener("input", function () { searchPreview.textContent = searchURL(); }); }
    var doSearch = function () { window.open(searchURL(), "_blank", "noopener"); };
    searchBtn.addEventListener("click", doSearch);
    searchInput.addEventListener("keydown", function (e) { if (e.key === "Enter") doSearch(); });
  }
  var urlInput = $("mosque-url"), parseBtn = $("mosque-parse-btn"),
      visitBtn = $("mosque-visit-btn"),
      result = $("parse-result"), idInput = $("mosque-id");
  function normalizeURL(raw) {
    var s = (raw || "").trim();
    if (!s) return "";
    if (!/^[a-z][a-z0-9+.-]*:\/\//i.test(s)) return "https://" + s;
    return s;
  }
  function openURLInput() {
    var href = normalizeURL(urlInput.value);
    if (!href) { urlInput.focus(); return; }
    try { new URL(href); } catch (e) { urlInput.focus(); return; }
    window.open(href, "_blank", "noopener");
  }
  if (visitBtn) {
    visitBtn.addEventListener("click", openURLInput);
    urlInput.addEventListener("keydown", function (e) { if (e.key === "Enter" && e.metaKey) openURLInput(); });
  }
  var BOOKMARKLET = "javascript:(function(){var d=document,h=d.documentElement.outerHTML,m=h.match(/manifest\\/(\\d{1,7})/)||h.match(/\\/id\\/(\\d{1,7})\\//)||h.match(/#(\\d{2,7})</)||h.match(/mosqueId\\s*=\\s*(\\d{1,7})/);var id=m?m[1]:'';if(id){prompt('Mosque ID (copy it, then paste in step 3):',id);}else{alert('No ID found on this page. Look at the bottom-left corner for its number.');}})();";
  function extractId(raw) {
    var s = (raw || "").trim();
    if (!s) return { ok: false, reason: "empty" };
    if (!/mawaqit\.net/i.test(s)) return { ok: false, reason: "not-mawaqit" };
    var m;
    m = s.match(/\/calendar\/(\d{1,7})/i);
    if (m) return { ok: true, id: m[1], how: "calendar/ID in the address" };
    m = s.match(/[?&](?:mosque|mosquee|moskee|id)=(\d{1,7})/i);
    if (m) return { ok: true, id: m[1], how: "?mosque=ID in the address" };
    m = s.match(/[\-\/](\d{2,7})(?:[\-\/]|$|[?#])/);
    if (m) return { ok: true, id: m[1], how: "number in the page address" };
    if (/\/m\//.test(s)) return { ok: false, reason: "slug" };
    return { ok: false, reason: "no-id" };
  }
  function showBookmarkletTip(container) {
    var tip = document.createElement("div");
    tip.className = "helper__bookmark";
    var p = document.createElement("p");
    p.innerHTML = "<strong>This address has no ID in it</strong> (normal for slug pages). Two options:";
    tip.appendChild(p);
    var ol = document.createElement("ol");
    var li1 = document.createElement("li");
    li1.textContent = "Open the page (Open page button above), find its number at the bottom-left corner (e.g. #256), and type it in step 3 — or use the page's own download button.";
    var li2 = document.createElement("li");
    li2.textContent = "Or drag this button to your bookmarks bar, open the mosque page, click it — it reads the ID from the page you are viewing: ";
    var bm = document.createElement("a");
    bm.href = BOOKMARKLET;
    bm.className = "button helper__btn helper__btn--small";
    bm.textContent = "Get mosque ID";
    bm.addEventListener("click", function (e) { e.preventDefault(); });
    li2.appendChild(bm);
    ol.appendChild(li1); ol.appendChild(li2);
    tip.appendChild(ol);
    container.appendChild(tip);
  }
  function updateCalendarLinks() {
    var links = $("calendar-links");
    var id = (idInput.value || "").trim().replace(/\D+/g, "");
    if (!id || !links) { if (links) links.hidden = true; return; }
    links.hidden = false;
    $("cal-nl").href = "https://mawaqit.net/nl/calendar/" + id + "/choice";
    $("cal-fr").href = "https://mawaqit.net/fr/calendar/" + id + "/choice";
    $("cal-en").href = "https://mawaqit.net/en/calendar/" + id + "/choice";
  }
  if (parseBtn) {
    parseBtn.addEventListener("click", function () {
      var r = extractId(urlInput.value);
      result.hidden = false;
      result.innerHTML = "";
      if (r.ok) {
        idInput.value = r.id;
        updateCalendarLinks();
        var b = document.createElement("p");
        var strong = document.createElement("strong");
        strong.className = "mono helper__id"; strong.textContent = r.id;
        b.textContent = "Mosque ID: ";
        b.appendChild(strong);
        var note = document.createElement("span");
        note.className = "helper__note"; note.textContent = " (" + r.how + ")";
        b.appendChild(note);
        var c = document.createElement("button");
        c.className = "button helper__btn helper__btn--small"; c.type = "button"; c.textContent = "Copy ID";
        c.addEventListener("click", function () { copyText(r.id, c); });
        result.appendChild(b); result.appendChild(c);
        document.getElementById("tool3").scrollIntoView({ behavior: "smooth", block: "nearest" });
      } else if (r.reason === "slug" || r.reason === "no-id") {
        var p = document.createElement("p");
        p.textContent = "No ID found in that address — it is a name-based (slug) page.";
        result.appendChild(p);
        showBookmarkletTip(result);
      } else if (r.reason === "not-mawaqit") {
        result.innerHTML = "<p>That does not look like a timetable-provider address. Search in step 1, open your mosque, and paste its address here.</p>";
      } else if (r.reason === "empty") {
        result.innerHTML = "<p>Paste your mosque's timetable-provider address above first.</p>";
      }
    });
  }
  var openBtn = $("mosque-open-btn"), copyBtn = $("mosque-copy-btn");
  function calURL() {
    var id = (idInput.value || "").trim().replace(/\D+/g, "") || "256";
    return "https://mawaqit.net/nl/calendar/" + id + "/choice";
  }
  if (idInput) idInput.addEventListener("input", updateCalendarLinks);
  if (openBtn) openBtn.addEventListener("click", function () {
    if (!(idInput.value || "").trim().replace(/\D+/g, "")) { idInput.focus(); return; }
    updateCalendarLinks();
    window.open(calURL(), "_blank", "noopener");
  });
  if (copyBtn) copyBtn.addEventListener("click", function () {
    if (!(idInput.value || "").trim().replace(/\D+/g, "")) { idInput.focus(); return; }
    copyText(calURL(), copyBtn);
  });
  var bmBtn = $("bookmarklet-btn");
  if (bmBtn) bmBtn.href = BOOKMARKLET;
})();
