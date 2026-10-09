-- Execute production pose math against scaled R6/R15 chains.
local count = 0
local function check(v,msg) assert(v,msg); count=count+1 end
local vec = {}; vec.__index = vec
vec.__add = function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vec.__sub = function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vec.__mul = function(a,b) return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
Vector3 = {new=function(x,y,z) return setmetatable({X=x,Y=y,Z=z},vec) end}
CFrame = assert(loadfile(ROOT.."/tests/aim_math.lua"))()(Vector3)
local Pose = assert(loadfile(ROOT.."/src/server/CrouchPose.lua"))()
for _,r15 in ipairs({true,false}) do
    for _,scale in ipairs({.6,1,1.5}) do
        local joints,parts = {},{}
        local function part(name,x,y,z)
            local p={Size=Vector3.new(x*scale,y*scale,z*scale)};parts[name]=p;return p
        end
        local root,torso = part("RootPart",2,2,1),part("Torso",2,2,1)
        local function motor(name,p0,p1,c0,c1)
            local j={Name=name,Part0=p0,Part1=p1,C0=c0,C1=c1,Parent=true,IsA=function(_,kind) return kind=="Motor6D" end}
            joints[name]=j;return j
        end
        local rootJoint = motor(r15 and "Root" or "RootJoint",root,torso,CFrame.new(),CFrame.new())
        local chains={}
        for _,side in ipairs({"Left","Right"}) do
            local x=side=="Left" and -.5*scale or .5*scale
            if r15 then
                local thigh,shin,foot = part(side.."Thigh",1,1.4,1),part(side.."Shin",1,1.4,1),part(side.."Foot",1,.4,1.5)
                chains[#chains+1]={
                    motor(side.."Hip",torso,thigh,CFrame.new(x,-scale,0),CFrame.new(0,.7*scale,0)),
                    motor(side.."Knee",thigh,shin,CFrame.new(0,-.7*scale,0),CFrame.new(0,.7*scale,0)),
                    motor(side.."Ankle",shin,foot,CFrame.new(0,-.7*scale,0),CFrame.new(0,.2*scale,0)),
                }
            else
                local leg=part(side.."Leg",1,2,1)
                local axis=CFrame.Angles(0,side=="Left" and -math.pi/2 or math.pi/2,0)
                chains[#chains+1]={motor(side.." Hip",torso,leg,CFrame.new(x,-scale,0)*axis,CFrame.new(0,scale,0)*axis)}
            end
        end
        local model={FindFirstChild=function(_,name) return joints[name] end}
        local function foot(chain)
            local cf=rootJoint.C0*rootJoint.C1:Inverse()
            for _,j in ipairs(chain) do cf=cf*j.C0*j.C1:Inverse() end
            local s=chain[#chain].Part1.Size
            local lowest=cf.Position.Y-(math.abs(cf.RightVector.Y)*s.X+math.abs(cf.UpVector.Y)*s.Y+math.abs(cf.LookVector.Y)*s.Z)/2
            return cf.Position,lowest
        end
        local rest={}
        for i,chain in ipairs(chains) do local p,y=foot(chain);rest[i]={p,y} end
        local pose=Pose.capture(model,root)
        check(pose~=nil,"standard rig captured")
        for repetition=1,5 do
            Pose.apply(pose,true)
            check(rootJoint.C0.Position.Y<0,"torso visibly lowered")
            for i,chain in ipairs(chains) do
                local p,y=foot(chain)
                check(math.abs(y-rest[i][2])<1e-6,"lowest foot point preserved")
                check(math.abs(p.X-rest[i][1].X)<1e-6 and math.abs(p.Z-rest[i][1].Z)<1e-6,"foot horizontal anchor preserved")
            end
            Pose.apply(pose,true)
            Pose.apply(pose,false)
            check(rootJoint.C0==pose.base,"root joint restored exactly")
            for _,leg in ipairs(pose.legs) do
                for i,j in ipairs(leg.chain) do check(j.C0==leg.bases[i],"leg joint restored without accumulation") end
            end
        end
        rootJoint.Parent=false
        Pose.apply(pose,true);Pose.apply(pose,false)
    end
end
check(Pose.capture({FindFirstChild=function() return nil end},{})==nil,"custom rig safely keeps standing clearance")
print("PASS: "..count.." numeric crouch pose assertions (engine physics remains separate)")
