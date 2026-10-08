-- Invoked from visuals.lua with its engine double; executes the real server and
-- client modules. Rendering, physics and replication still require Studio.
return function(check, Visuals, Visibility, workspace, delayed)
    local function avatar(r15)
        local model=Instance.new("Model");model.Parent=workspace
        local names=r15 and {"Head","UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm",
            "LeftLowerArm","RightLowerArm","LeftLowerLeg","RightLowerLeg"}
            or {"Head","Torso","Left Arm","Right Arm","Left Leg","Right Leg"}
        for _,name in ipairs(names) do
            local part=Instance.new("Part");part.Name=name;part.Size=Vector3.new(1.4,1.8,.9);part.Parent=model
        end
        local accessory=Instance.new("Part");accessory.Name="UserAccessory";accessory.CanQuery=true;accessory.Parent=model
        return {model=model,player={},alive=true,humanoid={Health=100},roundId=1,
            evolutionCount=0,evolutionStacks={}},accessory
    end
    local function parts(a)
        local total=0
        for _,record in pairs(a.evolutionVisualParts or {}) do
            total=total+1
            local p=record.part
            check(not p.CanCollide and not p.CanTouch and not p.CanQuery and p.Massless and not p.Anchored,
                "evolution part is outside gameplay physics and queries")
            local weld=p:FindFirstChild("WeldConstraint")
            check(weld and weld.Part0==record.anchor and weld.Part1==p and record.anchor.Parent==a.model,
                "each armor piece follows only its own rig limb")
        end
        return total
    end
    for _,r15 in ipairs({false,true}) do
        local a,accessory=avatar(r15)
        Visuals.initialize(a);Visuals.update(a)
        check(a.evolutionVisualFolder==nil and accessory.Parent==a.model,"zero evolution preserves avatar")
        a.evolutionStacks.SwiftLegs=1;a.evolutionCount=1;Visuals.update(a,"SwiftLegs")
        check(a.model:GetAttribute("DropzoneEvolutionStage")==1 and parts(a)==4,"first evolution adds two mechanical leg drives")
        local drive=a.evolutionVisualParts.SwiftLegsleftLegDrive
        check(drive.anchor.Name==(r15 and "LeftLowerLeg" or "Left Leg"),"leg mapping follows R6/R15 rig")
        local firstWidth=drive.size.X
        local firstGlow=a.evolutionVisualParts.SwiftLegsleftLegRail.transparency
        a.evolutionStacks.SwiftLegs=2;a.evolutionCount=2;Visuals.update(a,"SwiftLegs")
        check(parts(a)==4 and drive.size.X>firstWidth and a.evolutionVisualParts.SwiftLegsleftLegRail.transparency<firstGlow,"same ability grows existing armor without duplicate parts")
        local before=#delayed
        Visuals.update(a,"SwiftLegs")
        local newPulse=a.evolutionVisualFolder:FindFirstChild("EnergyPulse")
        delayed[before]()
        check(newPulse.Parent==a.evolutionVisualFolder,"older pulse callback cannot destroy new pulse")
        a.evolutionStacks.Builder=1;a.evolutionCount=3;Visuals.update(a,"Builder")
        check(a.evolutionVisualParts.BuilderGauntlet.anchor.Name==(r15 and "LeftLowerArm" or "Left Arm"),"Builder attaches to the left arm")
        check(a.evolutionVisualParts.SwiftLegsleftLegDrive==drive and parts(a)==12,
            "different abilities coexist and third evolution adds six chassis pieces")
        a.evolutionStacks.HunterEyes=1;a.evolutionCount=4;Visuals.update(a,"HunterEyes")
        check(a.evolutionVisualParts.HunterEyesVisor.anchor.Name=="Head" and a.model:GetAttribute("DropzoneEvolutionStage")==2,
            "Hunter visor coexists in intermediate stage")
        a.evolutionStacks.Regeneration=1;a.evolutionCount=5;Visuals.update(a,"Regeneration")
        check(a.model:GetAttribute("DropzoneEvolutionStage")==3 and a.evolutionVisualParts.BackUnit and a.evolutionVisualParts.CentralCore,
            "fifth evolution adds heavy chassis, energy towers and central core")
        check(a.evolutionVisualParts.RegenerationCore.part.Color.g==255,"regeneration has a green core")
        local all={"SwiftLegs","IronSkin","HunterEyes","QuickHands","Builder","HighJump","Regeneration","Scavenger","Adrenaline","CombatShield","Overcharge"}
        for _,id in ipairs(all) do a.evolutionStacks[id]=3 end
        a.evolutionCount=33;Visuals.update(a,"Overcharge")
        check(parts(a)==50 and parts(a)<=Visuals.MaxParts,"all abilities at rank III stay within a fixed persistent budget")
        for key,slot in pairs({IronSkinPlate="chest",QuickHandsGauntlet="rightArm",BuilderGauntlet="leftArm",
            HighJumpleftLegBooster="leftLeg",HighJumprightLegBooster="rightLeg",RegenerationCore="chest",
            ScavengerPack1="waist",AdrenalinechestLine="chest",CombatShieldEmitter="chest",OverchargeReactor="chest"}) do
            local mapping={chest=r15 and "UpperTorso" or "Torso",waist=r15 and "LowerTorso" or "Torso",
                rightArm=r15 and "RightLowerArm" or "Right Arm",leftArm=r15 and "LeftLowerArm" or "Left Arm",
                leftLeg=r15 and "LeftLowerLeg" or "Left Leg",rightLeg=r15 and "RightLowerLeg" or "Right Leg"}
            check(a.evolutionVisualParts[key].anchor.Name==mapping[slot],"ability uses correct R6/R15 region: "..key)
        end
        for _,item in ipairs(a.evolutionVisualFolder:GetDescendants()) do
            check(item.ClassName=="Part" or item.ClassName=="WeldConstraint" or item.ClassName=="Highlight",
                "no emitters/lights/trails or external mesh assets in evolution")
        end
        check(accessory.Parent==a.model and accessory.CanQuery,"avatar accessories are preserved")
        -- Local transparency never changes the replicated Transparency.
        local visibility=Visibility.new();visibility:bind(a.model);visibility:step(true)
        local sample=a.evolutionVisualParts.BackUnit.part;local transparency=sample.Transparency
        check(sample.LocalTransparencyModifier==1 and sample.Transparency==transparency and accessory.LocalTransparencyModifier==0,
            "AIM hides only owned local armor and leaves server appearance intact")
        local late=Instance.new("Part");late:SetAttribute("DropzoneEvolutionAdornment",true);late.Parent=a.evolutionVisualFolder
        visibility:step(true)
        check(late.LocalTransparencyModifier==1,"new replicated armor is hidden during ongoing AIM")
        visibility:step(false);check(sample.LocalTransparencyModifier==0,"AIM exit restores armor visibility")
        visibility:step(true);visibility:clear();check(sample.LocalTransparencyModifier==0,"death/results/character replacement restores local transparency")
        local cachedFolder=a.evolutionVisualFolder
        a.alive=false;Visuals.update(a,"IronSkin")
        check(a.evolutionVisualFolder==cachedFolder,"dead player cannot receive new visuals")
        Visuals.stop(a)
        check(not cachedFolder:FindFirstChild("EnergyPulse") and not cachedFolder:FindFirstChild("EvolutionFlash"),"death stops transient effects")
        Visuals.clear(a)
        for _,callback in ipairs(delayed) do callback() end
        check(cachedFolder.Parent==nil and a.evolutionVisualParts==nil and accessory.Parent==a.model,"reset removes owned armor, pending pulses cannot recreate it")
        a.alive=true;a.evolutionCount=0;a.evolutionStacks={};Visuals.update(a)
        check(a.evolutionVisualFolder==nil,"next match starts with no armor")
        a.model:Destroy()
    end
    local bot,accessory=avatar(false);bot.player=nil;bot.evolutionCount=5;bot.evolutionStacks={IronSkin=3}
    local legacy=Instance.new("Folder");legacy.Name="Mutation";legacy.Parent=bot.model
    local soldier=Instance.new("Folder");soldier.Name="DroneShell";soldier.Parent=bot.model
    Visuals.update(bot,"IronSkin")
    check(bot.evolutionVisualFolder==nil and legacy.Parent==nil and soldier.Parent==bot.model and accessory.Parent==bot.model,
        "BOT clears only old Mutation, preserves soldier model and receives no new visual")
    check(bot.evolutionStacks.IronSkin==3,"BOT stats remain untouched by cosmetics")
    local missing=avatar(false);missing.model:ClearAllChildren();missing.evolutionCount=5;missing.evolutionStacks={IronSkin=3}
    Visuals.update(missing,"IronSkin");check(parts(missing)==0,"missing limbs safely skip armor")
    Visuals.clear(missing)
    local subjects={}
    for i=1,Visuals.MaxPulses+2 do
        local a=avatar(false);a.evolutionCount=1;a.evolutionStacks={HunterEyes=1};subjects[i]=a
        Visuals.update(a,"HunterEyes")
    end
    local flashes=0
    for _,a in ipairs(subjects) do if a.evolutionVisualFolder:FindFirstChild("EvolutionFlash") then flashes=flashes+1 end end
    check(flashes==Visuals.MaxPulses,"simultaneous global evolution effects are capped")
    local otherFolder=subjects[2].evolutionVisualFolder
    Visuals.clear(subjects[1]);check(otherFolder.Parent==subjects[2].model,"cleanup cannot remove another player's evolution")
    for _,a in ipairs(subjects) do Visuals.clear(a);a.model:Destroy() end
    bot.model:Destroy();missing.model:Destroy()
    print("PASS: player evolution stages, R6/R15, coexistence, pulse cap, local AIM and reset (engine double)")
end
