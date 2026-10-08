-- Server-owned, replicated cosmetics. No gameplay stats or client requests here.
local Cosmetics = require(script.Parent.Cosmetics)
local TweenService = game:GetService("TweenService")
local Visuals = {}
Visuals.MaxParts = 64
Visuals.MaxPulses = 4
Visuals.Duration = .45
local pulses = {}
local armor = Color3.fromRGB(36, 48, 65)
local silver = Color3.fromRGB(132, 153, 177)
local colors = {
    SwiftLegs=Color3.fromRGB(55,225,255), IronSkin=Color3.fromRGB(255,180,75),
    HunterEyes=Color3.fromRGB(255,95,100), QuickHands=Color3.fromRGB(255,95,100),
    Builder=Color3.fromRGB(180,140,255), HighJump=Color3.fromRGB(55,225,255),
    Regeneration=Color3.fromRGB(65,255,130), Scavenger=Color3.fromRGB(180,140,255),
    Adrenaline=Color3.fromRGB(55,225,255), CombatShield=Color3.fromRGB(70,150,255),
    Overcharge=Color3.fromRGB(180,140,255),
}
local rig = {
    chest={"UpperTorso","Torso"}, waist={"LowerTorso","Torso"}, head={"Head"},
    leftArm={"LeftLowerArm","Left Arm"}, rightArm={"RightLowerArm","Right Arm"},
    leftShoulder={"LeftUpperArm","Left Arm"}, rightShoulder={"RightUpperArm","Right Arm"},
    leftLeg={"LeftLowerLeg","Left Leg"}, rightLeg={"RightLowerLeg","Right Leg"},
}
function Visuals.stage(count)
    return count >= 5 and 3 or count >= 3 and 2 or count > 0 and 1 or 0
end
local function limb(model, slot)
    for _, name in ipairs(rig[slot]) do
        local part = model:FindFirstChild(name)
        if part and part:IsA("BasePart") then return part end
    end
end
local function stopPulse(a)
    local pulse = pulses[a]
    if not pulse then return end
    pulses[a] = nil
    for _, tween in ipairs(pulse.tweens) do tween:Cancel() end
    pulse.highlight:Destroy()
    if pulse.part then pulse.part:Destroy() end
end
function Visuals.stop(a)
    stopPulse(a)
    for _, record in pairs(a.evolutionVisualParts or {}) do
        if record.tween then record.tween:Cancel(); record.tween = nil end
        if record.part.Parent then record.part.Size, record.part.Transparency = record.size, record.transparency end
    end
end
function Visuals.clear(a)
    Visuals.stop(a)
    -- Only this Actor's owned container, never another model/accessory folder.
    if a.evolutionVisualFolder then a.evolutionVisualFolder:Destroy() end
    a.evolutionVisualFolder, a.evolutionVisualParts = nil, nil
    if a.model then a.model:SetAttribute("DropzoneEvolutionStage", nil) end
end
function Visuals.initialize(a)
    Visuals.clear(a)
    -- Remove only explicitly marked leftovers on this character. Legacy Mutation
    -- belongs to Evolution; BOTs must no longer receive even that decoration.
    for _, child in ipairs(a.model:GetChildren()) do
        if child:GetAttribute("DropzoneEvolutionOwned") == true
            or (child.Name == "Mutation" and child:IsA("Folder")) then child:Destroy() end
    end
    a.mutationFolder = nil
end
local function pulse(a, color)
    stopPulse(a)
    local count = 0
    for _ in pairs(pulses) do count = count + 1 end
    if count >= Visuals.MaxPulses then return end
    local container = a.evolutionVisualFolder
    local h = Instance.new("Highlight")
    h.Name, h.Adornee, h.DepthMode = "EvolutionFlash", a.model, Enum.HighlightDepthMode.Occluded
    h.FillColor, h.OutlineColor = color, color
    h.FillTransparency, h.OutlineTransparency = .78, .3
    h.Parent = container
    local flash = TweenService:Create(h, TweenInfo.new(Visuals.Duration), {FillTransparency=1,OutlineTransparency=1})
    local state = {highlight=h, tweens={flash}}
    local chest = limb(a.model, "chest")
    if chest then
        local p = Cosmetics.part(container, "EnergyPulse", Vector3.new(.2,.2,.2),
            chest.CFrame*CFrame.new(0,0,-chest.Size.Z/2-.24), color, chest, Enum.Material.Neon, Enum.PartType.Ball, true)
        p.Transparency = .45
        local expand = TweenService:Create(p, TweenInfo.new(Visuals.Duration), {Size=Vector3.new(1.2,1.2,1.2),Transparency=1})
        state.part = p
        table.insert(state.tweens, expand)
    end
    pulses[a] = state
    for _, tween in ipairs(state.tweens) do tween:Play() end
    task.delay(Visuals.Duration, function()
        -- Identity check prevents an old callback from destroying a newer pulse.
        if pulses[a] == state then stopPulse(a) end
    end)
