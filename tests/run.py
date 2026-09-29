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
