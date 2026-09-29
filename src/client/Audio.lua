local Config = require(game.ReplicatedStorage.DropzoneShared.AudioConfig)
local Audio = {}
Audio.__index = Audio
function Audio.asset(id)
    if type(id) ~= "string" then return nil end
    local digits = id:match("^rbxassetid://(%d+)$") or id:match("^(%d+)$")
    if not digits or not tonumber(digits) or tonumber(digits) <= 0 then return nil end
    return "rbxassetid://" .. digits
end
function Audio.new(parent)
    return setmetatable({parent = parent, voices = {}, cooldowns = {}}, Audio)
end
function Audio:play(key, position, looped)
    local spec, now = Config[key], os.clock()
    local id = spec and Audio.asset(spec.Id)
    -- No instances, loads or playback calls for missing / malformed placeholders.
    if not id or now < (self.cooldowns[key] or 0) then return nil end
    self.cooldowns[key] = now + spec.Cooldown
    local voice
    for _, candidate in ipairs(self.voices) do
        if not candidate.sound.IsPlaying then voice = candidate; break end
    end
    if not voice and #self.voices < Config.MaxVoices then
        local anchor = Instance.new("Part")
        anchor.Name, anchor.Size, anchor.Transparency = "AudioAnchor", Vector3.new(.1,.1,.1), 1
        anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = true, false, false, false
        anchor.Parent = self.parent
        local sound = Instance.new("Sound")
        sound.RollOffMinDistance, sound.RollOffMaxDistance = Config.MinDistance, Config.MaxDistance
        sound.Parent = anchor
        voice = {anchor = anchor, sound = sound}
        table.insert(self.voices, voice)
    end
    -- Drop excess cues instead of stealing a loop or allocating unbounded voices.
    if not voice then return nil end
    local sound = voice.sound
    sound.Parent = position and voice.anchor or self.parent
    if position then voice.anchor.Position = position end
    sound.SoundId, sound.Volume, sound.Looped = id, spec.Volume, looped == true
    sound.TimePosition = 0
    voice.generation = (voice.generation or 0)+1
    local generation = voice.generation
    sound:Play()
    -- A stopped/completed voice can be reused: old owners must not stop its new cue.
    return {
        Stop = function() if voice.generation == generation then sound:Stop() end end,
        SetPosition = function(_, value) if voice.generation == generation then voice.anchor.Position = value end end,
    }
end
function Audio:clear()
    for _, voice in ipairs(self.voices) do voice.generation = (voice.generation or 0)+1; voice.sound:Stop() end
    self.cooldowns = {}
end
function Audio:destroy()
    self:clear()
    for _, voice in ipairs(self.voices) do voice.sound:Destroy(); voice.anchor:Destroy() end
    self.voices = {}
end
return Audio
