local World = {}

-- Loot lies just beyond the open +Z entrance and roof footprint.
function World.townLootPosition(x, z)
    return Vector3.new(x, 2, z + 22)
end
local function part(parent, name, size, cf, color, material)
    local p = Instance.new("Part")
    p.Name, p.Size, p.CFrame = name, size, cf
    p.Anchored = true
    p.Color = color
    p.Material = material or Enum.Material.SmoothPlastic
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end
World.part = part
function World.create()
    local old = workspace:FindFirstChild("DropzoneWorld")
    if old then old:Destroy() end
    local root = Instance.new("Folder")
    root.Name, root.Parent = "DropzoneWorld", workspace
    local map = Instance.new("Folder")
    map.Name, map.Parent = "Map", root
    local dynamic = Instance.new("Folder")
    dynamic.Name, dynamic.Parent = "Round", root
    local self = {root = root, map = map, dynamic = dynamic, spawns = {}, loot = {}}
    part(map, "Island", Vector3.new(520, 4, 520), CFrame.new(0, -2, 0), Color3.fromRGB(88, 119, 103), Enum.Material.Grass)
    local road = Color3.fromRGB(49, 58, 70)
    part(map, "RoadX", Vector3.new(510, 0.2, 24), CFrame.new(0, 0.1, 0), road, Enum.Material.Asphalt)
    part(map, "RoadZ", Vector3.new(24, 0.2, 510), CFrame.new(0, 0.1, 0), road, Enum.Material.Asphalt)
    -- Open courtyards and wide routes keep the first map navigable for bots.
    for x = -190, -70, 60 do
        for z = -185, -65, 60 do
            local c = Color3.fromRGB(125, 151, 173)
            part(map, "TownBack", Vector3.new(30, 14, 2), CFrame.new(x, 7, z - 13), c)
            part(map, "TownSide", Vector3.new(2, 14, 28), CFrame.new(x - 14, 7, z), c)
            part(map, "TownSide", Vector3.new(2, 14, 28), CFrame.new(x + 14, 7, z), c)
            part(map, "TownRoof", Vector3.new(32, 2, 30), CFrame.new(x, 15, z), Color3.fromRGB(64, 83, 108))
            table.insert(self.loot, World.townLootPosition(x, z))
        end
    end
    for x = 70, 190, 40 do
        for z = -180, -60, 40 do
            part(map, "WarehouseContainer", Vector3.new(20, 10, 12), CFrame.new(x, 5, z), Color3.fromRGB(166, 109, 63), Enum.Material.Metal)
            table.insert(self.loot, Vector3.new(x, 2, z + 13))
        end
    end
    local rng = Random.new(721)
    for _ = 1, 27 do
        local x, z = rng:NextNumber(-220, -55), rng:NextNumber(55, 220)
        part(map, "TreeTrunk", Vector3.new(3, 13, 3), CFrame.new(x, 6.5, z), Color3.fromRGB(100, 74, 57), Enum.Material.Wood)
        local crown = part(map, "TreeCrown", Vector3.new(14, 13, 14), CFrame.new(x, 18, z), Color3.fromRGB(43, 94, 72), Enum.Material.Grass)
        crown.CanCollide, crown.CanQuery = false, false
        table.insert(self.loot, Vector3.new(x + 6, 2, z))
    end
    -- A broad, climbable slope instead of an inaccessible cliff.
    local hill = Instance.new("WedgePart")
    hill.Name, hill.Size = "Hill", Vector3.new(90, 18, 110)
    hill.CFrame, hill.Color = CFrame.new(135, 9, 135), Color3.fromRGB(116, 133, 106)
    hill.Anchored, hill.Parent = true, map
    for i = 1, 8 do
        local angle = i * math.pi / 4
        local x, z = math.cos(angle) * 42, math.sin(angle) * 42
        part(map, "CentralCover", Vector3.new(12, 7, 4), CFrame.new(x, 3.5, z) * CFrame.Angles(0, -angle, 0), Color3.fromRGB(67, 94, 120), Enum.Material.Concrete)
        table.insert(self.loot, Vector3.new(x * 0.65, 2, z * 0.65))
    end
    part(map, "CentralPad", Vector3.new(32, 0.3, 32), CFrame.new(0, 0.2, 0), Color3.fromRGB(70, 171, 171), Enum.Material.Metal)
    for i = 1, 24 do
        local a = (i - 1) * math.pi * 2 / 24
        local position = Vector3.new(math.cos(a) * 225, 4, math.sin(a) * 225)
        table.insert(self.spawns, position)
        table.insert(self.loot, position + Vector3.new(-math.sin(a) * 7, -2, math.cos(a) * 7))
    end
    part(root, "Lobby", Vector3.new(65, 3, 65), CFrame.new(0, 99, 360), Color3.fromRGB(39, 52, 75), Enum.Material.Metal)
    self.lobby = CFrame.new(0, 104, 360)
    for _, item in ipairs({{"TOWN", -130, -130}, {"WAREHOUSE", 130, -130}, {"FOREST", -130, 130}, {"HILL", 135, 135}, {"CORE", 0, 0}}) do
        local anchor = part(map, item[1], Vector3.new(1, 1, 1), CFrame.new(item[2], 28, item[3]), Color3.new(1, 1, 1))
        anchor.Transparency, anchor.CanCollide, anchor.CanQuery = 1, false, false
        local ui = Instance.new("BillboardGui")
        ui.Size, ui.MaxDistance, ui.Parent = UDim2.fromOffset(170, 30), 180, anchor
        local label = Instance.new("TextLabel")
        label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
        label.Text, label.TextColor3, label.TextSize = item[1], Color3.new(1, 1, 1), 20
        label.Font, label.Parent = Enum.Font.GothamBold, ui
    end
    return self
end
function World.ground(self, position)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = {self.map}
    local hit = workspace:Raycast(Vector3.new(position.X, 80, position.Z), Vector3.new(0, -120, 0), params)
    return hit and hit.Position or Vector3.new(position.X, 0, position.Z)
end
return World
