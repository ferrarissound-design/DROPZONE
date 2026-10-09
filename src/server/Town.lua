local ServerStorage = game:GetService("ServerStorage")
local Theme = require(game.ReplicatedStorage.DropzoneShared.VisualTheme)
local Cosmetics = require(script.Parent.Cosmetics)

local Town = {}

Town.TemplateFolderName = "TownTemplates"
Town.TemplateLimits = {parts = 96, meshParts = 32, collisionParts = 20}
Town.FallbackBudget = {buildings = 13, collisionParts = 91, visualParts = 106}
Town.Layout = {
    {name="House01", role="House", x=-190, z=-185, rotation=0, color="Gold"},
    {name="House02", role="House", x=-130, z=-185, rotation=0, color="Blue"},
    {name="Shop01", role="Shop", x=-70, z=-185, rotation=math.pi/2, color="Orange"},
    {name="House03", role="House", x=-190, z=-125, rotation=0, color="Coral"},
    {name="Shop02", role="Shop", x=-130, z=-125, rotation=0, color="Cream"},
    {name="Office01", role="Office", x=-70, z=-125, rotation=math.pi/2, color="Blue"},
    {name="House01", role="House", x=-190, z=-65, rotation=0, color="Gold"},
    {name="House02", role="House", x=-130, z=-65, rotation=0, color="Blue"},
    {name="Shop01", role="Shop", x=-70, z=-65, rotation=0, color="Orange"},
}

Town.WarehouseLayout = {
    {name="Warehouse01", role="Warehouse", x=92, z=-160, rotation=0},
    {name="Warehouse01", role="Warehouse", x=168, z=-160, rotation=math.pi},
    {name="Warehouse01", role="Warehouse", x=92, z=-80, rotation=0},
    {name="Warehouse01", role="Warehouse", x=168, z=-80, rotation=math.pi},
}

local forbiddenClasses = {
    Script=true, LocalScript=true, ModuleScript=true,
    RemoteEvent=true, RemoteFunction=true, UnreliableRemoteEvent=true,
    BindableEvent=true, BindableFunction=true,
    ParticleEmitter=true, Trail=true, Beam=true,
    PointLight=true, SpotLight=true, SurfaceLight=true,
    Sound=true, ClickDetector=true, ProximityPrompt=true,
    Explosion=true, Fire=true, Smoke=true, Sparkles=true,
    AnimationController=true, Animator=true,
    Animation=true, Humanoid=true, Tool=true, Seat=true, VehicleSeat=true,
    AlignPosition=true, AlignOrientation=true, LinearVelocity=true,
    AngularVelocity=true, VectorForce=true, Torque=true,
    BodyPosition=true, BodyGyro=true, BodyVelocity=true,
}

local function isCollisionPart(part, root)
    if part:GetAttribute("TownCollision") == true then return true end
    local ancestor = part.Parent
    while ancestor and ancestor ~= root do
        if ancestor.Name == "Collision" then return true end
        ancestor = ancestor.Parent
    end
    return false
end

-- Imported visual meshes may be non-collidable so doors and paths stay open,
-- but visible surfaces must still stop server bullet and BOT sight raycasts.
-- Explicit movement colliders always block, including invisible colliders.
function Town.blocksShots(part, collision)
    if collision then return true end
    if part:GetAttribute("TownBulletPassThrough") == true then return false end
    return part.Transparency < 0.95
end

