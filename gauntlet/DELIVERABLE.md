# DELIVERABLE — Collider OS Gauntlet

Everything built for the competition, where it lives, and how a round runs.

---

## 1. The repo

**https://github.com/Davidebri1/collider-cos-gauntlet** (private)

| Branch | Purpose |
|---|---|
| `main` | clean COS base (`1fbd207`) + all gauntlet tooling |
| `1-vort-lance` … `6-vort-lance` | one per competitor — submissions land here |
| worktrees `worktrees/{branch}` | each competitor's physical working copy (gitignored) |

Local project folder: `C:\Users\D\Documents\collider COS gauntlet`

## 2. Roster (number → nickname → model)

**Organizer-private** — `gauntlet/roster.local.json`, gitignored. Competitors only ever see numbers.

| # | Nickname | Model |
|---|---|---|
| 1 | vort-lance | Deepseek 4.1 Flash |
| 2 | vort-lance | Minimax M3 |
| 3 | vort-lance | GLM 5.3 Flash |
| 4 | vort-lance | Mimo 2.6 Pro |
| 5 | vort-lance | GPT 6 Sol |
| 6 | vort-lance | Qwen 3.8 Omni Flash |

Kimi K3 excluded (assigned elsewhere).

## 3. The rules and the surfaces

| Item | Path |
|---|---|
| Rules (inline, canonical) | `gauntlet/README.md` |
| Judge cheat sheet | `gauntlet/cheatsheets/judges.md` |
| Competitor cheat sheet | `gauntlet/cheatsheets/competitors.md` |
| Jury/crowd cheat sheet | `gauntlet/cheatsheets/crowd-voting.md` |
| Reference map (27 rows + requirements) | `gauntlet/figma-reference-map.pdf` |
| **Physical references, one per row** | `gauntlet/reference/per-row/` |
| Row → feature → node → code table | `gauntlet/reference/ROW-REFERENCE.md` |

### Forms (open in any browser, no build, no server)
| Phase | Form |
|---|---|
| Round-opening feature vote + copy/challenge intent | `gauntlet/forms/feature-vote.html` |
| Submission log (branch, intent, notes) | `gauntlet/forms/submission-log.html` |
| Judge scoring (challenge 500 / copy 400 + deviation counter) | `gauntlet/forms/judge-scoring.html` |
| Head-to-head jury vote (mandatory reasons) | `gauntlet/forms/head-to-head-vote.html` |
| **Results dashboard** (import exports → scores, categories, h2h, power rankings) | `gauntlet/dashboard.html` |

Every form saves locally and exports JSON; commit exports to `gauntlet/results/` as the round record.

## 4. Reference library (4.4 GB, two locations)

- `C:\Users\D\Documents\Collider Figma Consolidated\` — `index.html` gallery, `INDEX.md` manifest
- `P:\My Drive\Collider Figma Consolidated\` — same, synced

Buckets: reference map · `.fig` sources · 751 visionOS/community reference images · component
library · per-row app assets · 150 code files · design specs · art-pack archives (extracted) ·
Google Drive library (767 images, 370 code files). Pipeline scripts in `_tools/`.

**Figma links are dead.** The per-row images are the physical reference for judging and building.

## 5. How a round runs

1. **Feature vote** → `feature-vote.html`. Highest-voted feature is the task. Intent (copy/challenge) stays anonymous.
2. **Build** → each competitor works in `worktrees/{n}-vort-lance` against `reference/per-row/NN - …`.
3. **Submit** → push to `gauntlet/round-{n}/vort-lance`, log in `submission-log.html`, notify proctor.
4. **Judge** → both judges score in `judge-scoring.html`. Deviations: 1→5%, 2→10%, 3→15%, ≥4→0.
5. **Categorize** → Superior ≥85%, Qualified ≥70%, else Unqualified.
6. **Head-to-head** → random pairs of Superior; jury votes with reasons; popular vote wins.
7. **Results** → import JSON into `dashboard.html`; power rankings update round by round.

## 6. Known caveats

- Row **08 Composer/Message Bar (REVIEWED)** survives only as a 3 KB image. Rows 18, 22, 26, 27 are low-res. Rows 10, 12, 13, 15, 21, 23, 24, 25 are full quality.
- D: drive is offline — anything that lived there was not swept.
- `.gdoc`/`.gsheet` files are cloud placeholders; their content stays in Google Drive.
- Chat conversations cannot be branched from the assistant side; the per-competitor **branches and worktrees** are the persistent lanes.

## 7. State

- Repo pushed, all 7 branches live, references committed (`3be46d0`).
- Consolidation complete and mirrored.
- Round 1 has not started — waiting on the opening feature vote.
