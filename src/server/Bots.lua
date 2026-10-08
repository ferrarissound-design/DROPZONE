local PathfindingService = game:GetService("PathfindingService")
local World = require(script.Parent.World)
local Shared = game.ReplicatedStorage.DropzoneShared
local Rules = require(Shared.Rules)
local Config = require(Shared.Config)
local Bots = {}
Bots.__index = Bots
function Bots.new(actors, combat, loot, zone, world)
    return setmetatable({actors = actors, combat = combat, loot = loot, zone = zone, world = world, jobs = 0, generation = 0, rng = Random.new()}, Bots)
end
function Bots:clear()
    self.generation = self.generation + 1
    -- In-flight jobs belong to the old generation and must not reserve slots for the next round.
    self.jobs = 0
end
function Bots:path(a, goal, now)
    if a.pathBusy or now < (a.nextPath or 0) or self.jobs >= 2 then return end
    a.pathBusy, a.nextPath, self.jobs = true, now + 2.5 + self.rng:NextNumber(), self.jobs + 1
    local generation, start = self.generation, a.root.Position
    task.spawn(function()
        local path, waypoints
        local ok = pcall(function()
            path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 6})
            path:ComputeAsync(start, goal)
            if path.Status == Enum.PathStatus.Success then waypoints = path:GetWaypoints() end
        end)
        local currentGeneration = generation == self.generation
        a.pathBusy = false
        if currentGeneration then self.jobs = math.max(0, self.jobs - 1) end
        if not currentGeneration or not a.alive then return end
        if ok and waypoints then
            a.waypoints, a.waypointIndex, a.pathGoal = waypoints, 2, goal
        else
            a.waypoints = nil
            a.humanoid.Jump = true
        end
    end)
end
-- Keep the rendered weapon and body aligned with the actual bot shot even
-- while the navigation goal moves away from a close enemy.
function Bots.faceTarget(a, delta)
    local flat = Vector3.new(delta.X, 0, delta.Z)
    if flat.Magnitude <= .1 then return false end
    a.humanoid.AutoRotate = false
    a.root.CFrame = CFrame.lookAt(a.root.Position, a.root.Position + flat.Unit)
    return true
