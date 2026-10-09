-- Tests the actual mobile AIM tracking module with deterministic engine doubles.
-- Roblox's camera ownership, occlusion and touch gestures still require Studio.
local count = 0
local function check(ok, label) assert(ok, label); count = count + 1 end
local v = {}
v.__index = function(t,k)
    if k == "Magnitude" then return math.sqrt(t.X*t.X+t.Y*t.Y+t.Z*t.Z) end
    if k == "Unit" then return t/t.Magnitude end
    return v[k]
end
Vector3 = {new=function(x,y,z) return setmetatable({X=x,Y=y,Z=z},v) end}
function v:Dot(other) return self.X*other.X+self.Y*other.Y+self.Z*other.Z end
v.__add = function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
v.__sub = function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
v.__mul = function(a,b) return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
v.__div = function(a,b) return Vector3.new(a.X/b,a.Y/b,a.Z/b) end
CFrame = {lookAt=function(position, target) return {Position=position,LookVector=(target-position).Unit} end}
Enum = {RaycastFilterType={Exclude="Exclude"},CameraType={Custom="Custom",Scriptable="Scriptable"}}
RaycastParams = {new=function() return {} end}
math.clamp = function(x,a,b) return math.min(b,math.max(a,x)) end
local assist = assert(loadfile(ROOT.."/src/client/MobileAimTracking.lua"))()
local spec = assert(loadfile(ROOT.."/src/shared/PresentationConfig.lua"))()
local helper = assist.new(spec)
local char, effects = {}, {}
local ray = {Origin=Vector3.new(0,1.4,10),Direction=Vector3.new(0,0,-1)}
local origin = Vector3.new(0,1.4,0)
local camera = {CameraType="Custom", CFrame=CFrame.lookAt(ray.Origin,ray.Origin+ray.Direction),
    Focus={Position=Vector3.new(0,1.4,0)}}
local part = {Position=Vector3.new(4,.6,-65)}
local model = {FindFirstChild=function(_,name) return name=="HumanoidRootPart" and part or nil end}
local targets = {{id=101,model=model}}
local block
local queries = 0
workspace = {Raycast=function(_,start,delta,params)
    queries = queries + 1
    check(params.RespectCanCollide == false, "query-only imported wall participates in LOS")
    check(params.FilterDescendantsInstances[1]==char and params.FilterDescendantsInstances[2]==effects,
        "own avatar and effects excluded from LOS")
    if block then return {Instance={IsDescendantOf=function() return false end}} end
end}
local picked = helper:scan(ray,origin,targets,char,effects,0,false)
check(picked and picked.X==4 and helper.lockedId==101, "visible enemy acquired close to reticle")
check(queries==2, "camera and server muzzle both require LOS")
local initial = camera.CFrame.LookVector
check(helper:track(camera,ray,picked,.016,0), "camera gently tracks close enemy")
check(camera.CFrame.LookVector.X>initial.X and camera.CFrame.LookVector.X<.02,
    "tracking is gradual with a capped per-frame turn, not snap aim")
local before=queries
picked=helper:scan(ray,origin,targets,char,effects,.03,false)
check(picked and queries==before, "reuses cached target between bounded LOS scans")
part.Position=Vector3.new(9,.6,-65)
picked=helper:scan(ray,origin,targets,char,effects,.1,false)
check(picked and picked.X==9 and helper.lockedId==101,
    "moving locked enemy retained outside the narrower acquisition cone")
helper:manualLook(.15)
local pausedCamera=camera.CFrame
check(not helper:track(camera,ray,picked,.016,.25) and camera.CFrame==pausedCamera,
    "manual view gesture overrides camera tracking")
check(helper:track(camera,ray,picked,.016,.5), "camera tracking resumes after manual pause")
block=true
check(helper:scan(ray,origin,targets,char,effects,.6,true)==nil and helper.lockedId==nil,
    "occluded opponent immediately loses lock even within tracking cone")
block=false
part.Position=Vector3.new(80,.6,-65)
check(helper:scan(ray,origin,targets,char,effects,.7,true)==nil,"wide-angle enemy cannot be auto-acquired")
part.Position=Vector3.new(0,.6,2)
check(helper:scan(ray,origin,targets,char,effects,.8,true)==nil,"enemy behind shooting origin cannot be selected")
part.Position=Vector3.new(0,.6,-155)
check(helper:scan(ray,origin,targets,char,effects,.9,true)==nil,"target outside range cannot be acquired")
helper:clear()
check(helper.lockedId==nil and helper.lockedPart==nil and helper.nextScan==0,"round/mode exit removes lock")
camera.CameraType="Scriptable"
check(not helper:track(camera,ray,Vector3.new(1,1.4,-30),.016,1),
    "scripted camera never modified")
print("PASS: "..count.." mobile aim tracking assertions (engine doubles, Studio pending)")
