local Players = game:GetService("Players")
local Config = require(game.ReplicatedStorage.DropzoneShared.Config)
local Rules = require(game.ReplicatedStorage.DropzoneShared.Rules)
local World = require(script.Parent.World)
local Actors = require(script.Parent.Actors)
local Evolution = require(script.Parent.Evolution)
local Round = {}
Round.__index = Round
function Round.new(services)
    local self = setmetatable(services, Round)
    self.phase, self.id, self.remaining = "Waiting", 0, 0
    self.loading, self.connections = {}, {}
    self.actors.onDeath = function(a, killer)
        if killer and killer ~= a and killer.alive then
            killer.kills = killer.kills + 1
            killer.energy = math.min(Config.MaxEnergy, killer.energy + 25)
            local evolution = Evolution.grant(killer)
            if killer.player and evolution then self.effects:FireClient(killer.player, "Notice", "EVOLUTION: " .. evolution) end
        end
        if a.player then self.effects:FireClient(a.player, "Notice", "敗退 — 観戦中") end
    end
    return self
end
function Round:isActive()
    return self.phase == "Active" or self.phase == "FinalZone"
end
function Round:loadLobby(player)
    if self.loading[player] then return end
    self.loading[player] = true
    task.spawn(function()
        local ok = pcall(function() player:LoadCharacterAsync() end)
        self.loading[player] = nil
        if ok and player.Parent and not self.actors.byPlayer[player] and player.Character then
            player.Character:PivotTo(self.world.lobby)
            local root = player.Character:FindFirstChild("HumanoidRootPart")
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
    local pending = 0
    for i, player in ipairs(roster) do
        if i <= Config.MaxPlayers then
            pending = pending + 1
            task.spawn(function()
                -- Wait briefly for an in-flight lobby load rather than race two avatar loads.
                local deadline = os.clock() + 5
                while self.loading[player] and os.clock() < deadline do task.wait(0.1) end
                if self.loading[player] or not player.Parent then pending = pending - 1; return end
                self.loading[player] = true
                local ok = pcall(function() player:LoadCharacterAsync() end)
                self.loading[player] = nil
                if ok and player.Parent and player.Character then
                    if self.id == id and self.phase == "Starting" then
                        local a = self.actors:add(player.Character, player, player.UserId)
                        if a then
                            local ground = World.ground(self.world, self.world.spawns[spawnIndices[i]])
                            a.model:PivotTo(CFrame.new(ground + Vector3.new(0, 4, 0)))
                            a.root.Anchored = true
                        end
                    elseif not self.actors.byPlayer[player] then player.Character:PivotTo(self.world.lobby) end
                end
                pending = pending - 1
            end)
        end
    end
    local deadline = os.clock() + 15
    while pending > 0 and os.clock() < deadline do task.wait(0.1) end
    local humans = #self.actors:alive()
    if humans == 0 then return false end
    local occupied = {}
    for _, a in ipairs(self.actors.list) do table.insert(occupied, a.root.Position) end
    for i = 1, Rules.botCount(humans, Config.TargetCombatants) do
        local choice
        for _, index in ipairs(spawnIndices) do
            local candidate, valid = self.world.spawns[index], true
            for _, p in ipairs(occupied) do if (candidate - p).Magnitude < 25 then valid = false; break end end
            if valid then choice = candidate; break end
        end
        choice = choice or self.world.spawns[i]
        table.insert(occupied, choice)
        local model = Actors.botModel(self.world.dynamic, i)
        model:PivotTo(CFrame.new(World.ground(self.world, choice) + Vector3.new(0, 4, 0)))
        local a = self.actors:add(model, nil, -i)
        if a then self.combat:give(a, "Pistol") end
    end
    self.phase, self.started = "Active", os.clock()
    for _, a in ipairs(self.actors.list) do a.startTime, a.root.Anchored = self.started, false end
    return true
end
function Round:finish()
    self.phase = "Results"
    local alive = self.actors:alive()
    self.winner = alive[1] and alive[1].name or nil
    for _, a in ipairs(self.actors.list) do
        if a.alive then a.rank, a.survival = 1, os.clock() - self.started end
        a.reloadToken, a.reloading = a.reloadToken + 1, false
        if a.root.Parent then a.root.Anchored = true end
    end
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
            self.actors:eliminate(a)
        elseif self.zone:outside(a.root.Position) then
            self.actors:damage(a, self.zone.damage * dt, nil, true)
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
        local slots = {}
        for i, w in ipairs(a.inventory) do slots[i] = w.kind end
        data.me = {alive = a.alive, hp = math.ceil(a.humanoid.Health), maxHp = a.humanoid.MaxHealth, shield = math.ceil(a.shield),
            kills = a.kills, damage = math.floor(a.damage), energy = a.energy, evolutions = a.evolutionCount,
            evolution = Evolution.order[a.evolutionCount], weapon = item and item.kind, ammo = item and item.ammo or 0,
            reserve = item and item.reserve or 0, reloading = a.reloading, slots = slots, slot = a.slot,
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
            if self:isActive() then self:finish() end
            for t = Config.ResultsTime, 1, -1 do self.remaining = t; task.wait(1) end
        end
        self:reset()
        task.wait(1)
    end
end
return Round
