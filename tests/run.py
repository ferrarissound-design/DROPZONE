"""Offline Lua 5.4 syntax + logic checks. Roblox engine validation is separate.
Uses the system liblua without downloading or executing third-party packages.
"""
import ctypes
import ctypes.util
from pathlib import Path
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