-- Toolbox content never enters Workspace directly. A clone is stripped while it
-- is still detached, then accepted only when it has an explicit collision set.
function Town.sanitizeTemplate(source)
    if not source or not source:IsA("Model") then return nil, "Modelではありません" end
    local ok, clone = pcall(function() return source:Clone() end)
    if not ok or not clone then return nil, "Cloneできません" end
    clone.Parent = nil
    local report = {removed=0, parts=0, meshParts=0, collisionParts=0, raycastVisualParts=0}
    for _, descendant in ipairs(clone:GetDescendants()) do
        if forbiddenClasses[descendant.ClassName]
            or descendant:IsA("Constraint") or descendant:IsA("JointInstance") then
            report.removed = report.removed + 1
            descendant:Destroy()
        elseif descendant:IsA("BasePart") then
            report.parts = report.parts + 1
            if descendant:IsA("MeshPart") then report.meshParts = report.meshParts + 1 end
            local collision = isCollisionPart(descendant, clone)
            descendant.Anchored = true
            descendant.CanTouch = false
            descendant.CanCollide = collision
            local blocksShots = Town.blocksShots(descendant, collision)
            descendant.CanQuery = blocksShots
            descendant.Massless = not collision
            if collision then
                report.collisionParts = report.collisionParts + 1
            elseif blocksShots then
                -- Building placement can also recognize this visual-only cover.
                descendant:SetAttribute("TownBulletCover", true)
                report.raycastVisualParts = report.raycastVisualParts + 1
            end
        end
    end
    local limits = Town.TemplateLimits
    if report.parts == 0 or report.parts > limits.parts then
        clone:Destroy()
        return nil, "Part数が範囲外です", report
    end
    if report.meshParts > limits.meshParts then
        clone:Destroy()
        return nil, "MeshPart数が多すぎます", report
    end
    if report.collisionParts == 0 or report.collisionParts > limits.collisionParts then
        clone:Destroy()
        return nil, "CollisionフォルダまたはTownCollision属性が必要です", report
    end
    local size = clone:GetExtentsSize()
    if size.X > 50 or size.Y > 34 or size.Z > 50 then
        clone:Destroy()
        return nil, "50x34x50 studsの上限を超えています", report
    end
    return clone, nil, report
end

local function palette(key)
    if key == "Gold" then return Theme.Town[2] end
    if key == "Blue" then return Theme.Town[1] end
    if key == "Coral" then return Theme.Town[3] end
    if key == "Cream" then return Theme.Town[4] end
    if key == "Green" then return Theme.Town[5] end
    if key == "Orange" then return Theme.Orange end
    return Theme.Paper
end

local function rotatedPosition(entry, forward)
    local distance = forward or 22
    return Vector3.new(entry.x + math.sin(entry.rotation) * distance, 2,
        entry.z + math.cos(entry.rotation) * distance)
end
Town.lootPosition = rotatedPosition

local function makeFolders(world)
    local structures = Instance.new("Folder")
    structures.Name, structures.Parent = "Buildings", world.map
    local visuals = Instance.new("Folder")
    visuals.Name, visuals.Parent = "TownVisuals", world.scenery
    return structures, visuals
end

local function structural(partFactory, parent, name, size, cf, color, material)
    local p = partFactory(parent, name, size, cf, color, material)
    p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = true, true, false, false
    return p
end

local function placeTemplate(template, parent, entry)
    template.Name = string.format("%s_%d_%d", entry.name, entry.x, entry.z)
    template:SetAttribute("TownRole", entry.role)
    template.Parent = parent
    template:PivotTo(CFrame.new(entry.x, 0, entry.z) * CFrame.Angles(0, entry.rotation, 0))
    local box, size = template:GetBoundingBox()
    local delta = Vector3.new(entry.x - box.Position.X, -(box.Position.Y - size.Y/2), entry.z - box.Position.Z)
    template:PivotTo(template:GetPivot() + delta)
end

local function externalTemplate(templates, parent, entry)
    local source = templates and templates:FindFirstChild(entry.name)
    if not source then return false end
    local template, reason, report = Town.sanitizeTemplate(source)
    if not template then
        warn(string.format("[DROPZONE] Town template %s rejected: %s", entry.name, reason))
        return false
    end
    placeTemplate(template, parent, entry)
    if report.removed > 0 then
        warn(string.format("[DROPZONE] Town template %s: removed %d unsafe/unneeded descendants", entry.name, report.removed))
    end
    return true
end

