-- Pure functions used by both the game and offline regression tests.
local Rules = {}
function Rules.botCount(humans, target)
    return math.max(0, target - humans)
end
function Rules.finite(n)
    return type(n) == "number" and n == n and math.abs(n) < 1e8
end
function Rules.resolveDamage(health, shield, amount, bypass)
    local absorbed = bypass and 0 or math.min(shield, amount)
    local hpDamage = math.min(health, math.max(0, amount - absorbed))
    return health - hpDamage, shield - absorbed, hpDamage + absorbed
end
function Rules.phaseAt(phases, elapsed)
    local offset = 0
    for i, phase in ipairs(phases) do
        local duration = phase.hold + phase.shrink
        if elapsed < offset + duration then
            local time = elapsed - offset
            local alpha = math.max(0, math.min(1, (time - phase.hold) / phase.shrink))
            local remaining = time < phase.hold and phase.hold - time or duration - time
            return i, alpha, remaining, time >= phase.hold
        end
        offset = offset + duration
    end
    return #phases, 1, 0, true
end
function Rules.totalDuration(phases)
    local total = 0
    for _, p in ipairs(phases) do total = total + p.hold + p.shrink end
    return total
end

function Rules.shouldShowEvolutionDraft(snapshot)
    if not snapshot then return false end
    local active = snapshot.phase == "Active" or snapshot.phase == "FinalZone"
    local me = snapshot.me
    return active and me ~= nil and me.alive == true and me.evolutionDraft ~= nil
end
function Rules.closestLiveTarget(actor, actors, maxDistance)
    local target, distance = nil, maxDistance
    for _, candidate in ipairs(actors) do
        if candidate ~= actor and candidate.alive then
            local current = (candidate.root.Position - actor.root.Position).Magnitude
            if current < distance then target, distance = candidate, current end
        end
    end
    return target, distance
end
 function Rules.canFire(actor, weapon, now)
    return actor.alive and weapon ~= nil and not actor.reloading
        and actor.ammo > 0 and now >= actor.nextShot
end
return Rules
