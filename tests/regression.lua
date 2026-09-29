-- Narrow engine doubles exercise actual modules, not a second implementation.
local count = 0
local function check(ok, message)
    assert(ok, message)
    count = count + 1
end
local nativeRequire = require
local modules = {}
local function load(name, path)
    local module = assert(loadfile(ROOT .. "/src/" .. path))()
    modules[name] = module
    return module
end
require = function(name) return modules[name] or nativeRequire(name) end
local vec = {}
vec.__index = function(a, key)
    if key == "Magnitude" then return math.sqrt(a.X*a.X + a.Y*a.Y + a.Z*a.Z) end
    if key == "Unit" then return a / a.Magnitude end
    return vec[key]
end
vec.__add = function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vec.__sub = function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vec.__mul = function(a,b) return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
vec.__div = function(a,b) return Vector3.new(a.X/b,a.Y/b,a.Z/b) end
function vec:Lerp(b,t) return self + (b-self)*t end
Vector3 = {new = function(x,y,z) return setmetatable({X=x,Y=y,Z=z},vec) end}
Vector3.zero = Vector3.new(0,0,0)
Random = {new = function() return {NextNumber = function(_,a,b) return (a+b)/2 end, NextInteger = function(_,a,b) return a end} end}
Color3 = {fromRGB = function(...) return {...} end, fromHSV = function(...) return {...} end}
local fakeCF
fakeCF = setmetatable({}, {__mul=function() return fakeCF end})
CFrame = {new=function() return fakeCF end}
Enum = {Material={Neon="Neon"}}
Instance = {new=function(kind)
    local value = {ClassName=kind, children={}}
    return setmetatable(value, {__newindex=function(t,k,v)
        rawset(t,k,v)
        if k=="Parent" and type(v)=="table" and v.children then table.insert(v.children,t) end
    end})
end}
local delayed = {}
task = {delay = function(_, f) table.insert(delayed,f) end, defer = function(f) f() end}
local players = {GetPlayers = function() return {} end}
game = {ReplicatedStorage = {DropzoneShared = {Config="Config", Rules="Rules", Weapons="Weapons", VisualTheme="VisualTheme"}}, GetService=function(_, name) if name=="Players" then return players end end}
script = {Parent = {World="World", Actors="Actors", Evolution="Evolution", Movement="Movement", Cosmetics="Cosmetics", MapVisuals="MapVisuals"}}
local Config = load("Config", "shared/Config.lua")
local Rules = load("Rules", "shared/Rules.lua")
load("Weapons", "shared/Weapons.lua")
load("VisualTheme", "shared/VisualTheme.lua")
load("Cosmetics", "server/Cosmetics.lua")
load("MapVisuals", "server/MapVisuals.lua")
local Movement = load("Movement", "server/Movement.lua")
local World = load("World", "server/World.lua")
local Actors = load("Actors", "server/Actors.lua")
local Evolution = load("Evolution", "server/Evolution.lua")
local Zone = load("Zone", "server/Zone.lua")
local Round = load("Round", "server/Round.lua")
local Combat = load("Combat", "server/Combat.lua")
check(Rules.totalDuration(Config.ZonePhases)==375, "zone schedule is 375 seconds")
check(World.townLootPosition(-130,-130).Z == -108, "town loot is outside the +Z roof footprint")
check(not Rules.shouldShowEvolutionDraft({phase="Active",me={alive=true}}),
    "snapshot without an Evolution draft hides the draft UI")
check(not Rules.shouldShowEvolutionDraft({phase="Active",me={alive=false,evolutionDraft={id=1}}}),
    "eliminated player cannot see or select a pending Evolution draft")
check(not Rules.shouldShowEvolutionDraft({phase="Results",me={alive=true,evolutionDraft={id=1}}})
    and not Rules.shouldShowEvolutionDraft({phase="Resetting",me={alive=true,evolutionDraft={id=1}}}),
    "Results and Resetting close any stale draft UI")
