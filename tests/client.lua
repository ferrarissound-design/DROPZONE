-- Execute the actual client entry point with event doubles. No Roblox rendering claims.
local count = 0
local function check(ok, message) assert(ok, message); count=count+1 end
local function signal()
    local s={callbacks={}}
    function s:Connect(fn) table.insert(self.callbacks,fn); return {Disconnect=function() end} end
    function s:emit(...) for _,fn in ipairs(self.callbacks) do fn(...) end end
    return s
end
local now=10
os.clock=function() return now end
local vec={}
vec.__index=function(v,k)
    if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
    if k=="Unit" then return v/v.Magnitude end
    return vec[k]
end
Vector3={new=function(x,y,z) return setmetatable({X=x,Y=y,Z=z},vec) end}
Vector2={new=function(x,y) return Vector3.new(x,y,0) end}
vec.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vec.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vec.__mul=function(a,b) return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
vec.__div=function(a,b) return Vector3.new(a.X/b,a.Y/b,a.Z/b) end
function vec:Dot(b) return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
Color3={fromRGB=function(...) return {...} end}
Enum=setmetatable({RenderPriority={Camera={Value=100}}},{__index=function(t,k)
    local values=setmetatable({},{__index=function(_,v) return v end});rawset(t,k,values);return values
end})
RaycastParams={new=function() return {} end}
local requests={}
local action={FireServer=function(_,...) requests[#requests+1]={...} end}
local snapshot,effectEvent=signal(),signal()
local remotes={WaitForChild=function(_,name) return ({Action=action,Snapshot={OnClientEvent=snapshot},Effects={OnClientEvent=effectEvent}})[name] end}
local input={InputChanged=signal(),InputBegan=signal(),InputEnded=signal(),WindowFocusReleased=signal(),JumpRequest=signal(),GetFocusedTextBox=function() return nil end,TouchEnabled=false}
local bindings={}
local run={RenderStepped=signal(),BindToRenderStep=function(_,name,priority,fn) bindings[name]={priority=priority,fn=fn} end,UnbindFromRenderStep=function(_,name) bindings[name]=nil end}
local renderEmit = run.RenderStepped.emit
function run.RenderStepped:emit()
    if bindings.DropzonePresentationBefore then bindings.DropzonePresentationBefore.fn() end
    if bindings.DropzonePresentationAfter then bindings.DropzonePresentationAfter.fn(.016) end
    renderEmit(self)
end
local root={Position=Vector3.new(0,0,0)}
local humanoid={}
local character={FindFirstChild=function() return root end,FindFirstChildOfClass=function() return humanoid end}
local player={UserId=7,Character=character,CharacterRemoving=signal(),CharacterAdded=signal()}
local theme={Orange={},Ink={},Blue={},Gold={},Cyan={},Paper={}}
local hud={buttons={},draft={Visible=false},crosshair={AbsolutePosition=Vector2.new(435,225),AbsoluteSize=Vector2.new(30,30)},hitMarker={},notice={}}
function hud:button(name,_,x,y,w,h,callback)
    local b={Activated=signal(),InputBegan=signal()}
    if callback then b.Activated:Connect(callback) end
    self.buttons[name]=b
    return b
end
function hud:setMobileMode(mode) self.mobileMode=mode end
function hud:update() end
function hud:learn() end
function hud:step() end
function hud:toggleDraft() self.draft.Visible = not self.draft.Visible end
function hud:toast() end
function hud:eliminated() self.kills=(self.kills or 0)+1 end
local effects={folder={},shots={},hits={},clears=0}
function effects:shot(...) self.shots[#self.shots+1]={...} end
function effects:impact(...) self.hits[#self.hits+1]={...} end
function effects:clear() self.clears=self.clears+1;self.shots={};self.hits={} end
function effects:zone() end
function effects:step() end
function effects:destroy() end
local numbers={calls=0,clear=function() end,step=function() end}
function numbers:show(records) if #records>0 then self.calls=self.calls+1 end end
local muzzle=Vector3.new(2,3,-2)
local presentation={audio={play=function() end},snapshot=function() end,step=function() end,undoCamera=function() end,destroy=function() end,damage=function() end}
function presentation:shot() return muzzle end
function presentation:cancelAim() self.aimHeld=false; self.combatAimHeld=false end
function presentation:setAimHeld(value) self.aimHeld=value end
function presentation:setCombatAim(value) self.combatAimHeld=value end
function presentation:isAiming() return self.aimHeld end
local weapons=assert(loadfile(ROOT.."/src/shared/Weapons.lua"))()
local modules={Weapons=weapons,VisualTheme=theme,Hud={new=function() return hud end},Effects={new=function() return effects end},DamageFeedback={new=function() return numbers end},Presentation={new=function() return presentation end}}
CFrame=assert(loadfile(ROOT.."/tests/aim_math.lua"))()(Vector3)
math.clamp=function(x,a,b) return math.max(a,math.min(b,x)) end
math.atan2=function(y,x) return math.atan(y,x) end
modules.FireDrag=assert(loadfile(ROOT.."/src/client/FireDrag.lua"))()
modules.PresentationConfig=assert(loadfile(ROOT.."/src/shared/PresentationConfig.lua"))()
require=function(name) return assert(modules[name],name) end
local shared={WaitForChild=function(_,name) return name end}
local replicated={WaitForChild=function(_,name) return name=="DropzoneShared" and shared or remotes end}
game={GetService=function(_,name) return ({Players={LocalPlayer=player},UserInputService=input,RunService=run,ReplicatedStorage=replicated})[name] end}
script={Parent={Hud="Hud",Effects="Effects",DamageFeedback="DamageFeedback",Presentation="Presentation",FireDrag="FireDrag"},Destroying=signal()}
local aimFilter
workspace={CurrentCamera={CFrame={},ScreenPointToRay=function() return {Origin=Vector3.new(0,5,10),Direction=Vector3.new(0,0,-1)} end},Raycast=function(_,_,_,params) aimFilter=params.FilterDescendantsInstances end}
assert(loadfile(ROOT.."/src/client/Main.client.lua"))()
local state={roundId=5,phase="Active",me={alive=true,weapon="Rifle",ammo=28,reloading=false},zone={},targets={}}
snapshot:emit(state)
local mouse={UserInputType="MouseButton1",Position=Vector2.new(450,240)}
input.InputBegan:emit(mouse,false)
input.InputEnded:emit(mouse)
check(#requests==1 and requests[1][1]==5 and requests[1][2]=="Fire","quick PC click fires once even before a render frame")
run.RenderStepped:emit()
check(#requests==1,"release plus render cannot duplicate the click")
check(aimFilter[1]==character and aimFilter[2]==effects.folder,"client aim excludes character and local effects folder")
now=11;input.InputBegan:emit(mouse,false)
local start=#requests
run.RenderStepped:emit();check(#requests==start,"press plus same-frame update cannot double fire")
now=11.13;run.RenderStepped:emit();check(#requests==start,"held fire respects Rifle interval")
now=11.14;run.RenderStepped:emit();check(#requests==start+1,"held fire at Rifle interval sends next shot")
now=11.14+weapons.Rifle.interval;run.RenderStepped:emit();check(#requests==start+2,"held fire continues at configured cadence")
input.InputEnded:emit(mouse)
for i,key in ipairs({"One","Two","Three"}) do
    input.InputBegan:emit({KeyCode=key},false)
    check(requests[#requests][2]=="Equip" and requests[#requests][3]==i,"number key equips matching slot")
    hud.buttons["Slot"..i].Activated:emit()
    check(requests[#requests][2]=="Equip" and requests[#requests][3]==i,"slot Activated routes mouse/touch to Equip")
end
run.RenderStepped:emit();check(input.MouseBehavior=="Default","PC cursor reaches slots when not holding aim")
input.InputBegan:emit({UserInputType="MouseButton2",Position=mouse.Position},false)
run.RenderStepped:emit();check(input.MouseBehavior=="LockCenter","right mouse retains shoulder aim lock")
input.InputEnded:emit({UserInputType="MouseButton2"})
local endpoint=Vector3.new(0,3,-20)
effectEvent:emit("Shot",root.Position,{endpoint},"Rifle",7,4,{})
check(#effects.shots==0,"old round Shot never reaches visual effects")
effectEvent:emit("Shot",root.Position,{endpoint},"Rifle",7,5,{{position=endpoint,normal=Vector3.new(0,0,1)}})
check(#effects.shots==1 and effects.shots[1][1]==muzzle and effects.shots[1][2][1]==endpoint,"Shot uses muzzle display origin and unchanged server endpoint")
check(#effects.shots[1][5]==1 and not hud.hitMarker.Visible and numbers.calls==0,"world hit retains payload but never confirms enemy damage")
local damage={{position=endpoint,normal=Vector3.new(0,0,1),hp=0,shield=12}}
effectEvent:emit("Damage",4,damage);check(numbers.calls==0,"stale damage rejected")
effectEvent:emit("Damage",5,{})
check(not hud.hitMarker.Visible,"empty confirmation cannot show a hit marker")
effectEvent:emit("Damage",5,damage)
check(hud.hitMarker.Visible and hud.hitMarker.TextColor3==theme.Cyan and numbers.calls==1 and #effects.hits==1,"confirmed shield damage shows marker, number and spark together")
damage[1].hp,damage[1].shield,damage[1].eliminated=20,0,true
effectEvent:emit("Damage",5,damage)
check(hud.hitMarker.TextColor3==theme.Gold and hud.hitMarker.TextSize==52 and hud.kills==1,"lethal confirmation differs from ordinary hit")
state.phase="Results";snapshot:emit(state)
check(not hud.hitMarker.Visible and #effects.shots==0 and #effects.hits==0,"Results clears transient feedback")
effectEvent:emit("Shot",root.Position,{endpoint},"Rifle",7,5,{})
check(#effects.shots==0,"Results refuses otherwise matching Shot")
state={roundId=6,phase="Active",me=state.me,zone=state.zone,targets={}};snapshot:emit(state)
check(hud.hitMarkerUntil==0 and effects.clears>=3,"new round clears timers and pools")
print("PASS: "..count.." actual client input/event/lifecycle assertions")

-- Expanded draft consumes only pointer clicks inside its rectangle.
hud.draft.Visible=true;hud.draft.AbsolutePosition=Vector2.new(16,100);hud.draft.AbsoluteSize=Vector2.new(600,177)
local before=#requests
input.InputBegan:emit({UserInputType="MouseButton1",Position=Vector2.new(100,150)},false)
check(#requests==before,"draft card click does not fire background weapon")
input.InputBegan:emit({KeyCode="R"},false)
check(requests[#requests][2]=="Reload","keyboard gameplay remains available with draft open")
input.InputBegan:emit({UserInputType="MouseButton2",Position=Vector2.new(800,300)},false)
run.RenderStepped:emit();check(input.MouseBehavior=="Default","expanded draft leaves pointer available")
hud.draft.Visible=false;run.RenderStepped:emit()
check(input.MouseBehavior=="LockCenter","collapsed ready notification does not prevent aiming")
input.InputEnded:emit({UserInputType="MouseButton2"})
local subjects={{},{}}
state.me.alive=false;state.targets={}
for i=1,2 do state.targets[i]={model={FindFirstChildOfClass=function() return subjects[i] end}} end
snapshot:emit(state);local first=workspace.CurrentCamera.CameraSubject
input.InputBegan:emit({KeyCode="Tab"},true);snapshot:emit(state)
check(workspace.CurrentCamera.CameraSubject~=first,"processed Tab still cycles spectator subject after death")
state.me.alive=true;state.targets={};snapshot:emit(state)
print("PASS: "..count.." client assertions including draft pointer boundaries and spectator Tab")

-- Feed real client Fire payloads into real Combat.fire. Intersections depend on
-- the actual ray, so a wrong sign, rotation, camera, origin or endpoint fails.
CFrame=assert(loadfile(ROOT.."/tests/aim_math.lua"))()(Vector3)
Vector3.zero=Vector3.new(0,0,0)
typeof=function(v) return getmetatable(v)==vec and "Vector3" or type(v) end
Random={new=function() return {NextNumber=function(_,a,b) return (a+b)/2 end} end}
game.ReplicatedStorage={DropzoneShared={Weapons="Weapons",VisualTheme="VisualTheme",WeaponStats="WeaponStats",Rules="Rules"}}
script.Parent.Evolution,script.Parent.Cosmetics="Evolution","Cosmetics"
modules.Rules=assert(loadfile(ROOT.."/src/shared/Rules.lua"))()
modules.WeaponStats=assert(loadfile(ROOT.."/src/shared/WeaponStats.lua"))()
modules.Evolution={total=function() return 0 end};modules.Cosmetics={}
local shooter={root=root,model=character,humanoid={Health=100},player={Parent=true},id=7,roundId=6,alive=true,slot=1,nextShot=0}
character.Parent=true
local clientGetService=game.GetService
local combatPlayers={GetPlayers=function() return {shooter.player} end}
game.GetService=function(self,name)
    if name=="Players" then return combatPlayers end
    return clientGetService(self,name)
end
local Combat=assert(loadfile(ROOT.."/src/server/Combat.lua"))()
root.Parent=true
local victim={alive=true,health=100,shield=0}
local enemyPart,wallPart={},{}
local actors={byPlayer={[shooter.player]=shooter},fromPart=function(_,p) return p==enemyPart and victim end}
function actors:damage(v,amount)
    local h,s=v.health,v.shield
    v.health,v.shield=modules.Rules.resolveDamage(h,s,amount,false)
    return h-v.health,s-v.shield
end
local events={}
local combat=Combat.new(actors,{FireClient=function(_,_,kind,...) events[#events+1]={kind=kind,args={...}} end})
local camera=workspace.CurrentCamera
local width,height,inset=1280,720,36
function camera:ScreenPointToRay(x,y)
    local focal=height/(2*math.tan(math.rad(70)/2))
    return {Origin=self.CFrame.Position,Direction=self.CFrame:VectorToWorldSpace(Vector3.new((x-width/2)/focal,-(y+inset-height/2)/focal,-1).Unit)}
end
local function near(a,b) return (a-b).Magnitude<1e-6 end
local function clientFire()
    now=now+1
    local before=#requests
    input.InputBegan:emit(mouse,false);input.InputEnded:emit(mouse)
    check(#requests==before+1 and requests[#requests][2]=="Fire","client emits exactly one aim payload")
    return requests[#requests][3]
end
local function prepare(kind)
    local spec=weapons[kind or "Rifle"]
    shooter.inventory={{kind=kind or "Rifle",rarity="Common",ammo=spec.magazine,reserve=100}}
    shooter.ammo,shooter.nextShot=spec.magazine,0
    victim.health,victim.shield,victim.alive=100,0,true
    events={}
end
local function findEvent(kind)
    for _,e in ipairs(events) do if e.kind==kind then return e.args end end
end
local serverRay,serverOrigin,target,wall,behindWall,phase
local function sphere(origin,direction,center,radius,part)
    local d=direction.Unit
    local delta=origin-center
    local b=delta:Dot(d)
    local disc=b*b-delta:Dot(delta)+radius*radius
    if disc<0 then return end
    local t=-b-math.sqrt(disc)
    if t<0 or t>direction.Magnitude then return end
    local position=origin+d*t
    return {Instance=part,Position=position,Normal=(position-center).Unit,Distance=t}
end
workspace.Raycast=function(_,origin,direction,params)
    if phase=="server" then
        serverOrigin,serverRay=origin,direction
        check(params.FilterDescendantsInstances[1]==character,"server excludes shooter")
    end
    local best=sphere(origin,direction,target,1,enemyPart)
    for _,center in ipairs({wall or false,behindWall or false}) do
        if center then
            local hit=sphere(origin,direction,center,.5,wallPart)
            if hit and (not best or hit.Distance<best.Distance) then best=hit end
        end
    end
    return best
end
for i,forward in ipairs({Vector3.new(0,0,-1),Vector3.new(1,0,0),Vector3.new(0,0,1),Vector3.new(-1,0,0),Vector3.new(.2,.9,-.3).Unit,Vector3.new(.2,-.9,-.3).Unit}) do
    root.Position=Vector3.new(1200+i*10,30,-2100)
    local firingOrigin=root.Position+Vector3.new(0,1.4,0)
    camera.CFrame=CFrame.lookAt(firingOrigin-forward*12+Vector3.new(2,3,0),firingOrigin+forward*60)
    width,height,inset=i%2==0 and 1920 or 900,i%2==0 and 1080 or 480,i%2==0 and 58 or 36
    hud.crosshair.AbsoluteSize=Vector2.new(30,30)
    hud.crosshair.AbsolutePosition=Vector2.new(width/2-15,(height-inset)/2-15)
    -- Independent screen->local ray expectation, including topbar inset.
    local slope=-(inset/height)*math.tan(math.rad(70)/2)
    local displayedRay=camera.CFrame:VectorToWorldSpace(Vector3.new(0,slope,-1).Unit)
    target=camera.CFrame.Position+displayedRay*65
    for _,recoil in ipairs({0,6}) do
        presentation.camera=camera
        presentation.applied=CFrame.Angles(math.rad(recoil),math.rad(recoil/2),0)
        local displayed=camera.CFrame
        wall,behindWall=nil,nil
        phase="client";local direction=clientFire()
        check(camera.CFrame==displayed,"aim does not temporarily mutate the rendered camera")
        prepare();phase="server";combat:fire(shooter,direction)
        check(near(serverOrigin,firingOrigin),"server origin agrees with client root offset")
        check(serverRay.Unit:Dot(direction)>1-1e-9,"zero spread preserves client direction through lookAt and Angles")
        check(victim.health==84 and findEvent("Damage"),"crosshair target receives server damage across headings and recoil")
        local shot=findEvent("Shot")
        check(near(shot[2][1],serverOrigin+serverRay.Unit*(shot[2][1]-serverOrigin).Magnitude),"tracer endpoint lies on authoritative server ray")
        effectEvent:emit("Shot",table.unpack(shot))
        check(effects.shots[#effects.shots][1]==muzzle and effects.shots[#effects.shots][2]==shot[2],"muzzle changes only display start, never confirmed endpoints")
    end
end

-- A camera-visible obstacle behind the root used to turn the shot backwards.
root.Position=Vector3.new(0,0,0)
camera.CFrame=CFrame.lookAt(Vector3.new(0,1.4,10),Vector3.new(0,1.4,-50))
width,height,inset=900,480,0
hud.crosshair.AbsolutePosition=Vector2.new(435,225)
presentation.applied=nil
target=Vector3.new(0,1.4,-50);behindWall=Vector3.new(0,1.4,5);wall=nil
phase="client";local direction=clientFire()
prepare();phase="server";combat:fire(shooter,direction)
check(direction.Z<0 and victim.health==84,"camera-to-root obstacle cannot reverse the shot or prevent a forward hit")

-- Touch assist must not reselect an actor in that excluded rear segment.
behindWall=nil
input.TouchEnabled=true
state.targets={{model={FindFirstChild=function() return {Position=Vector3.new(0,.6,5)} end}}}
phase="client";direction=clientFire()
check(direction.Z<0,"touch assistance cannot turn a forward shot toward an actor behind the root")
input.TouchEnabled=false;state.targets={}

-- Camera can see around cover; root ray still cannot shoot through it.
behindWall=nil
camera.CFrame=CFrame.lookAt(Vector3.new(6,4,10),target)
phase="client";direction=clientFire()
wall=(root.Position+Vector3.new(0,1.4,0))+direction*5
prepare();phase="server";combat:fire(shooter,direction)
check(victim.health==100 and not findEvent("Damage"),"server cover blocks damage even when camera acquired the enemy")
check(#findEvent("Shot")[6]==1,"cover endpoint yields a world impact")

-- Exercise nonzero spread and all seven pellets, checking cone and range.
wall=nil;target=Vector3.new(9999,9999,9999)
for _,kind in ipairs({"Pistol","Rifle","Shotgun"}) do
    for _,sign in ipairs({-1,1}) do
        prepare(kind)
        combat.rng.NextNumber=function(_,a,b) return sign<0 and a or b end
        combat:fire(shooter,Vector3.new(.7,.2,-.4).Unit)
        local shot=findEvent("Shot");local spec=weapons[kind]
        check(#shot[2]==spec.pellets,"server preserves pellet count")
        for _,endpoint in ipairs(shot[2]) do
            local delta=endpoint-shot[1]
            check(math.abs(delta.Magnitude-spec.range)<1e-6,"spread keeps server range")
            check(delta.Unit:Dot(Vector3.new(.7,.2,-.4).Unit)>=math.cos(math.rad(spec.spread))^2-1e-6,"spread stays in forward cone, never reverses")
        end
        check(not findEvent("Damage"),"range-only rays never confirm damage")
    end
end
prepare();phase="server"
local invalid={Vector3.zero,Vector3.new(0/0,0,0),Vector3.new(math.huge,0,0),Vector3.new(2,0,0),"forged"}
for _,value in ipairs(invalid) do combat:fire(shooter,value) end
check(shooter.ammo==28 and #events==0,"invalid aim payloads consume no ammo and cause no damage")
print("PASS: "..count.." client/server assertions including numeric aim, recoil, cover, spread and tracer provenance")


-- Execute the actual Fire GUI handlers + FireDrag math, with ordered render
-- callbacks. These doubles cannot prove Roblox's touch sinking or occlusion.
input.TouchEnabled=true
state={roundId=9,phase="Active",me={alive=true,weapon="Rifle",ammo=28,reloading=false},zone={},targets={}}
snapshot:emit(state)
width,height,inset=900,480,0
root.Position=Vector3.zero
hud.crosshair.AbsolutePosition=Vector2.new(435,225)
camera.CameraType="Custom"
camera.Focus=CFrame.new(0,1.4,0)
camera.CFrame=CFrame.lookAt(Vector3.new(0,1.4,10),camera.Focus.Position)
workspace.Raycast=function() return nil end
local function touch(x,y) return {UserInputType="Touch",UserInputState="Begin",Position=Vector3.new(x,y,0)} end
local function move(t,x,y)
    t.Position=Vector3.new(x,y,0);t.UserInputState="Change"
    input.InputChanged:emit(t,true)
end
local function begin(t)
    now=now+1;hud.buttons.Fire.InputBegan:emit(t)
end
local function frame()
    now=now+weapons.Rifle.interval;run.RenderStepped:emit()
end
local t=touch(820,220)
local n=#requests
hud.buttons.Aim.Activated:emit()
check(presentation.aimHeld and #requests==n,"AIM toggle enters shoulder aim without a Fire request")
hud.buttons.Aim.Activated:emit()
check(not presentation.aimHeld and #requests==n,"second AIM toggle exits without a Fire request")
hud.buttons.Aim.Activated:emit()
check(presentation.aimHeld and hud.buttons.Aim.Text=="AIM\nON","active AIM toggle exposes its state")
begin(t)
check(#requests==n+1 and requests[#requests][2]=="Fire" and presentation.aimHeld and not presentation.combatAimHeld,"Fire touch shoots without changing independent AIM state")
check(hud.buttons.Fire.Active,"Fire GUI explicitly sinks its touch for standard CameraInput")
local second=touch(820,220)
hud.buttons.Fire.InputBegan:emit(second)
move(second,500,500);input.InputEnded:emit(second)
local original=camera.CFrame
frame()
check(camera.CFrame==original and #requests==n+2,"second touch cannot move camera, steal ownership or end firing")
move(t,920,170)
frame()
local look=camera.CFrame.LookVector
check(look.X>0 and look.Y>0,"right/up drag rotates camera right/up even outside Fire button")
check(math.abs(math.asin(look.Y)-math.rad(9))<1e-6,"vertical sensitivity is degrees per pixel")
check(math.abs((camera.CFrame.Position-camera.Focus.Position).Magnitude-10)<1e-6,"orbit preserves focus distance")
check(#requests==n+3 and requests[#requests][3]:Dot(look)>.999,"drag continues Rifle firing using the new camera ray")
local displayed=camera.CFrame
frame();check(camera.CFrame==displayed,"input displacement is consumed once, with no idle drift")
move(t,920,10000);frame()
check(math.abs(camera.CFrame.LookVector.Y+math.sin(math.rad(80)))<1e-6,"extreme downward drag clamps pitch")
move(t,920,9990);frame()
check(camera.CFrame.LookVector.Y>-math.sin(math.rad(80)),"pitch clamp releases immediately on reverse drag")
move(t,950,9990);input.InputEnded:emit(t)
n=#requests;displayed=camera.CFrame;frame()
check(#requests==n and camera.CFrame==displayed and presentation.aimHeld and not presentation.combatAimHeld,"release ends firing and preserves independent AIM")
move(t,1000,9990);frame();check(camera.CFrame==displayed,"released finger cannot revive drag")
local screen=touch(500,200);input.InputBegan:emit(screen,false);move(screen,600,300);frame()
check(#requests==n and camera.CFrame==displayed,"ordinary screen touch is left entirely to standard camera")
for _,name in ipairs({"Reload","Sprint","Crouch","Build","Slot1"}) do
    local other=touch(100,100)
    hud.buttons[name].InputBegan:emit(other);move(other,200,200);frame()
    check(#requests==n and camera.CFrame==displayed,name.." touch never starts FireDrag")
end
hud.draft.Visible=true;hud.draft.AbsolutePosition=Vector2.new(100,100);hud.draft.AbsoluteSize=Vector2.new(200,150)
local draftTouch=touch(150,150)
hud.buttons.Fire.InputBegan:emit(draftTouch);move(draftTouch,500,500);frame()
check(#requests==n and camera.CFrame==displayed,"Draft-origin touch cannot pass through to Fire even if GUI event is delivered")
t=touch(820,220);begin(t);move(t,800,210);frame()
check(presentation.aimHeld and not presentation.combatAimHeld and #requests==n+2,"open Draft does not interrupt a distinct Fire-origin touch")
input.InputEnded:emit(t);hud.draft.Visible=false
for _,event in ipairs({"focus","cancel","cancelWithoutMove","respawn","round","death","results"}) do
    state.me.alive=true;state.phase="Active";snapshot:emit(state)
    t=touch(820,220);begin(t);move(t,850,220)
    if event=="focus" then input.WindowFocusReleased:emit()
    elseif event=="cancel" then t.UserInputState="Cancel";input.InputChanged:emit(t,true)
    elseif event=="cancelWithoutMove" then t.UserInputState="Cancel";bindings.DropzonePresentationBefore.fn()
    elseif event=="respawn" then player.CharacterRemoving:emit(character);player.CharacterAdded:emit(character)
    elseif event=="round" then state={roundId=state.roundId+1,phase="Active",me=state.me,zone={},targets={}};snapshot:emit(state)
    elseif event=="death" then state.me.alive=false;snapshot:emit(state)
    else state.phase="Results";snapshot:emit(state) end
    n=#requests;displayed=camera.CFrame;move(t,900,200);frame()
    check(#requests==n and camera.CFrame==displayed and not presentation.combatAimHeld,event.." clears held shooting and pending drag")
    state.me.alive=true;state.phase="Active";snapshot:emit(state)
    local fresh=touch(820,220);begin(fresh);move(fresh,830,220);frame()
    check(#requests==n+2 and camera.CFrame~=displayed,event.." permits a fresh touch without stale ownership")
    input.InputEnded:emit(fresh)
end

-- Verify render bracketing with real numeric recoil transforms (Presentation
-- lifecycle/recovery remains covered by the existing visuals suite).
camera.CFrame=CFrame.lookAt(Vector3.new(0,1.4,10),camera.Focus.Position)
local recoil=CFrame.Angles(math.rad(3),math.rad(2),0)
camera.CFrame=camera.CFrame*recoil
presentation.applied=recoil
local oldUndo,oldStep=presentation.undoCamera,presentation.step
function presentation:undoCamera()
    if self.applied then camera.CFrame=camera.CFrame*self.applied:Inverse();self.applied=nil end
end
function presentation:step() self.applied=recoil;camera.CFrame=camera.CFrame*recoil end
t=touch(820,220);begin(t);move(t,920,220);frame()
local expected=CFrame.lookAt(camera.Focus.Position-Vector3.new(math.sin(math.rad(18)),0,-math.cos(math.rad(18)))*10,
    camera.Focus.Position)*recoil
check(near(camera.CFrame.LookVector,expected.LookVector),"old recoil is undone before drag; recoil is applied once afterwards")
displayed=camera.CFrame;frame()
check(near(camera.CFrame.LookVector,displayed.LookVector),"repeated frames do not accumulate recoil into drag")
input.InputEnded:emit(t);presentation:undoCamera()
presentation.undoCamera,presentation.step=oldUndo,oldStep
check(bindings.DropzonePresentationBefore.priority<100 and bindings.DropzonePresentationAfter.priority>100,"drag and recoil bracket standard camera priority")

-- Existing aim assistance follows the rotated ray; visible candidates within the
-- cone are assisted, occluded/out-of-cone/out-of-range candidates are not.
camera.CFrame=CFrame.lookAt(Vector3.new(0,1.4,10),camera.Focus.Position)
t=touch(820,220);begin(t);move(t,920,220);frame()
input.InputEnded:emit(t)
local ray=camera:ScreenPointToRay(450,240)
local assisted=ray.Origin+ray.Direction*80+camera.CFrame.RightVector*3
local model={FindFirstChild=function() return {Position=assisted-Vector3.new(0,.8,0)} end}
state.targets={{model=model}}
local block={IsDescendantOf=function() return false end}
workspace.Raycast=function() return nil end
local assistedDirection=clientFire()
check(near(assistedDirection,(assisted-root.Position-Vector3.new(0,1.4,0)).Unit),"existing 5-degree Aim Assist works with dragged camera")
workspace.Raycast=function(_,origin,delta)
    -- Aim trace length 300; candidate LOS length approximately 80.
    if delta.Magnitude<180 then return {Instance=block,Position=origin+delta*.5} end
end
local blockedDirection=clientFire()
check(not near(blockedDirection,assistedDirection) and near(blockedDirection,ray.Direction),"wall occludes Aim Assist after FireDrag")
workspace.Raycast=function() return nil end
for _,position in ipairs({ray.Origin+ray.Direction*80+camera.CFrame.RightVector*20,ray.Origin+ray.Direction*200+camera.CFrame.RightVector*3}) do
    model.FindFirstChild=function() return {Position=position-Vector3.new(0,.8,0)} end
    check(near(clientFire(),ray.Direction),"existing assist cone and max distance remain enforced")
end
state.targets={};input.TouchEnabled=false
camera.CameraType="Scriptable";t=touch(820,220);begin(t);move(t,920,220)
displayed=camera.CFrame;frame();check(camera.CFrame==displayed,"FireDrag does not rotate a Scriptable camera")
input.InputEnded:emit(t)
camera.CameraType="Custom"
script.Destroying:emit()
check(next(bindings)==nil and not presentation.combatAimHeld,"script cleanup unbinds both camera callbacks and clears Fire touch")
-- Execute mode changes through actual button callbacks, including held Fire.
input.TouchEnabled=true
state.me.alive=true;state.phase="Active";snapshot:emit(state)
hud.buttons.Aim.Activated:emit()
t=touch(820,220);begin(t)
n=#requests
hud.buttons.Build.Activated:emit()
check(hud.mobileMode=="Build" and not presentation.aimHeld and #requests==n,"BUILD changes mode, cancels aim, and never places or fires")
move(t,850,210);frame()
check(#requests==n,"entering build cancels held Fire and pending drag")
hud.buttons.Aim.Activated:emit();begin(touch(820,220));frame()
check(#requests==n and not presentation.aimHeld,"hidden/stale combat events cannot aim or shoot in Build")
for _,kind in ipairs({"Wall","Floor","Ramp"}) do
    hud.buttons[kind].Activated:emit()
    check(#requests==n,"part selection sends no Fire or Build")
    hud.buttons.Place.Activated:emit()
    check(requests[#requests][2]=="Build" and requests[#requests][3]==kind,"PLACE sends selected kind through existing server action")
    n=#requests
end
hud.buttons.Combat.Activated:emit()
check(hud.mobileMode=="Combat" and #requests==n,"COMBAT restores controls without firing")
hud.buttons.Place.Activated:emit()
check(#requests==n,"stale PLACE event ignored in Combat")
t=touch(820,220);begin(t);input.InputEnded:emit(t)
check(requests[#requests][2]=="Fire","fresh Fire works after Combat return")
hud.buttons.Build.Activated:emit();hud.buttons.Slot2.Activated:emit()
check(hud.mobileMode=="Combat" and requests[#requests][2]=="Equip" and requests[#requests][3]==2,"weapon slot returns to combat and equips")
for _,event in ipairs({"death","results","round","respawn","focus"}) do
    hud.buttons.Build.Activated:emit()
    if event=="death" then state.me.alive=false;snapshot:emit(state)
    elseif event=="results" then state.phase="Results";snapshot:emit(state)
    elseif event=="round" then state={roundId=state.roundId+1,phase="Active",me=state.me,zone={},targets={}};snapshot:emit(state)
    elseif event=="respawn" then player.CharacterRemoving:emit(character)
    else input.WindowFocusReleased:emit() end
    check(hud.mobileMode=="Combat",event.." resets Build mode")
    state.me.alive=true;state.phase="Active";snapshot:emit(state)
end
input.TouchEnabled=false
n=#requests
input.InputBegan:emit({KeyCode="X"},false);input.InputBegan:emit({KeyCode="Q"},false)
check(#requests==n+1 and requests[#requests][2]=="Build" and requests[#requests][3]=="Floor","PC X/Q retains direct selection and placement")
print("PASS: "..count.." client/server assertions including FireDrag ownership, camera math, lifecycle, UI and Aim Assist")
