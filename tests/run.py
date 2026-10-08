"""Offline Lua 5.4 syntax + logic checks. Roblox engine validation is separate.
Uses system liblua or an explicitly installed Lua 5.4 Lupa runtime; never downloads dependencies.
"""
import ctypes
import ctypes.util
from pathlib import Path
import re
import sys
import subprocess

ROOT = Path(__file__).resolve().parents[1]
library = ctypes.util.find_library('lua5.4')
if not library:
    # Optional Windows fallback: pip install lupa (Lua 5.4, not LuaJIT).
    # No automatic download; the normal system liblua path stays unchanged.
    from lupa.lua54 import LuaRuntime

    def run(source, name, execute=False):
        lua = LuaRuntime()
        chunk = lua.eval('function(s, n) return assert(load(s, n)) end')(source, name)
        if execute:
            chunk()
else:
    lib = ctypes.CDLL(library)
    lib.luaL_newstate.restype = ctypes.c_void_p
    lib.luaL_openlibs.argtypes = [ctypes.c_void_p]
    lib.luaL_loadbufferx.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p, ctypes.c_char_p]
    lib.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_longlong, ctypes.c_void_p]
    lib.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
    lib.lua_tolstring.restype = ctypes.c_char_p
    lib.lua_close.argtypes = [ctypes.c_void_p]

    def run(source, name, execute=False):
        state = lib.luaL_newstate()
        lib.luaL_openlibs(state)
        code = source.encode()
        status = lib.luaL_loadbufferx(state, code, len(code), name.encode(), None)
        if not status and execute:
            status = lib.lua_pcallk(state, 0, 0, 0, 0, None)
        if status:
            error = lib.lua_tolstring(state, -1, None).decode()
            lib.lua_close(state)
            raise RuntimeError(error)
        lib.lua_close(state)

for path in sorted((ROOT / 'src').rglob('*.lua')):
    run(path.read_text(encoding='utf-8'), str(path.relative_to(ROOT)))
print('PASS: syntax of all Lua modules (Lua 5.4 compatible subset)')
run('ROOT = ' + repr(ROOT.as_posix()) + '\n' + (ROOT / 'tests/spawns.lua').read_text(encoding='utf-8'), 'spawns.lua', True)
if "--spawn-only" in sys.argv:
    sys.exit(0)
# Targeted client regressions can run independently of unrelated engine doubles.
if "--client-only" in sys.argv:
    run('ROOT = ' + repr(ROOT.as_posix()) + '\n' + (ROOT / 'tests/client.lua').read_text(encoding='utf-8'), 'client.lua', True)
    print('PASS: targeted client regressions (Roblox engine validation remains separate)')
    sys.exit(0)
source = (ROOT / 'tests' / 'regression.lua').read_text(encoding='utf-8')
source = 'ROOT = ' + repr(ROOT.as_posix()) + '\n' + source
run(source, 'regression.lua', True)
visual_source = 'ROOT = ' + repr(ROOT.as_posix()) + '\n' + (ROOT / 'tests' / 'visuals.lua').read_text(encoding='utf-8')
run(visual_source, 'visuals.lua', True)
run('ROOT = ' + repr(ROOT.as_posix()) + '\n' + (ROOT / 'tests/client.lua').read_text(encoding='utf-8'), 'client.lua', True)

hud = (ROOT / 'src' / 'client' / 'Hud.lua').read_text(encoding='utf-8')
assert not re.search(r'EVOLUTION\s+[^\n]*\s*/\s*7', hud, re.I)
print('PASS: HUD has no obsolete seven-Evolution cap')
assert 'self.draft.ZIndex, self.draft.Active, self.draft.Selectable = 20, false, false' in hud
assert 'self.draftTitle.ZIndex = 21' in hud and 'card.ZIndex, card.AutoButtonColor = 22, true' in hud
print('PASS: draft overlay, title, and cards use explicit ZIndex without an active full-screen frame')

docs = '\n'.join(path.read_text(encoding='utf-8') for path in [ROOT / 'README.md', *(ROOT / 'docs').glob('*.md')])
assert not re.search(r'(?:EVOLUTION|Evolution).{0,40}(?:/\s*7|max(?:imum)?\s+seven|最大\s*7)', docs, re.I)
print('PASS: README and docs have no obsolete seven-Evolution cap')

