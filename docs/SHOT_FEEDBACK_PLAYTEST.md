# Shot feedback verification

Scope: `ferrarissound-design/DROPZONE`, based on main `d0d4d4b`.

## Findings and changes

The reported playtest (ammo decreases, fire sound/flash works, server accepts Shot,
but flight and collisions are unreadable) is consistent with these main-branch issues:

- Tracers started at the authoritative root + 1.4 ray origin, not the visible muzzle.
  Their .08 stud width faded immediately over .1 seconds. The client now uses the
  same barrel tip as the muzzle flash; server origin, spread, endpoints and damage
  remain authoritative. `Muzzle`, `TwinBarrel` and `Barrel` cover all three weapons.
  An unavailable/streamed-out weapon falls back to the server origin.
- Shot endpoints did not distinguish a wall collision from a maximum-range miss.
  Shot now appends bounded `{position, normal}` world-impact records after roundId.
  Surface-oriented flashes, three short rays and a temporary dark mark sit .045
  studs outside the surface. No permanent decal or asset dependency is used.
- Existing hit feedback was a brief reticle color change and occludable numbers.
  Only positive server-confirmed Damage now drives a central ×, an impact spark
  and HP/Shield numbers. Cyan = shield, orange = HP, larger gold × = elimination.
  Numbers are briefly AlwaysOnTop; sparks and tracers retain world occlusion.
- A click beginning and ending between render frames could be lost. InputBegan
  now attempts the first shot immediately; held fire uses the same interval gate.
  There is no catch-up burst and the server still validates every request.
- PC cursor LockCenter prevented reaching the bottom slots. It now applies while
  holding right mouse for shoulder aim; release restores a cursor for slot clicks.
  Shots still aim at the central crosshair, not the unlocked cursor position.
- Ammo has two explicit lines, e.g. `RIFLE · Common` / `23 / 28 予備 198`.
  A reserve gain adds a temporary `(+N)` next to reserve, never magazine capacity.
  Slots retain their rectangles and rarity, add an arrow/gold outline when selected,
  and label unavailable slots `空`. Activated remains shared by mouse and touch.

PR #14's branch was inspected against main. It already contains some related UI,
click and impact changes alongside BOT pacing. Its tracers still originate at the
server root; spark directions ignore the surface; effects allocate per shot. This
branch builds on main and does not import BOT/Config/balance changes. If #14 merges
first, reconcile its overlapping client/Combat changes before merging this PR.

## Budgets and lifecycle

- 24 tracer slots × 2 Parts + 16 impact slots × 5 Parts = **128 fixed shot Parts**.
- Eight local tracer slots and eight local impact slots cannot be evicted by BOT
  or remote shots. Each partition replaces its oldest slot when full.
- Shotgun renders at most three tracer paths and three world impacts per shot;
  all seven server pellets are unchanged. Enemy numbers stay aggregated per victim.
- Local tracer life .20 seconds; remote .12; impact life .42 with .10 solid hold.
  A short moving streak is clamped inside the path, including point-blank shots.
- No shot-time Instance creation, Tween, Debris task, delayed callback or per-frame
  allocation of Instances. One existing render loop updates the fixed slots.
- All Parts are anchored, non-colliding, non-touching and non-queryable. Client aim
  additionally excludes the entire local effects folder. Client-only effects do
  not exist in the server's raycast world. Server weapon cosmetics also use
  CanQuery=false and CanCollide=false.
- New round and Results clear the pools and marker timers immediately; stale
  roundId Shot/Damage events are rejected. Teardown destroys the effects folder.

## Offline verification

Run `python -X utf8 tests/run.py`. Linux uses system liblua5.4. Windows can use an
explicitly installed `lupa==2.6` (Lua 5.4 backend); the runner downloads nothing.

The suite runs real Combat, HUD, Effects and client entrypoint code using engine
doubles. It covers quick click, held interval, key/Activated slot routing, cursor
lock, Shot argument order, hit position/normal, stale/Results events, positive-hit
feedback, miss without numbers, pool saturation/local reservation, surface offset,
line direction/length, short/zero paths, expiry/reset and current/capacity/reserve.
Existing gameplay, evolution, movement, lifecycle and diagnostic tests remain.

## Required Studio acceptance — not yet performed

No Studio instance was connected during this change. Offline tests cannot prove
readability, actual GUI hit testing, Roblox render behavior or mobile FPS. Do not
mark visual acceptance complete until all these are tested on the patched build:

1. PC solo + BOT11: Pistol click/release before a frame, Rifle hold, Shotgun. Each
   accepted Shot shows muzzle → path → endpoint. No double ammo decrement per click.
   Compare intervals with the unchanged server diagnostics; vary FPS and latency.
2. Fire at bright/dark walls, ground, player buildings and empty sky from 5/50/150/
   240 studs (within the weapon's range). A collision has a clear flash/spark/mark;
   sky/range misses have no false impact or damage number. Verify lowest graphics.
3. Normal and right-shoulder cameras, R6/R15, crouch/slide and very close walls:
   tracer starts at the barrel tip, ends at server collision, does not appear from
   feet/inside torso or extend through the endpoint. A barrel protruding into cover
   can still produce a cosmetic mismatch with the root-origin authoritative ray;
   document a reproducer before changing authoritative collision behavior.
4. Hit shield, HP, both, then eliminate: × plus numbers and target spark appear only
   after server damage. No marker on walls/misses. Under latency, visual feedback
   deliberately waits for server confirmation; it is not a predicted hit.
5. Press 1/2/3 and click/tap each slot. Cursor reaches slots after releasing right
   mouse. Selected arrow/outline changes on the authoritative snapshot. Empty slots
   do not equip. Clicking HUD/Draft does not fire through it; Draft exterior firing,
   movement and shoulder aim still work. Tab spectate still works after death.
6. Rifle `23 / 28 予備 198`, Pistol capacity 12, Shotgun capacity 6. Ammo pickup
   changes reserve and its +N only; reload transfers reserve into magazine normally.
   Verify no text clipping on the 900×480 canvas and narrow landscape phones.
7. Two complete rounds including Results/death: no old sparks, marker, numbers,
   audio or recoil persists. Sprint/crouch/slide, building, loot, evolution and zone
   remain functional; no Client/Server Output errors.
8. Low-end mobile, simultaneous BOT fire: measure frame time and Instance count.
   Fixed pools must stay constant; capacity replacement may shorten older cues at
   saturation. Confirm the three visual shotgun paths still communicate spread.

Reference behavior: Roblox [CanQuery](https://create.roblox.com/docs/reference/engine/classes/BasePart/CanQuery)
requires non-colliding Parts; [BillboardGui.AlwaysOnTop](https://create.roblox.com/docs/reference/engine/classes/BillboardGui)
controls whether numbers can be obscured by world geometry.
