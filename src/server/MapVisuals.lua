local Theme = require(game.ReplicatedStorage.DropzoneShared.VisualTheme)
local Cosmetics = require(script.Parent.Cosmetics)
local MapVisuals = {}

-- Static art is a sibling of Map, so World.ground's include filter cannot hit it.
-- No lights, emitters, mesh assets, scripts, physics, or animation jobs.
function MapVisuals.create(world)
    local f = Instance.new("Folder")
    f.Name, f.Parent = "Scenery", world.root
    local function p(name, size, cf, color, material, shape)
        return Cosmetics.part(f, name, size, cf, color, nil, material, shape)
    end
    -- Flat color fields break up the island without modifying walkable elevation.
    for _, patch in ipairs({{-133,130,Theme.Grass[3]}, {132,133,Theme.Grass[2]}, {-133,-133,Theme.Grass[2]}}) do
        p("GroundColor", Vector3.new(190,.04,190), CFrame.new(patch[1],.03,patch[2]), patch[3], Enum.Material.Grass, Enum.PartType.Ball)
    end
    for _, side in ipairs({-1,1}) do
        p("RoadEdge", Vector3.new(508,.08,.55), CFrame.new(0,.25,side*11.5), Theme.Paper)
        p("RoadEdge", Vector3.new(.55,.08,508), CFrame.new(side*11.5,.25,0), Theme.Paper)
        for i=-2,2 do
            p("Crosswalk", Vector3.new(2.4,.08,17), CFrame.new(side*23+i*3,.25,0), Theme.Paper)
            p("Crosswalk", Vector3.new(17,.08,2.4), CFrame.new(0,.25,side*23+i*3), Theme.Paper)
        end
    end
    -- Loading stripes sit on the ground; no new choke point in container lanes.
    for i=1,6 do
        p("LoadingStripe", Vector3.new(9,.06,1.5), CFrame.new(130+i*9,.06,-38)*CFrame.Angles(0,math.rad(35),0), Theme.Gold)
    end
    -- Small edge accents are too low to masquerade as combat cover.
    for i=1,7 do
        local x,z=-225+i*20,225
        p("ForestStone", Vector3.new(3,.55,2), CFrame.new(x,.1,z), Theme.Paper, Enum.Material.Slate, Enum.PartType.Ball)
        p("ForestFlower", Vector3.new(.8,.5,.8), CFrame.new(x+3,.2,z-2), i%2==0 and Theme.Gold or Theme.Purple, nil, Enum.PartType.Ball)
    end
    -- Existing hill keeps its exact wedge collision. Rock faces remain below its base.
    for i=1,5 do
        p("HillFoot", Vector3.new(12,2,9), CFrame.new(90+i*15,-.65,191), Theme.Slate, Enum.Material.Slate, Enum.PartType.Ball)
    end
    -- Landmark floats above combat: a 12-segment halo and suspended diamond.
    for i=1,12 do
        local angle=(i-1)*math.pi*2/12
        p("CoreHalo", Vector3.new(5.2,.65,1.3), CFrame.new(math.cos(angle)*10,24,math.sin(angle)*10)*CFrame.Angles(0,-angle-math.pi/2,0),
            i%3==0 and Theme.Purple or Theme.Cyan, Enum.Material.Neon)
        p("ArenaMark", Vector3.new(4,.08,.6), CFrame.new(math.cos(angle)*13,.4,math.sin(angle)*13)*CFrame.Angles(0,-angle-math.pi/2,0), Theme.Paper)
    end
    p("EvolutionCore", Vector3.new(3.8,3.8,3.8), CFrame.new(0,24,0)*CFrame.Angles(math.rad(35),0,math.rad(45)), Theme.Cyan, Enum.Material.Neon)
    p("CoreCrown", Vector3.new(1.8,1.8,1.8), CFrame.new(0,28,0)*CFrame.Angles(0,0,math.rad(45)), Theme.Purple, Enum.Material.Neon)
    -- Warm island skirt below the playing surface disguises its slab edge.
    for _, side in ipairs({-1,1}) do
        p("IslandSkirt", Vector3.new(524,6,4), CFrame.new(0,-5,side*259), Theme.Slate)
        p("IslandSkirt", Vector3.new(4,6,524), CFrame.new(side*259,-5,0), Theme.Slate)
    end
    return f
end
return MapVisuals
