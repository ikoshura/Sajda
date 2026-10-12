// Mosque timetable helper: 100% client-side. No API, no fetch, no scraping.
// Tool 1 builds a public DuckDuckGo hyperlink; tool 2 is a visual guide
// (ID printed on the mosque page, bottom-left corner); tool 3 concatenates
// the /calendar/ID/choice link the user clicks themselves.
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
  var idInput = $("mosque-id");
  var openBtn = $("mosque-open-btn"), copyBtn = $("mosque-copy-btn");
  function calURL() {
    var id = (idInput.value || "").trim().replace(/\D+/g, "") || "256";
    // English is the default: its /calendar/ download reliably produces a
    // text-based PDF (selectable, importable). Some other locales recently
    // served a visually-correct but text-empty export that no app can read.
    return "https://mawaqit.net/en/calendar/" + id + "/choice";
  }
  if (openBtn) openBtn.addEventListener("click", function () {
    if (!(idInput.value || "").trim().replace(/\D+/g, "")) { idInput.focus(); return; }
    window.open(calURL(), "_blank", "noopener");
  });
  if (copyBtn) copyBtn.addEventListener("click", function () {
    if (!(idInput.value || "").trim().replace(/\D+/g, "")) { idInput.focus(); return; }
    copyText(calURL(), copyBtn);
  });
})();
