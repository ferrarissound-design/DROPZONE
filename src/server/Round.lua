local Players = game:GetService("Players")
local Config = require(game.ReplicatedStorage.DropzoneShared.Config)
local Rules = require(game.ReplicatedStorage.DropzoneShared.Rules)
local World = require(script.Parent.World)
local Actors = require(script.Parent.Actors)
local Evolution = require(script.Parent.Evolution)
local Movement = require(script.Parent.Movement)
local Round = {}
Round.__index = Round
local weaponOrder = {"Pistol", "Rifle", "Shotgun"}
local function diagValue(a, bucket, kind)
    local d = a.diagnostics
    local values = d and d[bucket]
    return values and values[kind] or 0
end
local function weaponLine(a)
    local parts = {}
    for _, kind in ipairs(weaponOrder) do
        table.insert(parts, string.format("%s:S%d/H%d/D%d", kind,
            diagValue(a, "shots", kind), diagValue(a, "hits", kind), math.floor(diagValue(a, "weaponDamage", kind))))
    end
    return table.concat(parts, " ")
end
-- Session-only timings in seconds since round start. Nil means the milestone
-- was never reached; no DataStore, per-frame samples or new player tracking.
local function milestone(value)
    return type(value) == "number" and string.format("%.1f", value) or "-"