end
function Visuals.update(a, acquiredId)
    if not a.player then
        -- Preserve BOT ability stacks/AI but remove legacy Evolution-only visuals.
        Visuals.initialize(a)
        return
    end
    if not a.alive or not a.model.Parent or a.humanoid.Health <= 0 or a.roundId == -1 then return end
    local stage = Visuals.stage(a.evolutionCount or 0)
    if stage == 0 then Visuals.clear(a); return end
    if not a.evolutionVisualFolder or a.evolutionVisualFolder.Parent ~= a.model then
        Visuals.initialize(a)
        local f = Instance.new("Folder")
        f.Name = "PlayerEvolution"
        f:SetAttribute("DropzoneEvolutionOwned", true)
        f.Parent = a.model
        a.evolutionVisualFolder, a.evolutionVisualParts = f, {}
    end
    local records, used, partCount = a.evolutionVisualParts, {}, 0
    local function piece(key, slot, dimensions, position, color, neon, animate, rank)
        local anchor = limb(a.model, slot)
        if not anchor or partCount >= Visuals.MaxParts then return end
        partCount = partCount + 1
        used[key] = true
        -- Scale with the actual limb. The depth stays thin and the attachment
        -- never spans an elbow/knee joint, so R6/R15 animations remain free.
        local size = Vector3.new(dimensions[1]*anchor.Size.X, dimensions[2]*anchor.Size.Y, dimensions[3])
        local cf = anchor.CFrame*CFrame.new(position[1]*anchor.Size.X, position[2]*anchor.Size.Y,
            position[3] < 0 and -anchor.Size.Z/2+position[3] or anchor.Size.Z/2+position[3])
        local record = records[key]
        if record and (not record.part.Parent or record.anchor ~= anchor) then
            if record.tween then record.tween:Cancel() end
            record.part:Destroy(); records[key] = nil; record = nil
        end
        local fresh = not record
        if fresh then
            local p = Cosmetics.part(a.evolutionVisualFolder, key, size, cf, color, anchor,
                neon and Enum.Material.Neon or Enum.Material.Metal, nil, true)
            -- Hide all owned additions locally during AIM, including the pulse.
            -- The replicated Transparency and other observers are unaffected.
            record = {part=p, anchor=anchor}
            records[key] = record
        end
        local transparency = neon and math.max(.02, .22-stage*.04-((rank or 1)-1)*.05) or 0
        local changed = not record.size or (record.size-size).Magnitude > .001 or record.transparency ~= transparency
        if changed then
            if record.tween then record.tween:Cancel(); record.tween=nil end
            record.size, record.transparency = size, transparency
            if animate or fresh then
                record.part.Size, record.part.Transparency = size*.65, .8
                local tween = TweenService:Create(record.part, TweenInfo.new(Visuals.Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {Size=size,Transparency=transparency})
                record.tween = tween
                tween:Play()
            else record.part.Size, record.part.Transparency = size, transparency end
        end
    end
    -- Separate channels/slots let all eleven builds coexist without replacing
    -- an earlier ability. Rank changes geometry; global stage adds chassis armor.
    for _, id in ipairs({"SwiftLegs","IronSkin","HunterEyes","QuickHands","Builder","HighJump","Regeneration","Scavenger","Adrenaline","CombatShield","Overcharge"}) do
        local rank = (a.evolutionStacks or {})[id] or 0
        if rank > 0 then
            local color, grow = colors[id], 1+(rank-1)*.22
            local function add(suffix, slot, dims, pos, neon)
                piece(id..suffix, slot, {dims[1]*grow,dims[2]*grow,dims[3]+(rank-1)*.04}, pos,
                    neon and color or armor, neon, id == acquiredId, rank)
            end
            if id == "SwiftLegs" then
                for _, slot in ipairs({"leftLeg","rightLeg"}) do
                    add(slot.."Drive",slot,{.38,.48,.18},{-.24,0,-.19},false)
                    add(slot.."Rail",slot,{.12,.5,.07},{-.24,0,-.32},true)
                end
            elseif id == "IronSkin" then
                add("Plate","chest",{.82,.48,.2},{0,.16,-.14},false)
                for _, slot in ipairs({"leftShoulder","rightShoulder"}) do add(slot,slot,{1.05,.28,.25},{0,.26,-.1},false) end
                add("Seam","chest",{.65,.05,.07},{0,.3,-.29},true)
            elseif id == "HunterEyes" then
                add("HelmetBrow","head",{.82,.18,.14},{0,.28,-.13},false)
                add("Visor","head",{.76,.12,.07},{0,.12,-.22},true)
            elseif id == "QuickHands" or id == "Builder" then
                local slot = id == "Builder" and "leftArm" or "rightArm"
                add("Gauntlet",slot,{.78,.48,.22},{0,-.1,-.16},false)
                add("Display",slot,{.5,.16,.09},{0,-.08,-.32},true)
                if rank >= 2 then add("Fin",slot,{.2,.5,.16},{.36,-.08,-.12},false) end
            elseif id == "HighJump" then
                for _, slot in ipairs({"leftLeg","rightLeg"}) do
                    add(slot.."Booster",slot,{.42,.36,.3},{.24,-.28,.24},false)
                    add(slot.."Exhaust",slot,{.3,.12,.08},{.24,-.42,.42},true)
                end
            elseif id == "Regeneration" then
                add("Housing","chest",{.28,.32,.2},{-.23,-.17,-.2},false)
                add("Core","chest",{.2,.22,.09},{-.23,-.17,-.34},true)
            elseif id == "Scavenger" then
                for _, side in ipairs({-1,1}) do
                    add("Pack"..side,"waist",{.26,.38,.28},{side*.34,-.22,-.2},false)
                    add("Supply"..side,"waist",{.17,.07,.08},{side*.34,-.22,-.4},true)
                end
            elseif id == "Adrenaline" then
                for _, slot in ipairs({"chest","leftArm","rightArm"}) do add(slot.."Line",slot,{.09,.65,.07},{.25,0,-.38},true) end
            elseif id == "CombatShield" then
                add("Emitter","chest",{.24,.28,.2},{.23,-.17,-.2},false)
                add("Shield","chest",{.18,.18,.09},{.23,-.17,-.34},true)
                for _, slot in ipairs({"leftShoulder","rightShoulder"}) do add(slot.."Node",slot,{.55,.18,.1},{0,.1,-.4},true) end
            elseif id == "Overcharge" then
                add("Reactor","chest",{.55,.6,.38},{0,0,.3},false)
                add("Energy","chest",{.32,.38,.1},{0,0,.55},true)
                if rank >= 2 then
                    for _, side in ipairs({-1,1}) do add("Cell"..side,"chest",{.12,.55,.2},{side*.32,0,.35},true) end
                end
            end
        end
    end
    if stage >= 2 then
        for _, slot in ipairs({"leftShoulder","rightShoulder"}) do
            piece("Chassis"..slot,slot,{stage == 3 and 1.2 or 1,.24,.35},{0,.39,-.05},silver,false)
        end
        for _, slot in ipairs({"leftArm","rightArm","leftLeg","rightLeg"}) do
            piece("Chassis"..slot,slot,{.75,.2,.2},{0,.27,-.16},silver,false)
        end
    end
    if stage == 3 then
        piece("HeavyChest","chest",{.92,.26,.26},{0,-.34,-.17},silver,false)
        piece("CentralCore","chest",{.18,.2,.12},{0,0,-.5},colors[acquiredId] or colors.Overcharge,true)
        piece("BackUnit","chest",{.78,.8,.42},{0,0,.18},armor,false)
        for _, side in ipairs({-1,1}) do
            piece("BackTower"..side,"chest",{.18,.9,.28},{side*.38,.16,.46},silver,false)
            piece("BackEnergy"..side,"chest",{.12,.68,.1},{side*.38,.16,.65},colors.Overcharge,true)
        end
    end
    for key, record in pairs(records) do
        if not used[key] then
            if record.tween then record.tween:Cancel() end
            record.part:Destroy(); records[key] = nil
        end
    end
    a.model:SetAttribute("DropzoneEvolutionStage", stage)
    if acquiredId then pulse(a, colors[acquiredId] or colors.Overcharge) end
end
return Visuals
