local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.DropzoneShared.Config)
local Evolution = require(script.Parent.Evolution)
local Movement = require(script.Parent.Movement)
local World = require(script.Parent.World)
local Actors = require(script.Parent.Actors)
local Zone = require(script.Parent.Zone)
local Building = require(script.Parent.Building)
local Combat = require(script.Parent.Combat)
local Loot = require(script.Parent.Loot)
local Bots = require(script.Parent.Bots)
local Round = require(script.Parent.Round)
Players.CharacterAutoLoads = false
-- Reuse one canonical remote folder and remove accidental duplicates left by Studio/Rojo iteration.
local remotes
for _, child in ipairs(ReplicatedStorage:GetChildren()) do
    if child.Name == "DropzoneRemotes" then
        if not remotes and child:IsA("Folder") then remotes = child else child:Destroy() end
    end
end
if not remotes then
    remotes = Instance.new("Folder")
    remotes.Name, remotes.Parent = "DropzoneRemotes", ReplicatedStorage
end
local function remote(name)
    local event
    for _, child in ipairs(remotes:GetChildren()) do
        if child.Name == name then
            if not event and child:IsA("RemoteEvent") then event = child else child:Destroy() end
        end
    end
    if not event then
        event = Instance.new("RemoteEvent")
        event.Name, event.Parent = name, remotes
    end
    return event
end
local action, snapshot, effects = remote("Action"), remote("Snapshot"), remote("Effects")
local world, actors, zone = World.create(), Actors.new(), Zone.new()
zone:reset()
local builds = Building.new(world)
local combat = Combat.new(actors, effects, builds)
local loot = Loot.new(world, combat, effects)
local bots = Bots.new(actors, combat, loot, zone, world)
local round = Round.new({world = world, actors = actors, zone = zone, builds = builds, combat = combat, loot = loot, bots = bots, effects = effects})
local limits = {}
action.OnServerEvent:Connect(function(player, roundId, command, argument)
    -- Bounded ingress before any physics, tables, or gameplay work.
    local now = os.clock()
    local limit = limits[player] or {time = now, tokens = 30}
    limit.tokens = math.min(30, limit.tokens + (now - limit.time) * 20)
    limit.time, limits[player] = now, limit
    if limit.tokens < 1 then return end
    limit.tokens = limit.tokens - 1
    if roundId ~= round.id or not round:isActive() then return end
    local a = actors.byPlayer[player]
    if not a or not a.alive or not a.root.Parent then return end
    if command == "Fire" then combat:fire(a, argument)
    elseif command == "Reload" then combat:reload(a)
    elseif command == "Equip" then combat:equip(a, argument)
    elseif command == "Build" then builds:place(a, argument)
    elseif command == "Pickup" then loot:pickup(a)
    elseif command == "Sprint" then
        if Movement.sprint(a, argument) then Evolution.refresh(a) end
    elseif command == "Jump" then
        if Movement.jump(a) then Evolution.refresh(a); a.humanoid.Jump = true end
    elseif command == "Posture" then
        local changed
        if a.sprinting then changed = Movement.slide(a) else changed = Movement.toggleCrouch(a) end
        if changed then Evolution.refresh(a) end
    elseif command == "Crouch" then
        if Movement.toggleCrouch(a) then Evolution.refresh(a) end
    elseif command == "Slide" then
        if Movement.slide(a) then Evolution.refresh(a) end
    elseif command == "Evolve" and type(argument) == "table" then
        local gained = Evolution.select(a, roundId, argument.draftId, argument.index)
        if gained then effects:FireClient(player, "Notice", "EVOLUTION: " .. gained.name .. " " .. gained.rankText) end
    end
end)
local function join(player)
    round:loadLobby(player)
end
Players.PlayerAdded:Connect(join)
Players.PlayerRemoving:Connect(function(player)
    local a = actors.byPlayer[player]
    if a then actors:eliminate(a); actors.byPlayer[player] = nil end
    limits[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do join(player) end
-- Single bounded scheduler. Path computations alone yield in their own capped jobs.
task.spawn(function()
    local last, botClock, lootClock, snapshotClock = os.clock(), 0, 0, 0
    while true do
        task.wait(0.1)
        local now = os.clock()
        local dt = math.min(now - last, 0.5)
        last = now
        round:step(dt)
        botClock, lootClock, snapshotClock = botClock + dt, lootClock + dt, snapshotClock + dt
        if round:isActive() then
            if botClock >= Config.BotInterval then botClock = 0; bots:step() end
            if lootClock >= 0.4 then
                lootClock = 0
                for _, a in ipairs(actors:alive()) do loot:pickup(a) end
                builds:step()
            end
        end
        if snapshotClock >= Config.SnapshotInterval then
            snapshotClock = 0
            for _, player in ipairs(Players:GetPlayers()) do snapshot:FireClient(player, round:snapshot(player)) end
        end
    end
end)
task.spawn(function() round:run() end)
