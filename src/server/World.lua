local Theme = require(game.ReplicatedStorage.DropzoneShared.VisualTheme)
local MapVisuals = require(script.Parent.MapVisuals)
local Town = require(script.Parent.Town)
local World = {}

local SPAWN_CLEARANCE = Vector3.new(7, 9, 7)
local SPAWN_FOOTPRINT_MARGIN = 4
local SPAWN_MIN_SEPARATION = 28
local SPAWN_LIMIT = 248
local SPAWN_RADIAL_OFFSETS = {0, -18, -36, 18, -54}
local SPAWN_TANGENT_OFFSETS = {0, 16, -16, 32, -32, 48, -48}

-- Loot lies just beyond the open +Z entrance and roof footprint.
function World.townLootPosition(x, z, rotation)
    return Town.lootPosition({x=x, z=z, rotation=rotation or 0})
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

local function isGroundSurface(self, candidate)
    for _, surface in ipairs(self.groundSurfaces or {}) do
        if candidate == surface then return true end
    end
    return false
end

local function insideBuildingFootprint(self, position)
    local buildings = self.map and self.map:FindFirstChild("Buildings")
    if not buildings then return false end
    for _, building in ipairs(buildings:GetChildren()) do
        if building:IsA("Model") then
            local box, size = building:GetBoundingBox()
            local localPosition = box:PointToObjectSpace(position)
            if math.abs(localPosition.X) <= size.X / 2 + SPAWN_FOOTPRINT_MARGIN
                and math.abs(localPosition.Z) <= size.Z / 2 + SPAWN_FOOTPRINT_MARGIN then
                return true
            end
        end
    end
    return false
end

function World.spawnClear(self, ground)
    -- Reject the whole building footprint, not only walls. A hollow imported
    -- template can otherwise surround a perfectly empty overlap box and trap a
    -- player inside the building at round start.
    if insideBuildingFootprint(self, ground) then return false end

    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = {self.map}
    params.MaxParts = 32
    local center = ground + Vector3.new(0, 4, 0)
    for _, hit in ipairs(workspace:GetPartBoundsInBox(CFrame.new(center), SPAWN_CLEARANCE, params)) do
        if hit.CanCollide and not isGroundSurface(self, hit) then return false end
    end
    return true
end

local function separated(existing, candidate)
    for _, position in ipairs(existing) do
        local dx, dz = candidate.X - position.X, candidate.Z - position.Z
        if math.sqrt(dx * dx + dz * dz) < SPAWN_MIN_SEPARATION then return false end
    end
    return true
end

local function trySpawn(self, candidate, existing)
    if math.abs(candidate.X) > SPAWN_LIMIT or math.abs(candidate.Z) > SPAWN_LIMIT then return nil end
    local ground = World.ground(self, candidate)
    if World.spawnClear(self, ground) and separated(existing, ground) then
        return ground + Vector3.new(0, 4, 0)
    end
    return nil
end

function World.resolveSpawn(self, preferred, existing)
    existing = existing or {}
    local flat = Vector3.new(preferred.X, 0, preferred.Z)
    local magnitude = flat.Magnitude
    local radial = magnitude > 0 and flat / magnitude or Vector3.new(1, 0, 0)
    local tangent = Vector3.new(-radial.Z, 0, radial.X)

    -- Keep the original perimeter distribution whenever possible, then nudge
    -- blocked points inward or sideways. This protects the opening pacing while
    -- allowing larger Studio-saved TownTemplates.
    for _, radialOffset in ipairs(SPAWN_RADIAL_OFFSETS) do
        for _, tangentOffset in ipairs(SPAWN_TANGENT_OFFSETS) do
            local resolved = trySpawn(self, flat + radial * radialOffset + tangent * tangentOffset, existing)
            if resolved then return resolved end
        end
    end

    -- Main roads are intentionally kept clear by the Town layout, so they are a
    -- deterministic escape hatch if a custom template occupies much of the rim.
    for distance = -225, 225, 30 do
        local resolved = trySpawn(self, Vector3.new(distance, 0, 0), existing)
            or trySpawn(self, Vector3.new(0, 0, distance), existing)
        if resolved then return resolved end
    end

    -- Last-resort bounded scan. Never silently fall back to the blocked point.
    for radius = 220, 245, 5 do
        for step = 0, 71 do
            local angle = step * math.pi * 2 / 72
            local resolved = trySpawn(self, Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius), existing)
            if resolved then return resolved end
        end
    end
    return nil
end