client = (ROOT / 'src' / 'client' / 'Main.client.lua').read_text(encoding='utf-8')
round_reset = re.search(r'if not state or state\.roundId ~= s\.roundId then(?P<body>.*?)\n    end\n    state = s', client, re.S)
assert round_reset and 'submittedEvolutionDraft = nil' in round_reset.group('body')
print('PASS: a new round clears the submitted Evolution draft token')


actors_source = (ROOT / 'src' / 'server' / 'Actors.lua').read_text(encoding='utf-8')
assert 'descendant.CanQuery = false' in actors_source and 'descendant.CanTouch = false' in actors_source
print('PASS: eliminated actors are removed from raycast and touch queries')

world_source = (ROOT / 'src' / 'server' / 'World.lua').read_text(encoding='utf-8')
assert 'groundSurfaces = {}' in world_source
assert 'params.FilterDescendantsInstances = surfaces' in world_source
assert 'if not surfaces or #surfaces == 0 then return Vector3.new(position.X, 0, position.Z) end' in world_source
for required in ['island', 'roadX', 'roadZ', 'hill', 'centralPad']:
    assert f'table.insert(self.groundSurfaces, {required})' in world_source
print('PASS: ground raycasts use only designated walkable surfaces')
assert 'function World.spawnClear(self, ground)' in world_source
assert 'insideBuildingFootprint(self, ground)' in world_source
assert 'building:GetBoundingBox()' in world_source and 'box:PointToObjectSpace(position)' in world_source
assert 'workspace:GetPartBoundsInBox' in world_source
assert 'function World.resolveSpawn(self, preferred, existing)' in world_source
assert 'Never silently fall back to the blocked point.' in world_source
print('PASS: round-start spawn generation rejects building footprints and collidable blockers')

town_source = (ROOT / 'src' / 'server' / 'Town.lua').read_text(encoding='utf-8')
for unsafe_class in ('Script=true', 'LocalScript=true', 'ModuleScript=true', 'RemoteEvent=true',
                     'ParticleEmitter=true', 'PointLight=true', 'Sound=true',
                     'ClickDetector=true', 'ProximityPrompt=true'):
    assert unsafe_class in town_source
assert 'descendant.CanQuery = collision' in town_source
assert 'descendant.CanTouch = false' in town_source
assert 'descendant.Anchored = true' in town_source
assert 'CollisionフォルダまたはTownCollision属性が必要です' in town_source
assert 'Town.TemplateLimits = {parts = 96, meshParts = 32, collisionParts = 20}' in town_source
assert 'descendant:IsA("Constraint")' in town_source and 'descendant:IsA("JointInstance")' in town_source
assert 'Town.FallbackBudget = {buildings = 13, collisionParts = 91, visualParts = 106}' in town_source
for silhouette in ('GableRoof', 'ButterflyRoof', 'MonoPitchRoof'):
    assert silhouette in town_source
project = (ROOT / 'default.project.json').read_text(encoding='utf-8')
assert '"TownTemplates"' in project and '"$ignoreUnknownInstances": true' in project
print('PASS: Toolbox town templates are stripped, bounded and explicit about collision/query ownership')

server_source = (ROOT / 'src' / 'server' / 'Main.server.lua').read_text(encoding='utf-8')
assert 'ReplicatedStorage:GetChildren()' in server_source and 'child.Name == "DropzoneRemotes"' in server_source
assert 'remotes:GetChildren()' in server_source and 'child:IsA("RemoteEvent")' in server_source
print('PASS: Studio/Rojo startup deduplicates the remote folder and events')

assert 'and Theme.Cyan or Theme.Paper' in client
print('PASS: hit marker restores the shared aim crosshair color')

