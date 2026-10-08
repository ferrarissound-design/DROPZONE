local Players = game:GetService("Players")
local Shared = game.ReplicatedStorage.DropzoneShared
local WeaponStats = require(Shared.WeaponStats)
local Rules = require(Shared.Rules)
local Evolution = require(script.Parent.Evolution)
local Cosmetics = require(script.Parent.Cosmetics)
local Combat = {}
Combat.__index = Combat
local function diagnostics(a)
    a.diagnostics = a.diagnostics or {shots={}, hits={}, weaponDamage={}, builds=0, pickups=0, zoneDamage=0}
    a.diagnostics.shots = a.diagnostics.shots or {}
    a.diagnostics.hits = a.diagnostics.hits or {}
    a.diagnostics.weaponDamage = a.diagnostics.weaponDamage or {}
    return a.diagnostics
end
function Combat.new(actors, effects, builds)
    return setmetatable({actors = actors, effects = effects, builds = builds, rng = Random.new()}, Combat)
end
function Combat:visual(a)
    local old = a.model:FindFirstChild("HeldWeapon")
    if old then old:Destroy() end
    local item = a.inventory[a.slot]
    if not item then return end
    local hand = a.model:FindFirstChild("RightHand") or a.model:FindFirstChild("Right Arm")
    if not hand then return end
    Cosmetics.weapon(a.model, item.kind, hand.CFrame * CFrame.new(0, -0.3, -1), hand)
end
function Combat:give(a, kind, rarity)
    rarity = rarity or "Common"
    local spec = WeaponStats.get(kind, rarity)
    if not spec or not a.alive then return false end
    for slot, item in ipairs(a.inventory) do
        if item.kind == kind then
            item.reserve = math.min(240, item.reserve + spec.reserve)
            if WeaponStats.rank(rarity) > WeaponStats.rank(item.rarity) then
                item.rarity = rarity
                if slot == a.slot then
                    a.reloadToken, a.reloading = a.reloadToken + 1, false
                end
            end
            return true -- lower/equal tiers provide ammo, never downgrade
        end
    end
    table.insert(a.inventory, {kind = kind, rarity = rarity, ammo = spec.magazine, reserve = spec.reserve})
    if #a.inventory == 1 then a.slot, a.ammo = 1, spec.magazine; self:visual(a) end
    return true
end
function Combat:equip(a, slot)
    if type(slot) ~= "number" or slot % 1 ~= 0 or not a.inventory[slot] or slot == a.slot then return end
    a.reloadToken, a.reloading = a.reloadToken + 1, false
    a.slot, a.ammo = slot, a.inventory[slot].ammo
    self:visual(a)
end
function Combat:reload(a)
    local item = a.inventory[a.slot]
    if not item or not a.alive or a.reloading then return end
    local spec = WeaponStats.get(item.kind, item.rarity)
    if item.ammo >= spec.magazine or item.reserve <= 0 then return end
    a.reloading, a.reloadToken = true, a.reloadToken + 1
    local token = a.reloadToken
    task.delay(spec.reload * math.max(0.73, 1 - Evolution.total(a, "QuickHands")), function()
        if not a.alive or token ~= a.reloadToken then return end
        local count = math.min(spec.magazine - item.ammo, item.reserve)
        item.ammo, item.reserve = item.ammo + count, item.reserve - count
        a.ammo, a.reloading = item.ammo, false
    end)
end
function Combat:stopFire(a)
    -- Stale cooldown callbacks compare the identity of this reservation.
    a.pendingShot = nil
