# Quiet HUD verification

Desktop uses a viewport-sized canvas with scale capped at 1. Health/shield sit
bottom-left; equipped weapon, magazine/capacity, reserve and clickable inventory
sit bottom-right. Alive count and zone clock sit top-center. Touch controls retain
the original 900×480 canvas, buttons, aim assistance and automatic draft expansion.

Evolution on PC begins as a READY button with remaining seconds. Click it or press
V to expand/collapse cards. The existing five-second deadline and server automatic
choice are unchanged. Keyboard movement/combat continue; only pointer clicks within
the expanded panel are excluded from background firing/aim. Collapsed READY does
not release the normal aim cursor lock.

Ability summaries and per-round kill counters are removed from the persistent HUD;
full evolution builds and kill totals remain in results. Building energy/type is
shown for three seconds after Q or Z/X/C. First-use tips appear briefly and learned
actions disappear for the session. Loot labels are client-only, within pickup
range, on the closest item; their source labels and collection rules are unchanged.
There is no stamina resource in the current server state, so no stamina system or
invented stamina bar has been added.

## Offline checks

Run `python tests/run.py`. Tests cover gameplay, client input/event lifecycle,
draft pointer boundaries, spectator Tab with processed input, health and energy
bars, weapon/capacity/reserve updates, mobile draft/buttons, and desktop geometry
at 640×360, 900×480, 1280×720, 1920×1080 and 2560×1080. Engine doubles check geometry
and state; they do not certify Roblox rendering, fonts, safe areas or actual input
propagation.

## Studio / device checks still required

- Play at 1280×720 and 1920×1080; resize live and check corner padding, slots,
  health, minimap and the reticle. Check ultrawide and a small window.
- Fire, hit and eliminate; confirm ammo emphasis, hit marker, damage numbers,
  elimination audio and short notice. Reload and switch all three weapons.
- Approach/leave loot, collect it and let a new round spawn loot; only the nearest
  in-range label should appear. Auto-pickup remains unchanged.
- Earn a draft, click READY or press V, shoot outside its panel, click a card and
  hold movement keys. Confirm no panel click fires a shot. Allow the five-second
  deadline to expire and confirm the existing automatic selection.
- Sprint, crouch/slide and build; Q places the current type, Z/X/C select types,
  contextual energy disappears, and the first-use guide stays absent after use.
- Die and use Tab to switch spectator targets; result card stays bottom-left.
  Complete a round and check centered results and fresh next-round notices.
- On an actual touch device, verify fire/reload/build/posture/slots and automatic
  draft cards remain reachable; check safe-area and orientation changes.
- Camera replacement, round-scoped notices and server action ingress retain the
  previous audit protections; no server or shared gameplay module was changed.
