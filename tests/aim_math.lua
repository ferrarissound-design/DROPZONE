-- Numeric engine doubles, not fixed LookVectors. Roblox engine playtest remains
-- separate. Basis columns follow Roblox's right/up/back (-Z forward) convention.
return function(Vector3)
    local function cross(a,b)
        return Vector3.new(a.Y*b.Z-a.Z*b.Y,a.Z*b.X-a.X*b.Z,a.X*b.Y-a.Y*b.X)
    end
    local zero=Vector3.new(0,0,0)
    local frame={}
    frame.__index=frame
    local function make(p,r,u,b)
        return setmetatable({Position=p,RightVector=r,UpVector=u,BackVector=b,LookVector=b*-1},frame)
    end
    function frame:VectorToWorldSpace(v)
        return self.RightVector*v.X+self.UpVector*v.Y+self.BackVector*v.Z
    end
    function frame:Inverse()
        local r,u,b=self.RightVector,self.UpVector,self.BackVector
        local inv=make(zero,Vector3.new(r.X,u.X,b.X),Vector3.new(r.Y,u.Y,b.Y),Vector3.new(r.Z,u.Z,b.Z))
        inv.Position=inv:VectorToWorldSpace(self.Position)*-1
        return inv
    end
    frame.__mul=function(a,b)
        return make(a.Position+a:VectorToWorldSpace(b.Position),a:VectorToWorldSpace(b.RightVector),
            a:VectorToWorldSpace(b.UpVector),a:VectorToWorldSpace(b.BackVector))
    end
    local CFrame={}
    function CFrame.lookAt(p,target)
        local back=(p-target).Unit
        local up=math.abs(back.Y)>.9999 and Vector3.new(0,0,1) or Vector3.new(0,1,0)
        local right=cross(up,back).Unit
        return make(p,right,cross(back,right),back)
    end
    function CFrame.Angles(x,y,z)
        local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
        local rx=make(zero,Vector3.new(1,0,0),Vector3.new(0,cx,sx),Vector3.new(0,-sx,cx))
        local ry=make(zero,Vector3.new(cy,0,-sy),Vector3.new(0,1,0),Vector3.new(sy,0,cy))
        local rz=make(zero,Vector3.new(cz,sz,0),Vector3.new(-sz,cz,0),Vector3.new(0,0,1))
        return rx*ry*rz
    end
    return CFrame
end
