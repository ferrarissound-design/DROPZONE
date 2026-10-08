local Layout = assert(loadfile(ROOT.."/src/client/MobileLayout.lua"))()
local count = 0
local function check(v,message) assert(v,message); count=count+1 end
local function overlap(a,b)
    return a[1]<b[1]+b[3] and b[1]<a[1]+a[3] and a[2]<b[2]+b[4] and b[2]<a[2]+a[4]
end
-- Safe content sizes: small landscape, iPhones after insets, tablets, portrait.
for _,size in ipairs({{640,320},{760,360},{844,350},{932,390},{1024,768},{390,760}}) do
    local w,h,scale = Layout.measure(size[1],size[2])
    local buttons = Layout.buttons(w,h)
    for _,mode in ipairs({"Combat","Build"}) do
        local visible = {}
        for name,rect in pairs(buttons) do
            if name ~= "Spectate" and Layout.visible(name,mode) then
                check(rect[1]>=0 and rect[2]>=0 and rect[1]+rect[3]<=w and rect[2]+rect[4]<=h,name.." safe bounds")
                check(not overlap(rect,{w-120,h-120,120,120}),name.." leaves native Jump free")
                check(not overlap(rect,{0,h-120,180,120}),name.." leaves native stick free")
                visible[#visible+1]={name,rect}
            end
        end
        for i,a in ipairs(visible) do
            for j=i+1,#visible do
                check(not overlap(a[2],visible[j][2]),a[1].." overlaps "..visible[j][1])
            end
        end
        if size[1]>=640 then check(buttons.Aim[3]*scale>=48,"landscape primary touch target >=48 px") end
        local draft = {16,104,math.min(w-304,540),132}
        for _,a in ipairs(visible) do check(not overlap(draft,a[2]),"Draft overlaps "..a[1]) end
    end
end
check(not Layout.visible("Fire","Build") and not Layout.visible("Aim","Build"),"build hides combat")
check(not Layout.visible("Wall","Combat") and Layout.visible("Place","Build"),"selection/placement are mode-specific")
print("PASS: "..count.." adaptive mobile layout assertions (geometry only)")
