-- Presentation only: none of these values enter movement, ammo or damage rules.
return {
    -- Fire GUI drag: degrees per screen pixel; pitch limit is degrees.
    MobileFireDragSensitivity = .18,
    MobileFireDragVerticalSensitivity = .18,
    MobileFireDragPitchLimit = 80,
    -- Fixed pools; local shots have reserved capacity so BOT fire cannot evict them.
    TracerPool = 24, LocalTracerPool = 8, ImpactPool = 16, LocalImpactPool = 8,
    TracerLife = .20, RemoteTracerLife = .12, TracerWidth = .13,
    ImpactLife = .42, ImpactHold = .10, ShotgunVisualPellets = 3,
    Weapons = {
        Rifle = {
            Vertical = .38, Horizontal = .10, Recovery = 18, Kick = .16, Flash = .30, Duration = .045,
            HipOffset = CFrame.new(0, 0, 0),
            AimOffset = CFrame.new(-.04, .04, .08),
            RightHandTarget = CFrame.new(.48, 1.2, .28), RightHandOffset = CFrame.Angles(math.rad(90), math.rad(90), 0),
            LeftGripPart = "Barrel", LeftGripOffset = CFrame.new(0, 0, .25),
            RightShoulder = CFrame.Angles(math.rad(-58), math.rad(-8), math.rad(14)),
            LeftShoulder = CFrame.Angles(math.rad(-64), math.rad(18), math.rad(-22)),
            Waist = CFrame.Angles(math.rad(-4), math.rad(-7), 0), Neck = CFrame.Angles(math.rad(3), math.rad(7), 0),
        },
        Shotgun = {
            Vertical = .85, Horizontal = .18, Recovery = 10, Kick = .34, Flash = .52, Duration = .065,
            HipOffset = CFrame.new(.02, -.03, .08) * CFrame.Angles(0, 0, math.rad(-2)),
            AimOffset = CFrame.new(-.06, .05, .1),
            RightHandTarget = CFrame.new(.5, 1.2, .3), RightHandOffset = CFrame.Angles(math.rad(90), math.rad(90), 0),
            LeftGripPart = "Pump", LeftGripOffset = CFrame.new(),
            RightShoulder = CFrame.Angles(math.rad(-56), math.rad(-10), math.rad(15)),
            LeftShoulder = CFrame.Angles(math.rad(-70), math.rad(24), math.rad(-27)),
            Waist = CFrame.Angles(math.rad(-5), math.rad(-8), 0), Neck = CFrame.Angles(math.rad(4), math.rad(8), 0),
        },
        Pistol = {
            Vertical = .28, Horizontal = .08, Recovery = 23, Kick = .12, Flash = .24, Duration = .04,
            HipOffset = CFrame.new(0, .04, .12) * CFrame.Angles(math.rad(-3), 0, 0),
            AimOffset = CFrame.new(-.08, .08, .12),
            RightHandTarget = CFrame.new(.42, .85, -.85), RightHandOffset = CFrame.Angles(math.rad(90), math.rad(90), 0),
            LeftGripPart = "Grip", LeftGripOffset = CFrame.new(-.16, .04, -.14),
            RightShoulder = CFrame.new(),
            LeftShoulder = CFrame.new(),
            Waist = CFrame.Angles(math.rad(-3), math.rad(-5), 0), Neck = CFrame.Angles(math.rad(2), math.rad(5), 0),
        },
    },
    MaxRecoil = 1.4, MaxHorizontal = .3,
    SprintFov = 5, SlideFov = 6, CameraRecovery = 12,
    AimFov = -6, AimShoulderX = 1.25, AimShoulderY = .12, AimRecovery = 14, AimTurnRecovery = 16, MobileCombatAimHold = .70,
    CrouchOffset = -.25, SlideOffset = -.4, ReloadTilt = 25,
    PulseDuration = .45, FlashPool = 8, FootstepInterval = .48, SprintFootstepInterval = .32,
}
