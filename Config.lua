return {
	
	--<< DEFAULTS >>--
	WalkSpeed = 16,
	WalkFOV = 70,
	JumpPower = 50,
	MaxStamina = 100,
	
	--<< SPRINTING >>--
	SprintingEnabled = true,
	SprintingAnimationEnabled = true,
	SprintingStaminaEnabled = true,
	SprintingActive = false,
	SprintingKey = Enum.KeyCode.LeftShift,
	SprintingSpeed = 22,
	SprintFOV = 80,
	
	--<< DASHING >>--
	DashingEnabled = true,
	DashCooldown = false,
	DashingActive = false,
	DashCooldownTime = 3,
	DashKey = Enum.KeyCode.Q,
	DashingVelocity = 40,
	
	--<< MOUSE LOCK >>--
	MouseLockEnabled = true,
	MouseLockMultipleKeys = true,
	MouseLockActive = false,
	--<< MouseLockKey = Enum.KeyCode.LeftControl, >>-- (Use this if MouseLockMultipleKeys is false)
	MouseLockKeys = {Enum.KeyCode.LeftControl, Enum.KeyCode.LeftAlt, Enum.KeyCode.RightAlt, Enum.KeyCode.RightShift},
	
	--<< CROUCHING >>--
	CrouchingEnabled = true,
	CrouchingActive = false,
	CrouchingKey = Enum.KeyCode.C,
	CancelCrouchKey = Enum.KeyCode.X,
	CrouchWalkSpeed = 8,
	CrouchHipHeight = 0, --<< -1.5 >>--
	
	--<< PRONING >>--
	ProningEnabled = true,
	ProningActive = false,
	ProneWalkSpeed = 4,
	ProneHipHeight = 0, --<< -2 >>--
	
	--<< SLIDING >>--
	SlidingEnabled = true,
	SlidingMultipleKeys = true,
	SlideCancel = true,
	SlidingActive = false,
	SlidingCooldown = false,
	SlidingCooldownTime = 5,
	SlidingVelocity = 75,
	--<< SlidingKey = Enum.KeyCode.C, >>-- (Use this if SlidingMultipleKeys is false)
	SlidingKeys = {Enum.KeyCode.F},
	SlideCancelKey = Enum.KeyCode.Space,
	SlideHipHeight = {
		Normal = 0,
		Slide = -1.5,
	},
	MaxSlideSpeedMultiplier = 1.6,
	SlideSpeedChangeRate = {
		Forward = 1,
		Up = 1.6,
		Down = 1,
	},
	SlidePushOnCancel = true,
	SlidePushVelocity = {
		Forward = 50,
		Up = 50,
	},
	SlideBaseVolume = 0.5,
	
	--<< VAULTING >>--
	VaultingEnabled = false,
	VaultingMultipleKeys = true,
	VaultingActive = false,
	VaultingAvailable = true,
	VaultingCooldown = false,
	VaultingCooldownTime = 1.5,
	--<< VaultingKey = Enum.KeyCode.Space, >>-- --<< Use this if VaultingMultipleKeys == false >>--
	VaultingKeys = {Enum.KeyCode.E},
	VaultingVelocity = 20,
	
}
