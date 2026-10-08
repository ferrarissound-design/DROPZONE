-- Execute the real World resolver and Round:start with narrow engine doubles.
-- This checks wiring/lifecycle; Studio remains the authority for real physics.
local assertions = 0
local function check(ok, message) assert(ok, message); assertions = assertions + 1 end
local vec = {}
vec.__index = function(v, key)
    if key == "Magnitude" then return math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z) end
    return vec[key]
end
Vector3 = {new=function(x,y,z) return setmetatable({X=x,Y=y,Z=z},vec) end}
vec.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vec.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vec.__mul=function(a,b) return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
vec.__div=function(a,b) return Vector3.new(a.X/b,a.Y/b,a.Z/b) end
Vector3.zero = Vector3.new(0,0,0)
CFrame = {new=function(position) return {Position=position} end}
Enum = {RaycastFilterType={Include="Include"}}
OverlapParams = {new=function() return {} end}
RaycastParams = {new=function() return {} end}
warn = function() end
local modules = {VisualTheme={}, MapVisuals={}, Town={}, Evolution={}, Movement={}}
require = function(name) return assert(modules[name], "unloaded "..tostring(name)) end
local roster = {}
local players = {GetPlayers=function() return roster end}
game = {ReplicatedStorage={DropzoneShared={Config="Config", Rules="Rules", VisualTheme="VisualTheme"}},
    GetService=function(_,name) if name=="Players" then return players end end}
script = {Parent={World="World",Actors="Actors",Evolution="Evolution",Movement="Movement",MapVisuals="MapVisuals",Town="Town"}}
local function load(name,path) modules[name]=assert(loadfile(ROOT.."/src/"..path))(); return modules[name] end
local Config = load("Config","shared/Config.lua")
load("Rules","shared/Rules.lua")
local World = load("World","server/World.lua")
local realResolve = World.resolveSpawn

local buildings, blocked, supported, overlaps, groundPart = {}, nil, nil, nil, {}
workspace = {
    Raycast=function(_,origin,_,params)
        check(params.FilterDescendantsInstances[1]==groundPart, "only designated ground is raycast")
        if supported and not supported(origin) then return nil end
        return {Position=Vector3.new(origin.X,0,origin.Z)}
    end,
    GetPartBoundsInBox=function(_,cf,_,params)
        check(params.MaxParts==0 and params.RespectCanCollide, "colliders are not truncated or hidden by CanQuery")
        if overlaps then return overlaps end
        return blocked and blocked(cf.Position) and {{CanCollide=true}} or {}
    end,
}
local function world(spawns)
    return {map={FindFirstChild=function(_,name)
        if name=="Buildings" then return {GetChildren=function() return buildings end} end
    end}, groundSurfaces={groundPart}, spawns=spawns or {}, dynamic={},
        lobby=CFrame.new(Vector3.new(0,104,360))}
end
local function building(x,z,sx,sz,angle)
    return {IsA=function(_,kind) return kind=="Model" end, GetBoundingBox=function()
        return {PointToObjectSpace=function(_,p)
            local dx,dz=p.X-x,p.Z-z
            return Vector3.new(dx*math.cos(angle)+dz*math.sin(angle),p.Y,-dx*math.sin(angle)+dz*math.cos(angle))
        end}, Vector3.new(sx,34,sz)
    end}
