-- Presentation only: none of these values enter movement, ammo or damage rules.
return {
    Weapons = {
        Rifle = {Vertical = .52, Horizontal = .12, Recovery = 16, Kick = .22, Flash = .42, Duration = .07},
        Shotgun = {Vertical = 1.00, Horizontal = .20, Recovery = 9, Kick = .42, Flash = .68, Duration = .09},
        Pistol = {Vertical = .38, Horizontal = .09, Recovery = 20, Kick = .17, Flash = .34, Duration = .06},
    },
    MaxRecoil = 1.4, MaxHorizontal = .3,
    SprintFov = 5, SlideFov = 6, CameraRecovery = 12,
    AimFov = -6, AimShoulderX = 1.25, AimShoulderY = .12, AimRecovery = 14, MobileCombatAimHold = .70,
    CrouchOffset = -.25, SlideOffset = -.4, ReloadTilt = 25,
    PulseDuration = .45, FlashPool = 8, FootstepInterval = .48, SprintFootstepInterval = .32,
}
