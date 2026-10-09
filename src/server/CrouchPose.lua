-- Lower the torso by bending the legs, never by lowering the Humanoid's
-- physical ground clearance. C0 offsets replicate and coexist with Animate's
-- Transform; no asset IDs, root teleport, or terrain-specific snapping.
local Pose = {}
local function rotated(base, angle)
    local p = base.Position
    return CFrame.new(p.X,p.Y,p.Z) * CFrame.Angles(math.rad(angle),0,0)
        * CFrame.new(-p.X,-p.Y,-p.Z) * base
end
local function endpoint(chain, frames)
    local cf = CFrame.new()
    for i,joint in ipairs(chain) do cf = cf * frames[i] * joint.C1:Inverse() end
    return cf
end
local function bottom(cf, part)
    local s = part.Size
    -- Lowest box corner, including tilted R6 legs (not just foot centre).
    return cf.Position.Y - (math.abs(cf.RightVector.Y)*s.X
        + math.abs(cf.UpVector.Y)*s.Y + math.abs(cf.LookVector.Y)*s.Z)/2
end
function Pose.capture(model, root)
    if not model or not root then return nil end
    local function motor(name)
        local j = model:FindFirstChild(name,true)
        return j and j:IsA("Motor6D") and j.Part0 and j.Part1 and j or nil
    end
    local rootJoint = motor("Root") or motor("RootJoint")
    if not rootJoint or rootJoint.Part0 ~= root then return nil end
    local legs = {}
    for _,side in ipairs({"Left","Right"}) do
        local hip = motor(side.."Hip") or motor(side.." Hip")
        if not hip or hip.Part0 ~= rootJoint.Part1 then return nil end
        local knee, ankle = motor(side.."Knee"), motor(side.."Ankle")
        -- R6 has one rigid leg segment; a deeper hip fold creates clearance
        -- even after accounting for the toe corner of its tilted box.
        local chain, angles = {hip}, {45}
        if knee and ankle and knee.Part0 == hip.Part1 and ankle.Part0 == knee.Part1 then
            chain, angles = {hip,knee,ankle}, {35,-70,35}
        end
        local bases, bent = {}, {}
        for i,j in ipairs(chain) do bases[i],bent[i] = j.C0,rotated(j.C0,angles[i]) end
        legs[#legs+1] = {chain=chain,bases=bases,bent=bent,foot=chain[#chain].Part1}
    end
    local standing = rootJoint.C0 * rootJoint.C1:Inverse()
    local drop = 0
    for _,leg in ipairs(legs) do
        local rest, bend = standing * endpoint(leg.chain,leg.bases), standing * endpoint(leg.chain,leg.bent)
        drop = drop + math.max(0,bottom(bend,leg.foot)-bottom(rest,leg.foot))/2
    end
    local loweredC0 = CFrame.new(0,-drop,0) * rootJoint.C0
    local lowered = loweredC0 * rootJoint.C1:Inverse()
    for _,leg in ipairs(legs) do
        local rest, bend = standing * endpoint(leg.chain,leg.bases), lowered * endpoint(leg.chain,leg.bent)
        local delta = rest.Position - bend.Position
        -- Preserve each foot's horizontal anchor and lowest point independently.
        delta = Vector3.new(delta.X,bottom(rest,leg.foot)-bottom(bend,leg.foot),delta.Z)
        delta = lowered:Inverse():VectorToWorldSpace(delta)
        leg.bent[1] = CFrame.new(delta.X,delta.Y,delta.Z) * leg.bent[1]
    end
    return {root=rootJoint,base=rootJoint.C0,lowered=loweredC0,legs=legs}
end
function Pose.apply(pose, enabled)
    if not pose or pose.enabled == enabled then return end
    pose.enabled = enabled
    if pose.root.Parent then pose.root.C0 = enabled and pose.lowered or pose.base end
    for _,leg in ipairs(pose.legs) do
        for i,j in ipairs(leg.chain) do
            if j.Parent then j.C0 = enabled and leg.bent[i] or leg.bases[i] end
        end
    end
end
return Pose
