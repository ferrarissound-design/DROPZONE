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
CFrame = {new=function() return fakeCF end, Angles=function() return fakeCF end}
Enum = {Material={Neon="Neon",Air="Air"}}
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
game = {ReplicatedStorage = {DropzoneShared = {Config="Config", Rules="Rules", Weapons="Weapons", VisualTheme="VisualTheme", WeaponStats="WeaponStats", PresentationConfig="PresentationConfig"}}, GetService=function(_, name) if name=="Players" then return players end; if name=="ServerStorage" then return {FindFirstChild=function() return nil end} end end}
script = {Parent = {PlayerEvolutionVisuals="PlayerEvolutionVisuals",World="World", Actors="Actors", Evolution="Evolution", Movement="Movement", Cosmetics="Cosmetics", MapVisuals="MapVisuals", Town="Town"}}
local Config = load("Config", "shared/Config.lua")
local Rules = load("Rules", "shared/Rules.lua")
load("Weapons", "shared/Weapons.lua")
load("VisualTheme", "shared/VisualTheme.lua")
local WeaponStats = load("WeaponStats", "shared/WeaponStats.lua")
load("PresentationConfig", "shared/PresentationConfig.lua")
load("Cosmetics", "server/Cosmetics.lua")
load("MapVisuals", "server/MapVisuals.lua")
local Town = load("Town", "server/Town.lua")
script.Parent.CrouchPose = "CrouchPose"
load("CrouchPose", "server/CrouchPose.lua")
local Movement = load("Movement", "server/Movement.lua")
local World = load("World", "server/World.lua")
-- Gameplay regressions spy on the visual boundary; tests/visuals.lua executes
-- the real constructor, tween, replication markers and lifecycle separately.
modules.PlayerEvolutionVisuals = {
    initialize=function(a) a.mutationFolder=nil end,
    update=function(a) if a.player then a.visualUpdates=(a.visualUpdates or 0)+1 end end,
    stop=function(a) a.visualStopped=true end,
    clear=function(a) a.visualCleared=true end,
}
local Actors = load("Actors", "server/Actors.lua")
local Evolution = load("Evolution", "server/Evolution.lua")
local Zone = load("Zone", "server/Zone.lua")
local Round = load("Round", "server/Round.lua")
local Combat = load("Combat", "server/Combat.lua")
check(Rules.totalDuration(Config.ZonePhases)==375, "zone schedule is 375 seconds")
check(World.townLootPosition(-130,-130).Z == -108, "town loot is outside the +Z roof footprint")
check(#Town.Layout==9 and #Town.WarehouseLayout==4, "bounded town and warehouse building counts")
check(Town.FallbackBudget.collisionParts==91 and Town.FallbackBudget.visualParts==106,
    "fallback town has an explicit static part budget")
-- A template's visible geometry blocks weapon and BOT rays independently of
-- its simplified movement colliders. Invisible helpers and explicit exceptions do not.
local function coverPart(transparency, passThrough)
    return {Transparency=transparency, GetAttribute=function(_,name)
        return name=="TownBulletPassThrough" and passThrough == true
    end}
end
check(Town.blocksShots(coverPart(0), false), "opaque imported wall stops shots")
check(Town.blocksShots(coverPart(0.5), false), "visible glass stops shots")
check(not Town.blocksShots(coverPart(1), false), "invisible non-collision helper does not block shots")
check(not Town.blocksShots(coverPart(0, true), false), "explicit non-collision decoration passes shots")
check(Town.blocksShots(coverPart(1, true), true), "explicit solid collider always blocks shots")
local roles={}
for _,entry in ipairs(Town.Layout) do roles[entry.role]=(roles[entry.role] or 0)+1 end
check(roles.House==5 and roles.Shop==3 and roles.Office==1,
    "town silhouettes reuse a small readable role catalog")
check(Town.lootPosition({x=-70,z=-185,rotation=math.pi/2}).X==-48,
    "rotated building loot remains outside its entrance")
for i,entry in ipairs(Town.Layout) do
    local halfX = math.abs(math.sin(entry.rotation)) > .5 and 14 or 15
    local halfZ = math.abs(math.sin(entry.rotation)) > .5 and 15 or 14
    check(entry.x + halfX < -12 and entry.z + halfZ < -12,
        "town footprint stays clear of both main roads")
    for j=i+1,#Town.Layout do
        local other=Town.Layout[j]
        local otherHalfX = math.abs(math.sin(other.rotation)) > .5 and 14 or 15
        local otherHalfZ = math.abs(math.sin(other.rotation)) > .5 and 15 or 14
        check(math.abs(entry.x-other.x) > halfX+otherHalfX+8
            or math.abs(entry.z-other.z) > halfZ+otherHalfZ+8,
            "town buildings retain a wide route between footprints")
    end
end
for i,entry in ipairs(Town.WarehouseLayout) do
    for j=i+1,#Town.WarehouseLayout do
        local other=Town.WarehouseLayout[j]
        check(math.abs(entry.x-other.x)>54 or math.abs(entry.z-other.z)>42,
            "warehouse footprints retain bot/mobile circulation lanes")
    end
end
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
-- Third-person hip-fire may be aimed behind the avatar while moving;
-- directional integrity comes from server-origin rays, cooldown and ammo.
check(Rules.finite(1) and Rules.finite(-1),"server still accepts valid signed shot components")
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
    local a={id=id,name=tostring(id),alive=true,humanoid={Health=100,MaxHealth=100,WalkSpeed=Config.BaseSpeed,JumpPower=Config.BaseJump,HipHeight=2,AutoRotate=true,FloorMaterial="Grass"},shield=0,kills=0,damage=0,
        reloadToken=0,reloading=false,inventory={},energy=Config.StartEnergy,evolutionCount=0,evolutions={},evolutionStacks={},evolutionHistory={},
        queuedDrafts=0,draftVersion=0,evolutionDraft=nil,roundId=0,lastDamage=0,startTime=os.clock(),
        diagnostics={shots={},hits={},weaponDamage={},builds=0,pickups=0,zoneDamage=0},
        root={Parent=true,Position=Vector3.zero,CFrame={LookVector=Vector3.new(0,0,-1)},Anchored=false,AssemblyLinearVelocity=Vector3.new(10,0,0)},model=model}
    function a.model:Destroy() self.Parent=false end
    table.insert(actors.list,a)
    return a
end
-- Crouch and slide are server-owned states with grounded/cooldown gates.
local mover=actor(30); mover.baseHipHeight=2
check(Movement.toggleCrouch(mover) and mover.crouching and mover.humanoid.HipHeight == mover.baseHipHeight,
    "crouch preserves physical ground clearance")
check(Movement.speedMultiplier(mover)==Config.CrouchSpeedMultiplier and not Movement.canJump(mover),
    "crouch slows movement and blocks jumping")
mover.nextCrouch=0
check(Movement.toggleCrouch(mover) and not mover.crouching,
    "second accepted crouch command returns to standing")
mover.root.AssemblyLinearVelocity=Vector3.new(24,0,0); mover.nextSlide=0
check(Movement.sprint(mover,true), "grounded actor can begin sprint")
check(Movement.slide(mover) and mover.sliding and mover.root.AssemblyLinearVelocity.Magnitude>=Config.SlideSpeed,
    "moving actor receives a bounded server slide impulse")
check(not Movement.slide(mover), "slide cooldown rejects repeated activation")
mover.slideUntil=os.clock()-1; Movement.step(mover)
check(not mover.sliding and mover.humanoid.AutoRotate and mover.crouching and mover.humanoid.HipHeight==mover.baseHipHeight,
    "slide timeout enters crouch and restores rotation")

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
check(drafter.diagnostics.firstEvolutionSeconds~=nil,"first server-approved Evolution records its time")
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
check(stackActor.visualUpdates==nil and stackActor.mutationFolder==nil,
    "BOT ability grants do not create player or legacy mutation visuals")
check(drafter.visualUpdates==1 and chosen~=nil,
    "server-confirmed human draft selection calls the visual boundary exactly once")
check(timerActor.visualUpdates==1,
    "timeout-confirmed human draft selection also calls the visual boundary")

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
    for _, a in ipairs(stormActors) do
        ranks[tostring(a.id)] = a.rank
        check(a.diagnostics.deathReason=="Zone" and math.abs(a.diagnostics.zoneDamage-5)<.0001,
            "lethal storm records exact zone damage and Zone death reason")
    end
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
check(lateEvolution.visualCleared and lateEvolution.roundId==-1 and lateEvolution.evolutionDraft==nil and lateEvolution.queuedDrafts==0,
    "Results invalidates deferred evolution work from the finished round")
local abandonedActors=Actors.new()
actors=abandonedActors
local abandonedBot=actor(64)
local abandonedRound=Round.new({actors=abandonedActors,zone=zone,bots=service("bots"),builds=service("builds"),loot=service("loot"),effects={FireClient=function() end}})
abandonedRound.started=os.clock()
abandonedRound:finish(true)
check(abandonedRound.winner==nil and abandonedBot.rank==nil,"empty human server cannot award a BOT victory")
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
load("MobileLayout", "client/MobileLayout.lua")
script.Parent.MobileLayout = "MobileLayout"
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
local originalLookAt=CFrame.lookAt
CFrame.lookAt=function() return fakeCF end
local strafingBot={root={Position=Vector3.zero,CFrame=fakeCF},humanoid={AutoRotate=true}}
check(Bots.faceTarget(strafingBot,Vector3.new(0,1,-10))
    and strafingBot.humanoid.AutoRotate==false and strafingBot.root.CFrame==fakeCF,
    "BOT attack locks body facing to enemy independent of retreat MoveTo")
CFrame.lookAt=originalLookAt
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

-- Movement transitions use the actual service; no delayed slide callbacks survive a round.
actors = Actors.new()
local runner = actor(900)
Movement.initialize(runner)
check(not Movement.slide(runner), "walking alone cannot trigger slide")
check(Movement.sprint(runner,true) and not Movement.sprint(runner,true), "sprint accepts one start and rejects spam")
check(Movement.sprint(runner,false) and not Movement.sprint(runner,true), "release always works and start cooldown remains")
runner.nextSprint=0; runner.humanoid.FloorMaterial=Enum.Material.Air
check(not Movement.sprint(runner,true), "airborne sprint is rejected")
runner.humanoid.FloorMaterial="Grass"; Movement.sprint(runner,true)
runner.evolutionStacks={SwiftLegs=3,Adrenaline=3};runner.adrenalineUntil=os.clock()+5
Evolution.refresh(runner)
check(runner.humanoid.WalkSpeed<=Config.MaxMoveSpeed and runner.humanoid.WalkSpeed>Config.BaseSpeed,
    "Swift Legs plus Adrenaline plus sprint remains capped")
runner.root.AssemblyLinearVelocity=Vector3.new(999,0,0)
check(Movement.slide(runner) and runner.root.AssemblyLinearVelocity.Magnitude==Config.SlideSpeed,
    "slide never amplifies an untrusted root velocity")
runner.slideUntil=os.clock()+Config.SlideDuration/2;Movement.step(runner)
check(runner.root.AssemblyLinearVelocity.Magnitude<Config.SlideSpeed,"flat slide progressively decelerates")
check(Movement.jump(runner) and not runner.sliding and not runner.crouching and runner.nextSlide>os.clock(),
    "jump cancels slide but cannot reset its cooldown")
Evolution.refresh(runner)
check(runner.humanoid.JumpPower>0,"jump cancel restores evolved jump strength")
runner.sprinting=true;runner.humanoid.FloorMaterial=Enum.Material.Air;Movement.step(runner)
check(not runner.sprinting,"leaving ground cancels sprint")
runner.humanoid.FloorMaterial="Grass";runner.nextSprint=0;Movement.sprint(runner,true)
actors:eliminate(runner)
check(not runner.sprinting and not runner.sliding and not Movement.sprint(runner,true),"death clears and rejects movement")
local nextRunner=actor(901);Movement.initialize(nextRunner)
check(Movement.sprint(nextRunner,true),"fresh second-round actor can sprint")
local movementRound=Round.new({actors=actors,effects={FireClient=function() end}})
movementRound.started=os.clock();movementRound:finish()
check(not nextRunner.sprinting and not nextRunner.sliding and nextRunner.roundId==-1,"Results clears movement and invalidates round")

-- Rarity is stored in the inventory, while all high-impact gun stats stay equal.
local rarities={"Common","Rare","Epic"}
for _,kind in ipairs({"Pistol","Rifle","Shotgun"}) do
    local common=WeaponStats.get(kind,"Common")
    for _,rarity in ipairs(rarities) do
        local spec=WeaponStats.get(kind,rarity)
        check(spec.damage==common.damage and spec.interval==common.interval and spec.magazine==common.magazine and spec.range==common.range,
            "rarity cannot raise damage, fire rate, magazine or range")
        check(spec.reload>=common.reload*.92 and spec.spread>=common.spread*.88,"rarity handling bonuses stay bounded")
    end
end
for _,roll in ipairs({{0,"Common"},{.719,"Common"},{.72,"Rare"},{.939,"Rare"},{.94,"Epic"},{.999,"Epic"}}) do
    check(WeaponStats.roll({NextNumber=function() return roll[1] end})==roll[2],"rarity loot weights")
end
local collector=actor(902);collector.slot=1
local rarityCombat=Combat.new(actors,{FireClient=function() end},nil)
rarityCombat.visual=function() end
check(not rarityCombat:give(collector,"Pistol","Legendary"),"unknown rarity cannot enter inventory")
rarityCombat:give(collector,"Pistol","Rare");collector.inventory[1].ammo=2;collector.ammo=2
rarityCombat:reload(collector);local oldReload=delayed[#delayed]
rarityCombat:give(collector,"Pistol","Epic");oldReload()
check(collector.inventory[1].rarity=="Epic" and collector.ammo==2 and not collector.reloading,
    "upgrade preserves magazine and invalidates stale reload")
rarityCombat:give(collector,"Pistol","Common")
check(#collector.inventory==1 and collector.inventory[1].rarity=="Epic","duplicate lower-tier pickup never downgrades or adds a slot")
rarityCombat:reload(collector);delayed[#delayed]()
check(collector.inventory[1].ammo==12,"BOT-compatible rarity inventory can reload normally")
actors:clear()
check(#collector.inventory==0 and collector.ammo==0,"reset discards rarity inventory")

-- Actual fire -> raycast -> damage resolution -> bounded confirmation payload.
actors=Actors.new()
local shooter,victim=actor(910),actor(911)
shooter.player={Parent=true};shooter.roundId=77;shooter.slot=1;shooter.nextShot=0
shooter.startTime=os.clock()-4
players.GetPlayers=function() return {shooter.player} end
shooter.inventory={{kind="Shotgun",rarity="Epic",ammo=6,reserve=24}};shooter.ammo=6
victim.humanoid.Health,victim.shield=20,30
actors.byModel[victim.model]=victim;actors.byPlayer[shooter.player]=shooter
local messages={}
local shotCombat=Combat.new(actors,{FireClient=function(_,player,kind,...) messages[#messages+1]={player=player,kind=kind,args={...}} end},nil)
Enum.RaycastFilterType={Exclude="Exclude"};RaycastParams={new=function() return {} end}
typeof=function(value) return getmetatable(value)==vec and "Vector3" or type(value) end
fakeCF.LookVector=Vector3.new(1,0,0);CFrame.lookAt=function() return fakeCF end;CFrame.Angles=function() return fakeCF end
workspace={Raycast=function() return {Instance={Parent=victim.model},Distance=10,Position=victim.root.Position} end}
shotCombat:fire(shooter,Vector3.new(1,0,0))
check(shooter.diagnostics.firstShotSeconds and shooter.diagnostics.firstShotSeconds>=4,
    "accepted server-authoritative shot records elapsed seconds once")
local confirmed
for _,event in ipairs(messages) do if event.kind=="Damage" then confirmed=event end end
check(confirmed and confirmed.player==shooter.player and confirmed.args[1]==77 and #confirmed.args[2]==1,
    "shotgun aggregates pellets per victim and confirms damage to shooter only with roundId")
check(math.abs(confirmed.args[2][1].hp-20)<.0001 and math.abs(confirmed.args[2][1].shield-30)<.0001 and confirmed.args[2][1].eliminated,
    "damage feedback contains actual HP/Shield losses, not overkill")
check(shooter.diagnostics.shots.Shotgun==1 and shooter.diagnostics.hits.Shotgun==1
    and math.abs(shooter.diagnostics.weaponDamage.Shotgun-50)<.0001,
    "accepted combat records one shot-level hit and exact non-overkill weapon damage")
local eventCount=#messages
shotCombat:fire(shooter,Vector3.new(1,0,0))
check(#messages==eventCount and shooter.ammo==5,"fire spam cannot generate extra damage feedback")
shooter.nextShot=0;workspace.Raycast=function() return nil end
messages={};shotCombat:fire(shooter,Vector3.new(1,0,0))
local damageEvents=0;for _,event in ipairs(messages) do if event.kind=="Damage" then damageEvents=damageEvents+1 end end
check(damageEvents==0,"misses never produce a damage number")
check(shooter.diagnostics.shots.Shotgun==2 and shooter.diagnostics.hits.Shotgun==1
    and math.abs(shooter.diagnostics.weaponDamage.Shotgun-50)<.0001,
    "misses count as shots but never inflate hit or damage diagnostics")
shooter.nextShot=0
local ammoBeforeReverse=shooter.ammo
shotCombat:fire(shooter,Vector3.new(-1,0,0))
check(shooter.ammo==ammoBeforeReverse-1,"third-person fire behind running avatar is valid and still ammo-authoritative")
print("PASS: "..count.." total gameplay assertions including movement, rarity and confirmed combat")

local shotEvent
for _,event in ipairs(messages) do if event.kind=="Shot" then shotEvent=event end end
check(shotEvent and shotEvent.args[5]==77,"presentation shot carries server round ID even on a miss")
shooter.reloading=true;shooter.nextShot=0
local beforeReloadShot=#messages
shotCombat:fire(shooter,Vector3.new(1,0,0))
check(#messages==beforeReloadShot,"reload rejects shot before presentation event is emitted")
print("PASS: "..count.." total gameplay assertions including presentation event guards")

-- World collisions must be distinguishable from range endpoints, with surface normals.
shooter.reloading=false;shooter.nextShot=0;messages={}
local worldPosition,worldNormal=Vector3.new(20,4,0),Vector3.new(-1,0,0)
workspace.Raycast=function() return {Instance={Parent={}},Distance=20,Position=worldPosition,Normal=worldNormal} end
shotCombat:fire(shooter,Vector3.new(1,0,0))
local worldShot
for _,event in ipairs(messages) do
    check(event.kind~="Damage","world hits cannot emit enemy confirmation")
    if event.kind=="Shot" then worldShot=event end
end
check(worldShot and worldShot.args[5]==77 and #worldShot.args[6]==7,"Shot argument order preserves roundId and bounded pellet impacts")
check(worldShot.args[6][1].position==worldPosition and worldShot.args[6][1].normal==worldNormal,
    "server sends exact world hit position and normal")
check(worldShot.args[2][1]==worldPosition,"world tracer endpoint equals authoritative ray result")
check(shotEvent and #shotEvent.args[6]==0,"range-only miss has no world impact")
print("PASS: "..count.." gameplay assertions including world impact provenance")


-- Execute authoritative cooldown buffering with a deterministic task clock.
local originalClock, originalDelay, originalRoster = os.clock, task.delay, players.GetPlayers
local clock, scheduled = 100, {}
os.clock=function() return clock end
task.delay=function(seconds, callback) scheduled[#scheduled+1]={at=clock+seconds, callback=callback} end
local function advanceTo(target)
    while true do
        local index
        for i, job in ipairs(scheduled) do
            if job.at<=target and (not index or job.at<scheduled[index].at) then index=i end
        end
        if not index then break end
        local job=table.remove(scheduled,index); clock=job.at; job.callback()
    end
    clock=target
end
actors=Actors.new()
local buffered=actor(920); buffered.player={Parent=true}; buffered.roundId=88
buffered.slot=1; buffered.nextShot=0; buffered.ammo=28
buffered.inventory={{kind="Rifle",rarity="Common",ammo=28,reserve=84}}
actors.byPlayer[buffered.player]=buffered
players.GetPlayers=function() return {buffered.player} end
workspace.Raycast=function() return nil end
local deliveries, acceptedTimes={},{}
local bufferedCombat=Combat.new(actors,{FireClient=function(_,recipient,kind)
    deliveries[#deliveries+1]={recipient=recipient,kind=kind}
    if recipient==buffered.player and kind=="Shot" then acceptedTimes[#acceptedTimes+1]=clock end
end},nil)
for i=0,9 do
    advanceTo(100+i*.15+(i%2==0 and .04 or 0))
    bufferedCombat:fire(buffered,Vector3.new(1,0,0))
end
advanceTo(101.5)
check(buffered.ammo==18 and #acceptedTimes==10,"jittered legitimate rifle sends retain all ten shots")
for i=2,#acceptedTimes do
    check(acceptedTimes[i]-acceptedTimes[i-1]>=.14-1e-9,"buffered fire never exceeds server weapon cadence")
end
local function prepareEarly()
    scheduled={}; buffered.pendingShot=nil; buffered.nextShot=clock+.03
    buffered.alive=true; buffered.humanoid.Health=100; buffered.reloading=false
    buffered.ammo=20; buffered.inventory[1].ammo=20; buffered.slot=1; buffered.roundId=88
    bufferedCombat:fire(buffered,Vector3.new(1,0,0))
    check(#scheduled==1 and buffered.ammo==20,"early shot reserves one callback without spending ammo")
end
prepareEarly()
for _=1,100 do bufferedCombat:fire(buffered,Vector3.new(1,0,0)) end
check(#scheduled==1,"request spam cannot create an unbounded shot queue")
advanceTo(clock+.04)
check(buffered.ammo==19,"spam-buffered request fires only one shot")
prepareEarly()
bufferedCombat:stopFire(buffered)
advanceTo(clock+.04)
check(buffered.ammo==20 and buffered.pendingShot==nil,"FireStop cancels buffered shot")
for _, invalidate in ipairs({
    function() buffered.alive=false end,
    function() buffered.humanoid.Health=0 end,
    function() buffered.reloadToken=buffered.reloadToken+1 end,
    function() buffered.slot=2 end,
    function() buffered.roundId=-1 end,
    function() buffered.roundId=89 end,
    function() buffered.player.Parent=nil end,
}) do
    buffered.player.Parent=true
    prepareEarly(); invalidate(); advanceTo(clock+.04)
    check(buffered.ammo==20,"death/reload/equip/results/reset/leave cancels deferred fire")
end
buffered.player.Parent=true; prepareEarly()
local oldItem=buffered.inventory[1]
buffered.inventory[1]={kind="Rifle",rarity="Common",ammo=20,reserve=84}
advanceTo(clock+.04)
check(buffered.ammo==20,"replacing inventory cancels an old weapon's buffered fire")
buffered.inventory[1]=oldItem
prepareEarly(); buffered.nextShot=0; bufferedCombat:fire(buffered,Vector3.new(1,0,0)); advanceTo(clock+.04)
check(buffered.ammo==19,"a newer accepted shot invalidates the old deferred callback")
scheduled={}; buffered.pendingShot=nil; buffered.nextShot=clock+.1
bufferedCombat:fire(buffered,Vector3.new(1,0,0))
check(#scheduled==0,"requests more than 50ms early are rejected")
buffered.nextShot=clock+.03
bufferedCombat:fire(buffered,Vector3.new(0/0,0,0))
check(#scheduled==0,"invalid aim never reserves a deferred shot")

-- Real connected roster includes dead spectators and unregistered late joiners.
local dead=actor(921); dead.alive=false; dead.root.Position=Vector3.new(-245,0,0)
dead.player={Parent=true}; actors.byPlayer[dead.player]=dead
local distant=actor(922); distant.player={Parent=true}; distant.root.Position=Vector3.new(-245,0,0)
actors.byPlayer[distant.player]=distant
local late, departed={Parent=true},{Parent=nil}
players.GetPlayers=function() return {buffered.player,dead.player,distant.player,late,departed} end
buffered.root.Position=Vector3.new(245,0,0);buffered.nextShot=0
local recipients={}
bufferedCombat.effects={FireClient=function(_,recipient,kind) if kind=="Shot" then recipients[recipient]=true end end}
bufferedCombat:fire(buffered,Vector3.new(1,0,0))
check(recipients[buffered.player] and recipients[dead.player] and recipients[late],
    "near shooter, far-dead spectator and late join all receive shot feedback")
check(not recipients[distant.player] and not recipients[departed],
    "live distance culling and disconnected-player exclusion remain intact")
os.clock, task.delay, players.GetPlayers=originalClock,originalDelay,originalRoster
local timingKiller,timingVictim=actor(940),actor(941)
timingKiller.player={Parent=true};timingKiller.startTime=os.clock()-11;timingKiller.roundId=88
local timingRound=Round.new({actors=actors,zone=zone,effects={FireClient=function() end}})
timingRound.id=88
actors.onDeath(timingVictim,timingKiller)
check(timingKiller.kills==1 and timingKiller.diagnostics.firstKillSeconds>=11,
    "first confirmed elimination has a single timestamp independent of presentation")
print("PASS: "..count.." gameplay assertions including jitter buffering, spectator delivery and first-match timings")

