// Gauntlet shared data + helpers. Loaded by every form and the dashboard.
"use strict";

const COMPETITORS = [1, 2, 3, 4, 5, 6].map(n => ({ n, label: `${n} · vort-lance` }));
const JUDGES = ["judge-1", "judge-2", "backup"];
const MAX = { challenge: 500, copy: 400 };

// 23 features: id, name, figma ref (community file), code location
const FEATURES = [
  { id: "feat-01", name: "Premium Theme Market", figma: "1-3", code: "lib/features/theme" },
  { id: "feat-02", name: "Music Widget & Theme Market Alt", figma: "417-1777", code: "lib/features/music + theme" },
  { id: "feat-03", name: "Theme Gallery", figma: "69-1926", code: "lib/features/theme + core/theme" },
  { id: "feat-04", name: "Files Screen", figma: "71-7502", code: "lib/features/files" },
  { id: "feat-05", name: "Composer / Message Bar", figma: "1-240 (reviewed)", code: "lib/features/prompt" },
  { id: "feat-06", name: "In-App Web Browser", figma: "1-71", code: "lib/features/browser" },
  { id: "feat-07", name: "Media Gen Ticker", figma: "26-1004", code: "lib/features/mediagen" },
  { id: "feat-08", name: "Media Gen Options Overlay", figma: "417-15864", code: "lib/features/mediagen" },
  { id: "feat-09", name: "Settings - Account Tab", figma: "417-8552", code: "lib/features/account" },
  { id: "feat-10", name: "Video Playback", figma: "417-8630", code: "lib/features/files/widgets" },
  { id: "feat-11", name: "Files - Music Video Platforms", figma: "417-6219", code: "lib/features/files + music" },
  { id: "feat-12", name: "Discover Market Templates", figma: "203-5891", code: "lib/features/market" },
  { id: "feat-13", name: "Settings Alert/Popup", figma: "130-75006", code: "lib/features/drawers" },
  { id: "feat-14", name: "Smart Gen - Kanban Board", figma: "2012-201531", code: "lib/features/smartgen" },
  { id: "feat-15", name: "Smart Gen - Inline Editing", figma: "59-170", code: "lib/features/smartgen" },
  { id: "feat-16", name: "Settings Drawer", figma: "0-1", code: "lib/features/drawers" },
  { id: "feat-17", name: "Consensus View", figma: "internal", code: "lib/features/consensus" },
  { id: "feat-18", name: "Navigation - Side Nav Rail", figma: "internal", code: "lib/features/nav" },
  { id: "feat-19", name: "Apps Popup Pane", figma: "internal", code: "lib/features/apps" },
  { id: "feat-20", name: "Model Ladder Drawer", figma: "internal", code: "lib/features/drawers" },
  { id: "feat-21", name: "Windowless Theme Scroller", figma: "internal", code: "lib/features/wallpaperwidgets" },
  { id: "feat-22", name: "Local History Pane", figma: "internal", code: "lib/features/stickerwidgets" },
  { id: "feat-23", name: "Figma Stage / F-Rail", figma: "internal", code: "lib/core/figma" },
];

// Deviation penalty per rules §6.3: 1=5%, 2=10%, 3=15%, >=4 → score 0
function devPenalty(d) {
  d = Number(d) || 0;
  if (d <= 0) return 0;
  if (d === 1) return 0.05;
  if (d === 2) return 0.10;
  if (d === 3) return 0.15;
  return 1.0;
}
function categoryOf(pct) {
  if (pct >= 0.85) return "Superior";
  if (pct >= 0.70) return "Qualified";
  return "Unqualified";
}
function compLabel(n) { return `${n} · vort-lance`; }
function featName(id) { const f = FEATURES.find(x => x.id === id); return f ? f.name : id; }

