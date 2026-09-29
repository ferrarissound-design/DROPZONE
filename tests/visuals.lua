-- Engine doubles exercise actual constructors and cleanup, not Roblox rendering/physics.
local assertions=0
local function check(value,message) assert(value,message); assertions=assertions+1 end
local modules={}
require=function(key) assert(modules[key],"unloaded module "..tostring(key)); return modules[key] end
local function load(name,path) modules[name]=assert(loadfile(ROOT.."/src/"..path))(); return modules[name] end
local vec={}; vec.__index=vec
function vec:Lerp(other,t) return self+(other-self)*t end
vec.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vec.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vec.__mul=function(a,b) return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
Vector3={new=function(x,y,z) return setmetatable({X=x,Y=y,Z=z},vec) end}
local cf={}; cf.__index=cf
cf.__mul=function(a) return a end
function cf:ToObjectSpace() return self end
CFrame={new=function() return setmetatable({},cf) end,Angles=function() return setmetatable({},cf) end}
Color3={fromRGB=function(r,g,b) return {r=r,g=g,b=b,Color3=true} end,new=function(r,g,b) return {r=r,g=g,b=b,Color3=true} end}
Enum=setmetatable({}, {__index=function(t,k)
    local values=setmetatable({}, {__index=function(_,v) return v end});rawset(t,k,values);return values
end})
UDim={new=function(s,o) return {Scale=s,Offset=o} end}
UDim2={new=function(x,xo,y,yo) return {X=UDim.new(x,xo),Y=UDim.new(y,yo)} end}
UDim2.fromOffset=function(x,y) return UDim2.new(0,x,0,y) end
UDim2.fromScale=function(x,y) return UDim2.new(x,0,y,0) end
Vector2={new=function(x,y) return {X=x,Y=y} end}
TweenInfo={new=function(t) return t end}
math.clamp=function(v,a,b) return math.min(b,math.max(a,v)) end
Random={new=function() return {NextNumber=function(_,a,b) return (a+b)/2 end} end}
local function signal() return {Connect=function() return {Disconnect=function() end} end} end
local methods={}
function methods:GetChildren() local out={}; for child in pairs(self._children) do out[#out+1]=child end;return out end
function methods:GetDescendants()
    local out={};for _,child in ipairs(self:GetChildren()) do out[#out+1]=child;for _,desc in ipairs(child:GetDescendants()) do out[#out+1]=desc end end;return out
end
function methods:FindFirstChild(name) for child in pairs(self._children) do if child.Name==name then return child end end end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name),name) end
function methods:GetPropertyChangedSignal() return signal() end
function methods:Destroy() self:ClearAllChildren();self.Parent=nil;self._destroyed=true end
function methods:ClearAllChildren() for _,child in ipairs(self:GetChildren()) do child:Destroy() end end
local propertiesOf={}
Instance={new=function(kind)
    local properties={ClassName=kind,Name=kind,Size=Vector3.new(1,1,1),CFrame=CFrame.new(),AbsoluteSize=Vector2.new(900,480),Activated=signal(),InputBegan=signal()}
    local obj={_children={}}
    propertiesOf[obj]=properties
    return setmetatable(obj,{
        __index=function(t,k) if methods[k] then return methods[k] end; if properties[k]~=nil then return properties[k] end; return methods.FindFirstChild(t,k) end,
        __newindex=function(t,k,v)
            if k=="Color" or k=="BackgroundColor3" or k=="TextColor3" then assert(type(v)=="table" and v.Color3,"invalid Color3 on "..kind.."."..k) end
            if k=="Parent" then
                if properties.Parent then properties.Parent._children[t]=nil end
                if v then v._children[t]=true end
            end
            properties[k]=v
        end,
    })
end}
local function folder(parent,name) local f=Instance.new("Folder");f.Name,f.Parent=name,parent;return f end
workspace=folder(nil,"Workspace")
local replicated=folder(nil,"ReplicatedStorage")
local shared=folder(replicated,"DropzoneShared")
for _,name in ipairs({"VisualTheme","Rules","Config","Weapons"}) do
    local key=folder(shared,name);modules[key]=nil
end
local playerGui=folder(nil,"PlayerGui")
local player={WaitForChild=function() return playerGui end}
local tweens={Create=function(_,_,_,_) return {Play=function() end,Cancel=function() end} end}
game={ReplicatedStorage={DropzoneShared={VisualTheme="VisualTheme",Rules="Rules",Config="Config",Weapons="Weapons"}},GetService=function(_,name)
    return ({Players={LocalPlayer=player},TweenService=tweens,ReplicatedStorage=replicated})[name]
end}
script={Parent={Cosmetics="Cosmetics",MapVisuals="MapVisuals"}}
local Theme=load("VisualTheme","shared/VisualTheme.lua")
load("Config","shared/Config.lua");load("Rules","shared/Rules.lua");load("Weapons","shared/Weapons.lua")
for _,key in ipairs(shared:GetChildren()) do modules[key]=modules[key.Name] end
local Cosmetics=load("Cosmetics","server/Cosmetics.lua")
local MapVisuals=load("MapVisuals","server/MapVisuals.lua")
local Actors=load("Actors","server/Actors.lua")
local function cosmeticCount(root,anchored)
    local count=0
    for _,p in ipairs(root:GetDescendants()) do
        if p.ClassName=="Part" then
            check(p.CanCollide==false and p.CanTouch==false and p.CanQuery==false and p.Massless==true,"cosmetic cannot affect physics, pickup, hitbox or rays: "..p.Name)
            check(p.Anchored==anchored,"correct cosmetic ownership: "..p.Name)
            count=count+1
        end
    end
    return count