end
function Combat:fire(a, direction)
    if typeof(direction) ~= "Vector3" or not Rules.finite(direction.X) or not Rules.finite(direction.Y)
        or not Rules.finite(direction.Z) or direction.Magnitude < 0.5 or direction.Magnitude > 1.5 then return end
    local item = a.inventory[a.slot]
    local spec = item and WeaponStats.get(item.kind, item.rarity)
    local now = os.clock()
    if not a.alive or not spec or a.reloading or a.ammo <= 0 or not a.root.Parent
        or not a.model.Parent or a.humanoid.Health <= 0 then return end
    -- A Roblox third-person camera may legitimately aim behind the avatar while
    -- moving. Reject invalid vectors/cadence via existing server checks, not
    -- avatar-facing comparisons that suppress normal hip-fire.
    if now < a.nextShot then
        -- Keep at most one human request arriving just before the cooldown.
        -- It fires at the authoritative deadline, never early or as a burst.
        local waitSeconds = a.nextShot - now
        if a.player and waitSeconds <= math.min(0.05, spec.interval / 2) and not a.pendingShot then
            local pending = {item=item, slot=a.slot, token=a.reloadToken, roundId=a.roundId}
            a.pendingShot = pending
            task.delay(waitSeconds, function()
                if a.pendingShot ~= pending then return end
                a.pendingShot = nil
                if a.alive and a.roundId == pending.roundId and a.reloadToken == pending.token
                    and a.slot == pending.slot and a.inventory[a.slot] == pending.item
                    and a.player.Parent then self:fire(a, direction) end
            end)
        end
        return
    end
    if not Rules.canFire(a, spec, now) then return end
    a.pendingShot = nil -- any newer accepted shot invalidates an old callback
    a.nextShot = now + spec.interval
    item.ammo, a.ammo = item.ammo - 1, item.ammo - 1
    local diag = diagnostics(a)
    if diag.firstShotSeconds == nil and a.startTime then
        diag.firstShotSeconds = math.max(0, now - a.startTime)
    end
    diag.shots[item.kind] = (diag.shots[item.kind] or 0) + 1
    local origin = a.root.Position + Vector3.new(0, 1.4, 0)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {a.model}
    local basis = CFrame.lookAt(Vector3.zero, direction.Unit)
    local spread = math.rad(spec.spread * math.max(0.76, 1 - Evolution.total(a, "HunterEyes")))
    local endpoints, impacts, hitEnemy, damageByVictim = {}, {}, false, {}
    for _ = 1, spec.pellets do
        local shot = (basis * CFrame.Angles(self.rng:NextNumber(-spread, spread), self.rng:NextNumber(-spread, spread), 0)).LookVector
        local result = workspace:Raycast(origin, shot * spec.range, params)
        table.insert(endpoints, result and result.Position or origin + shot * spec.range)
        if result then
            local victim = self.actors:fromPart(result.Instance)
            if victim and victim ~= a and victim.alive then
                local falloff = item.kind == "Shotgun" and math.max(0.3, 1 - result.Distance / spec.range * 0.65) or 1
                local victimDiag = diagnostics(victim)
                local previousReason = victimDiag.deathReason
                victimDiag.deathReason = "Combat"
                local hp, shield = self.actors:damage(victim, spec.damage * falloff, a)
                if victim.alive then victimDiag.deathReason = previousReason end
                if hp + shield > 0 then
                    diag.weaponDamage[item.kind] = (diag.weaponDamage[item.kind] or 0) + hp + shield
                    local damage = damageByVictim[victim] or {position=result.Position, normal=result.Normal, hp=0, shield=0}
                    damage.hp, damage.shield = damage.hp + hp, damage.shield + shield
                    damage.eliminated = not victim.alive
                    damageByVictim[victim] = damage
                    hitEnemy = true
                end
            else
                if not victim then table.insert(impacts, {position=result.Position, normal=result.Normal}) end
                if self.builds then self.builds:damage(result.Instance, spec.damage) end
            end
        end
    end
    -- Capped shot rate, recipients and endpoints; no client-supplied hit or damage data.
    for _, player in ipairs(Players:GetPlayers()) do
        local viewer = self.actors.byPlayer[player]
        -- Spectator cameras can be anywhere in the arena, including late joins
        -- without an Actor. Corpse/lobby distance cannot bound their view.
        if player.Parent and (not viewer or not viewer.alive
            or (viewer.root.Parent and (viewer.root.Position - origin).Magnitude < 330)) then
            self.effects:FireClient(player, "Shot", origin, endpoints, item.kind, a.id, a.roundId, impacts)
        end
    end
    if hitEnemy then diag.hits[item.kind] = (diag.hits[item.kind] or 0) + 1 end
    if a.player and hitEnemy then
        local confirmed = {}
        for _, damage in pairs(damageByVictim) do table.insert(confirmed, damage) end
        self.effects:FireClient(a.player, "Damage", a.roundId, confirmed)
    end
end
return Combat