check(Rules.shouldShowEvolutionDraft({phase="FinalZone",me={alive=true,evolutionDraft={id=1}}}),
    "living player keeps draft UI during FinalZone")
check(Rules.botCount(1,12)==11, "solo bots")
check(Rules.botCount(5,12)==7, "five humans")
check(Rules.botCount(20,12)==0, "no negative bots")
check(not Rules.finite(0/0) and not Rules.finite(math.huge), "NaN and infinity rejected")
local scout, corpse, living =
    {alive=true, root={Position=Vector3.new(0,0,0)}},
    {alive=false, root={Position=Vector3.new(1,0,0)}},
    {alive=true, root={Position=Vector3.new(12,0,0)}}
local target, targetDistance = Rules.closestLiveTarget(scout, {scout,corpse,living}, 145)
check(target==living and targetDistance==12, "bot targeting skips actors eliminated earlier this decision cycle")
local hp,shield,dealt = Rules.resolveDamage(100,20,35,false)
check(hp==85 and shield==0 and dealt==35,"shield first")
hp,shield,dealt = Rules.resolveDamage(10,20,999,false)
check(hp==0 and shield==0 and dealt==30,"damage stats exclude overkill")
hp,shield = Rules.resolveDamage(100,50,10,true)
check(hp==90 and shield==50,"storm bypasses shield")
local zone = Zone.new(); zone:reset()
check(zone.radius==320 and zone.phase==1,"zone reset")
local previous = 320
for _=1,Rules.totalDuration(Config.ZonePhases) do
    zone:update(1)
    check(zone.radius<=previous and zone.radius>=0,"zone monotonically shrinks")
    previous=zone.radius
    check((zone.nextCenter-zone.center).Magnitude + zone.nextRadius <= zone.radius + 0.00001,"next circle contained")
end
check(zone.radius==0 and zone:outside(Vector3.zero),"zero zone kills center campers")
zone:reset()
check(zone.elapsed==0 and zone.radius==320,"second round zone reset")
local actors = Actors.new()
local function actor(id)
    local model={Parent=true,parts={},mutationFolder=nil}
    function model:FindFirstChild(name)
        if name=="Mutation" then return self.mutationFolder end
        return self.parts[name]
    end
    for _, name in ipairs({"Head","Torso","UpperTorso","LowerTorso","LeftLowerLeg","RightLowerLeg","LeftFoot","RightHand","LeftHand","Left Leg","Right Leg","Left Arm","Right Arm"}) do
        local p={Name=name,Size=Vector3.new(2,2,1),CFrame=fakeCF,CanCollide=true,CanQuery=true,CanTouch=true}
        function p:IsA(kind) return kind=="BasePart" end
        model.parts[name]=p
    end
    function model:GetDescendants()
        local result={}
        for _, p in pairs(self.parts) do table.insert(result,p) end
        return result
    end
    local a={id=id,name=tostring(id),alive=true,humanoid={Health=100,MaxHealth=100,WalkSpeed=Config.BaseSpeed,JumpPower=Config.BaseJump,HipHeight=2,AutoRotate=true},shield=0,kills=0,damage=0,
        reloadToken=0,reloading=false,inventory={},energy=Config.StartEnergy,evolutionCount=0,evolutions={},evolutionStacks={},evolutionHistory={},
        queuedDrafts=0,draftVersion=0,evolutionDraft=nil,roundId=0,lastDamage=0,startTime=os.clock(),root={Parent=true,Position=Vector3.zero,Anchored=false,AssemblyLinearVelocity=Vector3.new(10,0,0)},model=model}
    function a.model:Destroy() self.Parent=false end
    table.insert(actors.list,a)
    return a
end
-- Crouch and slide are server-owned states with grounded/cooldown gates.
local mover=actor(30); mover.baseHipHeight=2
check(Movement.toggleCrouch(mover) and mover.crouching and mover.humanoid.HipHeight < mover.baseHipHeight,
    "crouch lowers stance through authoritative movement state")