# Draft pointer hit testing and camera handoff are source-level guards; Studio
# remains the authority for actual GUI hit testing and camera render order.
assert 'local function mouseOnEvolutionPanel(input)' in client
assert 'hud.draft.AbsolutePosition, hud.draft.AbsoluteSize' in client
assert 'or input.UserInputType == Enum.UserInputType.MouseButton2) and mouseOnEvolutionPanel(input)' in client
assert 'if playing() then action:FireServer(state.roundId, command, argument) end' in client
assert 'shooting and playing()' in client
assert 'button.Active = button.Visible and draft == nil' not in hud
assert 'me.evolutionDraft == nil' not in (ROOT / 'src' / 'client' / 'Presentation.lua').read_text(encoding='utf-8')
assert client.index('if input.KeyCode == Enum.KeyCode.Tab then') < client.index('if processed then return end')
assert 'and (state.phase == "Active" or state.phase == "FinalZone") then' in client
assert 'camera:ScreenPointToRay(center.X, center.Y)' in client
print('PASS: draft panel alone blocks pointer input; gameplay and spectator Tab remain available')
assert "place(self.evo,16,70,200,30)" in hud
assert "function Hud:setSpectateName(name)" in hud and "escapeRichText(tostring(name))" in hud
assert "self.onboardingComplete = true" in hud
assert "hud:setSpectateName(target.name or \"BOT\")" in client
presentation_source = (ROOT / "src/client/Presentation.lua").read_text(encoding="utf-8")
assert "self.warnedHoldPhase ~= zone.phase" in presentation_source
print('PASS: contextual first-match mission, safe spectator names and once-per-phase zone warning')
combat_src = (ROOT / 'src/server/Combat.lua').read_text(encoding='utf-8')
server_src = (ROOT / 'src/server/Main.server.lua').read_text(encoding='utf-8')
building_src = (ROOT / 'src/server/Building.lua').read_text(encoding='utf-8')
effects_src = (ROOT / 'src/client/Effects.lua').read_text(encoding='utf-8')
assert 'function Combat:stopFire(a)' in combat_src
assert 'if command == "FireStop" then' in server_src and server_src.index('if command == "FireStop" then') < server_src.index('local now = os.clock()')
assert 'local obstruction = workspace:Raycast(sightOrigin, cf.Position-sightOrigin, sightParams)' in building_src
assert 'Rules.facingShot' not in combat_src
assert 'function Bots.faceTarget(a, delta)' in (ROOT / 'src/server/Bots.lua').read_text(encoding='utf-8')
assert 'DropzoneWeaponWeld' in (ROOT / 'src/server/Cosmetics.lua').read_text(encoding='utf-8')
assert 'traceOrigin = serverOrigin' in effects_src
print('PASS: stop fire, build LOS, third-person fire and visual tracer source guards')

loot_source = (ROOT / 'src' / 'server' / 'Loot.lua').read_text(encoding='utf-8')
assert '"Notice", self.id, "敗退' in (ROOT / 'src' / 'server' / 'Round.lua').read_text(encoding='utf-8')
assert '"Notice", a.roundId, "取得:' in loot_source
assert '"Notice", round.id, "EVOLUTION:' in (ROOT / 'src' / 'server' / 'Main.server.lua').read_text(encoding='utf-8')
assert 'kind == "Notice" and state and a == state.roundId' in client
print('PASS: delayed notices carry a server round ID and cannot appear in a later round')
assert 'spectateId = target.id' in client and 'local function cycleSpectate()' in client
assert 'sprintDesired, sprintRequestTime = enabled, os.clock()' in client
assert 'record.lastAppliedTransform == current' in (ROOT / 'src/client/Presentation.lua').read_text(encoding='utf-8')
assert 'loadToken' in (ROOT / 'src/server/Round.lua').read_text(encoding='utf-8')
assert 'self:finish(#Players:GetPlayers() == 0)' in (ROOT / 'src/server/Round.lua').read_text(encoding='utf-8')
print('PASS: stable spectate identity, rapid sprint, noncompounding pose, stale load and abandoned round guards')
assert 'a.roundId ~= round.id' in server_source
assert 'a.humanoid.Health <= 0' in server_source
print('PASS: action ingress rejects stale actors and the death-before-Died window')


building_source = (ROOT / 'src' / 'server' / 'Building.lua').read_text(encoding='utf-8')
assert 'params.FilterDescendantsInstances = self.world.groundSurfaces or {}' in building_source
print('PASS: build overlap ignores every designated ground surface, including Hill')

bots_source = (ROOT / 'src' / 'server' / 'Bots.lua').read_text(encoding='utf-8')
assert re.search(r'function Bots:clear\(\).*?self\.jobs = 0', bots_source, re.S)
assert 'if currentGeneration then self.jobs = math.max(0, self.jobs - 1) end' in bots_source
print('PASS: bot path worker accounting is generation-safe across resets')

round_source = (ROOT / 'src' / 'server' / 'Round.lua').read_text(encoding='utf-8')
assert 'a.roundId = -1' in round_source
print('PASS: Results invalidates stale deferred Evolution work')

