-- Coordinates are inside ScreenGui.CoreUISafeInsets, never the raw viewport.
-- Leave both native thumbstick and the bottom-right native Jump area empty.
local Layout = {}
function Layout.measure(width, height)
    local scale = math.min(width / 760, height / 360)
    scale = math.max(scale, .01)
    return width / scale, height / scale, scale
end
function Layout.buttons(w, h)
    return {
        Fire={w-88,h-268,72,72}, Aim={w-168,h-260,64,64},
        Reload={w-248,h-260,64,64}, Build={w-88,h-188,64,64},
        Crouch={w-168,h-188,64,64}, Sprint={w-248,h-188,64,64},
        Wall={w-248,h-260,64,64}, Floor={w-168,h-260,64,64},
        Ramp={w-88,h-260,64,64}, Place={w-168,h-188,64,64},
        Combat={w-88,h-188,64,64},
        Slot1={w/2-130,h-64,80,48}, Slot2={w/2-40,h-64,80,48},
        Slot3={w/2+50,h-64,80,48},
        EvolutionReady={16,68,210,32}, Spectate={w/2-100,h-64,200,48},
    }
end
local combat = {Fire=true,Aim=true,Reload=true,Build=true,Crouch=true}
local build = {Wall=true,Floor=true,Ramp=true,Place=true,Combat=true}
function Layout.visible(name, mode)
    if combat[name] then return mode ~= "Build" end
    if build[name] then return mode == "Build" end
    return true
end
return Layout
