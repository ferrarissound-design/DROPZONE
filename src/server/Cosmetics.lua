local Theme = require(game.ReplicatedStorage.DropzoneShared.VisualTheme)
local PresentationConfig = require(game.ReplicatedStorage.DropzoneShared.PresentationConfig)
local ServerStorage = game:GetService("ServerStorage")
local Cosmetics = {}

-- All visual additions pass through this boundary. Never participate in gameplay
-- physics, touch pickup, raycast, placement overlap, or navigation.
function Cosmetics.part(parent, name, size, cf, color, anchor, material, shape)
    local p = Instance.new("Part")
    p.Name, p.Size, p.CFrame = name, size, cf
    p.Color, p.Material = color, material or Enum.Material.SmoothPlastic
    p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, true
    p.Anchored, p.CastShadow = anchor == nil, false
    if shape then p.Shape = shape end
    p.Parent = parent
    if anchor then
        local weld = Instance.new("WeldConstraint")
        weld.Part0, weld.Part1, weld.Parent = anchor, p, p
    end
    return p
end
local function folder(parent, name)
    local old = parent:FindFirstChild(name)
    if old then old:Destroy() end
    local f = Instance.new("Folder")
    f.Name, f.Parent = name, parent
    return f
end

local unsafeWeaponClasses = {
    Script=true, LocalScript=true, ModuleScript=true, Tool=true,
    RemoteEvent=true, RemoteFunction=true, BindableEvent=true, BindableFunction=true,
    Humanoid=true, AnimationController=true,
    ParticleEmitter=true, Trail=true, Beam=true,
    PointLight=true, SpotLight=true, SurfaceLight=true, Sound=true,
    ClickDetector=true, ProximityPrompt=true,
    Explosion=true, Fire=true, Smoke=true, Sparkles=true,
    VectorForce=true, LinearVelocity=true, AngularVelocity=true,
    AlignPosition=true, AlignOrientation=true, Torque=true,
    BodyForce=true, BodyGyro=true, BodyPosition=true, BodyVelocity=true,
    BodyAngularVelocity=true, RocketPropulsion=true,
}

local function templateWeapon(parent, kind, cf, anchor)
    local models = ServerStorage:FindFirstChild("WeaponModels")
    local template = models and models:FindFirstChild(kind)
    local templateRoot = template and template:FindFirstChild("Root")
    if not template or not template:IsA("Model") or not templateRoot or not templateRoot:IsA("BasePart") then return nil end

    local model = template:Clone()
    model.Name = "WeaponModel"
    for _, item in ipairs(model:GetDescendants()) do
        if unsafeWeaponClasses[item.ClassName]
            or (item:IsA("Constraint") and not item:IsA("WeldConstraint"))
            or item:IsA("JointInstance") then
            item:Destroy()
        end
    end
    local root = model:FindFirstChild("Root")
    if not root or not root:IsA("BasePart") then model:Destroy(); return nil end
    model.PrimaryPart = root
    model:PivotTo(cf * (template:GetAttribute("RootOffset") or CFrame.new()))
    model.Parent = parent
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide, part.CanTouch, part.CanQuery, part.Massless = false, false, false, true
            part.Anchored = anchor == nil
        end
    end
    if anchor then
        root.Anchored = false
        local joint = Instance.new("Motor6D")
        joint.Name, joint.Part0, joint.Part1 = "PresentationJoint", anchor, root
        joint.C0, joint.Parent = anchor.CFrame:ToObjectSpace(root.CFrame), parent
    end
    return parent
end

-- Shared silhouettes for the held weapon and the grounded pickup. Forward is -Z.
-- At most 6 parts per weapon; one optional presentation joint, no emitters/lights.
function Cosmetics.weapon(parent, kind, cf, anchor)
    local f = folder(parent, "HeldWeapon")
    local accent = Theme.Weapon[kind] or Theme.Gold
    local presentation = PresentationConfig.Weapons[kind]
    if anchor and presentation and presentation.HipOffset then cf = cf * presentation.HipOffset end
    -- Keep pickups on the bounded procedural silhouettes. Studio templates are
    -- only for held weapons so large custom models are never cloned across loot.
    if anchor and templateWeapon(f, kind, cf, anchor) then return f end
    local weaponRoot
    local function piece(name, x,y,z, px,py,pz, color)
        local part = Cosmetics.part(f, name, Vector3.new(x,y,z), cf*CFrame.new(px,py,pz), color, weaponRoot)
        if anchor and not weaponRoot then
            part.Anchored = false
            local joint = Instance.new("Motor6D")
            joint.Name, joint.Part0, joint.Part1 = "PresentationJoint", anchor, part
            joint.C0, joint.Parent = anchor.CFrame:ToObjectSpace(part.CFrame), f
            weaponRoot = part
        end
        return part
    end
    if kind == "Pistol" then
        piece("Slide", .62,.55,1.45, 0,.15,-.2, accent)
        piece("Grip", .48,.8,.5, 0,-.42,.2, Theme.Ink)
        piece("Muzzle", .38,.32,.3, 0,.12,-1.03, Theme.Slate)
        piece("Sight", .22,.18,.22, 0,.5,.1, Theme.Paper)
    elseif kind == "Shotgun" then
        piece("Receiver", .72,.65,1.1, 0,0,.05, Theme.Slate)
        piece("TwinBarrel", .8,.42,1.8, 0,.12,-1.15, Theme.Ink)
        piece("Pump", .88,.42,.65, 0,-.2,-1.05, accent)
        piece("Stock", .62,.85,1.0, 0,-.05,1.0, accent)
        piece("TopRail", .28,.12,1.3, 0,.4,-.65, Theme.Paper)
    else
        piece("Receiver", .65,.65,1.65, 0,0,-.15, accent)
        piece("Magazine", .52,.95,.6, 0,-.65,-.3, Theme.Ink)
        piece("Stock", .52,.65,.85, 0,-.08,1.0, Theme.Slate)
        piece("Barrel", .3,.3,.95, 0,.05,-1.45, Theme.Ink)
        piece("Sight", .32,.25,.45, 0,.48,-.2, Theme.Paper)
        piece("Grip", .38,.65,.35, 0,-.5,.45, Theme.Slate)
    end
    return f