end
local function emitDiagnostics(self)
    if not Config.PlaytestDiagnostics then return end
    local totalKills, totalDamage, zoneDeaths = 0, 0, 0
    local aggregate = {diagnostics={shots={}, hits={}, weaponDamage={}}}
    for _, a in ipairs(self.actors.list) do
        totalKills = totalKills + (a.kills or 0)
        totalDamage = totalDamage + (a.damage or 0)
        if a.diagnostics and a.diagnostics.deathReason == "Zone" then zoneDeaths = zoneDeaths + 1 end
        for _, kind in ipairs(weaponOrder) do
            aggregate.diagnostics.shots[kind] = (aggregate.diagnostics.shots[kind] or 0) + diagValue(a, "shots", kind)
            aggregate.diagnostics.hits[kind] = (aggregate.diagnostics.hits[kind] or 0) + diagValue(a, "hits", kind)
            aggregate.diagnostics.weaponDamage[kind] = (aggregate.diagnostics.weaponDamage[kind] or 0) + diagValue(a, "weaponDamage", kind)
        end
    end
    local duration = self.started and math.max(0, os.clock() - self.started) or 0
    print(string.format("[DROPZONE DIAG] round=%d duration=%.1fs combatants=%d winner=%s kills=%d damage=%d zoneDeaths=%d %s",
        self.id, duration, #self.actors.list, self.winner or "DRAW", totalKills, math.floor(totalDamage), zoneDeaths, weaponLine(aggregate)))
    for _, a in ipairs(self.actors.list) do
        if a.player then
            local d = a.diagnostics or {}
            local evolution = #a.evolutionHistory > 0 and table.concat(a.evolutionHistory, ">") or "-"
            print(string.format("[DROPZONE DIAG] player=%s rank=%s kills=%d damage=%d survival=%ds builds=%d pickups=%d zoneDamage=%d death=%s evo=%s firstWeapon=%s firstShot=%s firstKill=%s firstEvolution=%s %s",
                a.name, tostring(a.rank or "-"), a.kills or 0, math.floor(a.damage or 0), math.floor(a.survival or 0),
                d.builds or 0, d.pickups or 0, math.floor(d.zoneDamage or 0), d.deathReason or (a.alive and "Alive" or "Other"),
                evolution, milestone(d.firstWeaponSeconds), milestone(d.firstShotSeconds),
                milestone(d.firstKillSeconds), milestone(d.firstEvolutionSeconds), weaponLine(a)))
        end
    end
end
function Round.new(services)
    local self = setmetatable(services, Round)
    self.phase, self.id, self.remaining = "Waiting", 0, 0
    self.loading, self.connections = {}, {}
    self.actors.onDeath = function(a, killer)
        Evolution.cancel(a) -- pending/queued drafts never survive elimination
        if a.diagnostics and not a.diagnostics.deathReason then
            a.diagnostics.deathReason = killer and killer ~= a and "Combat" or "Other"
        end
        if killer and killer ~= a and killer.alive then
            killer.kills = killer.kills + 1
            if killer.kills == 1 and killer.diagnostics and killer.startTime then
                killer.diagnostics.firstKillSeconds = math.max(0, os.clock() - killer.startTime)
            end
            killer.energy = math.min(Evolution.maxEnergy(killer), killer.energy + 25)
            Evolution.onKill(killer, self.id, self.zone)
        end
        if a.player then self.effects:FireClient(a.player, "Notice", self.id, "敗退 — 観戦中") end
    end
    return self
end
function Round:isActive()
    return self.phase == "Active" or self.phase == "FinalZone"
end
function Round:loadLobby(player)
    if self.loading[player] then return end
    local loadToken = {}
    self.loading[player] = loadToken
    task.spawn(function()
        local ok = pcall(function() player:LoadCharacterAsync() end)
        -- Never let an old asynchronous completion clear a newer load lock.
        if self.loading[player] ~= loadToken then return end
        self.loading[player] = nil
        local character = player.Character
        if ok and player.Parent and not self.actors.byPlayer[player] and character then
            character:PivotTo(self.world.lobby)
            local root = character:FindFirstChild("HumanoidRootPart")
            if root then root.Anchored = false end
        end
    end)
end
function Round:start()
    self.id, self.phase, self.winner = self.id + 1, "Starting", nil
    self.zone:reset()
    self.loot:reset()
    local id, roster = self.id, Players:GetPlayers()
    table.sort(roster, function(a, b) return a.UserId < b.UserId end)
    local spawnIndices = {}
    for i = 1, #self.world.spawns do spawnIndices[i] = i end
    for i = #spawnIndices, 2, -1 do local j = math.random(i); spawnIndices[i], spawnIndices[j] = spawnIndices[j], spawnIndices[i] end
    -- Share reservations across asynchronous avatar loads AND BOT placement.
    -- Resolve -> register -> reserve -> PivotTo below never yields.
    local occupied, acceptingLoads = {}, true
    local function preferredSpawn(slot)
        if #spawnIndices > 0 then
            return self.world.spawns[spawnIndices[(slot - 1) % #spawnIndices + 1]]
        end
        -- Even an empty generated pool can recover via the resolver's scans.
        local angle = (slot - 1) * math.pi * 2 / 24
        return Vector3.new(math.cos(angle) * 245, 4, math.sin(angle) * 245)
    end
    local pending = 0
    for i, player in ipairs(roster) do
        if i <= Config.MaxPlayers then
            pending = pending + 1
            task.spawn(function()
                -- Wait briefly for an in-flight lobby load rather than race two avatar loads.
                local deadline = os.clock() + 5
                while self.loading[player] and os.clock() < deadline do task.wait(0.1) end
                if self.loading[player] or not player.Parent then pending = pending - 1; return end
                local loadToken = {}
                self.loading[player] = loadToken
                local ok = pcall(function() player:LoadCharacterAsync() end)
                if self.loading[player] ~= loadToken then pending = pending - 1; return end
                self.loading[player] = nil
                local character = player.Character
                if ok and player.Parent and character and character == player.Character then
                    if acceptingLoads and self.id == id and self.phase == "Starting" then
                        local position = World.resolveSpawn(self.world, preferredSpawn(i), occupied)
                        local a = position and self.actors:add(character, player, player.UserId)
                        if a then
                            a.roundId = id
                            table.insert(occupied, position)
                            a.root.Anchored = true
                            a.model:PivotTo(CFrame.new(position))
                            a.root.AssemblyLinearVelocity, a.root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
                        else
                            -- Never register a combatant at an unchecked/blocked point.
                            character:PivotTo(self.world.lobby)
                            local root = character:FindFirstChild("HumanoidRootPart")
                            if root then root.Anchored = false end
                            warn(string.format("[DROPZONE] safe spawn unavailable for %s; waiting for next round", player.Name))
                            self.effects:FireClient(player, "Notice", id, "安全な開始位置がないため、次の試合を待ちます")
                        end
                    elseif not self.actors.byPlayer[player] then
                        -- A late load is a lobby-only avatar, never a round actor.
                        character:PivotTo(self.world.lobby)
                        local root = character:FindFirstChild("HumanoidRootPart")
                        if root then root.Anchored = false end
                    end
                end
                pending = pending - 1
            end)
        end
    end
    local deadline = os.clock() + 15
    while pending > 0 and os.clock() < deadline do task.wait(0.1) end
    acceptingLoads = false -- late loads cannot consume BOT reservations after the deadline
    if self.id ~= id or self.phase ~= "Starting" then return false end
    local humans = #self.actors:alive()
    -- run() resets/retries if no human can safely enroll; Starting never hangs.
    if humans == 0 then return false end
    for i = 1, Rules.botCount(humans, Config.TargetCombatants) do
        local position = World.resolveSpawn(self.world, preferredSpawn(#roster + i), occupied)
        if not position then
            warn("[DROPZONE] safe spawn pool exhausted; starting with fewer BOTs")
            break -- keep the human round playable; never force a blocked BOT spawn
        end
        local model = Actors.botModel(self.world.dynamic, i)
        model:PivotTo(CFrame.new(position))
        local a = self.actors:add(model, nil, -i)
        if a then
            table.insert(occupied, position)
            a.roundId, a.root.Anchored = id, true
            a.root.AssemblyLinearVelocity, a.root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
            self.combat:give(a, "Pistol")
        else model:Destroy() end
    end
    self.phase, self.started = "Active", os.clock()
    for _, a in ipairs(self.actors.list) do a.startTime, a.root.Anchored = self.started, false end
    return true
end
function Round:finish(abandoned)
    self.phase = "Results"
    local alive = self.actors:alive()
    -- Everyone leaving is an abandoned match, not an automatic BOT victory.
    self.winner = not abandoned and alive[1] and alive[1].name or nil
    for _, a in ipairs(self.actors.list) do
        Evolution.cancel(a)
        -- Invalidate deferred/timeout Evolution work from the finished round before Results begins.
        Movement.reset(a)
        Evolution.refresh(a)
        a.roundId = -1
        if a.alive and not abandoned then a.rank, a.survival = 1, os.clock() - self.started end
        a.reloadToken, a.reloading = a.reloadToken + 1, false
        if a.root.Parent then a.root.Anchored = true end
    end
    emitDiagnostics(self)
end
function Round:reset()
    self.phase, self.id = "Resetting", self.id + 1
    self.bots:clear()
    self.actors:clear()
    self.builds:clear()
    self.loot:clear()
    self.zone:reset()
    self.winner, self.remaining = nil, 0
    for _, player in ipairs(Players:GetPlayers()) do self:loadLobby(player) end
end
function Round:step(dt)
    if not self:isActive() then return end
    self.zone:update(dt)
    if self.zone.phase == #Config.ZonePhases then self.phase = "FinalZone" end
    self.remaining = math.max(0, math.ceil(Rules.totalDuration(Config.ZonePhases) - self.zone.elapsed))
    -- Resolve a stable start-of-tick cohort before deciding the winner. Environmental
    -- eliminations in this tick share the same finishing rank, independent of list order.
    -- Zero-radius storm damage also applies at the exact center.
    local cohort = self.actors:alive()
    local eliminatedThisTick = {}
    for _, a in ipairs(cohort) do
        if not a.root.Parent or not a.model.Parent or a.root.Position.Y < -30 then
            if a.diagnostics then
                a.diagnostics.deathReason = a.root.Parent and a.model.Parent and a.root.Position.Y < -30 and "Fall" or "Other"
            end
            self.actors:eliminate(a)
        elseif self.zone:outside(a.root.Position) then
            local previousReason = a.diagnostics and a.diagnostics.deathReason
            if a.diagnostics then a.diagnostics.deathReason = "Zone" end
            local hpLoss = self.actors:damage(a, self.zone.damage * dt, nil, true)
            if a.diagnostics then
                a.diagnostics.zoneDamage = (a.diagnostics.zoneDamage or 0) + (hpLoss or 0)
                if a.alive then a.diagnostics.deathReason = previousReason end
            end
            if hpLoss and hpLoss > 0 and a.player and os.clock() >= (a.nextZoneAudio or 0) then
                a.nextZoneAudio = os.clock()+1.2
                self.effects:FireClient(a.player, "ZoneDamage", self.id)
            end
        end
        if not a.alive then
            table.insert(eliminatedThisTick, a)
        else
            Evolution.step(a, dt)
        end
    end
    -- Multiple environmental deaths at one tick share a placement. A simultaneous
    -- final storm elimination is a draw, never a traversal-order winner.
    if #eliminatedThisTick > 1 then
        local sharedRank = #self.actors:alive() + 1
        for _, a in ipairs(eliminatedThisTick) do a.rank = sharedRank end
    end
    -- Fail-safe is deterministic and only used after the circle is already zero.
    if self.zone.elapsed > Rules.totalDuration(Config.ZonePhases) + Config.SuddenDeath then
        local alive = self.actors:alive()
        table.sort(alive, function(a, b)
            if a.kills ~= b.kills then return a.kills > b.kills end
            if a.damage ~= b.damage then return a.damage > b.damage end
            return a.id < b.id
        end)
        for i = #alive, 2, -1 do self.actors:eliminate(alive[i]) end
    end
    if #self.actors:alive() <= 1 then self:finish() end
end
function Round:snapshot(player)
    local a = self.actors.byPlayer[player]
    local targets = {}
    for _, live in ipairs(self.actors:alive()) do table.insert(targets, {id = live.id, name = live.name, model = live.model}) end
    local data = {phase = self.phase, roundId = self.id, remaining = self.remaining, alive = #targets,
        zone = self.zone:snapshot(), winner = self.winner, targets = targets}
    if a then
        local item = a.inventory[a.slot]
        local slots, slotRarities = {}, {}
        for i, w in ipairs(a.inventory) do slots[i], slotRarities[i] = w.kind, w.rarity or "Common" end
        local evolutionBuild, evolutionDraft = Evolution.snapshot(a)
        data.me = {alive = a.alive, hp = math.ceil(a.humanoid.Health), maxHp = a.humanoid.MaxHealth, shield = math.ceil(a.shield),
            kills = a.kills, damage = math.floor(a.damage), energy = a.energy, maxEnergy = Evolution.maxEnergy(a), evolutions = a.evolutionCount,
            evolutionBuild = evolutionBuild, evolutionDraft = evolutionDraft, weapon = item and item.kind, rarity = item and (item.rarity or "Common"), slotRarities = slotRarities, ammo = item and item.ammo or 0,
            reserve = item and item.reserve or 0, reloading = a.reloading, slots = slots, slot = a.slot,
            crouching = a.crouching == true, sliding = a.sliding == true, sprinting = a.sprinting == true,
            slideCooldown = math.max(0, (a.nextSlide or 0) - os.clock()),
            rank = a.rank, survival = math.floor(a.alive and os.clock() - a.startTime or a.survival)}
    end
    return data
end
function Round:run()
    while true do
        self.phase = "Waiting"
        while #Players:GetPlayers() == 0 do task.wait(1) end
        self.phase = "Intermission"
        for t = Config.Intermission, 1, -1 do self.remaining = t; task.wait(1) end
        local started = self:start()
        if started then
            while self:isActive() and #Players:GetPlayers() > 0 do task.wait(0.25) end
            if self:isActive() then self:finish(#Players:GetPlayers() == 0) end
            if #Players:GetPlayers() > 0 then
                for t = Config.ResultsTime, 1, -1 do self.remaining = t; task.wait(1) end
            end
        end
        self:reset()
        task.wait(1)
    end
end
return Round
