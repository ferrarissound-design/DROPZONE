-- Engine doubles exercise actual constructors and cleanup, not Roblox rendering/physics.
local assertions=0
local function check(value,message) assert(value,message); assertions=assertions+1 end
local modules={}
require=function(key) assert(modules[key],"unloaded module "..tostring(key)); return modules[key] end
local function load(name,path) modules[name]=assert(loadfile(ROOT.."/src/"..path))(); return modules[name] end
local vec={}; vec.__index=function(v,k)
    if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
    if k=="Unit" then return v/v.Magnitude end
    return vec[k]
end
function vec:Lerp(other,t) return self+(other-self)*t end
vec.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vec.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vec.__mul=function(a,b) return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
vec.__div=function(a,b) return Vector3.new(a.X/b,a.Y/b,a.Z/b) end
Vector3={new=function(x,y,z) return setmetatable({X=x,Y=y,Z=z},vec) end}
local cf={}; cf.__index=cf
cf.__mul=function(a) return a end
function cf:ToObjectSpace() return self end
function cf:Lerp() return self end
CFrame={new=function(x,y,z)
    local position=type(x)=="table" and x or Vector3.new(x or 0,y or 0,z or 0)
    return setmetatable({Position=position,LookVector=Vector3.new(0,0,-1)},cf)
end,Angles=function() return CFrame.new() end}
CFrame.lookAt=function() return CFrame.new() end
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
local function signal()
    local callbacks = {}
    return {Connect=function(_,f) local token={fn=f}; callbacks[#callbacks+1]=token; return {Disconnect=function() token.fn=nil end} end,
        Fire=function(_,...) for _,token in ipairs(callbacks) do if token.fn then token.fn(...) end end end}
end
local methods={}
function methods:SetAttribute(name,value) self._attributes=self._attributes or {};self._attributes[name]=value end
function methods:GetAttribute(name) return self._attributes and self._attributes[name] end
function methods:GetChildren() local out={}; for child in pairs(self._children) do out[#out+1]=child end;return out end
function methods:GetDescendants()
    local out={};for _,child in ipairs(self:GetChildren()) do out[#out+1]=child;for _,desc in ipairs(child:GetDescendants()) do out[#out+1]=desc end end;return out
end
function methods:FindFirstChild(name) for child in pairs(self._children) do if child.Name==name then return child end end end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name),name) end
function methods:GetPropertyChangedSignal(name)
    self._signals = self._signals or {}
    self._signals[name] = self._signals[name] or signal()
    return self._signals[name]
end
function methods:IsA(kind)
    return self.ClassName==kind or (kind=="BasePart" and (self.ClassName=="Part" or self.ClassName=="WedgePart"))
end
function methods:Destroy() self:ClearAllChildren();self.Parent=nil;self._destroyed=true end
function methods:ClearAllChildren() for _,child in ipairs(self:GetChildren()) do child:Destroy() end end
local propertiesOf={}
Instance={new=function(kind)
    local properties={ClassName=kind,Name=kind,Size=Vector3.new(1,1,1),Position=Vector3.new(0,0,0),CFrame=CFrame.new(),AbsoluteSize=Vector2.new(900,480),Activated=signal(),InputBegan=signal(),DescendantAdded=signal(),LocalTransparencyModifier=0}
    local obj={_children={}}
    propertiesOf[obj]=properties
    return setmetatable(obj,{
        __index=function(t,k) if methods[k] then return methods[k] end; if properties[k]~=nil then return properties[k] end; return methods.FindFirstChild(t,k) end,
        __newindex=function(t,k,v)
            if k=="Color" or k=="BackgroundColor3" or k=="TextColor3" then assert(type(v)=="table" and v.Color3,"invalid Color3 on "..kind.."."..k) end
            if k=="Parent" then
                if properties.Parent then properties.Parent._children[t]=nil end
                if v then
                    v._children[t]=true
                    local ancestor=v
                    while ancestor do
                        if ancestor.DescendantAdded then ancestor.DescendantAdded:Fire(t) end
                        ancestor=ancestor.Parent
                    end
                end
            end
            properties[k]=v
        end,
    })
end}
local function folder(parent,name) local f=Instance.new("Folder");f.Name,f.Parent=name,parent;return f end
workspace=folder(nil,"Workspace")
local replicated=folder(nil,"ReplicatedStorage")
local shared=folder(replicated,"DropzoneShared")
for _,name in ipairs({"VisualTheme","Rules","Config","Weapons","WeaponStats"}) do
    local key=folder(shared,name);modules[key]=nil
end
local playerGui=folder(nil,"PlayerGui")
local player={WaitForChild=function() return playerGui end}
local tweens={Create=function(_,_,_,_) return {Play=function() end,Cancel=function() end} end}
game={ReplicatedStorage={DropzoneShared={VisualTheme="VisualTheme",Rules="Rules",Config="Config",Weapons="Weapons",WeaponStats="WeaponStats",PresentationConfig="PresentationConfig"}},GetService=function(_,name)
    return ({Players={LocalPlayer=player},TweenService=tweens,ReplicatedStorage=replicated,ServerStorage=folder(nil,"ServerStorage"),RunService={PreSimulation=signal()}})[name]
end}
script={Parent={PlayerEvolutionVisuals="PlayerEvolutionVisuals",Cosmetics="Cosmetics",MapVisuals="MapVisuals",Movement="Movement",Town="Town"}}
local Theme=load("VisualTheme","shared/VisualTheme.lua")
load("Config","shared/Config.lua");load("Rules","shared/Rules.lua");load("Weapons","shared/Weapons.lua");load("WeaponStats","shared/WeaponStats.lua")
load("PresentationConfig","shared/PresentationConfig.lua")
for _,key in ipairs(shared:GetChildren()) do modules[key]=modules[key.Name] end
local Cosmetics=load("Cosmetics","server/Cosmetics.lua")
local MapVisuals=load("MapVisuals","server/MapVisuals.lua")
load("Town","server/Town.lua")
script.Parent.CrouchPose = "CrouchPose"
load("CrouchPose","server/CrouchPose.lua")
load("Movement","server/Movement.lua")
local evolutionDelayed={}
task={delay=function(_,callback) evolutionDelayed[#evolutionDelayed+1]=callback end}
local PlayerEvolutionVisuals=load("PlayerEvolutionVisuals","server/PlayerEvolutionVisuals.lua")
local Actors=load("Actors","server/Actors.lua")
local World=load("World","server/World.lua")
-- Eliminated bodies remain visible but leave weapon/LOS query space immediately.
local corpse=folder(workspace,"Corpse")
local corpsePart=Instance.new("Part");corpsePart.CanCollide,corpsePart.CanQuery,corpsePart.CanTouch=true,true,true;corpsePart.Anchored=false;corpsePart.Parent=corpse
local actorService=Actors.new()
local deadActor={alive=true,model=corpse,root=corpsePart,humanoid={Health=100},startTime=os.clock(),reloading=false,reloadToken=0}
actorService.list={deadActor}
actorService:eliminate(deadActor)
check(corpsePart.Anchored and corpsePart.CanCollide==false and corpsePart.CanQuery==false and corpsePart.CanTouch==false,
    "eliminated body stays stable without blocking movement, weapon rays, LOS, or touch queries")

-- Ground projection must use only explicitly designated walkable surfaces.
RaycastParams={new=function() return {} end}
local groundA,groundB=Instance.new("Part"),Instance.new("Part")
local capturedGroundFilter
workspace.Raycast=function(_,_,_,params) capturedGroundFilter=params.FilterDescendantsInstances;return nil end
World.ground({map=folder(workspace,"MapForGround"),groundSurfaces={groundA,groundB}},Vector3.new(4,3,2))
check(capturedGroundFilter and #capturedGroundFilter==2 and capturedGroundFilter[1]==groundA and capturedGroundFilter[2]==groundB,
    "ground projection excludes roofs, containers, trees, and cover")

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
load("MobileLayout","client/MobileLayout.lua")
script.Parent.MobileLayout="MobileLayout"
local Hud=load("Hud","client/Hud.lua")
local hud=Hud.new(true)
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
check(rightEdge < hud.mobileWidth-248,"draft stays left of existing right controls")
for _,card in ipairs(hud.draftCards) do
    check(card.Position.Y.Offset+card.Size.Y.Offset<=hud.draft.Size.Y.Offset,"card remains within bounded touch region")
end
hud:button("Sprint", "", 0,0,1,1)
hud:button("Crouch", "", 0,0,1,1)
me.rarity="Epic";me.sprinting=true;me.slideCooldown=0
hud:update(s)
check(hud.ammo.Text:find("Epic",1,true) and hud.ammo.TextColor3==Theme.Purple,"equipped rarity is labeled and colored")
check(hud.buttons.Sprint.Text=="走行中" and hud.buttons.Crouch.Text=="スライド","posture button follows server sprint state")
s.me.alive=false;hud:update(s);check(not hud.draft.Visible,"death closes decorated draft")
check(not hud.buttons.Sprint.Visible and not hud.buttons.Crouch.Visible,"death hides movement controls")
s.phase="Results";s.winner="Drone";s.me.rank=1;hud:update(s);check(hud.result.Visible and hud.result.RichText,"result renders with hierarchy")
s.roundId=2;s.me=nil;s.phase="Intermission";hud:update(s)
check(not hud.draft.Visible and hud.hpBar.Size.X.Scale==0 and hud.energyBar.Size.X.Scale==0,"new round clears visuals/bars")
s.phase="Active";s.me=me;me.alive=true
for _,name in ipairs({"Fire","Aim","Reload","Build","Wall","Floor","Ramp","Place","Combat","Slot1"}) do hud:button(name,"",0,0,1,1) end
check(hud.buttons.Fire.BackgroundColor3==Theme.Orange and hud.buttons.Fire.BackgroundTransparency==.25,"mobile FIRE has orange emphasis")
check(hud.buttons.Aim.BackgroundTransparency==.62 and hud.buttons.Build.BackgroundTransparency==.62,"auxiliary controls reveal more of the world")
check(hud.mini.Size.X.Offset==104 and hud.mini.Size.Y.Offset==66,"mobile minimap is reduced")
hud:update(s)
hud:setMobileMode("Build")
check(not hud.buttons.Fire.Visible and not hud.buttons.Fire.Active and hud.buttons.Place.Visible and hud.buttons.Place.Active,"real HUD hides/disables Fire and exposes PLACE immediately")
check(hud.energy.Visible and not hud.ammo.Visible,"build shows energy instead of ammo")
hud:setMobileMode("Combat")
check(hud.buttons.Fire.Visible and not hud.buttons.Place.Visible and hud.ammo.Visible and not hud.energy.Visible,"real HUD restores Combat without waiting for snapshot")
check(hud.gui.ScreenInsets==Enum.ScreenInsets.CoreUISafeInsets,"mobile uses core UI/device safe area")
for _,size in ipairs({{640,320},{844,350},{932,390},{1024,768},{390,760}}) do
    hud.gui.AbsoluteSize=Vector2.new(size[1],size[2]);hud.gui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
    local r=modules.MobileLayout.buttons(hud.mobileWidth,hud.mobileHeight).Fire
    check(hud.buttons.Fire.Position.X.Offset==r[1] and hud.buttons.Fire.Size.X.Offset==r[3],"real HUD recomputes button coordinates after resize")
    check(hud.crosshair.Position.X.Scale==.5 and hud.crosshair.Position.Y.Scale==.5,"adaptive reticle remains centered")
end
local old=hud.gui;Hud.new();check(old.Parent==nil,"HUD reconstruction does not duplicate UI")
print("PASS: "..assertions.." visual constructor / cleanup assertions; map cosmetics="..mapCount)

-- Fixed damage pool never allocates per hit, including repeated shotgun bursts.
local DamageFeedback=load("DamageFeedback","client/DamageFeedback.lua")
local fxRoot=folder(workspace,"Feedback")
local feedback=DamageFeedback.new(fxRoot)
local before=#fxRoot:GetDescendants()
local damage={{position=Vector3.new(0,0,0),hp=12,shield=5}}
for i=1,100 do feedback:show(damage,10) end
check(#feedback.slots==8 and #fxRoot:GetDescendants()==before,"damage feedback stays at eight reusable slots")
check(feedback.slots[feedback.cursor].hp.Text=="HP −12" and feedback.slots[feedback.cursor].shield.Text=="◇ −5",
    "HP and Shield loss have distinct labels")
feedback:step(11)
local visible=0;for _,slot in ipairs(feedback.slots) do if slot.gui.Enabled then visible=visible+1 end end
check(visible==0,"damage numbers expire without timer callbacks")
feedback:show(damage,12);feedback:clear();feedback:step(12.1)
check(not feedback.slots[1].gui.Enabled and feedback.cursor==0,"round change clears feedback immediately")
for _,slot in ipairs(feedback.slots) do
    check(not slot.anchor.CanCollide and not slot.anchor.CanTouch and not slot.anchor.CanQuery,"feedback anchors never enter physics/rays")
end

-- Execute actual Loot spawn/claim/cleanup with deterministic rarity.
script.Parent.World="World";script.Parent.Evolution="Evolution"
modules.Evolution={maxEnergy=function() return 150 end,total=function() return 0 end}
local Loot=load("Loot","server/Loot.lua")
local lootWorld={dynamic=folder(workspace,"LootRound"),groundSurfaces={},loot={},spawns={}}
local rewards=0
local loot=Loot.new(lootWorld,{give=function(_,a,kind,rarity) rewards=rewards+1;a.received=rarity;return true end},{FireClient=function() end})
loot.rng={NextNumber=function() return .97 end}
loot:spawn(Vector3.new(0,0,0),"Rifle")
local pickup,entry=next(loot.items);pickup.Position=Vector3.new(0,0,0)
check(entry.rarity=="Epic" and pickup.RarityFootprint.CanQuery==false,"server-generated rarity has a harmless glow footprint")
local looter={alive=true,inventory={},root={Position=Vector3.new(30,0,0)},humanoid={Health=100,MaxHealth=100},
    diagnostics={},startTime=os.clock()-7}
loot:pickup(looter);check(rewards==0,"loot distance enforced before rarity reward")
looter.root.Position=Vector3.new(0,0,0);loot:pickup(looter);loot:pickup(looter)
check(rewards==1 and looter.received=="Epic" and pickup.Parent==nil,"duplicate pickup cannot award twice; visuals deleted")
check(looter.diagnostics.firstWeaponSeconds and looter.diagnostics.firstWeaponSeconds>=7
    and looter.diagnostics.firstWeaponSeconds<8,"first valid weapon pickup records time without duplicate claims")
loot:spawn(Vector3.new(0,0,0),"Pistol",true)
local starter,startEntry=next(loot.items)
check(startEntry.rarity=="Common","insertion weapons always use common tier")
loot:clear()
check(next(loot.items)==nil and #loot.folder:GetChildren()==0,"loot rarity state and cosmetic roots cleared together")

-- Auto pickup must never delete loot that gives this actor no benefit.
looter.inventory={{kind="Rifle",rarity="Epic",ammo=28,reserve=240}}
loot:spawn(Vector3.new(0,0,0),"Rifle",true)
local uselessWeapon=next(loot.items);uselessWeapon.Position=Vector3.new(0,0,0)
local rewardsBefore=rewards
loot:pickup(looter)
check(loot.items[uselessWeapon]~=nil and uselessWeapon.Parent~=nil and rewards==rewardsBefore,
    "full-ammo higher-tier owner leaves useless lower-tier weapon for another player")
loot:clear()

looter.inventory={{kind="Rifle",rarity="Common",ammo=28,reserve=240}}
loot.rng={NextNumber=function() return .97 end}
loot:spawn(Vector3.new(0,0,0),"Rifle")
local upgrade=next(loot.items);upgrade.Position=Vector3.new(0,0,0)
loot:pickup(looter)
check(loot.items[upgrade]==nil and upgrade.Parent==nil and looter.received=="Epic",
    "higher-tier weapon remains useful even when reserve ammo is already full")
loot:clear()

looter.inventory={{kind="Rifle",rarity="Common",ammo=28,reserve=240}}
loot:spawn(Vector3.new(0,0,0),"Ammo")
local fullAmmo=next(loot.items);fullAmmo.Position=Vector3.new(0,0,0)
loot:pickup(looter)
check(loot.items[fullAmmo]~=nil and fullAmmo.Parent~=nil,
    "full reserves do not consume shared ammo loot")
looter.inventory[1].reserve=200
loot:pickup(looter)
check(loot.items[fullAmmo]==nil and looter.inventory[1].reserve==230,
    "ammo becomes useful again as soon as one weapon has reserve capacity")
loot:clear()

looter.inventory={}
looter.humanoid.Health=50
loot:spawn(Vector3.new(0,0,0),"Health")
local healthPickup=next(loot.items);healthPickup.Position=Vector3.new(0,0,0)
loot:pickup(looter)
check(loot.items[healthPickup]==nil and looter.humanoid.Health==85,
    "unarmed actors can still collect useful health loot")
loot:clear()
print("PASS: "..assertions.." total visual/pickup/pool assertions")

-- Presentation lifecycle uses actual controllers with engine doubles. Rendering and
-- asset permissions remain Studio tests; these assertions cover state/ownership.
for _, name in ipairs({"AudioConfig","AnimationConfig","PresentationConfig"}) do
    game.ReplicatedStorage.DropzoneShared[name]=name
    load(name,"shared/"..name..".lua")
end
script.Parent.Audio,script.Parent.Animations="Audio","Animations"
function methods:FindFirstChildOfClass(kind) for _,child in ipairs(self:GetChildren()) do if child.ClassName==kind then return child end end end
function methods:Play() self.IsPlaying=true end
function methods:Stop() self.IsPlaying=false end
function cf:Inverse() return self end
local Audio=load("Audio","client/Audio.lua")
local Animations=load("Animations","client/Animations.lua")
script.Parent.EvolutionVisibility="EvolutionVisibility"
local EvolutionVisibility=load("EvolutionVisibility","client/EvolutionVisibility.lua")
local Presentation=load("Presentation","client/Presentation.lua")
assert(loadfile(ROOT.."/tests/evolution_visuals.lua"))()(check, PlayerEvolutionVisuals, EvolutionVisibility, workspace, evolutionDelayed)
local audioFolder=folder(workspace,"PresentationTest")
local audio=Audio.new(audioFolder)
-- Empty optional channels still allocate nothing.
local savedFootstep=modules.AudioConfig.Footstep.Id
modules.AudioConfig.Footstep.Id=""
check(audio:play("Footstep")==nil,"empty optional audio is a safe no-op")
check(#audio.voices==0 and #audioFolder:GetChildren()==0,"empty IDs allocate no voices or anchors")
modules.AudioConfig.Footstep.Id=savedFootstep
-- Reviewed configured cues normalize numeric Creator Store IDs.
check(Audio.asset(modules.AudioConfig.RifleFire.Id)=="rbxassetid://9114727096","configured rifle sound normalizes")
check(Audio.asset(modules.AudioConfig.EvolutionApplied.Id)=="rbxassetid://9119902088","configured evolution sound normalizes")
for _,id in ipairs({"", "bogus", "rbxassetid://0", "-20"}) do check(Audio.asset(id)==nil,"invalid ID skipped") end
-- Synthetic ID only in the test double; never shipped as an asset setting.
modules.AudioConfig.Button.Id="123"
modules.AudioConfig.Button.Cooldown=0
local lease=audio:play("Button")
check(lease~=nil and #audio.voices==1,"configured cue creates one pooled voice")
lease:Stop()
local newer=audio:play("Button")
lease:Stop()
check(audio.voices[1].sound.IsPlaying,"old lease cannot stop a newer cue on reused voice")
for _=1,30 do audio:play("Button") end
check(#audio.voices==modules.AudioConfig.MaxVoices,"audio saturation never exceeds fixed pool cap")
audio:clear()
for _,voice in ipairs(audio.voices) do check(not voice.sound.IsPlaying,"round reset stops every voice") end
audio:destroy();check(#audioFolder:GetChildren()==0,"audio destruction removes sounds and anchors")
modules.AudioConfig.Button.Id=""

local character=folder(workspace,"PresentationCharacter")
local humanoid=Instance.new("Humanoid");humanoid.Parent=character
humanoid.Health,humanoid.CameraOffset,humanoid.FloorMaterial,humanoid.RigType=100,Vector3.new(0,0,0),"Grass",Enum.HumanoidRigType.R15
local root=Instance.new("Part");root.Name,root.Parent="HumanoidRootPart",character
root.AssemblyLinearVelocity=Vector3.new(0,0,20)
local hand2=Instance.new("Part");hand2.Parent=character
local held=Cosmetics.weapon(character,"Rifle",CFrame.new(),hand2)
check(held.PresentationJoint.Part0==hand2 and held.PresentationJoint.Part1==held.Receiver,"kick joint only links hand to cosmetic receiver")
folder(character,"Mutation")
local camera=Instance.new("Camera");camera.FieldOfView=73;workspace.CurrentCamera=camera
local presentation=Presentation.new(audioFolder,{Character=character,UserId=1})
local function snap(roundId,values,phase)
    local me={alive=true,weapon="Rifle",rarity="Common",slot=1,evolutions=0}
    for k,v in pairs(values or {}) do me[k]=v end
    return {roundId=roundId,phase=phase or "Active",me=me,zone={shrinking=false}}
end
presentation:snapshot(snap(1,{sprinting=true}))
presentation:step(.1)
check(camera.FieldOfView>73 and camera.FieldOfView<79,"sprint FOV is relative to original camera")
check(#presentation.audio.voices==0 and next(presentation.animations.tracks)==nil,"unconfigured assets preserve code-only feedback")

-- Shoulder aim is presentation-only: PC hold and mobile AIM toggle share one bounded camera state.
presentation:snapshot(snap(1,{}))
presentation:setAimHeld(true)
presentation:undoCamera();presentation:step(.1)
check(presentation:isAiming() and camera.FieldOfView<73 and humanoid.CameraOffset.X>0,
    "PC aim narrows FOV and shifts to a right-shoulder camera")
presentation:snapshot(snap(1,{evolutionDraft={id=1}}))
presentation:undoCamera();presentation:step(.1)
check(presentation.aimActive,"Evolution Draft does not interrupt shoulder aim during ongoing combat")
presentation:snapshot(snap(1,{sprinting=true}))
presentation:undoCamera();presentation:step(.1)
check(not presentation.aimActive,"sprint suppresses shoulder aim even while the input is held")
presentation:snapshot(snap(1,{}))
presentation:setAimHeld(false)
presentation:setAimHeld(true)
presentation:undoCamera();presentation:step(.1)
check(presentation:isAiming(),"mobile AIM toggle enters the shoulder camera without firing")
presentation:setAimHeld(false)
presentation:cancelAim()
check(not presentation.aimHeld and not presentation.combatAimHeld and presentation.combatAimUntil==0,
    "sprint/build/round hard cancel removes pending aim grace")
presentation:snapshot(snap(1,{reloading=true}))
presentation:undoCamera();presentation:step(.1)
check(presentation.tilt>0,"confirmed reload tilts held cosmetic")
presentation:snapshot(snap(1,{reloading=false,rarity="Rare"}))
check(presentation.tilt==0 and presentation.reloadSound==nil,"rarity switch cancels reload presentation")
presentation:snapshot(snap(1,{sliding=true}))
presentation:undoCamera();presentation:step(.1)
check(humanoid.CameraOffset.Y<0,"slide lowers camera without changing character position")
presentation:snapshot(snap(1,{crouching=true}))
presentation:undoCamera();presentation:step(.1)
check(presentation.animations.movementKey=="CrouchWalk","slide transitions to crouch movement track")
presentation:shot(Vector3.new(0,0,0),"Shotgun",1,{})
check(presentation.kick==modules.PresentationConfig.Weapons.Shotgun.Kick and presentation.vertical>0,"confirmed shot drives weapon-specific kick/recoil")
check(#presentation.flashes==8,"muzzle flashes use a fixed pool")
for _,flash in ipairs(presentation.flashes) do check(not flash.part.CanQuery and not flash.part.CanCollide and not flash.part.CanTouch,"flash never enters gameplay queries") end
presentation:snapshot(snap(1,{evolutions=1}))
check(presentation.pulse==nil,"shared server evolution pulse does not duplicate local Highlight")
presentation:snapshot(snap(1,{alive=false}))
check(camera.FieldOfView==73 and humanoid.CameraOffset.Y==0 and presentation.vertical==0,"death restores FOV, offset and recoil")
check(presentation.pulse==nil and presentation.me==nil and next(presentation.animations.tracks)==nil,"death clears pulse, movement state and tracks")
presentation:snapshot(snap(2,{sprinting=true,reloading=true}))
presentation:step(.1)
presentation:snapshot(snap(2,{},"Results"))
check(camera.FieldOfView==73 and presentation.tilt==0 and presentation.reloadSound==nil,"Results clears second-round reload and FOV")
presentation:snapshot(snap(3,{}));check(presentation.roundId==3 and presentation.vertical==0,"third round starts without previous recoil")
local earlyZone=snap(3,{})
earlyZone.zone={phase=2,shrinking=false,remaining=9}
presentation:snapshot(earlyZone)
check(presentation.warnedHoldPhase==2,"zone cue triggers once when hold reaches 10 seconds")
presentation:snapshot(earlyZone)
check(presentation.warnedHoldPhase==2,"repeated 5Hz snapshots do not reset warning phase")
earlyZone.zone={phase=3,shrinking=false,remaining=9}
presentation:snapshot(earlyZone)
check(presentation.warnedHoldPhase==3,"next zone phase can warn again")
presentation:setAimHeld(true)
presentation:step(.1)
local nextCamera=Instance.new("Camera");nextCamera.FieldOfView=81
workspace.CurrentCamera=nextCamera
presentation:undoCamera();presentation:step(.1)
check(camera.FieldOfView==73 and nextCamera.FieldOfView<81,"camera replacement restores the previous FOV and records the new baseline")
presentation:snapshot(snap(3,{alive=false}))
check(nextCamera.FieldOfView==81 and humanoid.CameraOffset.X==0,"death restores the replacement camera and shoulder offset")
-- Zoom lifecycle executes the actual controller. Standard camera collision/orbit
-- remains an engine playtest; this verifies smooth distance and ownership.
presentation:snapshot(snap(4,{}))
local zoomPlayer = presentation.player
zoomPlayer.CameraMinZoomDistance, zoomPlayer.CameraMaxZoomDistance = .5, 30
nextCamera.CFrame, nextCamera.Focus = CFrame.new(0,0,12), CFrame.new()
presentation:prepareCamera(1/60)
check(presentation.zoomState==nil and zoomPlayer.CameraMaxZoomDistance==30,"hip camera never owns zoom")
presentation:setAimHeld(true)
presentation:prepareCamera(1/60)
check(zoomPlayer.CameraMaxZoomDistance<12 and zoomPlayer.CameraMaxZoomDistance>4.2,"AIM approaches close distance without snapping")
for _=1,90 do presentation:prepareCamera(1/60) end
check(math.abs(zoomPlayer.CameraMaxZoomDistance-4.2)<.001,"rifle settles at upper-body distance")
check(zoomPlayer.CameraMinZoomDistance==zoomPlayer.CameraMaxZoomDistance,"AIM prevents scroll or pinch from pulling camera away")
for _,kind in ipairs({"Shotgun","Pistol","Rifle"}) do
    presentation:snapshot(snap(4,{weapon=kind}))
    for _=1,90 do presentation:prepareCamera(1/60) end
    check(math.abs(zoomPlayer.CameraMaxZoomDistance-modules.PresentationConfig.Weapons[kind].AimDistance)<.001,"weapon switch adjusts close distance")
    check(presentation.zoomState.distance==12,"weapon switch preserves original normal distance")
end
presentation:cancelAim()
presentation:prepareCamera(1/60)
check(zoomPlayer.CameraMaxZoomDistance>4.2 and zoomPlayer.CameraMaxZoomDistance<12,"AIM exit eases back")
presentation:setAimHeld(true);presentation:prepareCamera(1/60)
check(presentation.zoomState.distance==12,"rapid retoggle keeps original normal distance")
presentation:cancelAim()
for _=1,90 do presentation:prepareCamera(1/60) end
check(presentation.zoomState==nil and zoomPlayer.CameraMinZoomDistance==.5 and zoomPlayer.CameraMaxZoomDistance==30,"exit restores original zoom bounds")
for _,ending in ipairs({"sprint","slide","death","results","respawn","destroy"}) do
    presentation:snapshot(snap(5,{}));presentation:setAimHeld(true);presentation:prepareCamera(.1)
    if ending=="sprint" or ending=="slide" then
        presentation:snapshot(snap(5,{sprinting=ending=="sprint",sliding=ending=="slide"}))
        for _=1,90 do presentation:prepareCamera(1/60) end
    elseif ending=="death" then presentation:snapshot(snap(5,{alive=false}))
    elseif ending=="results" then presentation:snapshot(snap(5,{},"Results"))
    elseif ending=="respawn" then presentation:snapshot(snap(6,{}))
    else presentation:clear() end
    check(presentation.zoomState==nil and zoomPlayer.CameraMinZoomDistance==.5 and zoomPlayer.CameraMaxZoomDistance==30,ending.." restores zoom ownership")
end
-- Numeric world/local rotations catch wrong multiplication order and pitch/yaw.
local oldCFrame, oldJoint, oldHumanoid = CFrame, presentation.joint, presentation.humanoid
CFrame=assert(loadfile(ROOT.."/tests/aim_math.lua"))()(Vector3)
local numericFrame=getmetatable(CFrame.new())
function numericFrame:ToObjectSpace(other) return self:Inverse()*other end
function numericFrame:Lerp(other,t)
    assert(t==0 or t==1,"orientation test only claims settled endpoints")
    return t==1 and other or self
end
presentation.humanoid={RigType=Enum.HumanoidRigType.R15}
for _,offset in ipairs({Vector3.new(.48,1.28,-1.42),Vector3.new(.48,1.22,-1.4),Vector3.new(.58,1.2,-1.25)}) do
    for _,target in ipairs({Vector3.new(10,12,-25),Vector3.new(-12,-6,8),Vector3.new(2,2,-4)}) do
        local parent=CFrame.new(2,0,1)*CFrame.Angles(0,.7,0)
        presentation.joint={Parent=true,Part0={CFrame=parent},C0=CFrame.new(offset.X,offset.Y,offset.Z)}
        local start=(parent*presentation.joint.C0).Position
        presentation.aimBlend=1
        presentation:updateWeaponAim(target)
        local world=parent*presentation.joint.C0
        check((world.LookVector-(target-start).Unit).Magnitude<1e-6,"each weapon converges toward target through pitched/yawed local transform")
        check((world.Position-start).Magnitude<1e-6,"aim orientation preserves grip position")
        local aimed=presentation.joint.C0
        presentation.aimBlend=0;presentation:updateWeaponAim(Vector3.new(50,0,0))
        check(presentation.joint.C0==aimed,"normal stance is untouched by target alignment")
        presentation.aimBlend=1;presentation.me={reloading=true}
        presentation:updateWeaponAim(Vector3.new(50,0,0))
        check(presentation.joint.C0==aimed,"reload tilt is not overwritten by aim alignment")
        presentation.me=nil
    end
end
CFrame,presentation.joint,presentation.humanoid=oldCFrame,oldJoint,oldHumanoid
presentation:destroy();check(#audioFolder:GetChildren()==0,"presentation destroy releases all pooled instances")

-- Track caching, rig selection and failed-load suppression with a fake Animator.
local loads=0
local animator=Instance.new("Animator");animator.Parent=humanoid
animator.LoadAnimation=function(_,animation)
    loads=loads+1
    check(animation.AnimationId=="rbxassetid://123","selected R15 ID is normalized")
    return Instance.new("AnimationTrack")
end
modules.AnimationConfig.RifleFire.R15="123"
local tracks=Animations.new();tracks:bind(humanoid)
for _=1,20 do tracks:play("RifleFire") end
check(loads==1,"repeated fire reuses one loaded track")
local loaded=tracks.tracks.RifleFire
tracks:clear();check(loaded._destroyed and next(tracks.tracks)==nil,"character cleanup destroys cached tracks")
tracks:bind(humanoid);animator.LoadAnimation=function() loads=loads+1;error("unavailable test asset") end
tracks:play("RifleFire");tracks:play("RifleFire")
check(loads==2 and tracks.failed.RifleFire,"failed asset is not loaded repeatedly")
modules.AnimationConfig.RifleFire.R15=""
print("PASS: "..assertions.." total visual/audio/animation/presentation assertions")

-- Ammo and equipment use the actual HUD update, preserving rarity and mobile rectangles.
local equipHud=Hud.new()
for i=1,3 do equipHud:button("Slot"..i,"",279+(i-1)*116,418,110,48) end
local uiMe={alive=true,hp=100,maxHp=100,shield=0,energy=60,maxEnergy=100,kills=0,evolutions=0,
    weapon="Rifle",rarity="Epic",ammo=23,reserve=198,slots={"Rifle","Pistol"},slotRarities={"Epic","Common"},slot=1}
local uiState={roundId=90,phase="Active",alive=12,remaining=300,me=uiMe,zone={phase=1,radius=250,nextRadius=140,remaining=30,center=Vector3.new(0,0,0),nextCenter=Vector3.new(0,0,0)}}
equipHud:update(uiState)
check(equipHud.ammo.Text:find("23 / 28",1,true) and equipHud.ammo.Text:find("予備 198",1,true),"Rifle displays current / capacity and separate reserve")
check(equipHud.evo.Visible and equipHud.evo.Text:find("MISSION 2/3",1,true),
    "first combat snapshot uses the dormant label to guide a new player toward a kill")
check(equipHud.hint.Text:find("1 / 2 / 3",1,true),"first guide teaches weapon switch")
check(equipHud.buttons.Slot1.Text:find("▶",1,true) and equipHud.buttons.Slot1.UIStroke.Thickness==3,"selected slot has arrow and thick outline")
check(equipHud.buttons.Slot3.Text:find("空",1,true) and not equipHud.buttons.Slot3.Active,"empty slot visibly differs and is inactive")
local newer={};for k,v in pairs(uiMe) do newer[k]=v end
newer.reserve=220;uiState.me=newer;equipHud:update(uiState)
check(equipHud.ammo.Text:find("23 / 28",1,true) and equipHud.ammo.Text:find("予備 220 (+22)",1,true),"ammo pickup emphasizes only the reserve increase")
for _,kind in ipairs({"Pistol","Shotgun"}) do
    newer.weapon=kind;newer.ammo=2;newer.reserve=24;equipHud:update(uiState)
    check(equipHud.ammo.Text:find("2 / "..modules.Weapons[kind].magazine,1,true),"capacity follows equipped weapon")
end
-- Contextual onboarding consumes the existing snapshot; no new remotes or GUI
-- instances. The guide is not reset to beginner mode after first Evolution.
newer.weapon=nil;newer.kills=0;newer.evolutions=0;newer.evolutionDraft=nil
equipHud:update(uiState)
check(equipHud.evo.Visible and equipHud.evo.Text:find("MISSION 1/3",1,true),"no weapon prompts pickup")
newer.weapon="Rifle";equipHud:update(uiState)
check(equipHud.evo.Text:find("MISSION 2/3",1,true),"weapon acquisition advances to eliminate")
newer.kills=1;newer.evolutionDraft={id=1,seconds=5,options=cards};equipHud:update(uiState)
check(equipHud.evo.Text:find("MISSION 3/3",1,true),"server-offered Evolution prompt advances the guide")
newer.evolutions=1;newer.evolutionDraft=nil;equipHud:update(uiState)
check(equipHud.onboardingComplete and equipHud.evo.Text:find("MISSION COMPLETE",1,true),
    "first Evolution completes guide once per client session")
uiState.roundId=91;equipHud:update(uiState)
check(not equipHud.evo.Visible,"subsequent rounds do not repeat completed tutorial")
equipHud:setSpectateName("Drone<&>")
check(equipHud.evo.Visible and equipHud.evo.Text:find("&lt;&amp;&gt;",1,true),
    "spectator label escapes arbitrary RichText names")
-- Real vector math for the effect geometry; engine drawing still needs Studio.
vec.__index=function(v,k)
    if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
    if k=="Unit" then return v/v.Magnitude end
    return vec[k]
end
vec.__div=function(a,b) return Vector3.new(a.X/b,a.Y/b,a.Z/b) end
local function cross(a,b) return Vector3.new(a.Y*b.Z-a.Z*b.Y,a.Z*b.X-a.X*b.Z,a.X*b.Y-a.Y*b.X) end
CFrame.lookAt=function(position,target,up)
    local direction=(target-position).Unit
    local right=cross(direction,up or Vector3.new(0,1,0)).Unit
    local top=cross(right,direction)
    return {Position=position,LookVector=direction,PointToWorldSpace=function(_,v) return position+right*v.X+top*v.Y-direction*v.Z end}
end
local Effects=load("Effects","client/Effects.lua")
local fx=Effects.new()
local budget=#fx.folder:GetDescendants()
check(budget==96+24*2+16*5,"fixed effects budget: 96 zone parts plus 128 shooting parts")
local origin,endpoint=Vector3.new(2,4,0),Vector3.new(2,4,-40)
local endpoints={endpoint,endpoint,endpoint,endpoint,endpoint,endpoint,endpoint}
fx:shot(origin,endpoints,"Shotgun",true,{{position=endpoint,normal=Vector3.new(0,0,1)}},10)
local shown=0;for _,slot in ipairs(fx.tracers) do if slot.expires>0 then shown=shown+1 end end
check(shown==3,"shotgun draws only three representative pellet paths")
check(fx.tracers[1].trail.CFrame.Position.Z==-20 and fx.tracers[1].trail.Size.Z==40,"tracer centered and long axis oriented between endpoints")
check(fx.tracers[1].trail.CFrame.LookVector.Z==-1 and fx.tracers[1].origin==origin,"trace begins at supplied display muzzle")
local savedRaycast=workspace.Raycast
workspace.Raycast=function(_,muzzle,path) return {Position=muzzle+path*.2} end
local blockedMuzzle=Vector3.new(5,4,0)
fx:shot(blockedMuzzle,{endpoint},"Rifle",true,{},10.05,origin)
check(fx.tracers[4].origin==origin,"blocked cosmetic muzzle uses server ray origin")
workspace.Raycast=savedRaycast
check(fx.tracers[1].streak.Size.Z<=40,"moving streak cannot overshoot short shots")
check(fx.impacts[1].parts[1].CFrame.Position.Z>endpoint.Z,"wall flash offset is outside surface")
fx:step(10.1)
check(fx.tracers[1].streak.Transparency<1 and fx.impacts[1].parts[1].Transparency<.01,"feedback remains readable after first 100ms")
for i=1,500 do fx:shot(origin,endpoints,"Shotgun",false,{{position=endpoint,normal=Vector3.new(0,1,0)}},10.1) end
check(#fx.folder:GetDescendants()==budget,"sustained bot fire allocates no additional instances")
check(fx.tracers[1].started==10 and fx.impacts[1].started==10,"remote fire cannot evict local feedback")
for _,p in ipairs(fx.folder:GetDescendants()) do
    check(p.CanCollide==false and p.CanTouch==false and p.CanQuery==false,"all effects excluded from physics/touch/raycast")
end
fx:clear()
for _,slot in ipairs(fx.tracers) do check(slot.trail.Transparency==1 and slot.streak.Transparency==1 and slot.expires==0,"round clears tracers") end
for _,slot in ipairs(fx.impacts) do for _,p in ipairs(slot.parts) do check(p.Transparency==1,"round clears impact parts") end end
fx:shot(origin,{origin},"Pistol",true,{},11)
check(fx.tracers[1].expires==0,"zero-length trace safely skips lookAt")
fx:shot(origin,{origin+Vector3.new(0,0,-.1)},"Pistol",true,{},11)
check(fx.tracers[1].streak.Size.Z<=.10001,"near-wall trace is clamped to its endpoint")
fx:step(12)
check(fx.tracers[1].expires==0 and fx.tracers[1].streak.Transparency==1,"expired trace hidden")
fx:destroy();check(fx.folder.Parent==nil,"effect teardown removes fixed pool")
print("PASS: "..assertions.." total visual assertions including bounded shot effects and ammo HUD")


-- Desktop HUD behavior and viewport geometry, using the real Hud constructor.
local desktop=Hud.new(false)
for _,name in ipairs({"Fire","Aim","Build","Reload","Sprint","Crouch","Wall","Floor","Ramp","Slot1","Slot2","Slot3","Spectate"}) do desktop:button(name,"",0,0,80,40) end
s.roundId=10;s.phase="Active";s.me=me;me.alive=true;me.evolutionDraft={id=10,seconds=5,options=cards}
desktop:update(s,function() return true end)
check(not desktop.draft.Visible and desktop.ready.Visible,"PC draft begins as a small ready notification")
desktop:toggleDraft();check(desktop.draft.Visible,"ready click opens draft")
desktop:update(s);check(desktop.draft.Visible,"same draft snapshot preserves expansion")
me.evolutionDraft={id=11,seconds=5,options=cards};desktop:update(s)
check(not desktop.draft.Visible,"queued new draft starts collapsed")
check(desktop.evo.Visible and desktop.evo.Text:find("MISSION 3/3",1,true) and not desktop.energy.Visible,
    "desktop first-match mission is compact and build energy stays hidden at rest")
for _,name in ipairs({"Fire","Aim","Build","Reload","Sprint","Crouch","Wall","Floor","Ramp"}) do check(not desktop.buttons[name].Visible,"PC hides touch control "..name) end
check(desktop.buttons.Slot1.Visible and desktop.ammo.Visible,"PC retains usable slots and ammunition")
for _,command in ipairs({"Equip","Sprint","Posture","Build"}) do desktop:learn(command) end
desktop:update(s);check(not desktop.hint.Visible and desktop.energy.Visible,"used tutorials disappear; building exposes contextual energy")
for _,viewport in ipairs({{900,480},{1280,720},{1920,1080},{2560,1080},{640,360}}) do
    desktop.gui.AbsoluteSize=Vector2.new(viewport[1],viewport[2]);desktop.gui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
    local factor=desktop.canvas:FindFirstChild("UIScale").Scale
    local width,height=desktop.canvas.Size.X.Offset,desktop.canvas.Size.Y.Offset
    check(factor<=1 and math.abs(width*factor-viewport[1])<.001 and math.abs(height*factor-viewport[2])<.001,"desktop fits viewport without upscaling")
    local function rect(obj)
        local x=obj.Position.X.Scale*width+obj.Position.X.Offset-obj.AnchorPoint.X*obj.Size.X.Offset
        local y=obj.Position.Y.Scale*height+obj.Position.Y.Offset-obj.AnchorPoint.Y*obj.Size.Y.Offset
        return x,y,obj.Size.X.Offset,obj.Size.Y.Offset
    end
    for _,obj in ipairs({desktop.stats,desktop.ammo,desktop.ready,desktop.draft,desktop.mini,desktop.buttons.Slot1,desktop.buttons.Slot3}) do
        local x,y,w,h=rect(obj);check(x>=0 and y>=0 and x+w<=width and y+h<=height,"anchored HUD stays within viewport: "..obj.Name)
    end
    local x,y,w,h=rect(desktop.crosshair)
    check(x+w/2==width/2 and y+h/2==height/2,"reticle stays centered after resize")
end
me.alive=false;desktop:update(s)
check(not desktop.ready.Visible and not desktop.draft.Visible and desktop.buttons.Spectate.Visible,"spectator hides draft and exposes target switching")
check(desktop.result.AnchorPoint.X==0 and desktop.result.AnchorPoint.Y==1,"spectator result is anchored away from center")
print("PASS: "..assertions.." visual assertions including desktop HUD states and five viewport sizes")