// ---- persistence (localStorage, keys g:r{round}:{kind}:{id}) ----
function entryKey(round, kind, id) { return `g:r${round}:${kind}:${id}`; }
function saveEntry(round, kind, id, obj) { localStorage.setItem(entryKey(round, kind, id), JSON.stringify(obj)); }
function allEntries(prefix) {
  const out = [];
  for (let i = 0; i < localStorage.length; i++) {
    const k = localStorage.key(i);
    if (k && k.startsWith(prefix)) {
      try { out.push({ key: k, ...JSON.parse(localStorage.getItem(k)) }); } catch (e) { /* skip */ }
    }
  }
  return out;
}
function roundEntries(round) {
  return {
    featureVotes: allEntries(`g:r${round}:fv:`),
    submissions: allEntries(`g:r${round}:sub:`),
    judgeScores: allEntries(`g:r${round}:js:`),
    h2hVotes: allEntries(`g:r${round}:h2h:`),
  };
}
function classifyStored(obj) {
  if ("featureId" in obj && "voter" in obj) return { kind: "fv", id: obj.voter };
  if ("branch" in obj && "competitor" in obj) return { kind: "sub", id: "c" + obj.competitor };
  if (("challenge" in obj || "copy" in obj) && "judge" in obj) return { kind: "js", id: `${obj.judge}:c${obj.competitor}` };
  if ("votedFor" in obj && "a" in obj) return { kind: "h2h", id: obj.voter };
  return null;
}
function deleteEntry(key) { localStorage.removeItem(key); }
function downloadJSON(obj, filename) {
  const blob = new Blob([JSON.stringify(obj, null, 2)], { type: "application/json" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = filename;
  a.click();
  URL.revokeObjectURL(a.href);
}

// ---- UI shell ----
const CSS = `
:root { --bg:#0a0a0c; --panel:#141419; --panel2:#1b1b22; --fg:#ececf1; --mut:#9a9aa5; --line:#2a2a33;
  --acc:#c8ccd4; --good:#4ade80; --warn:#fbbf24; --bad:#f87171; }
* { box-sizing:border-box; margin:0; }
body { background:var(--bg); color:var(--fg); font:15px/1.5 "Segoe UI", system-ui, sans-serif; padding:24px; max-width:1100px; margin:0 auto; }
h1 { font-size:22px; font-weight:600; letter-spacing:-0.02em; }
h2 { font-size:16px; font-weight:600; margin:20px 0 8px; color:var(--acc); }
.sub { color:var(--mut); font-size:13px; margin-top:2px; }
header { display:flex; justify-content:space-between; align-items:center; margin-bottom:18px; border-bottom:1px solid var(--line); padding-bottom:14px; }
nav a { color:var(--mut); text-decoration:none; margin-left:14px; font-size:13px; }
nav a:hover { color:var(--fg); }
.panel { background:var(--panel); border:1px solid var(--line); border-radius:12px; padding:16px; margin-bottom:14px; }
label { display:block; font-size:12px; color:var(--mut); margin:10px 0 4px; text-transform:uppercase; letter-spacing:0.05em; }
select, input, textarea { width:100%; background:var(--panel2); color:var(--fg); border:1px solid var(--line); border-radius:8px; padding:8px 10px; font:inherit; }
textarea { resize:vertical; min-height:70px; }
button { background:var(--acc); color:#0a0a0c; border:0; border-radius:8px; padding:8px 16px; font:inherit; font-weight:600; cursor:pointer; }
button.ghost { background:transparent; color:var(--mut); border:1px solid var(--line); font-weight:400; }
button:hover { filter:brightness(1.1); }
.row { display:flex; gap:12px; } .row > * { flex:1; }
table { width:100%; border-collapse:collapse; font-size:13px; }
th { text-align:left; color:var(--mut); font-weight:500; font-size:11px; text-transform:uppercase; letter-spacing:0.05em; padding:6px 8px; border-bottom:1px solid var(--line); }
td { padding:8px; border-bottom:1px solid var(--line); vertical-align:top; }
.tag { display:inline-block; padding:2px 8px; border-radius:99px; font-size:11px; font-weight:600; }
.t-superior { background:#14331f; color:var(--good); } .t-qualified { background:#332a14; color:var(--warn); }
.t-unqualified { background:#331a1a; color:var(--bad); } .t-copy { background:#1b1b22; color:var(--mut); }
.t-challenge { background:#14202e; color:#7db4e0; }
.win { outline:2px solid var(--good); border-radius:8px; }
.muted { color:var(--mut); } .mono { font-family:Consolas, monospace; font-size:12px; }
.score-big { font-size:22px; font-weight:700; }
`;

function shell(title, subtitle) {
  document.title = title;
  const style = document.createElement("style"); style.textContent = CSS; document.head.appendChild(style);
  document.body.innerHTML = `
    <header>
      <div><h1>${title}</h1><div class="sub">${subtitle}</div></div>
      <nav>
        <a href="feature-vote.html">Feature Vote</a>
        <a href="submission-log.html">Submissions</a>
        <a href="judge-scoring.html">Judging</a>
        <a href="head-to-head-vote.html">Head-to-Head</a>
        <a href="../dashboard.html">Dashboard</a>
      </nav>
    </header>
    <main id="main"></main>`;
  return document.getElementById("main");
}

function selRound() {
  return `<label>Round</label><select id="round">${[1,2,3,4,5,6,7,8].map(r => `<option value="${r}">Round ${r}</option>`).join("")}</select>`;
}
function selCompetitor(id = "competitor") {
  return `<label>Competitor</label><select id="${id}">${COMPETITORS.map(c => `<option value="${c.n}">${c.label}</option>`).join("")}</select>`;
}
function getRound() { return Number(document.getElementById("round").value); }
