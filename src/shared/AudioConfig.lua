-- Supply only assets owned by / permitted for this experience. Empty IDs are silent.
local Audio = {MaxVoices = 12, MaxDistance = 140, MinDistance = 12}
for _, key in ipairs({
    "RifleFire", "ShotgunFire", "PistolFire", "Reload", "Empty",
    "ShieldHit", "HealthHit", "Elimination", "Pickup", "RarePickup", "EpicPickup",
    "Footstep", "SprintFootstep", "SlideStart", "SlideLoop", "SlideEnd",
    "EvolutionReady", "EvolutionSelect", "EvolutionApplied", "ZoneWarning", "ZoneDamage", "Button", "Error",
}) do
    Audio[key] = {Id = "", Volume = .35, Cooldown = .08}
end
Audio.ZoneDamage.Cooldown = 1.2
Audio.ZoneWarning.Cooldown = 3
Audio.Empty.Cooldown = .6
Audio.Footstep.Volume, Audio.SprintFootstep.Volume = .12, .16
Audio.SlideLoop.Volume = .15
return Audio
