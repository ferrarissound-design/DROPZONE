local Config = require(game.ReplicatedStorage.DropzoneShared.Config)
local Rules = require(game.ReplicatedStorage.DropzoneShared.Rules)
local Cosmetics = require(script.Parent.Cosmetics)
local Theme = require(game.ReplicatedStorage.DropzoneShared.VisualTheme)
local Actors = {}
Actors.__index = Actors
function Actors.new()
    return setmetatable({list = {}, byPlayer = {}, byModel = {}, connections = {}}, Actors)
end
function Actors:add(model, player, id)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root then return nil end
    local a = {id = id, name = player and player.DisplayName or string.format("DRONE %02d", -id), player = player,
        model = model, humanoid = humanoid, root = root, alive = true,
        shield = 0, kills = 0, damage = 0, energy = Config.StartEnergy,
        inventory = {}, slot = 1, ammo = 0, nextShot = 0, reloading = false, reloadToken = 0,
        evolutions = {}, evolutionStacks = {}, evolutionHistory = {}, evolutionCount = 0,
        queuedDrafts = 0, draftVersion = 0, evolutionDraft = nil, roundId = 0,
        lastDamage = 0, startTime = 0, survival = 0}
    humanoid.MaxHealth, humanoid.Health = Config.BaseHealth, Config.BaseHealth
    humanoid.WalkSpeed, humanoid.UseJumpPower, humanoid.JumpPower = Config.BaseSpeed, true, Config.BaseJump
    humanoid.BreakJointsOnDeath = false
    local ff = model:FindFirstChildOfClass("ForceField")
    if ff then ff:Destroy() end
    model:SetAttribute("DropzoneActor", id)
    table.insert(self.list, a)
    self.byModel[model] = a
    if player then self.byPlayer[player] = a else root:SetNetworkOwner(nil) end
    table.insert(self.connections, humanoid.Died:Connect(function() self:eliminate(a) end))
    return a
end
function Actors:alive()
    local result = {}
    for _, a in ipairs(self.list) do if a.alive then table.insert(result, a) end end
    return result
end
function Actors:eliminate(a, killer)
    if not a.alive then return end
    a.alive = false
    a.rank = #self:alive() + 1
    a.survival = math.max(0, os.clock() - a.startTime)
    a.reloading, a.reloadToken = false, a.reloadToken + 1
    -- Keep the corpse visible, but never let it block shots, LOS checks, or touch triggers.
    if a.model and a.model.Parent then
        for _, descendant in ipairs(a.model:GetDescendants()) do
            if descendant:IsA("BasePart") then
                descendant.CanQuery = false
                descendant.CanTouch = false
            end
        end
    end
    if a.humanoid.Health > 0 then a.humanoid.Health = 0 end
    if self.onDeath then self.onDeath(a, killer) end
end
function Actors:damage(a, amount, attacker, bypass)
    if not a or not a.alive or amount <= 0 then return end
    local hp, shield, actual = Rules.resolveDamage(a.humanoid.Health, a.shield, amount, bypass)
    a.shield, a.lastDamage = shield, os.clock()
    if attacker and attacker ~= a and attacker.alive then
        attacker.damage = attacker.damage + actual
        a.lastAttacker, a.lastAttackTime = attacker, os.clock()
    end
    -- Mark death before writing Health, so Died cannot steal killer attribution.
    if hp <= 0 then
        local killer = attacker
        if not killer and a.lastAttacker and os.clock() - a.lastAttackTime < 8 then killer = a.lastAttacker end
        self:eliminate(a, killer)
    else
        a.humanoid.Health = hp
    end
end
function Actors:fromPart(p)
    while p and p ~= workspace do
        if self.byModel[p] then return self.byModel[p] end
        p = p.Parent
    end
end
function Actors:clear()
    for _, c in ipairs(self.connections) do c:Disconnect() end
    for _, a in ipairs(self.list) do
        a.alive, a.reloadToken = false, a.reloadToken + 1
        a.evolutionDraft, a.queuedDrafts = nil, 0
        a.draftVersion = (a.draftVersion or 0) + 1
        a.evolutionStacks, a.evolutions, a.evolutionHistory = {}, {}, {}
        a.evolutionCount, a.mutationFolder = 0, nil
        if a.model.Parent then a.model:Destroy() end
    end
    self.list, self.byPlayer, self.byModel, self.connections = {}, {}, {}, {}
end
function Actors.botModel(parent, index)
    local model = Instance.new("Model")
    model.Name = "Drone" .. index
    local parts = {}
    local specs = {
        {"HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0)},
        {"Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0)},
        {"Head", Vector3.new(2, 1, 1), Vector3.new(0, 4.5, 0)},
        {"Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0)},
        {"Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0)},
        {"Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0)},
        {"Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0)},
    }
    for _, s in ipairs(specs) do
        local p = Instance.new("Part")
        p.Name, p.Size, p.Position = s[1], s[2], s[3]
        p.Color = s[1] == "Head" and Theme.Paper or Theme.Slate
        p.CanCollide = s[1] == "Torso"
        p.Parent, parts[s[1]] = model, p
    end
    parts.HumanoidRootPart.Transparency = 1
    for name, p in pairs(parts) do
        if name ~= "HumanoidRootPart" then
            local joint = Instance.new("Motor6D")
            joint.Name = name == "Head" and "Neck" or name .. "Joint"
            joint.Part0 = name == "Head" and parts.Torso or parts.HumanoidRootPart
            joint.Part1 = p
            joint.C0 = joint.Part0.CFrame:ToObjectSpace(p.CFrame)
            joint.Parent = joint.Part0
        end
    end
    Cosmetics.drone(model, parts)
    local humanoid = Instance.new("Humanoid")
    humanoid.DisplayName, humanoid.Parent = "DRONE " .. index, model
    model.PrimaryPart, model.Parent = parts.HumanoidRootPart, parent
    return model
end
return Actors
