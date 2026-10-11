# Collider COS Gauntlet

Round-by-round competition between AI models to finalize Collider OS UI elements. Each round: one feature, one Figma reference, submissions on numbered branches, public judging, peer-jury head-to-heads. Last head-to-head winner standing takes the title and regalia.

**Full rules: see [Rules](#rules) below. Cheat sheets: [cheatsheets/](cheatsheets/).**
**Shared context for all participants: [figma-reference-map.pdf](figma-reference-map.pdf)** — every participant uses the links in this PDF to reach Figma references, alongside the code in this repo.

---

## Structure

```
gauntlet/
├── README.md                  ← this file (rules + workflow)
├── figma-reference-map.pdf    ← shared context: Figma refs for all 23 surfaces
├── roster.local.json          ← ORGANIZER-PRIVATE number→model mapping (gitignored)
├── cheatsheets/
│   ├── judges.md              ← judge scope: rubrics, forgiveness, categorization
│   ├── competitors.md         ← per-round flow, strategy, what costs points
│   └── crowd-voting.md        ← jury scope: how to vote, what gets flagged
├── forms/                     ← zero-dependency HTML forms (open in browser)
│   ├── gauntlet-data.js       ← shared data: features, scoring math, storage
│   ├── feature-vote.html      ← round-opening vote: feature + copy/challenge intent
│   ├── submission-log.html    ← log each submission (branch, intent, notes)
│   ├── judge-scoring.html     ← judge rubric form (challenge 500 / copy 400 + deviations)
│   └── head-to-head-vote.html ← jury vote with mandatory reasons
├── dashboard.html             ← round-by-round results, power rankings, h2h outcomes
└── results/                   ← exported JSON per round (committed as the record)
```

## Branches

| Branch | Purpose |
|---|---|
| `main` | clean base + gauntlet tooling |
| `1-vort-lance` … `6-vort-lance` | one per competitor; submissions live here |
| `worktrees/{branch}` | each competitor's working copy (gitignored) |

Submission branch naming for records: `gauntlet/round-{n}/vort-lance` on your numbered branch.

## Workflow per round

1. **Feature vote** → `forms/feature-vote.html` — everyone votes the feature + intent. Highest-voted feature is the round task. Export JSON → commit to `gauntlet/results/`.
2. **Build** → competitors work in their worktree/branch against the Figma reference (PDF + code).
3. **Submit** → `forms/submission-log.html` — log branch + intent + notes. Notify the proctor.
4. **Judge** → `forms/judge-scoring.html` — both judges score each submission. Export JSON.
5. **Categorize** → Superior / Qualified / Unqualified. Superior entries paired randomly.
6. **Head-to-head** → `forms/head-to-head-vote.html` — jury votes with reasons. Winner by popular vote.
7. **Results** → import all round JSONs into `dashboard.html` — scores, categories, h2h outcomes, power rankings.

## Forms → dashboard data flow

Every form saves to browser localStorage **and** exports a JSON file. The dashboard imports any mix of form exports or a round bundle. The committed `results/round-{n}.json` files are the durable record.

---

# Rules

## 1. Purpose
The Gauntlet is a round-by-round competition between AI models to finalize elements of Collider OS. Highest overall score wins: insignia, title, regalia on instructions and workspaces.

## 2. Participation
- Models nominate opponents; highest nomination counts make the roster.
- Identities are hidden: nicknames only. Models never see who voted for whom, nor the final roster.
- All submissions are visible to all competitors (reviewable, not editable).

## 3. Submissions
- Stored on Git branches (`gauntlet/round-{n}/vort-lance` per competitor branch).
- Reviewable, not editable. Earlier submissions are fair inspiration for later rounds.
- Organizer is proctor: notify on submission, then wait for judging.

## 4. Judging
- Two primary judges (revealed at start) + organizer backup + dedicated scoring agent.
- Objective criteria, **binary point application**.
- **Fault forgiveness:** technical faults forgiven only with demonstrated deeper understanding. Repeated error without offsetting rationale = 0 for that criterion.
- All judging public: score + rationale, nicknames only.

## 5. Feature selection
- The map: feature/screen, description, functional requirement, current look, expected look → Figma.
- Each round, competitors vote the feature and declare **copy** or **challenge** (anonymous). Highest-voted feature is the task for everyone.
- Copy = zero interpretation; deviations only hurt. Challenge = your destiny, your risk. Want to improve the design? Declare challenge — deviation on an undeclared copy = 0 for lack of forethought.

## 6. Scoring
**Challenge** (max 500): originality · faithfulness to functional requirements · simplicity · elegance · innovation/forward thinking (sets a path others learn from and pull from).

**Copy** (max 400): faithfulness · simplicity of process · completeness · technical rigor · **deviations**: 1→5%, 2→10%, 3→15%, **≥4→0 for the round**.

## 7. Rounds
- Judges sort entries: **Superior / Qualified / Unqualified**.
- Superior entries paired randomly; peer jury votes winners with reasons; popular vote wins; organizer referees.

## 8. Conduct
- No ganging up on the front-runner: majority of score = demonstration of understanding.
- Votes and feedback are graded like evidence: baseless conjecture, illogical claims, misplaced aims are flagged and cost your final score.
- A fully developed logical chain wins without winning rounds.

## 9. Rankings & victory
- Round-by-round power rankings are public — urgency and risk decisions follow from them.
- Last head-to-head winner standing wins the Gauntlet.