local function shell(partFactory, parent, base, width, depth, height, wallColor, roofColor, backDoor)
    local wall, roof = 2, 1.6
    local door, rear = 10, backDoor and 8 or 0
    local frontWing, backWing = (width-door)/2, rear > 0 and (width-rear)/2 or width
    structural(partFactory, parent, "LeftWall", Vector3.new(wall,height,depth), base*CFrame.new(-width/2+wall/2,height/2,0), wallColor)
    structural(partFactory, parent, "RightWall", Vector3.new(wall,height,depth), base*CFrame.new(width/2-wall/2,height/2,0), wallColor)
    structural(partFactory, parent, "FrontWall", Vector3.new(frontWing,height,wall), base*CFrame.new(-(door+frontWing)/2,height/2,depth/2-wall/2), wallColor)
    structural(partFactory, parent, "FrontWall", Vector3.new(frontWing,height,wall), base*CFrame.new((door+frontWing)/2,height/2,depth/2-wall/2), wallColor)
    if rear > 0 then
        structural(partFactory, parent, "RearWall", Vector3.new(backWing,height,wall), base*CFrame.new(-(rear+backWing)/2,height/2,-depth/2+wall/2), wallColor)
        structural(partFactory, parent, "RearWall", Vector3.new(backWing,height,wall), base*CFrame.new((rear+backWing)/2,height/2,-depth/2+wall/2), wallColor)
    else
        structural(partFactory, parent, "RearWall", Vector3.new(width,height,wall), base*CFrame.new(0,height/2,-depth/2+wall/2), wallColor)
    end
    structural(partFactory, parent, "RoofCollider", Vector3.new(width+1,roof,depth+1), base*CFrame.new(0,height+roof/2,0), roofColor)
end

local function visual(parent, name, size, cf, color, material)
    return Cosmetics.part(parent, name, size, cf, color, nil, material)
end

local function fallbackBuilding(structures, visuals, partFactory, entry)
    local model = Instance.new("Model")
    model.Name = string.format("%s_%d_%d", entry.name, entry.x, entry.z)
    model:SetAttribute("TownRole", entry.role)
    model.Parent = structures
    local art = Instance.new("Folder")
    art.Name, art.Parent = model.Name, visuals
    local base = CFrame.new(entry.x,0,entry.z) * CFrame.Angles(0,entry.rotation,0)
    local wallColor = palette(entry.color)
    local height = entry.role == "Office" and 18 or entry.role == "Shop" and 13 or 14
    shell(partFactory, model, base, 30, 28, height, wallColor, Theme.Slate, true)

    -- Large, high-contrast openings and rooflines do the visual work. Every art
    -- part is non-colliding/non-query; the simple shell remains authoritative.
    if entry.role == "House" then
        if entry.name == "House01" then
            visual(art,"GableRoof",Vector3.new(17,1,30),base*CFrame.new(-7.1,height+4,0)*CFrame.Angles(0,0,math.rad(-26)),Theme.Slate)
            visual(art,"GableRoof",Vector3.new(17,1,30),base*CFrame.new(7.1,height+4,0)*CFrame.Angles(0,0,math.rad(26)),Theme.Slate)
            visual(art,"PorchAwning",Vector3.new(14,.6,4),base*CFrame.new(0,10,15),Theme.Paper)
            visual(art,"DoorHeader",Vector3.new(11,1,.35),base*CFrame.new(0,12.2,14.15),Theme.Paper)
        elseif entry.name == "House02" then
            visual(art,"ButterflyRoof",Vector3.new(17,1,30),base*CFrame.new(-7.2,height+2.8,0)*CFrame.Angles(0,0,math.rad(18)),Theme.Ink)
            visual(art,"ButterflyRoof",Vector3.new(17,1,30),base*CFrame.new(7.2,height+2.8,0)*CFrame.Angles(0,0,math.rad(-18)),Theme.Ink)
            visual(art,"WideEave",Vector3.new(20,.6,3.5),base*CFrame.new(0,10.5,14.8),Theme.Paper)
            visual(art,"EntryStripe",Vector3.new(11,.8,.35),base*CFrame.new(0,12.2,14.15),Theme.Cyan)
        else
            visual(art,"MonoPitchRoof",Vector3.new(33,1,30),base*CFrame.new(0,height+3.6,0)*CFrame.Angles(0,0,math.rad(-12)),Theme.Slate)
            visual(art,"HighRoofEdge",Vector3.new(.8,3,30),base*CFrame.new(-15.5,height+6.8,0),Theme.Paper)
            visual(art,"GarageEave",Vector3.new(18,.7,4),base*CFrame.new(-3,10.2,15),Theme.Paper)
            visual(art,"EntryStripe",Vector3.new(11,.8,.35),base*CFrame.new(0,12.2,14.15),Theme.Orange)
        end
    elseif entry.role == "Shop" then
        visual(art,"Awning",Vector3.new(18,.7,4),base*CFrame.new(0,10.5,15),Theme.Orange)
        visual(art,"ShopSign",Vector3.new(16,3,.45),base*CFrame.new(0,14.2,14.4),entry.name=="Shop02" and Theme.Blue or Theme.Gold)
        visual(art,"Parapet",Vector3.new(31,2,.7),base*CFrame.new(0,height+1.2,13.8),Theme.Ink)
    else
        visual(art,"OfficeBand",Vector3.new(31,1,.45),base*CFrame.new(0,14,14.2),Theme.Blue)
        visual(art,"OfficeSign",Vector3.new(12,2.5,.5),base*CFrame.new(0,19.1,14.4),Theme.Gold)
        visual(art,"Balcony",Vector3.new(16,.6,3.5),base*CFrame.new(0,12.2,15),Theme.Paper)
    end
    for _, x in ipairs({-9,9}) do
        visual(art,"FrontWindow",Vector3.new(5,4,.3),base*CFrame.new(x,7,14.15),Theme.Ink)
    end
    for _, side in ipairs({-1,1}) do
        visual(art,"SideWindow",Vector3.new(.3,4,6),base*CFrame.new(side*15.05,7,-3),Theme.Ink)
        visual(art,"CornerTrim",Vector3.new(.35,height,.35),base*CFrame.new(side*14.9,height/2,13.9),Theme.Paper)
    end
