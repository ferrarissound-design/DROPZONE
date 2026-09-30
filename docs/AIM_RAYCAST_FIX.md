# Crosshair / authoritative raycast investigation

Base: main `ca4ab2a1599fb86c73c62f5b4a7d0bb410f750af` (PR #15).

## Findings and fix

- The HUD uses `IgnoreGuiInset = false`. Its scaled crosshair's
  `AbsolutePosition + AbsoluteSize / 2` is in the GUI coordinate system expected
  by `Camera:ScreenPointToRay`. Keep this pairing; switching to
  `ViewportPointToRay` without converting coordinates would add an inset error.
  See the [Roblox Camera reference](https://create.roblox.com/docs/reference/engine/classes/Camera#ScreenPointToRay).
- The old client removed `presentation.applied` from the displayed camera when
  computing aim, then restored it. During recoil, the visible reticle and the
  submitted direction therefore referred to different camera orientations.
  Aim now uses the displayed camera without mutating it. Recoil recovery and
  render-step cleanup remain unchanged.
- The old camera ray could pick an obstacle between the third-person camera and
  the firing origin. Subtracting the root origin from this rearward target could
  send the server ray backwards or sideways. The acquisition ray now starts on
  the camera ray at the firing-origin depth plane (or at the camera if already
  ahead). Mobile assistance also rejects targets behind that plane.
- Client and server both use `HumanoidRootPart.Position + (0, 1.4, 0)` as the
  firing origin. The server still derives its own origin; the remote still only
  carries a unit direction. The camera merely selects a forward target. Cover
  along the root-to-target path continues to block the server ray.
- `CFrame.lookAt(Vector3.zero, direction.Unit)` points local **-Z** / `LookVector`
  along the submitted direction. Postmultiplying `CFrame.Angles(pitch,yaw,0)`
  applies local spread correctly. No sign reversal was found; server Combat.lua
  and weapon balance are unchanged.
- Server ray hit positions (or range endpoints on misses) remain the exact Shot
  endpoints. The client substitutes only the cosmetic muzzle start. This line
  can differ from the root ray near the muzzle, but cannot change damage or the
  confirmed endpoint. Enemy feedback remains exclusively server-confirmed.

## Automated validation

`python tests/run.py` includes numeric camera/CFrame and ray/sphere doubles in
`tests/client.lua` and `tests/aim_math.lua`. It executes the actual client entry
point, captures Fire directions and passes them to actual `Combat:fire`.
Unlike the older fixed-LookVector/always-hit doubles, intersections depend on
the submitted ray. Cases cover:

- Four horizontal headings, steep upward/downward aim, translated world origins,
  two viewport sizes/topbar insets, zero and nonzero displayed recoil.
- Zero-spread target damage, server origin/direction and unchanged visual endpoints.
- A camera-to-root obstruction and cover that the camera sees around but the
  authoritative root ray must hit.
- Both spread extremes for Pistol/Rifle/Shotgun, all seven shotgun pellets,
  unchanged range and forward cone, and misses without damage confirmation.
- Invalid vectors, NaN/infinity and forged payloads rejected before ammo use.

These are offline numerical regressions, not Roblox engine or visual validation.
No Studio instance was connected during this investigation. They reproduce two
concrete defects; they do not prove which condition occurred in the reported
play session. No claim is made that the spread-free ray must hit the center at
every distance: parallax converges at the acquired target, and live weapons
retain their configured spread.

## Studio acceptance checks still required

1. Sync this branch and aim the visible crosshair at a bot at close and medium
   range. Fire single shots and sustained bursts in hip and shoulder views.
   Verify server-confirmed damage and impacts while recoil is active.
2. Repeat facing +X, -X, +Z, -Z and up/down slopes, including crouch/slide and
   resized windows/mobile safe areas. Test touch assistance separately.
3. Stand with a wall behind the character in the camera-to-character segment:
   forward shots should not reverse. Then put cover between the firing origin
   and enemy: the wall must take the hit even if the camera sees the enemy.
4. Confirm each tracer ends at the server impact, even though its cosmetic start
   is at the muzzle. Test all three weapons; shotgun spread remains intentional.
