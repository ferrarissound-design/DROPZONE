-- Creator Store sound selection for DROPZONE.
-- Use only sounds that remain permitted for this experience. Invalid/unavailable IDs fail silently.
local Audio = {MaxVoices = 12, MaxDistance = 140, MinDistance = 12}

local function cue(id, volume, cooldown)
    return {Id = id or "", Volume = volume or .35, Cooldown = cooldown or .08}
end

-- Combat
Audio.RifleFire = cue("9114727096", .28, .10)      -- ProSoundEffects: Gun Single Shots 10
Audio.ShotgunFire = cue("5656322299", .40, .25)    -- Creator Store: shotgun fire sound
Audio.PistolFire = cue("9119136387", .24, .16)     -- ProSoundEffects: Silenced Pistol 6
Audio.Reload = cue("8145744063", .24, .25)         -- Gun Reload
Audio.Empty = cue("9117048600", .18, .60)          -- ProSoundEffects: Nail Gun Clicking 2
Audio.ShieldHit = cue("9119074309", .20, .10)      -- ProSoundEffects: Shield Impacts 2
Audio.HealthHit = cue("9119060148", .18, .10)      -- ProSoundEffects: Sharp Body Hit 6
Audio.Elimination = cue("9120705982", .28, .30)    -- ProSoundEffects: Whoosh Explosion 1

-- Loot / UI
Audio.Pickup = cue("113397864512278", .12, .08)    -- UI Click 1
Audio.RarePickup = cue("9119802009", .20, .10)     -- ProSoundEffects: Synth Chime Single Synth Tone 3
Audio.EpicPickup = cue("9119902088", .24, .10)     -- ProSoundEffects: Synth Zap High Pitch...
Audio.Button = cue("113397864512278", .10, .05)
Audio.Error = cue("9113085665", .16, .35)          -- ProSoundEffects: Alarm Buzzer 3

-- Movement
-- Footstep clips found in Creator Store are multi-step sequences, so leave them empty
-- until we have single-step assets. The controller safely skips empty IDs.
Audio.Footstep = cue("", .12, .08)
Audio.SprintFootstep = cue("", .16, .08)
Audio.SlideStart = cue("9119195254", .15, .30)     -- ProSoundEffects: Slide By Books Across Table 1
Audio.SlideLoop = cue("", .15, .08)                -- no safe loop-ready clip selected yet
Audio.SlideEnd = cue("9126229490", .12, .25)       -- ProSoundEffects: Fast Airy Whoosh

-- Evolution / Zone
Audio.EvolutionReady = cue("9119802009", .22, .20)
Audio.EvolutionSelect = cue("9119144736", .14, .10) -- ProSoundEffects: Single High Pitch Beep Tone 3
Audio.EvolutionApplied = cue("9119902088", .26, .25)
Audio.ZoneWarning = cue("9113085665", .20, 3.0)
Audio.ZoneDamage = cue("9114648992", .14, 1.2)      -- ProSoundEffects: Graphics Beeps 2

return Audio