end

local function fallbackWarehouse(structures, visuals, partFactory, entry)
    local model = Instance.new("Model")
    model.Name = string.format("Warehouse_%d_%d", entry.x, entry.z)
    model:SetAttribute("TownRole", "Warehouse")
    model.Parent = structures
    local art = Instance.new("Folder")
    art.Name, art.Parent = model.Name, visuals
    local base = CFrame.new(entry.x,0,entry.z)*CFrame.Angles(0,entry.rotation,0)
    shell(partFactory, model, base, 46, 34, 15, Theme.Town[4], Theme.Slate, true)
    visual(art,"WarehouseAccent",Vector3.new(47,2,.45),base*CFrame.new(0,13.5,16.3),Theme.Blue)
    visual(art,"GarageHeader",Vector3.new(17,1,.5),base*CFrame.new(0,12,16.2),Theme.Paper)
    visual(art,"WarehouseSign",Vector3.new(10,3,.55),base*CFrame.new(12,9,16.25),Theme.Orange)
    for _, side in ipairs({-1,1}) do
        visual(art,"HighWindow",Vector3.new(.35,3,7),base*CFrame.new(side*23.05,10,-3),Theme.Ink)
    end
end

function Town.create(world, partFactory)
    local structures, visuals = makeFolders(world)
    local templates = ServerStorage:FindFirstChild(Town.TemplateFolderName)
    for _, entry in ipairs(Town.Layout) do
        if not externalTemplate(templates, structures, entry) then
            fallbackBuilding(structures, visuals, partFactory, entry)
        end
        table.insert(world.loot, rotatedPosition(entry))
    end
    for _, entry in ipairs(Town.WarehouseLayout) do
        if not externalTemplate(templates, structures, entry) then
            fallbackWarehouse(structures, visuals, partFactory, entry)
        end
        -- Four pickups per warehouse retain the old warehouse area's loot density.
        local base = CFrame.new(entry.x,0,entry.z)*CFrame.Angles(0,entry.rotation,0)
        for _, offset in ipairs({Vector3.new(-13,2,22),Vector3.new(13,2,22),Vector3.new(-13,2,-22),Vector3.new(13,2,-22)}) do
            table.insert(world.loot, (base*CFrame.new(offset)).Position)
        end
    end
    return structures
end

return Town
