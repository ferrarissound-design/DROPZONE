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
Color3={fromRGB=function(...) return {...} end}
Enum=setmetatable({RenderPriority={Camera={Value=100}}},{__index=function(t,k)
    local values=setmetatable({},{__index=function(_,v) return v end});rawset(t,k,values);return values
end})
RaycastParams={new=function() return {} end}
local requests={}
local action={FireServer=function(_,...) requests[#requests+1]={...} end}
local snapshot,effectEvent=signal(),signal()
local remotes={WaitForChild=function(_,name) return ({Action=action,Snapshot={OnClientEvent=snapshot},Effects={OnClientEvent=effectEvent}})[name] end}
local input={InputBegan=signal(),InputEnded=signal(),WindowFocusReleased=signal(),JumpRequest=signal(),GetFocusedTextBox=function() return nil end,TouchEnabled=false}
local run={RenderStepped=signal(),BindToRenderStep=function() end,UnbindFromRenderStep=function() end}
local root={Position=Vector3.new(0,0,0)}
local humanoid={}
local character={FindFirstChild=function() return root end,FindFirstChildOfClass=function() return humanoid end}
local player={UserId=7,Character=character}
local theme={Orange={},Ink={},Blue={},Gold={},Cyan={},Paper={}}
local hud={buttons={},draft={Visible=false},crosshair={AbsolutePosition=Vector2.new(435,225),AbsoluteSize=Vector2.new(30,30)},hitMarker={},notice={}}
function hud:button(name,_,x,y,w,h,callback)
    local b={Activated=signal(),InputBegan=signal()}
    if callback then b.Activated:Connect(callback) end
    self.buttons[name]=b
    return b
end
function hud:update() end
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
function presentation:cancelAim() self.aimHeld=false end
function presentation:setAimHeld(value) self.aimHeld=value end
function presentation:setCombatAim() end
function presentation:isAiming() return self.aimHeld end
local weapons=assert(loadfile(ROOT.."/src/shared/Weapons.lua"))()
local modules={Weapons=weapons,VisualTheme=theme,Hud={new=function() return hud end},Effects={new=function() return effects end},DamageFeedback={new=function() return numbers end},Presentation={new=function() return presentation end}}
require=function(name) return assert(modules[name],name) end
local shared={WaitForChild=function(_,name) return name end}
local replicated={WaitForChild=function(_,name) return name=="DropzoneShared" and shared or remotes end}
game={GetService=function(_,name) return ({Players={LocalPlayer=player},UserInputService=input,RunService=run,ReplicatedStorage=replicated})[name] end}
script={Parent={Hud="Hud",Effects="Effects",DamageFeedback="DamageFeedback",Presentation="Presentation"},Destroying=signal()}
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