end
local function clear() buildings,blocked,supported,overlaps={ },nil,nil,nil end
local w=world()
local preferred=Vector3.new(245,4,0)
local position=World.resolveSpawn(w,preferred,{})
check(position.X==245 and position.Y==4 and position.Z==0, "clear preferred spawn and height are preserved")
buildings={building(245,0,50,50,math.pi/4)}
check(not World.spawnClear(w,Vector3.new(245,0,0)), "hollow rotated TownTemplate footprint is rejected")
position=World.resolveSpawn(w,preferred,{})
check(position and World.spawnClear(w,position-Vector3.new(0,4,0)), "blocked template resolves outside footprint")
buildings={building(130,-130,50,34,0)}
check(not World.spawnClear(w,Vector3.new(130,0,-130)), "Warehouse footprint is rejected")
clear(); overlaps={}
for i=1,40 do overlaps[i]={CanCollide=false} end
overlaps[41]={CanCollide=true}
check(not World.spawnClear(w,Vector3.zero), "collider beyond 32 decorations is still rejected")
clear(); blocked=function(p) return (p-Vector3.new(245,4,0)).Magnitude < 10 end
position=World.resolveSpawn(w,preferred,{})
check(position and not blocked(position), "Collision Part at preferred position is avoided")
clear(); position=World.resolveSpawn(w,preferred,{preferred})
check(position and (position-preferred).Magnitude>=28, "occupied preferred position retains 28-stud separation")
clear(); blocked=function(p) return not (p.X==80 and p.Z==80) end
position=World.resolveSpawn(w,preferred,{})
check(position and position.X==80 and position.Z==80, "interior grid recovers when rim and roads are blocked")
clear(); supported=function() return false end
check(World.resolveSpawn(w,preferred,{})==nil, "missing ground is not silently replaced with Y=0")
clear(); blocked=function() return true end
check(World.resolveSpawn(w,preferred,{})==nil, "fully blocked arena never returns original point")
clear()