assert 'descendant.CanCollide = false' in actors_source and 'a.root.Anchored = true' in actors_source
print('PASS: eliminated actors are physically non-blocking and remain stable')


movement_source = (ROOT / 'src' / 'server' / 'Movement.lua').read_text(encoding='utf-8')
assert 'function Movement.toggleCrouch(a)' in movement_source and 'function Movement.slide(a)' in movement_source
assert 'Config.SlideCooldown' in movement_source and 'Config.SlideMinSpeed' in movement_source
assert 'a.root.AssemblyLinearVelocity' in movement_source
print('PASS: crouch and slide are server-authoritative with cooldown and movement gates')

assert 'command == "Crouch"' in server_source and 'command == "Slide"' in server_source
assert 'hud:button("Crouch"' in client and 'hud:button("Sprint"' in client and 'hud:button("Aim"' in client
assert 'Enum.KeyCode.LeftControl' in client and 'Enum.KeyCode.LeftShift' in client
print('PASS: mobile buttons and keyboard movement controls are wired')

assert 'crouching = a.crouching == true' in round_source and 'slideCooldown = math.max' in round_source
print('PASS: authoritative crouch/slide state is replicated in snapshots')

# Server ingress guards must run before every movement dispatch, including Results.
assert server_source.index('roundId ~= round.id or not round:isActive()') < server_source.index('command == "Sprint"')
assert server_source.index('not a or not a.alive') < server_source.index('command == "Sprint"')
assert 'requestSprint(true)' in client and 'requestSprint(false)' in client
assert 'UserInputService.JumpRequest' in client and 'command == "Jump"' in server_source
print('PASS: sprint/posture/jump use existing round/alive/ingress validation')
# Test the actual adaptive layout, including both mutually exclusive modes.
run('ROOT = ' + repr(ROOT.as_posix()) + '\n' + (ROOT / 'tests/mobile_layout.lua').read_text(encoding='utf-8'), 'mobile_layout.lua', True)

assert 'local function useful(a, item)' in loot_source
assert 'WeaponStats.rank(item.rarity) > WeaponStats.rank(weapon.rarity)' in loot_source
assert 'weapon.reserve < 240' in loot_source
assert '#a.inventory == 0 and not Weapons[kind]' not in loot_source
print('PASS: auto pickup preserves loot that gives no weapon/ammo benefit and allows useful consumables')

# Event provenance and camera bracketing are integration checks, not engine simulation.
presentation = (ROOT / 'src/client/Presentation.lua').read_text(encoding='utf-8')
assert client.count('presentation:damage(b)') == 1
confirmed_handler = client[client.index('elseif kind == "Damage"'):client.index('local feedbackClock')]
assert 'a == state.roundId' in confirmed_handler and 'presentation:damage(b)' in confirmed_handler
assert 'roundId == state.roundId' in client
assert 'camera.CFrame =' not in client
assert 'Enum.RenderPriority.Camera.Value-1' in client and 'Enum.RenderPriority.Camera.Value+1' in client
assert 'UnbindFromRenderStep("DropzonePresentationBefore")' in client
assert 'UnbindFromRenderStep("DropzonePresentationAfter")' in client
assert 'Enum.UserInputType.MouseButton2' in client
assert 'presentation:setAimHeld(touchAimToggled)' in client
assert 'presentation:setCombatAim(' not in client
assert 'if not fireDrag:begin(input) then return end' in client
assert 'if input == fireDrag.input then stopFireTouch() end' in client
assert 'aimButton.Activated:Connect' in client and 'tryShoot()' not in client[client.index('aimButton.Activated:Connect'):client.index('hud:button("Reload"')]
assert 'AimShoulderX' in presentation and 'AimFov' in presentation
assert 'task.delay' not in presentation and 'TweenService' not in presentation
# Animation defaults remain empty; audio may use reviewed Creator Store numeric IDs.
animation_config = (ROOT / 'src/shared/AnimationConfig.lua').read_text(encoding='utf-8')
assert not re.search(r'rbxassetid://[1-9][0-9]+', animation_config)
audio_config = (ROOT / 'src/shared/AudioConfig.lua').read_text(encoding='utf-8')
for required_id in ('9114727096','5656322299','9119136387','8145744063','9119074309','9119060148','9120705982','9119802009','9119902088'):
    assert required_id in audio_config
