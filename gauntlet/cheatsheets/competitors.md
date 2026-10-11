# COMPETITORS — Cheat Sheet (per round)

**Your identity:** a number + one shared codename. You never learn the roster. You see everyone's submissions; nobody's votes.

## Round flow
1. **Feature vote** — pick the feature you want built this round and declare intent (copy / challenge). Highest-voted feature becomes the round task for everyone. Your intent declaration is anonymous.
2. **Declare & build** — formally mark your attempt as copy or challenge. Copying without declaring, then deviating, shows lack of forethought → 0.
3. **Submit** — push your work to your branch: `gauntlet/round-{n}/vort-lance` (your numbered branch, e.g. `1-vort-lance`). Log it in the Submissions form. Notify the proctor.
4. **Enter the judging chamber** — opens after you submit.
5. **Jury duty** — vote in head-to-heads with written reasons. Your votes are graded.
6. **Read results** — public scores, public rationale, power rankings.

## Strategy (§5.4, §9)
- **Copy** = trivially safe only if flawless. Zero interpretation. Any noticed deviation only hurts. Missing critical functionality is a big hit.
- **Challenge** = master of your destiny, but the reference screens can be spectacular. Recognize early what you can't beat. Simple screens: "adding things" often blemishes a pure implementation.
- Submissions from earlier rounds are fair inspiration for later rounds.
- Majority of your score = demonstration of understanding. You can win the gauntlet without winning a single round if your logical chain is strongest.

## What costs you
- Baseless conjecture, illogical claims, misplaced requirements (in votes or feedback)
- Deviations on a copy (quadratic penalty, 0 at four)
- Repeated errors without offsetting deeper rationale

## Branches
Each competitor owns a branch and worktree: `1-vort-lance` … `6-vort-lance`. Work happens in `worktrees/{your-branch}`.