check(Movement.speedMultiplier(mover)==Config.CrouchSpeedMultiplier and not Movement.canJump(mover),
    "crouch slows movement and blocks jumping")
mover.nextCrouch=0
check(Movement.toggleCrouch(mover) and not mover.crouching,
    "second accepted crouch command returns to standing")
mover.root.AssemblyLinearVelocity=Vector3.new(10,0,0); mover.nextSlide=0
check(Movement.slide(mover) and mover.sliding and mover.root.AssemblyLinearVelocity.Magnitude>=Config.SlideSpeed,
    "moving actor receives a bounded server slide impulse")
check(not Movement.slide(mover), "slide cooldown rejects repeated activation")
mover.slideUntil=os.clock()-1; Movement.step(mover)
check(not mover.sliding and mover.humanoid.AutoRotate and mover.humanoid.HipHeight==mover.baseHipHeight,
    "slide timeout restores standing posture")

-- Evolution Draft offers are server-created, three distinct options from mixed build categories.
local drafter=actor(31); drafter.player={}; drafter.roundId=41
Evolution.onKill(drafter,41,nil)
local draft=drafter.evolutionDraft
check(draft and #draft.options==3, "kill creates exactly three server-side draft choices")
local choiceIds,choiceCategories={},{}
for _, option in ipairs(draft.options) do choiceIds[option.id]=true; choiceCategories[option.category]=true end
local distinct=0; for _ in pairs(choiceIds) do distinct=distinct+1 end
local categoryCount=0; for _ in pairs(choiceCategories) do categoryCount=categoryCount+1 end
check(distinct==3 and categoryCount>=2, "draft choices are unique and favor varied categories")
local staleCount=#delayed
check(Evolution.select(drafter,41,draft.id,4)==nil and drafter.evolutionCount==0,
    "candidate outside server-held choices cannot be acquired")
local chosen=Evolution.select(drafter,41,draft.id,1)
check(chosen~=nil and drafter.evolutionCount==1, "valid pick grants exactly one evolution")
check(Evolution.select(drafter,41,draft.id,2)==nil and drafter.evolutionCount==1,
    "a draft token cannot be selected twice")
-- Fire the real five-second callback after advancing its deadline; stale callbacks are harmless.
local timerActor=actor(32); timerActor.player={}; timerActor.roundId=42
Evolution.onKill(timerActor,42,nil)
local timerDraft=timerActor.evolutionDraft
local timerCallback=delayed[#delayed]
timerDraft.expiresAt=os.clock()-1
timerCallback()
check(timerActor.evolutionDraft==nil and timerActor.evolutionCount==1,
    "expired draft auto-picks one offered ability")
local deadDraft=actor(33); deadDraft.player={}; deadDraft.roundId=43
Evolution.onKill(deadDraft,43,nil)
local deadTimer=delayed[#delayed]
Evolution.cancel(deadDraft); deadDraft.alive=false
deadTimer()
check(deadDraft.evolutionDraft==nil and deadDraft.evolutionCount==0,
    "death cancels pending evolution and timer cannot grant later")
local stackActor=actor(34)
for _=1,4 do Evolution.grant(stackActor,"SwiftLegs") end
check(Evolution.rank(stackActor,"SwiftLegs")==3 and stackActor.evolutionCount==3,
    "same ability stacks to the configured rank cap")
check(stackActor.humanoid.WalkSpeed<=Config.BaseSpeed*1.19,
    "diminishing movement stacks stay under the stat cap")
local diminishing = true
for _, ability in ipairs(Evolution.abilities) do
    for rank=2, Evolution.maxRank do if ability.values[rank] >= ability.values[rank-1] then diminishing=false end end
end
check(diminishing, "every stackable evolution has diminishing rank values")
local shieldEvolution=actor(37)
Evolution.grant(shieldEvolution,"CombatShield")
check(shieldEvolution.shield==10,"Combat Shield grants its first rank when selected")
Evolution.grant(shieldEvolution,"CombatShield")
check(shieldEvolution.shield==17,"Combat Shield upgrade grants only its diminishing rank value")
local visualParts=#stackActor.mutationFolder.children
check(visualParts==3 and stackActor.mutationFolder.children[1].CanCollide==false
    and stackActor.mutationFolder.children[1].CanTouch==false and stackActor.mutationFolder.children[1].CanQuery==false,
    "stack visuals are cosmetic and do not add queryable hitboxes")

-- Keep evolution-specific fixtures out of round population/rank assertions.
actors:clear()
local a,b,c = actor(1),actor(2),actor(3)
local deaths=0
actors.onDeath=function() deaths=deaths+1 end
actors:damage(b,1000,a)
actors:eliminate(b,a)
check(deaths==1 and b.rank==3 and #actors:alive()==2,"death is idempotent and rank correct")
check(b.root.Anchored and b.model.parts.Torso.CanCollide==false and b.model.parts.Torso.CanQuery==false and b.model.parts.Torso.CanTouch==false,
    "eliminated actor remains visible but cannot block movement, shots, LOS or touch")
check(a.damage==100,"damage accounting")
actors:eliminate(c)
check(c.rank==2 and #actors:alive()==1,"last survivor count")
local calls={}
local service=function(name) return {clear=function() calls[name]=(calls[name] or 0)+1 end} end
local round=Round.new({actors=actors,zone=zone,bots=service("bots"),builds=service("builds"),loot=service("loot"),effects={FireClient=function() end}})
round.phase,round.started = "Active",os.clock()
round:step(0.1)
check(round.phase=="Results" and round.winner=="1" and a.rank==1,"winner results")
round:reset()
check(#actors.list==0 and next(actors.byPlayer)==nil and calls.bots==1 and calls.builds==1 and calls.loot==1,"all services reset")
check(zone.radius==320 and round.winner==nil,"results cleared")
-- Reload callbacks cannot mutate another weapon, a dead actor, or the next match.
local combat=Combat.new(actors,{},nil)
local fighter={alive=true,inventory={{kind="Pistol",ammo=2,reserve=5},{kind="Rifle",ammo=28,reserve=84}},slot=1,ammo=2,reloadToken=0,reloading=false,evolutions={}}
combat.visual=function() end
combat:reload(fighter); delayed[#delayed]()
check(fighter.ammo==7 and fighter.inventory[1].reserve==0 and not fighter.reloading,"partial reserve reload")
fighter.inventory[1].reserve=20
combat:reload(fighter); local pending=delayed[#delayed]
combat:equip(fighter,2); pending()
check(fighter.ammo==28 and fighter.inventory[1].ammo==7 and not fighter.reloading,"equip invalidates reload")
combat:equip(fighter,1); combat:reload(fighter); fighter.alive=false; delayed[#delayed]()
check(fighter.inventory[1].ammo==7,"death invalidates reload")
check(not Rules.canFire(fighter,{},os.clock()),"dead actor cannot fire")
fighter.alive=true; fighter.nextShot=os.clock()+3; fighter.reloading=false
check(not Rules.canFire(fighter,{},os.clock()),"fire rate enforced")
fighter.nextShot=0; fighter.ammo=0
check(not Rules.canFire(fighter,{},os.clock()),"empty magazine cannot fire")
-- New round actors do not retain any previous combatant record.
local fresh=actor(4)
check(fresh.kills==0 and fresh.damage==0 and fresh.shield==0 and fresh.alive,"fresh second-round actor")
round.phase,round.started="Active",os.clock(); round:step(0.1)
check(round.phase=="Results" and round.winner=="4","second-round result")
check(fresh.evolutionCount==0 and #fresh.inventory==0 and fresh.energy==Config.StartEnergy, "fresh actor has no kills, evolution, inventory or energy residue")
round:reset()
check(#actors.list==0 and calls.builds==2,"second reset")
-- Simultaneous lethal storm damage must tie, not elect whichever actor is visited last.
local function stormOutcome(order)
    actors = Actors.new()
    local stormActors = {}
    for _, id in ipairs(order) do
        local fighter = actor(id)
        fighter.humanoid.Health = 5
        table.insert(stormActors, fighter)
    end
    local stormZone = {
        phase = #Config.ZonePhases, elapsed = 374, damage = 10,
        update = function(self, dt) self.elapsed = self.elapsed + dt end,
        outside = function() return true end,
        snapshot = function() return {} end,
        reset = function() end,
    }
    local stormRound = Round.new({actors=actors,zone=stormZone,bots=service("bots"),
        builds=service("builds"),loot=service("loot"),effects={FireClient=function() end}})
    stormRound.phase, stormRound.started = "FinalZone", os.clock()
    stormRound:step(1)
    local ranks = {}
    for _, a in ipairs(stormActors) do ranks[tostring(a.id)] = a.rank end
    return stormRound.winner, ranks, stormRound.phase
end
local winnerForward, rankForward, phaseForward = stormOutcome({21,22})
local winnerReverse, rankReverse, phaseReverse = stormOutcome({22,21})
check(winnerForward==nil and winnerReverse==nil, "simultaneous final storm is a draw in either actor order")
check(rankForward["21"]==1 and rankForward["22"]==1 and rankReverse["21"]==1 and rankReverse["22"]==1,
    "same-tick storm deaths share an order-independent rank")
check(phaseForward=="Results" and phaseReverse=="Results", "simultaneous storm resolves the round")

-- Deferred Evolution work captured before Results cannot reopen/apply after the round finishes.
actors = Actors.new()
local lateEvolution=actor(36); lateEvolution.player={}; lateEvolution.roundId=77
Evolution.onKill(lateEvolution,77,nil)
Evolution.onKill(lateEvolution,77,nil)
local lateDraft=lateEvolution.evolutionDraft
local deferredEvolution
task.defer=function(callback) deferredEvolution=callback end
check(Evolution.select(lateEvolution,77,lateDraft.id,1)~=nil and deferredEvolution~=nil,
    "queued evolution schedules its next draft")
local finishRound=Round.new({actors=actors,zone=zone,bots=service("bots"),builds=service("builds"),loot=service("loot"),effects={FireClient=function() end}})
finishRound.id,finishRound.phase,finishRound.started=77,"Active",os.clock()
finishRound:finish()
deferredEvolution()
check(lateEvolution.roundId==-1 and lateEvolution.evolutionDraft==nil and lateEvolution.queuedDrafts==0,
    "Results invalidates deferred evolution work from the finished round")
task.defer=function(callback) callback() end

-- Three consecutive lifecycles clear service state, not just the Actor list.
actors = Actors.new()
local third = actor(5)
round.actors = actors
round.phase, round.started = "Active", os.clock()
round:step(0.1)
check(round.phase=="Results" and round.winner=="5", "third-round actor can finish a fresh round")
round:reset()
check(#actors.list==0 and calls.bots==3 and calls.builds==3 and calls.loot==3,
    "third-round reset clears actors, bots, building and loot")
check(zone.radius==320 and zone.elapsed==0 and round.winner==nil,
    "third-round reset clears the zone and winner")
local resetDraft=actor(35); resetDraft.player={}; resetDraft.roundId=round.id
Evolution.grant(resetDraft,"IronSkin"); Evolution.onKill(resetDraft,round.id,nil)
local staleTimer=delayed[#delayed]
actors.list={resetDraft}; actors.byPlayer[resetDraft.player]=resetDraft
local resetServices={
    actors=actors, zone=zone, bots=service("bots"), builds=service("builds"), loot=service("loot"),
    effects={FireClient=function() end},
}
local resetRound=Round.new(resetServices)
resetRound:reset(); staleTimer()
check(resetDraft.evolutionCount==0 and next(resetDraft.evolutionStacks)==nil
    and resetDraft.evolutionDraft==nil and resetDraft.queuedDrafts==0
    and resetDraft.mutationFolder==nil and resetDraft.model.Parent==false,
    "Round reset clears stack, pending offer, queue, visual state and model")

print("PASS: " .. count .. " regression assertions")

-- Execute the real card renderer with a strict Color3 property double.
local shared = {WaitForChild=function(_, name) return name end}
local services = {ReplicatedStorage={WaitForChild=function() return shared end}}
game.GetService=function(_, name) return services[name] or {} end
local Hud = load("Hud", "client/Hud.lua")
local cards = {}
for i=1,3 do
    local properties = {}
    cards[i] = setmetatable({}, {
        __index=properties,
        __newindex=function(_, key, value)
            if key=="BackgroundColor3" then assert(type(value)=="table", "Color3 must never receive false/nil") end
            properties[key]=value
        end,
    })
end
local view=setmetatable({draftCards=cards,currentDraft={id=1,options={
    {name="Swift Legs",rankText="I",description="Speed +8%",category="Mobility"},
    {name="Iron Skin",rankText="I",description="HP +20",category="Survival"},
    {name="Builder",rankText="I",description="Energy -15%",category="Utility"},
}}}, Hud)
view:updateDraftCards()
check(cards[1].Active and cards[3].Active,"fresh draft renderer accepts all cards without a Color3 runtime error")
view.submittedDraftId,view.submittedChoice=1,2
view:updateDraftCards()
check(not cards[1].Active and not cards[2].Active and not cards[3].Active,"submission disables every card")
check(cards[2].Text:find("送信中",1,true)~=nil,"pending selection never claims server confirmation")
view.submittedDraftId,view.currentDraft.id=nil,2
view:updateDraftCards()
check(cards[1].Active and cards[2].TextTransparency==0,"next draft restores card input and appearance")
local visualCalls=0
combat.visual=function() visualCalls=visualCalls+1 end
fighter.slot,fighter.reloading,fighter.reloadToken=1,true,90
combat:equip(fighter,1)
check(visualCalls==0 and fighter.reloading and fighter.reloadToken==90,"same-slot equip spam neither rebuilds parts nor cancels reload")
-- Path construction failures release the bounded worker and leave recovery available.
services.PathfindingService={CreatePath=function() error("simulated engine path failure") end}
local Bots=load("Bots", "server/Bots.lua")
local botService=Bots.new({}, {}, {}, {}, {})
botService.rng={NextNumber=function() return 0 end}
task.spawn=function(callback) callback() end
local pathActor={alive=true,root={Position=Vector3.zero},humanoid={}}
botService:path(pathActor,Vector3.zero,10)
check(botService.jobs==0 and not pathActor.pathBusy and pathActor.humanoid.Jump,
    "CreatePath failure releases worker and enables stuck recovery")
-- A stale path completion from the previous round must never consume a new round's worker slot.
local queuedPaths={}
task.spawn=function(callback) table.insert(queuedPaths,callback) end
local oldPathActor={alive=true,root={Position=Vector3.zero},humanoid={}}
local newPathActor={alive=true,root={Position=Vector3.zero},humanoid={}}
botService:path(oldPathActor,Vector3.zero,20)
check(botService.jobs==1,"old generation reserves one path worker")
botService:clear()
check(botService.jobs==0,"round clear releases old generation path slots immediately")
botService:path(newPathActor,Vector3.zero,30)
check(botService.jobs==1 and #queuedPaths==2,"new round can start a path while old computation is still pending")
queuedPaths[1]()
check(botService.jobs==1,"stale path completion cannot decrement the current generation worker count")
queuedPaths[2]()
check(botService.jobs==0,"current generation path completion releases its worker exactly once")
print("PASS: " .. count .. " total regression assertions including release UI checks")