end
function Bots:step()
    local alive, now = self.actors:alive(), os.clock()
    for _, a in ipairs(alive) do
        if not a.player and a.root.Parent then
            -- Unlocked navigation whenever this tick is not aiming at an enemy.
            a.humanoid.AutoRotate = true
            local pos = a.root.Position
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = {a.model}
            local opening = now - (a.startTime or now) < Config.BotOpeningSeconds
            local retaliating = (a.lastDamage or 0) > (a.startTime or math.huge)
            local target, distance
            if not opening or retaliating then
                target, distance = Rules.closestLiveTarget(a, alive, Config.BotAggroRange)
            end
            -- Inventory decisions are cheap and independent of navigation/zone urgency.
            local bestSlot, bestScore = nil, -1
            for slot, item in ipairs(a.inventory) do
                if item.ammo + item.reserve > 0 then
                    local score = item.kind == "Rifle" and 2 or 1
                    if item.kind == "Shotgun" then score = target and distance < Config.BotShotgunRange and 3 or 0 end
                    if score > bestScore then bestSlot, bestScore = slot, score end
                end
            end
            if bestSlot and bestSlot ~= a.slot and not a.reloading then self.combat:equip(a, bestSlot) end
            local goal, groundedGoal
            if self.zone:outside(pos, 18) then
                -- Zone safety always wins over chasing or looting.
                goal = self.zone.center + Vector3.new(math.sin(a.id) * math.min(12, self.zone.radius * 0.3), 0, math.cos(a.id) * math.min(12, self.zone.radius * 0.3))
            else
                local armed = false
                for slot, item in ipairs(a.inventory) do
                    if item.ammo + item.reserve > 0 then
                        armed = true
                        local equipped = a.inventory[a.slot]
                        if equipped and equipped.ammo + equipped.reserve == 0 then self.combat:equip(a, slot) end
                        break
                    end
                end
                local lootRange = opening and not retaliating and Config.BotOpeningLootRange or (not armed and 150 or 28)
                local pickup = self.loot:nearest(a, lootRange)
                if pickup then goal, groundedGoal = pickup.Position, true end
                if not goal and target then
                    local delta = pos - target.root.Position
                    if distance < 27 then
                        goal = pos + (delta.Magnitude > 0.1 and delta.Unit or Vector3.xAxis) * 15
                    else goal, groundedGoal = target.root.Position, true end
                end
                if not goal then
                    if not a.wander or (a.wander - pos).Magnitude < 8 or now > (a.nextWander or 0) then
                        local radius = math.max(2, self.zone.radius * 0.55)
                        a.wander = self.zone.center + Vector3.new(self.rng:NextNumber(-radius, radius), 0, self.rng:NextNumber(-radius, radius))
                        a.nextWander = now + 6
                    end
                    goal = a.wander
                end
            end
            -- Preserve a reachable loot/target floor instead of raycasting onto its roof.
            if not groundedGoal then goal = World.ground(self.world, goal) + Vector3.new(0, 3, 0) end
            if target and #a.inventory > 0 then
                local item = a.inventory[a.slot]
                if item.ammo <= 0 then self.combat:reload(a) end
                local delta = target.root.Position + Vector3.new(0, 0.8, 0) - (pos + Vector3.new(0, 1.4, 0))
                local hit = workspace:Raycast(pos + Vector3.new(0, 1.4, 0), delta, params)
                if delta.Magnitude > 0.1 and (not hit or hit.Instance:IsDescendantOf(target.model)) then
                    Bots.faceTarget(a, delta)
                    -- Deliberate aim error and low tick rate leave humans room to react.
                    local aim = delta + Vector3.new(self.rng:NextNumber(-5, 5), self.rng:NextNumber(-2, 2), self.rng:NextNumber(-5, 5))
                    if aim.Magnitude > 0.1 then self.combat:fire(a, aim.Unit) end
                elseif hit and self.combat.builds.entries[hit.Instance] and delta.Magnitude > 0.1 then
                    Bots.faceTarget(a, delta)
                    self.combat:fire(a, delta.Unit)
                end
            end
            if now >= (a.nextStuckCheck or 0) then
                if a.lastPosition and (pos - a.lastPosition).Magnitude < 2 and (goal - pos).Magnitude > 8 then
                    a.stuck = (a.stuck or 0) + 1
                    a.humanoid.Jump = true
                    a.waypoints = nil
                else a.stuck = 0 end
                a.lastPosition, a.nextStuckCheck = pos, now + 1.5
            end
            local direction = goal - pos
            local obstruction = direction.Magnitude > 1 and workspace:Raycast(pos, direction.Unit * math.min(12, direction.Magnitude), params)
            if obstruction or (a.stuck or 0) > 0 then self:path(a, goal, now) end
            local move = goal
            if a.waypoints then
                if a.pathGoal and (a.pathGoal - goal).Magnitude > 28 then a.waypoints = nil
                else
                    local waypoint = a.waypoints[a.waypointIndex]
                    if waypoint and (waypoint.Position - pos).Magnitude < 6 then
                        a.waypointIndex = a.waypointIndex + 1
                        waypoint = a.waypoints[a.waypointIndex]
                    end
                    if waypoint then
                        move = waypoint.Position
                        if waypoint.Action == Enum.PathWaypointAction.Jump then a.humanoid.Jump = true end
                    else a.waypoints = nil end
                end
            end
            if (a.stuck or 0) >= 3 and not a.waypoints then
                -- Bounded sidestep recovery, never teleport a fighting bot.
                move = pos + Vector3.new(math.cos(now + a.id), 0, math.sin(now + a.id)) * 14
                a.humanoid.Jump = true
            end
            a.humanoid:MoveTo(move)
        end
    end
end
return Bots
