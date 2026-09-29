-- Presentation only: none of these values enter movement, ammo or damage rules.
return {
    Weapons = {
        Rifle = {Vertical = .38, Horizontal = .10, Recovery = 18, Kick = .16, Flash = .30, Duration = .045},
        Shotgun = {Vertical = .85, Horizontal = .18, Recovery = 10, Kick = .34, Flash = .52, Duration = .065},
        Pistol = {Vertical = .28, Horizontal = .08, Recovery = 23, Kick = .12, Flash = .24, Duration = .04},
    },
    MaxRecoil = 1.4, MaxHorizontal = .3,
    SprintFov = 5, SlideFov = 6, CameraRecovery = 12,
    CrouchOffset = -.25, SlideOffset = -.4, ReloadTilt = 25,
    PulseDuration = .45, FlashPool = 8, FootstepInterval = .48, SprintFootstepInterval = .32,
}
