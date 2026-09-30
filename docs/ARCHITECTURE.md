# Architecture / boundaries

## Authority

The server owns the roster, round ID, active flag, HP/shield, inventories, ammunition, reload tokens,
shot cooldowns, raycasts, loot proximity, build costs/occupancy, evolutions, ranks and winner.
The client sends only an action, current round ID and a unit aim vector / slot / build kind.
It never supplies damage, hit instances, ammo, placement CFrames, winner or ability awards.
A per-player token bucket permits 20 requests/sec and a 30-request burst before gameplay work.
Invalid vectors (NaN, infinity, oversized components, non-unit lengths) are rejected.

This is not a complete anti-cheat. Player movement uses normal Roblox character network ownership;
speed/teleport/aimbot detection and server reconciliation are not implemented. Server-validated shooting
prevents forged damage and wall penetration but cannot distinguish automated legitimate aim requests.

## Lifetime

One Actors record represents one combatant in one round. Player joins do not add to an active roster.
CharacterAutoLoads=false prevents eliminated players from respawning into the match.
Manual reset triggers Humanoid.Died and removes the actor from the live count. PlayerRemoving is idempotent.
The service roster includes both humans and bots and is the sole source of survivor count.

Round ID changes at start and reset. Reload callbacks carry a per-actor generation token.
Pathfinding callbacks carry the bot-service generation. Reset invalidates callbacks before deleting models.
Avatar loads are protected against overlapping lobby/start requests and late completions cannot enroll in a newer round.
Results retain statistics briefly, then reset discards actor tables and reconstructs characters.
No DataStore side effects are performed.

## Work budgets

- One server scheduler at ~10 Hz. Zone/evolution work scans at most 20 combatants.
- Snapshots at 5 Hz, including at most 20 spectator identities (no per-frame position replication).
- Bots decide every 0.35 sec; target search is bounded by 20 actors.
- Maximum 2 simultaneous path computations; per-bot cooldown >=2.5 sec.
- Loot pickup scan every 0.4 sec over fixed spawn points, no permanent Touched handlers.
- Maximum 100 builds, each expires after 100 sec. No unbounded physics objects.
- Current/next boundaries: 96 local anchored non-queryable segments, updated only with snapshots.
- At most 72 simultaneous local tracers; lifetime 0.12 sec; no persistent particle emitters.
- Dead bodies remain until reset, bounded by the match roster.

The generated arena is deliberately compact. Performance budgets are design limits, not measured FPS claims.

## Balance and implementation scope

Zone schedule is 375 seconds (6 minutes 15 seconds) plus up to 30 seconds emergency resolution. Earlier kills can end a match earlier.
All circle shifts keep the next circle contained and the last combat around Core. Storm bypasses shield. Same-tick environmental eliminations share a finishing rank; simultaneous final storm deaths result in a draw.
Bots prioritize safety, then nearby loot, then combat/wandering. Blocked shots can damage player-built cover.
Bots start with a pistol, humans have guaranteed nearby pickups. They share damage and reload code.
Bots use rigid R6-style procedural rigs: animation/art polish remains pending.

Builds are simple ground-snapped pieces, not a multi-storey Fortnite construction system.
Each kill presents up to three distinct, category-diverse Evolution choices from a server-held pool. Human choices expire after five seconds and auto-pick; Bots choose immediately using light health/zone/weapon heuristics. Choice requests carry only the draft token and index, and the server validates the current round, living Actor, pending token, expiry, and offered index. Eleven abilities have diminishing effects and a per-ability rank cap of three. Cosmetic welded mutation parts are non-colliding, non-touching, non-queryable, and are cleared with each Actor at round reset.
Regeneration is interrupted by storm damage as well as weapon hits. No persistence across rounds.
Audio and full airborne insertion are deferred; there are no external assets to fail moderation/loading.

## Engine references

- https://create.roblox.com/docs/workspace/raycasting
- https://create.roblox.com/docs/characters/pathfinding
- https://create.roblox.com/docs/reference/engine/classes/StarterGui
- https://create.roblox.com/docs/reference/engine/enums/ScreenInsets
- https://rojo.space/docs/v7/project-format/

## Visual boundary

`VisualTheme` is the shared palette only. `Cosmetics` builds held weapons, drone shells, pickup silhouettes and build rails with no collision/touch/query and Massless enabled. Welded pieces belong to the character; anchored pickup/build pieces are descendants of the existing pickup/build root, so existing removal/reset destroys them as one unit.

`MapVisuals` owns the static `DropzoneWorld/Scenery` folder. It is a sibling of `Map` and is never included by `World.ground`. Existing map colliders, spawns and bot logic remain authoritative. Do not add cover-shaped noncolliding decoration in combat lanes.

`Town` owns the bounded building catalog. Structural shells live under `Map/Buildings`; their broad walls and roofs are the only weapon/path/build-overlap geometry. Presentation trim lives under `Scenery/TownVisuals` with collision, touch and query disabled. Optional `ServerStorage/TownTemplates` models are cloned while detached, recursively stripped, capped, and rejected unless they declare a small `Collision` set or `TownCollision` attributes.

The HUD consumes server `maxEnergy` for its display bar. Category colors, RichText and selection-border Tweens do not grant abilities or send new remotes. Draft button rectangles remain unchanged; the reticle renders behind cards without moving its aiming anchor. No visual code runs a per-frame object-generation loop.

## Movement / rarity / confirmed feedback

Movement state is server-owned through the existing rate-limited Action ingress (roundId, Active/FinalZone, alive, root). Sprint accepts a boolean only; Slide uses finite server-observed horizontal velocity, a fixed impulse cap and a decaying cap in the existing scheduler. Death/Results/Actor clear reset posture. No movement timers or new RemoteEvents are introduced. This is not a full anti-teleport system for Roblox client-owned characters.

WeaponStats caches nine immutable-by-convention specs (3 kinds × 3 tiers). Loot.items stores {kind, rarity}; pickup claims the item without yielding before reward. Combat keeps the highest tier per weapon kind, cancels the equipped reload on upgrade and resolves effective specs on the server. Snapshots add rarity, slotRarities and sprinting; clients never submit a desired tier.

Actors.damage returns actual HP/Shield loss. Combat.fire aggregates shotgun pellets per victim and sends a shooter-only Damage message with roundId and at most seven records. DamageFeedback reuses eight anchors/Billboards and expires them at 10Hz without task.delay, Tween or per-hit Instance allocation. No client hit/damage prediction affects gameplay. Shot feedback reuses the crosshair, elimination reuses a single cancellable HUD Tween. POI label color/range changes add no map Parts; each weapon pickup gains one static rarity footprint.

Posture input is resolved from the server sprint state, avoiding a snapshot-latency race when Shift and Ctrl are pressed quickly. Jump cancel requests are client-throttled to 0.15 seconds and still pass the shared server ingress gate.
