-- Validates the real soldier-template branch with simple Roblox model doubles.
-- Actual Toolbox geometry, humanoid physics and accessories still need Studio.
local count=0
local function check(value,label) assert(value,label); count=count+1 end
local dependencies={Config={},Rules={},Cosmetics={drone=function() end},
    PlayerEvolutionVisuals={},VisualTheme={Paper="Paper",Slate="Slate"},Movement={}}
require=function(name) return assert(dependencies[name],tostring(name)) end
local modelFolder,source
modelFolder={FindFirstChild=function(_,name) return name=="Soldier" and source or nil end}
local storage={FindFirstChild=function(_,name) return name=="BotModels" and modelFolder or nil end}
game={ReplicatedStorage={DropzoneShared={Config="Config",Rules="Rules",VisualTheme="VisualTheme"}},
    GetService=function(_,name) return name=="ServerStorage" and storage or nil end}
script={Parent={Cosmetics="Cosmetics",PlayerEvolutionVisuals="PlayerEvolutionVisuals",Movement="Movement"}}
local cframe={ToObjectSpace=function() return {} end}
CFrame={new=function() return cframe end}
Vector3={new=function(x,y,z) return {X=x,Y=y,Z=z} end}
Instance={new=function(kind)
    local obj={ClassName=kind,CFrame=cframe}
    function obj:Destroy() self.destroyed=true end
    return obj
end}
local warnings={}
warn=function(msg) warnings[#warnings+1]=msg end
local function node(kind,name)
    local obj={ClassName=kind,Name=name or kind}
    function obj:IsA(other)
        return self.ClassName==other or (other=="BasePart" and self.ClassName=="Part")
    end
    function obj:Destroy() self.destroyed=true end
    return obj
end
local lastRig
local function rig()
    local root=node("Part","HumanoidRootPart")
    local torso=node("Part","Torso")
    local head=node("Part","Head")
    local left=node("Part","Left Arm")
    local right=node("Part","Right Arm")
    local leftLeg=node("Part","Left Leg")
    local rightLeg=node("Part","Right Leg")
    local humanoid=node("Humanoid","Humanoid")
    local motor=node("Motor6D","RootJoint")
    motor.Part0,motor.Part1=root,torso
    local malicious=node("Script","HiddenScript")
    local remote=node("RemoteEvent","UnwantedRemote")
    local force=node("BodyVelocity","Force")
    local members={root,torso,head,left,right,leftLeg,rightLeg,humanoid,motor,malicious,remote,force}
    local entries={HumanoidRootPart=root,Torso=torso,Head=head}
    local model={ClassName="Model",_members=members}
    function model:FindFirstChild(name) return entries[name] end
    function model:FindFirstChildOfClass(name) return name=="Humanoid" and humanoid or nil end
    function model:GetDescendants() return members end
    function model:Destroy() self.destroyed=true;self.Parent=nil end
    lastRig={model=model,members=members,root=root,torso=torso,humanoid=humanoid,
        malicious=malicious,remote=remote,force=force}
    return model
end
local template={Name="Soldier",ClassName="Model"}
function template:IsA(kind) return kind=="Model" end
function template:GetDescendants() return {1,2,3} end
function template:Clone() return rig() end
source=template
local Actors=assert(loadfile(ROOT.."/src/server/Actors.lua"))()
local parent={Name="DynamicActors"}
local soldier=Actors.botModel(parent,1)
check(soldier==lastRig.model and soldier.Parent==parent,"first bot clones Studio soldier into dynamic actors")
check(soldier.Name=="Drone1" and soldier.PrimaryPart==lastRig.root,"retains named actor and root reference")
check(lastRig.humanoid.DisplayName=="SOLDIER 1","soldier's visible humanoid display name")
check(lastRig.malicious.destroyed and lastRig.remote.destroyed and lastRig.force.destroyed,
    "unsafe Toolbox scripts, remotes and forces are destroyed while detached")
for _,part in ipairs({lastRig.root,lastRig.torso,lastRig.members[3],lastRig.members[4]}) do
    check(part.Anchored==false and part.CanQuery==true and part.CanTouch==false,
        "rig remains dynamic and combat-queryable without touch scripts")
end
check(lastRig.torso.CanCollide and not lastRig.root.CanCollide,"one predictable body collider")
check(not lastRig.torso.Massless and lastRig.members[4].Massless,"limbs and cosmetics remain massless")
check(lastRig.root.Transparency==1,"root part invisible")
local second=Actors.botModel(parent,2)
check(second~=soldier and second.Name=="Drone2" and second.Parent==parent,
    "each bot is a separate soldier clone")
check(#warnings==0,"valid template requires no warning")
-- Missing or invalid models cannot break the round: the existing procedural
-- robot remains the fallback (its visual construction is tested in visuals.lua).
source=nil
local default=Actors.botModel(parent,3)
check(default.ClassName=="Model" and default.Name=="Drone3" and default.Parent==parent,
    "missing Soldier creates the original procedural drone")
source={IsA=function() return false end}
local invalid=Actors.botModel(parent,4)
check(invalid.Name=="Drone4" and #warnings==1 and warnings[1]:find("Soldier must be a Model",1,true),
    "invalid template warns once and falls back to the procedural drone")
local another=Actors.botModel(parent,5)
check(another.Name=="Drone5" and #warnings==1,
    "repeating an invalid template does not flood server Output")
print("PASS: "..count.." Studio soldier template / sandbox / fallback assertions")
