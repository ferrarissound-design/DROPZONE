local Config = require(game.ReplicatedStorage.DropzoneShared.AnimationConfig)
local Audio = require(script.Parent.Audio)
local Animations = {}
Animations.__index = Animations
function Animations.new()
    return setmetatable({tracks = {}, failed = {}}, Animations)
end
function Animations:clear()
    for _, track in pairs(self.tracks) do track:Stop(0); track:Destroy() end
    self.tracks, self.failed, self.humanoid, self.movementKey = {}, {}, nil, nil
end
function Animations:bind(humanoid)
    if self.humanoid ~= humanoid then self:clear(); self.humanoid = humanoid end
end
function Animations:stop(key)
    local track = self.tracks[key]
    if track and track.IsPlaying then track:Stop(.1) end
end
function Animations:play(key)
    local spec, humanoid = Config[key], self.humanoid
    if not spec or not humanoid or not humanoid.Parent or self.failed[key] then return end
    local id = Audio.asset(spec[humanoid.RigType == Enum.HumanoidRigType.R6 and "R6" or "R15"])
    if not id then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end -- Never yield waiting for a character being destroyed.
    local track = self.tracks[key]
    if not track then
        local animation = Instance.new("Animation")
        animation.AnimationId = id
        local ok, result = pcall(function() return animator:LoadAnimation(animation) end)
        animation:Destroy()
        if not ok then self.failed[key] = true; return end
        track = result
        track.Priority, track.Looped = Enum.AnimationPriority[spec.Priority], spec.Looped
        self.tracks[key] = track
    end
    if not track.IsPlaying or not spec.Looped then track:Play(.08) end
end
function Animations:shot(kind)
    self:play(kind.."Fire")
end
function Animations:movement(key)
    if self.movementKey == key then if key then self:play(key) end; return end
    if self.movementKey then self:stop(self.movementKey) end
    self.movementKey = key
    if key then self:play(key) end
end
return Animations
