"""Offline Lua 5.4 syntax + logic checks. Roblox engine validation is separate.
Uses the system liblua without downloading or executing third-party packages.
"""
import ctypes
import ctypes.util
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
lib = ctypes.CDLL(ctypes.util.find_library('lua5.4'))
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
    run(path.read_text(), str(path.relative_to(ROOT)))
print('PASS: syntax of all Lua modules (Lua 5.4 compatible subset)')
source = (ROOT / 'tests' / 'regression.lua').read_text()
source = 'ROOT = ' + repr(str(ROOT)) + '\n' + source
run(source, 'regression.lua', True)
visual_source = 'ROOT = ' + repr(str(ROOT)) + '\n' + (ROOT / 'tests' / 'visuals.lua').read_text()
run(visual_source, 'visuals.lua', True)

hud = (ROOT / 'src' / 'client' / 'Hud.lua').read_text()
assert not re.search(r'EVOLUTION\s+[^\n]*\s*/\s*7', hud, re.I)
print('PASS: HUD has no obsolete seven-Evolution cap')
assert 'self.draft.ZIndex, self.draft.Active, self.draft.Selectable = 20, false, false' in hud
assert 'self.draftTitle.ZIndex = 21' in hud and 'card.ZIndex, card.AutoButtonColor = 22, true' in hud
print('PASS: draft overlay, title, and cards use explicit ZIndex without an active full-screen frame')

docs = '\n'.join(path.read_text() for path in [ROOT / 'README.md', *(ROOT / 'docs').glob('*.md')])
assert not re.search(r'(?:EVOLUTION|Evolution).{0,40}(?:/\s*7|max(?:imum)?\s+seven|最大\s*7)', docs, re.I)
print('PASS: README and docs have no obsolete seven-Evolution cap')

client = (ROOT / 'src' / 'client' / 'Main.client.lua').read_text()
round_reset = re.search(r'if not state or state\.roundId ~= s\.roundId then(?P<body>.*?)\n    end\n    state = s', client, re.S)
assert round_reset and 'submittedEvolutionDraft = nil' in round_reset.group('body')
print('PASS: a new round clears the submitted Evolution draft token')


actors_source = (ROOT / 'src' / 'server' / 'Actors.lua').read_text()
assert 'descendant.CanQuery = false' in actors_source and 'descendant.CanTouch = false' in actors_source
print('PASS: eliminated actors are removed from raycast and touch queries')

world_source = (ROOT / 'src' / 'server' / 'World.lua').read_text()
assert 'groundSurfaces = {}' in world_source
assert 'params.FilterDescendantsInstances = surfaces' in world_source
assert 'if not surfaces or #surfaces == 0 then return Vector3.new(position.X, 0, position.Z) end' in world_source
for required in ['island', 'roadX', 'roadZ', 'hill', 'centralPad']:
    assert f'table.insert(self.groundSurfaces, {required})' in world_source
print('PASS: ground raycasts use only designated walkable surfaces')

server_source = (ROOT / 'src' / 'server' / 'Main.server.lua').read_text()
assert 'ReplicatedStorage:GetChildren()' in server_source and 'child.Name == "DropzoneRemotes"' in server_source
assert 'remotes:GetChildren()' in server_source and 'child:IsA("RemoteEvent")' in server_source
print('PASS: Studio/Rojo startup deduplicates the remote folder and events')

assert 'and Theme.Orange or Theme.Paper' in client
print('PASS: hit marker restores the shared themed crosshair color')


building_source = (ROOT / 'src' / 'server' / 'Building.lua').read_text()
assert 'params.FilterDescendantsInstances = self.world.groundSurfaces or {}' in building_source
print('PASS: build overlap ignores every designated ground surface, including Hill')

bots_source = (ROOT / 'src' / 'server' / 'Bots.lua').read_text()
assert re.search(r'function Bots:clear\(\).*?self\.jobs = 0', bots_source, re.S)
assert 'if currentGeneration then self.jobs = math.max(0, self.jobs - 1) end' in bots_source
print('PASS: bot path worker accounting is generation-safe across resets')

round_source = (ROOT / 'src' / 'server' / 'Round.lua').read_text()
assert 'a.roundId = -1' in round_source
print('PASS: Results invalidates stale deferred Evolution work')

assert 'descendant.CanCollide = false' in actors_source and 'a.root.Anchored = true' in actors_source
print('PASS: eliminated actors are physically non-blocking and remain stable')


movement_source = (ROOT / 'src' / 'server' / 'Movement.lua').read_text()
assert 'function Movement.toggleCrouch(a)' in movement_source and 'function Movement.slide(a)' in movement_source
assert 'Config.SlideCooldown' in movement_source and 'Config.SlideMinSpeed' in movement_source
assert 'a.root.AssemblyLinearVelocity' in movement_source
print('PASS: crouch and slide are server-authoritative with cooldown and movement gates')

assert 'command == "Crouch"' in server_source and 'command == "Slide"' in server_source
assert 'hud:button("Crouch"' in client and 'hud:button("Sprint"' in client
assert 'Enum.KeyCode.LeftControl' in client and 'Enum.KeyCode.LeftShift' in client
print('PASS: mobile buttons and keyboard movement controls are wired')

assert 'crouching = a.crouching == true' in round_source and 'slideCooldown = math.max' in round_source
print('PASS: authoritative crouch/slide state is replicated in snapshots')

# Server ingress guards must run before every movement dispatch, including Results.
assert server_source.index('roundId ~= round.id or not round:isActive()') < server_source.index('command == "Sprint"')
assert server_source.index('not a or not a.alive') < server_source.index('command == "Sprint"')
assert 'send("Sprint", true)' in client and 'send("Sprint", false)' in client
assert 'UserInputService.JumpRequest' in client and 'command == "Jump"' in server_source
print('PASS: sprint/posture/jump use existing round/alive/ingress validation')
# Rectangles from actual button call sites; Draft stays clear at any uniform UIScale.
rects = []
for match in re.finditer(r'hud:button\("(Fire|Reload|Build|Sprint|Crouch)",\s*"[^"]+",\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)', client):
    rects.append((match[1], *map(int, match.groups()[1:])))
assert len(rects)==5
rects += [('Draft',16,132,600,177)]
rects += [(f'BuildType{i}',632+i*82,137,76,52) for i in range(3)]
rects += [(f'Slot{i}',279+i*116,418,110,48) for i in range(3)]
for i,(name,x,y,w,h) in enumerate(rects):
    for other,ox,oy,ow,oh in rects[i+1:]:
        assert x+w<=ox or ox+ow<=x or y+h<=oy or oy+oh<=y, (name,other)
print('PASS: movement/combat/build/slot/Draft rectangles do not overlap on the shared canvas')

loot_source = (ROOT / 'src' / 'server' / 'Loot.lua').read_text()
assert 'local function useful(a, item)' in loot_source
assert 'WeaponStats.rank(item.rarity) > WeaponStats.rank(weapon.rarity)' in loot_source
assert 'weapon.reserve < 240' in loot_source
assert '#a.inventory == 0 and not Weapons[kind]' not in loot_source
print('PASS: auto pickup preserves loot that gives no weapon/ammo benefit and allows useful consumables')