-- Cooperative scheduler: exercise async avatar loads, timeouts and late callbacks.
local now, jobs = 0, {}
os.clock=function() return now end
local function resume(job)
    local ok, delay=coroutine.resume(job.thread)
    assert(ok,delay)
    if coroutine.status(job.thread)~="dead" then job.at=now+(delay or 0); jobs[#jobs+1]=job end
end
local function advance(dt)
    local target=now+dt
    while true do
        local chosen
        for i,job in ipairs(jobs) do
            if job.at<=target and (not chosen or job.at<jobs[chosen].at) then chosen=i end
        end
        if not chosen then break end
        local job=table.remove(jobs,chosen);now=job.at;resume(job)
    end
    now=target
end
task = {spawn=function(callback) resume({thread=coroutine.create(callback)}) end,
    wait=function(dt)
        if coroutine.isyieldable() then return coroutine.yield(dt) end
        advance(dt)
    end}
local pivots, resolveCalls, registered = {}, {}, {}
local function model()
    local m={Parent=true,root={Position=Vector3.zero},humanoid={}}
    function m:PivotTo(cf) self.root.Position=cf.Position; pivots[#pivots+1]={model=self,position=cf.Position} end
    function m:FindFirstChild(name) if name=="HumanoidRootPart" then return self.root end end
    function m:Destroy() self.Parent=nil end
    return m
end
modules.Actors={botModel=function() return model() end}
local Round=load("Round","server/Round.lua")
local function setup(humans, spawns, delays)
    clear(); now,jobs,roster,pivots,resolveCalls,registered=0,{},{},{},{},{},{}
    World.resolveSpawn=function(self,point,existing)
        local result=realResolve(self,point,existing)
        resolveCalls[#resolveCalls+1]={point=point,position=result,count=#existing,existing=existing}
        return result
    end
    for i=1,humans do
        local p={UserId=i,Name="P"..i,DisplayName="P"..i,Parent=true}
        function p:LoadCharacterAsync()
            if delays and delays[i] then task.wait(delays[i]) end
            self.Character=model()
        end
        roster[i]=p
    end
    local actors={list={},byPlayer={}}
    function actors:add(m,p,id)
        local a={model=m,root=m.root,humanoid=m.humanoid,player=p,id=id,alive=true}
        self.list[#self.list+1]=a;registered[#registered+1]=a
        if p then self.byPlayer[p]=a end
        return a
    end
    function actors:alive() return self.list end
    local services={world=world(spawns),actors=actors,zone={reset=function() end},loot={reset=function() end},
        effects={FireClient=function() end},combat={give=function(_,a) a.armed=true end}}
    return Round.new(services)
end
local function spread(n)
    local points={}
    for i=1,n do local a=(i-1)*math.pi*2/n;points[i]=Vector3.new(math.cos(a)*245,4,math.sin(a)*245) end
    return points
end
local function verify(round, expected)
    check(#registered==expected and #resolveCalls==expected, "every actual human/BOT spawn invokes resolver")
    for i,a in ipairs(registered) do
        local call=resolveCalls[i]
        check(call.count==i-1 and call.existing==resolveCalls[1].existing, "human/BOT reservations are shared")
        check(a.root.Position==call.position, "PivotTo uses exact resolver result with no extra ground/height projection")
        check(a.roundId==round.id and a.root.Anchored==false, "combatant enters correct round and is released")
        check(a.root.AssemblyLinearVelocity==Vector3.zero and a.root.AssemblyAngularVelocity==Vector3.zero, "old avatar velocities are cleared")
        if not a.player then check(a.armed, "safe BOT gets pistol") end
        check(World.spawnClear(round.world,a.root.Position-Vector3.new(0,4,0)), "actual combatant is outside colliders/footprints")
        for j=i+1,#registered do
            local delta=a.root.Position-registered[j].root.Position
            check(math.sqrt(delta.X*delta.X+delta.Z*delta.Z)>=28, "all human/human, human/BOT and BOT/BOT pairs separated")
        end
    end
end
math.randomseed(21)
local round=setup(1,spread(24))
check(round:start() and round.phase=="Active", "solo round starts normally")
verify(round,12)
for _,call in ipairs(resolveCalls) do check((call.position-call.point).Magnitude<.001, "unblocked shuffled distribution preserved") end
check(resolveCalls[1].point.X~=245 or resolveCalls[1].point.Z~=0, "random shuffle is retained")
round=setup(20,spread(24),{.3,.1,.2})
check(round:start(), "20 humans load out of order and start")
verify(round,20)
round=setup(2,{preferred},{.2,.1})
blocked=function(p) return p.X>225 and math.abs(p.Z)<10 end
check(round:start(), "short stale pool is safely reused with new reservations")
verify(round,12)
round=setup(1,{})
check(round:start(), "empty generated pool recovers by safe searching")
verify(round,12)
round=setup(1,{preferred})
local allowed=0
World.resolveSpawn=function(self,p,existing)
    allowed=allowed+1
    if allowed==1 then return realResolve(self,p,existing) end
    return nil
end
check(round:start() and #registered==1 and round.phase=="Active", "BOT exhaustion starts fewer combatants instead of blocked fallback")
round=setup(2,spread(24))
local calls=0
World.resolveSpawn=function(self,p,existing)
    calls=calls+1
    if calls==1 then return nil end
    return realResolve(self,p,existing)
end
check(round:start() and not round.actors.byPlayer[roster[1]], "one unsafe human waits while others can start")
check(roster[1].Character.root.Position==round.world.lobby.Position, "unsafe human returns to lobby")
round=setup(1,{preferred}); blocked=function() return true end
check(not round:start() and #registered==0, "fully blocked arena terminates start without unsafe enrollment")
check(roster[1].Character.root.Position==round.world.lobby.Position and not roster[1].Character.root.Anchored, "failed human is not trapped/anchored")
-- Clearing the obstruction permits the next attempt without rebuilding Assets.
clear();check(round:start(), "retry recovers after no-safe-spawn attempt")
round=setup(2,spread(24),{0,20})
check(round:start(), "one delayed avatar does not prevent other human round")
local before=#registered; advance(21)
check(#registered==before and not round.actors.byPlayer[roster[2]], "late avatar never consumes BOT reservation")
check(roster[2].Character.root.Position==round.world.lobby.Position, "late avatar returns to lobby")
round=setup(1,spread(24),{20})
check(not round:start(), "all load timeouts return rather than hang")
round.id=round.id+1; round.phase="Starting"; advance(21)
check(#registered==0, "stale callback cannot enroll in newer round")
round=setup(1,spread(24),{.5})
local lobbyPlayer=roster[1]
round:loadLobby(lobbyPlayer)
local staleToken=round.loading[lobbyPlayer]
local newerToken={}
round.loading[lobbyPlayer]=newerToken
advance(1)
check(staleToken~=newerToken and round.loading[lobbyPlayer]==newerToken,
    "late lobby completion never removes another in-flight character load")
print("PASS: "..assertions.." spawn assertions (real World.resolveSpawn and Round:start)")