end

function Cosmetics.drone(model, parts)
    local f = folder(model, "DroneShell")
    local function shell(limb, name, size, offset, color, material)
        local anchor = parts[limb]
        return Cosmetics.part(f, name, size, anchor.CFrame*offset, color, anchor, material)
    end
    shell("Head", "Helmet", Vector3.new(2.15,1.12,1.1), CFrame.new(0,.06,0), Theme.Paper)
    shell("Head", "Visor", Vector3.new(1.72,.42,.12), CFrame.new(0,.03,-.6), Theme.Cyan, Enum.Material.Neon)
    shell("Torso", "Core", Vector3.new(.8,.65,.14), CFrame.new(0,.1,-.57), Theme.Orange, Enum.Material.Neon)
    for _, limb in ipairs({"Left Arm", "Right Arm"}) do
        shell(limb, "Shoulder", Vector3.new(1.12,.62,1.12), CFrame.new(0,.68,0), Theme.Blue)
    end
    for _, limb in ipairs({"Left Leg", "Right Leg"}) do
        shell(limb, "Knee", Vector3.new(.85,.5,.14), CFrame.new(0,0,-.57), Theme.Paper)
    end
    return f
end

function Cosmetics.loot(p, kind)
    if Theme.Weapon[kind] then
        p.Transparency = 1
        -- Flat side-on display lets all weapon silhouettes read from above.
        return Cosmetics.weapon(p, kind, p.CFrame*CFrame.Angles(0, math.pi/2, math.rad(80)), nil)
    end
    local f = folder(p, "PickupShell")
    p.Transparency = 1
    local color = kind == "Health" and Theme.Green or kind == "Shield" and Theme.Blue or kind == "Energy" and Theme.Gold or Theme.Orange
    local function piece(name, size, offset, tint, shape)
        return Cosmetics.part(f, name, size, p.CFrame*offset, tint, nil, nil, shape)
    end
    if kind == "Shield" then
        piece("Canister", Vector3.new(1.35,1.85,1.35), CFrame.new(), color, Enum.PartType.Ball)
        piece("Cap", Vector3.new(.9,.3,.9), CFrame.new(0,.95,0), Theme.Paper)
        piece("Band", Vector3.new(1.42,.28,1.42), CFrame.new(), Theme.Cyan)
    elseif kind == "Health" then
        piece("MedicalCase", Vector3.new(1.9,1.35,1.2), CFrame.new(), Theme.Paper)
        piece("CrossHorizontal", Vector3.new(1.15,.28,.1), CFrame.new(0,0,-.66), color)
        piece("CrossVertical", Vector3.new(.28,.95,.1), CFrame.new(0,0,-.67), color)
    elseif kind == "Energy" then
        piece("Cell", Vector3.new(.95,1.8,.95), CFrame.new(), color)
        piece("Terminal", Vector3.new(.5,.28,.5), CFrame.new(0,1,0), Theme.Ink)
        piece("Charge", Vector3.new(1,.7,1), CFrame.new(), Theme.Paper)
    else
        piece("AmmoCase", Vector3.new(1.8,1.15,1.2), CFrame.new(), Theme.Slate)
        piece("Lid", Vector3.new(1.95,.24,1.3), CFrame.new(0,.66,0), color)
        piece("Latch", Vector3.new(.4,.65,.12), CFrame.new(0,0,-.67), Theme.Gold)
    end
    return f
end

function Cosmetics.build(p, kind)
    local f = folder(p, "BuildFrame")
    local size = p.Size
    for _, side in ipairs({-1,1}) do
        local railSize, cf
        if kind == "Wall" then
            railSize, cf = Vector3.new(.35,size.Y,.16), p.CFrame*CFrame.new(side*(size.X/2-.3),0,-size.Z/2-.05)
        elseif kind == "Floor" then
            railSize, cf = Vector3.new(.35,.12,size.Z), p.CFrame*CFrame.new(side*(size.X/2-.3),size.Y/2+.05,0)
        else
            local length = math.sqrt(size.Y*size.Y + size.Z*size.Z)
            railSize = Vector3.new(.35,.12,length)
            cf = p.CFrame*CFrame.new(side*(size.X/2-.3),.08,0)*CFrame.Angles(-math.atan(size.Y/size.Z),0,0)
        end
        Cosmetics.part(f, "Rail", railSize, cf, Theme.Paper)
    end
    return f
end
return Cosmetics
