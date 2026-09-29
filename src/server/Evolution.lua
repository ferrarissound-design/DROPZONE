local Config = require(game.ReplicatedStorage.DropzoneShared.Config)
local Evolution = {}
Evolution.order = {"Swift Legs", "Iron Skin", "Hunter Eyes", "Quick Hands", "Builder", "High Jump", "Regeneration"}
function Evolution.grant(a)
    if a.evolutionCount >= Config.MaxEvolutions or not a.alive then return nil end
    a.evolutionCount = a.evolutionCount + 1
    local name = Evolution.order[a.evolutionCount]
    a.evolutions[name] = true
    if name == "Swift Legs" then a.humanoid.WalkSpeed = Config.BaseSpeed * 1.15 end
    if name == "Iron Skin" then
        a.humanoid.MaxHealth = 125
        a.humanoid.Health = math.min(125, a.humanoid.Health + 25)
    end
    if name == "High Jump" then a.humanoid.JumpPower = Config.BaseJump * 1.2 end
    local folder = a.model:FindFirstChild("Mutation") or Instance.new("Folder")
    folder.Name, folder.Parent = "Mutation", a.model
    local limbNames = {"LeftLowerLeg", "UpperTorso", "Head", "RightHand", "LeftHand", "RightLowerLeg", "UpperTorso"}
    local limb = a.model:FindFirstChild(limbNames[a.evolutionCount])
        or a.model:FindFirstChild(a.evolutionCount == 3 and "Head" or "Torso") or a.root
    local p = Instance.new("Part")
    local sizes = {Vector3.new(0.3, 1.8, 0.4), Vector3.new(2.2, 1.5, 0.4), Vector3.new(1.7, 0.3, 0.3), Vector3.new(0.7, 0.7, 0.7), Vector3.new(0.7, 0.7, 0.7), Vector3.new(0.3, 1.8, 0.4), Vector3.new(2.4, 0.25, 1.5)}
    p.Name, p.Size = name, sizes[a.evolutionCount]
    p.Color, p.Material = Color3.fromHSV((a.evolutionCount * 0.11) % 1, 0.65, 1), Enum.Material.Neon
    p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, true
    local offset = Vector3.new(limb.Size.X / 2 + 0.12, 0.15, -limb.Size.Z / 2)
    if a.evolutionCount == 2 or a.evolutionCount == 3 then offset = Vector3.new(0, 0.1, -limb.Size.Z / 2 - 0.2) end
    if a.evolutionCount == 7 then offset = Vector3.new(0, 1, 0) end
    p.CFrame = limb.CFrame * CFrame.new(offset)
    p.Parent = folder
    local weld = Instance.new("WeldConstraint")
    weld.Part0, weld.Part1, weld.Parent = limb, p, p
    return name
end
function Evolution.step(a, dt)
    if a.alive and a.evolutions.Regeneration and os.clock() - a.lastDamage >= 8 then
        a.humanoid.Health = math.min(a.humanoid.MaxHealth, a.humanoid.Health + 2 * dt)
    end
end
return Evolution