assert 'Audio.Footstep = cue("",' in audio_config and 'Audio.SlideLoop = cue("",' in audio_config
print('PASS: confirmed hit/round provenance, displayed-camera aim, camera cleanup and reviewed audio defaults')

# Playtest instrumentation must remain bounded and non-authoritative.
config_source = (ROOT / 'src' / 'shared' / 'Config.lua').read_text(encoding='utf-8')
combat_source = (ROOT / 'src' / 'server' / 'Combat.lua').read_text(encoding='utf-8')
round_source_text = (ROOT / 'src' / 'server' / 'Round.lua').read_text(encoding='utf-8')
assert 'PlaytestDiagnostics = true' in config_source
assert 'diag.shots[item.kind]' in combat_source and 'diag.weaponDamage[item.kind]' in combat_source
assert 'if hitEnemy then diag.hits[item.kind]' in combat_source
assert 'emitDiagnostics(self)' in round_source_text
assert round_source_text.count('[DROPZONE DIAG]') == 2
assert 'print(' not in combat_source
print('PASS: diagnostics collect silently during play and print only bounded round summaries')

# Opening pacing: hands-on testing showed BOTs attacking immediately at spawn.
bots_source = (ROOT / 'src' / 'server' / 'Bots.lua').read_text(encoding='utf-8')
for required in (
    'BotAggroRange = 110',
    'BotOpeningSeconds = 10',
    'BotOpeningLootRange = 90',
    'BotShotgunRange = 32',
):
    assert required in config_source
assert 'opening = now - (a.startTime or now) < Config.BotOpeningSeconds' in bots_source
assert 'retaliating = (a.lastDamage or 0) > (a.startTime or math.huge)' in bots_source
assert 'Rules.closestLiveTarget(a, alive, Config.BotAggroRange)' in bots_source
assert 'Config.BotOpeningLootRange' in bots_source
assert 'distance < Config.BotShotgunRange' in bots_source
assert 'closestLiveTarget(a, alive, 145)' not in bots_source
assert 'distance < 38' not in bots_source
print('PASS: BOT opening is loot-first, retaliation remains available, and engagement ranges are bounded')

# Shoulder aim remains presentation-only, restores state, and keeps the legacy
# procedural weapon path when Studio-side templates are unavailable.
presentation_source = (ROOT / 'src' / 'client' / 'Presentation.lua').read_text(encoding='utf-8')
presentation_config_source = (ROOT / 'src' / 'shared' / 'PresentationConfig.lua').read_text(encoding='utf-8')
cosmetics_source = (ROOT / 'src' / 'server' / 'Cosmetics.lua').read_text(encoding='utf-8')
project_source = (ROOT / 'default.project.json').read_text(encoding='utf-8')
for required in ('IKControl', 'DropzoneRightAimIK', 'DropzoneLeftAimIK', 'self.humanoid.AutoRotate = false', 'self:restorePose()'):
    assert required in presentation_source
for required in ('RightGripPart', 'WeaponRootOffset', 'usesWeaponRoot', 'joint.Part0 = root', 'self.baseJointPart0'):
    assert required in presentation_source or required in presentation_config_source
assert presentation_config_source.count('WeaponRootOffset = CFrame.new') == 3
assert 'self.humanoid.RigType == Enum.HumanoidRigType.R15' in presentation_source
for required in ('ServerStorage:FindFirstChild("WeaponModels")', 'if anchor and templateWeapon(f, kind, cf, anchor) then return f end', 'unsafeWeaponClasses', 'if kind == "Pistol" then'):
    assert required in cosmetics_source
for required in ('VectorForce=true', 'AlignPosition=true', 'BodyVelocity=true', 'item:IsA("Constraint")', 'DropzoneWeaponWeld', 'weld.Part0, weld.Part1, weld.Parent = root, part, root', 'item:IsA("JointInstance")'):
    assert required in cosmetics_source
assert project_source.count('"$ignoreUnknownInstances": true') == 2
assert '"TownTemplates"' in project_source and '"WeaponModels"' in project_source
assert '"ServerStorage": {\n      "$ignoreUnknownInstances"' not in project_source
print('PASS: shoulder aim restoration, safe weapon templates, scoped Rojo retention and procedural fallback are present')

subprocess.run([sys.executable, '-X', 'utf8', str(ROOT / 'tests' / 'preplay_analysis.py')], check=True)
