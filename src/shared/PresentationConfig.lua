-- Presentation only: none of these values enter movement, ammo or damage rules.
return {
    -- Fixed pools; local shots have reserved capacity so BOT fire cannot evict them.
    TracerPool = 24, LocalTracerPool = 8, ImpactPool = 16, LocalImpactPool = 8,
    TracerLife = .20, RemoteTracerLife = .12, TracerWidth = .13,
    ImpactLife = .42, ImpactHold = .10, ShotgunVisualPellets = 3,
    Weapons = {
        Rifle = {Vertical = .38, Horizontal = .10, Recovery = 18, Kick = .16, Flash = .30, Duration = .045},
        Shotgun = {Vertical = .85, Horizontal = .18, Recovery = 10, Kick = .34, Flash = .52, Duration = .065},
        Pistol = {Vertical = .28, Horizontal = .08, Recovery = 23, Kick = .12, Flash = .24, Duration = .04},
    },
    MaxRecoil = 1.4, MaxHorizontal = .3,
    SprintFov = 5, SlideFov = 6, CameraRecovery = 12,
    AimFov = -6, AimShoulderX = 1.25, AimShoulderY = .12, AimRecovery = 14, MobileCombatAimHold = .70,
    CrouchOffset = -.25, SlideOffset = -.4, ReloadTilt = 25,
    PulseDuration = .45, FlashPool = 8, FootstepInterval = .48, SprintFootstepInterval = .32,
}
