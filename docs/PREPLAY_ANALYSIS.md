# DROPZONE pre-play analysis

Studio / device testing has not been performed by this report. These are deterministic source-level checks intended to catch obvious balance or state problems before the first hands-on session.

## Current theoretical weapon envelope

Assumptions:

- No Evolution modifier.
- Common handling values.
- No reload inside the TTK window.
- For Shotgun, every pellet lands at effectively zero falloff. This is a maximum-hit ceiling, not an expected live result.

| Weapon | Max damage per trigger | 100 HP | 200 effective HP |
| --- | ---: | ---: | ---: |
| Pistol | 22 | 5 shots / 1.28 s | 10 shots / 2.88 s |
| Rifle | 16 | 7 shots / 0.84 s | 13 shots / 1.68 s |
| Shotgun | 77 (11 x 7) | 2 shots / 0.85 s | 3 shots / 1.70 s |

No current weapon can delete base 100 HP in a single trigger before spread/falloff is considered.

This does **not** prove live balance. Shotgun pellet spread, target movement, aim assist, cover, latency, Shield availability and Evolution all change practical outcomes.

## Zone

The five configured hold + shrink phases total **375 seconds (6:15)**.

Damage progresses:

`2 -> 4 -> 7 -> 12 -> 22`

The final target radius is zero. Existing regression coverage separately checks monotonic shrink, next-circle containment and zero-radius center damage.

## Building energy envelope

Current values:

- Start Energy: 60
- Max base Energy: 150
- Base Build Cost: 20
- Build limit: 100

Without pickups:

- Fresh player can place 3 base-cost builds.
- A player sitting at base Max Energy can place 7 base-cost builds.

Builder III totals a 33% discount. The existing 0.67 floor therefore makes the final cost **14 Energy**, allowing 4 placements from the initial 60 Energy.

This is only an economy envelope. Whether 3-4 opening builds feels useful or restrictive needs Studio play.

## Weapon rarity stress sample

Configured probability:

- Common 72%
- Rare 22%
- Epic 6%

`tests/preplay_analysis.py` performs 20,000 deterministic draws and requires every observed rate to remain within 2 percentage points of the source probability. The current deterministic seed produces approximately:

- Common 72.4%
- Rare 21.6%
- Epic 6.1%

Rarity still changes only handling (reload/spread), not damage, fire rate, magazine or range.

## Evolution draft stress sample

A fresh player has 11 eligible abilities across 4 categories. The draft logic intentionally prefers three different categories when possible.

`tests/preplay_analysis.py` mirrors that fresh-draft selection for 10,000 drafts and checks:

- exactly 3 cards are produced;
- the 3 cards span 3 categories;
- all 11 abilities appear across the sample;
- no ability disappears because of selection bias or an unreachable branch.

### Expected non-uniform individual exposure

The four categories do not contain the same number of abilities:

- Mobility: 3
- Attack: 2
- Survival: 3
- Utility: 3

Because categories are selected before an ability inside each category, an individual Attack ability is expected to appear more often than an individual ability from a 3-ability category.

That is an intentional consequence of category diversity, not currently treated as a bug. During hands-on play, watch for the subjective feeling that Hunter Eyes / Quick Hands appear too often.

## Playtest diagnostics

With `Config.PlaytestDiagnostics = true`, Results prints a bounded server-side summary only once per round:

- round duration;
- winner / combatants / total kills / total damage;
- Zone deaths;
- weapon shots / shot-level hits / real dealt damage;
- human player rank / survival;
- successful builds / pickups;
- Zone damage received;
- death reason;
- Evolution history.

These counters are observational only and never feed authoritative gameplay decisions.

## What still cannot be answered before Studio

The following remain real playtest questions:

- Is the right-shoulder camera comfortable on a phone?
- Does crosshair convergence feel correct near walls?
- Does Shotgun feel too strong or too inconsistent?
- Is the 6:15 maximum round too long in practice?
- Do BOTs create enough pressure without feeling artificial?
- Is Evolution readable while combat continues?
- Are 3 initial builds enough?
- Do Creator Store sounds load and mix well?
- Does BOT11 + Build100 + effects remain smooth on a low-end phone?

Do not change balance solely because of the theoretical numbers above. Use the first playtest logs and feel together.