end
local owner=folder(workspace,"Owner")
local hand=Instance.new("Part");hand.Parent=owner
for kind,expected in pairs({Pistol=4,Rifle=6,Shotgun=5}) do
    local weapon=Cosmetics.weapon(owner,kind,CFrame.new(),hand)
    check(cosmeticCount(weapon,false)==expected,"bounded distinct weapon silhouette")
    Cosmetics.weapon(owner,kind,CFrame.new(),hand)
    check(weapon.Parent==nil,"re-equip destroys every old weapon cosmetic")
end
local drone=Actors.botModel(workspace,1)
check(drone.Head.Size.X==2 and drone.Head.Size.Y==1 and drone.Torso.Size.X==2,"drone hitbox dimensions unchanged")
check(cosmeticCount(drone.DroneShell,false)==7,"bounded drone armor")
local shell=drone.DroneShell;drone:Destroy()
check(shell.Parent==nil and #shell:GetDescendants()==0,"drone destruction clears shell and welds")
for _,kind in ipairs({"Rifle","Pistol","Shotgun","Ammo","Health","Shield","Energy"}) do
    local pickup=Instance.new("Part");pickup.Parent=workspace
    local visual=Cosmetics.loot(pickup,kind)
    check(cosmeticCount(visual,true)<=6,"loot part cap")
    pickup:Destroy();check(visual.Parent==nil,"pickup removal also removes its cosmetic")
end
for _,kind in ipairs({"Wall","Floor","Ramp"}) do
    local build=Instance.new("Part");build.Parent=workspace;build.Size=Vector3.new(8,7,8)
    local visual=Cosmetics.build(build,kind)
    check(cosmeticCount(visual,true)==2,"two additional parts per build")
    build:Destroy();check(visual.Parent==nil,"build destruction clears rails")
end
local world={root=folder(workspace,"World")};world.map=folder(world.root,"Map")
local scenery=MapVisuals.create(world)
local mapCount=cosmeticCount(scenery,true)
check(mapCount<=210 and scenery.Parent==world.root and scenery.Parent~=world.map,"scenery budget and ground-ray exclusion")
local Hud=load("Hud","client/Hud.lua")
local hud=Hud.new()
local cards={
    {name="Swift Legs",rankText="III",description="移動速度 +4%",category="Mobility"},
    {name="Regeneration",rankText="II",description="静穏時 1.5 HP/s",category="Survival"},
    {name="Quick Hands",rankText="III",description="Reload time -6%",category="Attack"},
}
local me={alive=true,hp=80,maxHp=100,shield=25,energy=75,maxEnergy=150,kills=1,evolutions=0,slots={"Pistol"},slot=1,weapon="Pistol",ammo=8,reserve=48,damage=22,survival=10,evolutionBuild={},evolutionDraft={id=1,seconds=5,options=cards}}
local s={roundId=1,phase="Active",alive=11,remaining=350,me=me,zone={phase=1,shrinking=false,remaining=30,radius=250,nextRadius=140,center=Vector3.new(0,0,0),nextCenter=Vector3.new(0,0,0)}}
hud:update(s,function() return true end)
check(hud.hpBar.Size.X.Scale==.8 and hud.shieldBar.Size.X.Scale==.25 and hud.energyBar.Size.X.Scale==.5,"HUD bars follow authoritative snapshot")
check(hud.draft.Visible and hud.draftCards[2].RichText and hud.cardStrokes[2].Color==Theme.Category.Survival,"draft typography and category colors")
local rightEdge=hud.draft.Position.X.Offset+hud.draft.Size.X.Offset
check(rightEdge==616 and rightEdge<632,"draft stays left of existing right controls")
for _,card in ipairs(hud.draftCards) do
    check(card.Position.Y.Offset+card.Size.Y.Offset<=hud.draft.Size.Y.Offset,"card remains within bounded touch region")
end
s.me.alive=false;hud:update(s);check(not hud.draft.Visible,"death closes decorated draft")
s.phase="Results";s.winner="Drone";s.me.rank=1;hud:update(s);check(hud.result.Visible and hud.result.RichText,"result renders with hierarchy")
s.roundId=2;s.me=nil;s.phase="Intermission";hud:update(s)
check(not hud.draft.Visible and hud.hpBar.Size.X.Scale==0 and hud.energyBar.Size.X.Scale==0,"new round clears visuals/bars")
local old=hud.gui;Hud.new();check(old.Parent==nil,"HUD reconstruction does not duplicate UI")
print("PASS: "..assertions.." visual constructor / cleanup assertions; map cosmetics="..mapCount)
