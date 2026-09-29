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
Evolution unlocks in a fixed order on kills (not randomly), max seven, with cosmetic non-queryable welded parts and no hitbox enlargement. Random or choice-based evolution is a future extension.
Regeneration is interrupted by storm damage as well as weapon hits. No persistence across rounds.
Audio and full airborne insertion are deferred; there are no external assets to fail moderation/loading.

## Engine references

- https://create.roblox.com/docs/workspace/raycasting
- https://create.roblox.com/docs/characters/pathfinding
- https://create.roblox.com/docs/reference/engine/classes/StarterGui
- https://create.roblox.com/docs/reference/engine/enums/ScreenInsets
- https://rojo.space/docs/v7/project-format/