function World.create()
    local old = workspace:FindFirstChild("DropzoneWorld")
    if old then old:Destroy() end
    local root = Instance.new("Folder")
    root.Name, root.Parent = "DropzoneWorld", workspace
    local map = Instance.new("Folder")
    map.Name, map.Parent = "Map", root
    local dynamic = Instance.new("Folder")
    dynamic.Name, dynamic.Parent = "Round", root
    local self = {root = root, map = map, dynamic = dynamic, spawns = {}, loot = {}, groundSurfaces = {}}
    local island = part(map, "Island", Vector3.new(520, 4, 520), CFrame.new(0, -2, 0), Theme.Grass[1], Enum.Material.Grass)
    table.insert(self.groundSurfaces, island)
    local road = Color3.fromRGB(111, 118, 116)
    local roadX = part(map, "RoadX", Vector3.new(510, 0.2, 24), CFrame.new(0, 0.1, 0), road, Enum.Material.Asphalt)
    local roadZ = part(map, "RoadZ", Vector3.new(24, 0.2, 510), CFrame.new(0, 0.1, 0), road, Enum.Material.Asphalt)
    table.insert(self.groundSurfaces, roadX)
    table.insert(self.groundSurfaces, roadZ)
    -- Cosmetic markings never alter navigation, placement overlap or weapon rays.
    for offset = -220, 220, 20 do
        for axis = 1, 2 do
            local mark = part(map, "RoadMarking", axis == 1 and Vector3.new(8,0.05,0.5) or Vector3.new(0.5,0.05,8),
                CFrame.new(axis == 1 and offset or 0, 0.23, axis == 2 and offset or 0), Color3.fromRGB(218,199,140))
            mark.CanCollide, mark.CanTouch, mark.CanQuery = false, false, false
        end
    end
    self.scenery = MapVisuals.create(self)
    Town.create(self, part)
    local rng = Random.new(721)
    for _ = 1, 27 do
        local x, z = rng:NextNumber(-220, -55), rng:NextNumber(55, 220)
        part(map, "TreeTrunk", Vector3.new(3, 13, 3), CFrame.new(x, 6.5, z), Color3.fromRGB(100, 74, 57), Enum.Material.Wood)
        local crown = part(map, "TreeCrown", Vector3.new(14, 13, 14), CFrame.new(x, 18, z), Theme.Grass[(_-1)%3+1], Enum.Material.Grass)
        crown.Shape = Enum.PartType.Ball
        crown.CanCollide, crown.CanTouch, crown.CanQuery = false, false, false
        table.insert(self.loot, Vector3.new(x + 6, 2, z))
    end
    -- A broad, climbable slope instead of an inaccessible cliff.
    local hill = Instance.new("WedgePart")
    hill.Name, hill.Size = "Hill", Vector3.new(90, 18, 110)
    hill.CFrame, hill.Color = CFrame.new(135, 9, 135), Theme.Grass[2]
    hill.Anchored, hill.Parent = true, map
    table.insert(self.groundSurfaces, hill)
    for i = 1, 8 do
        local angle = i * math.pi / 4
        local x, z = math.cos(angle) * 42, math.sin(angle) * 42
        part(map, "CentralCover", Vector3.new(12, 7, 4), CFrame.new(x, 3.5, z) * CFrame.Angles(0, -angle, 0), Theme.Slate, Enum.Material.Concrete)
        table.insert(self.loot, Vector3.new(x * 0.65, 2, z * 0.65))
    end
    local centralPad = part(map, "CentralPad", Vector3.new(32, 0.3, 32), CFrame.new(0, 0.2, 0), Theme.Blue, Enum.Material.Metal)
    table.insert(self.groundSurfaces, centralPad)
    for i = 1, 24 do
        local a = (i - 1) * math.pi * 2 / 24
        local preferred = Vector3.new(math.cos(a) * 245, 4, math.sin(a) * 245)
        local position = World.resolveSpawn(self, preferred, self.spawns)
        if position then
            table.insert(self.spawns, position)
            table.insert(self.loot, position + Vector3.new(-math.sin(a) * 7, -2, math.cos(a) * 7))
        else
            warn(string.format("[DROPZONE] no safe start spawn found for slot %d", i))
        end
    end
    if #self.spawns < 20 then
        warn(string.format("[DROPZONE] only %d safe start spawns were generated; expected at least 20", #self.spawns))
    end
    part(root, "Lobby", Vector3.new(65, 3, 65), CFrame.new(0, 99, 360), Color3.fromRGB(39, 52, 75), Enum.Material.Metal)
    self.lobby = CFrame.new(0, 104, 360)
    local areaColors = {TOWN=Theme.Gold, WAREHOUSE=Theme.Orange, FOREST=Theme.Green, HILL=Theme.Paper, CORE=Theme.Cyan}
    for _, item in ipairs({{"TOWN", -130, -130}, {"WAREHOUSE", 130, -130}, {"FOREST", -130, 130}, {"HILL", 135, 135}, {"CORE", 0, 0}}) do
        local anchor = part(map, item[1], Vector3.new(1, 1, 1), CFrame.new(item[2], 28, item[3]), Color3.new(1, 1, 1))
        anchor.Transparency, anchor.CanCollide, anchor.CanQuery = 1, false, false
        local ui = Instance.new("BillboardGui")
        ui.Size, ui.MaxDistance, ui.Parent = UDim2.fromOffset(180, 32), 240, anchor
        local label = Instance.new("TextLabel")
        label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
        label.Text, label.TextColor3, label.TextSize = item[1], areaColors[item[1]], 22
        label.TextStrokeTransparency = .35
        label.Font, label.Parent = Enum.Font.GothamBold, ui
    end
    return self
end
function World.ground(self, position)
    local surfaces = self.groundSurfaces
    if not surfaces or #surfaces == 0 then return Vector3.new(position.X, 0, position.Z) end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    -- Only true walkable ground participates. Roofs, containers, trees, and cover must not become "ground".
    params.FilterDescendantsInstances = surfaces
    local hit = workspace:Raycast(Vector3.new(position.X, 80, position.Z), Vector3.new(0, -120, 0), params)
    return hit and hit.Position or Vector3.new(position.X, 0, position.Z)
end
return World
