--<< Roblox: IHaveAGreatNameToPut, Discord: ihaveagreatnametoput, GitHub: IHaveAGreatNameToPut >>--
--<< IHAVEAGREATNAMETOPUT'S CUSTOM MOVEMENT SYSTEM >>--
--<< SERVICES >>--
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

--<< VARIABLES >>--
local player, mouse, camera, character, humanoid, humanoidRootPart, rootJoint, rootC0, animator = nil, nil, nil, nil, nil, nil
local dashAnimation, dashBackAnimation, dashLeftAnimation, dashRightAnimation = nil, nil, nil, nil
local slideAnimation, slideBackAnimation, slideLeftAnimation, slideRightAnimation = nil, nil, nil, nil
local crouchAnimation, crouchWalkAnimation, proneAnimation, proneWalkAnimation = nil, nil, nil, nil
local positionCheck = nil
local sprintAnimation = nil
local mouseLockSpring = nil
local slideVelocity, dashVelocity, alignGyro = nil, nil
local previousY = nil
local currentMultiplier = 1
local params = RaycastParams.new(); params.FilterDescendantsInstances = {character}; params.FilterType = Enum.RaycastFilterType.Exclude

local staminaTick = 0
local tiltCF = CFrame.new()

local Miscellaneous = ReplicatedStorage:WaitForChild("Miscellaneous", 9e9)
local Audio = Miscellaneous:WaitForChild("Audio", 9e9); local MovementAudio = Audio:WaitForChild("Movement", 9e9)
local Animations = Miscellaneous:WaitForChild("Animations", 9e9)

local Spring = _G.Require("Spring")
local Math = _G.Require("Math")
local Config = require(script:WaitForChild("Config", 9e9))

--<< FUNCTIONS >>--
local MovementHandler = {}

--<< Checks if the player is in first person via their camera focus. If it's under 1, they are in first person. If it's above 1, they are not. Returns the result as a boolean >>--
local function IsInFirstPerson() return (camera.Focus.Position - camera.CFrame.Position).Magnitude <= 1 end

--<< This function is used to cancel a slide. It's used when a player presses the keybind (currently Space), and when the user sliding is no longer moving as they lost all momentum >>--
local function CancelSlide()
	
	--<< Play the slide cancel audio, and stop playing the sliding audio >>--
	MovementAudio:WaitForChild("Sliding"):WaitForChild("Cancel", 9e9):Play()
	MovementAudio:WaitForChild("Sliding"):WaitForChild("Sliding", 9e9):Stop()
	
	--<< Resets the SlidingActive value inside Config >>--
	Config.SlidingActive = false
	if slideVelocity then slideVelocity:Destroy() end --<< Destroys the velocity the slide created, to stop applying force >>--
	
	if humanoidRootPart:FindFirstChild("SlideAttachment") then humanoidRootPart.SlideAttachment:Destroy() end --<< Attempts to find the "SlideAttachment" attachment inside the HumanoidRootPart. I created this attachment when the user started sliding, as it's necessary for the LinearVelocity. If found, I destroy it >>--
	if alignGyro then alignGyro:Destroy() end --<< Attempts to find the BodyAlignGyro, which I created when the user started sliding, so if they are going down a ramp, for example, they will be stuck to it >>--
	if positionCheck and typeof(positionCheck) == "RBXScriptConnection" then positionCheck:Disconnect() end --<< Finds the PositionCheck connection, and disconnects it >>--
	
	--<< Stops all of the sliding animations >>--
	slideAnimation:Stop(0.15)
	slideBackAnimation:Stop(0.15)
	slideRightAnimation:Stop(0.15)
	slideLeftAnimation:Stop(0.15)
	
	--<< Resets the HipHeight >>--
	humanoid.HipHeight = Config.SlideHipHeight.Normal
	
end

--<< Handling the position check every frame a slide or dash is running. It ensures a slide/dash is following the player's camera as it turns, aligns the player to a ramp, floor, or anything below them. If the user is sliding, then it will adjust the speed based on whether they're moving up or down >>--
local function HandlePositionCheck(deltaTime, t, lookOrRight, v) --<< deltaTime, type ("Dash", "Sliding"), lookOrRight ("LookVector", "RightVector"), value >>--
	
	--<< Create a Raycast hitting anything 10 studs below the player (this allows us to see if the player is going down a ramp) >>--
	local rayDirection = -humanoidRootPart.CFrame.UpVector * 10
	local groundRay = workspace:Raycast(humanoidRootPart.Position, rayDirection, params) --<< Utilize the raycast >>--
	
	if groundRay then --<< The raycast hit something, make sure the player stays on it for the duration of the slide >>--
		
		local currentRightVector = humanoidRootPart.CFrame.RightVector
		local upVector = groundRay.Normal --<< The hit objects up direction. On a ramp, on the floor, etc >>--
		local newFacialVector = currentRightVector:Cross(upVector) --<< Returns a vector perpendicular to both, used as the new forward so the alignment works with the player's current facing >>--
		
		--<< Aligns the player to the surface they are on. Tilts them if they are on a ramp, lays them flat if they are not. >>--
		alignGyro.CFrame = CFrame.fromMatrix(humanoidRootPart.Position, currentRightVector, upVector, newFacialVector)
		
	end
	
	local veloToChange = t == "Dash" and dashVelocity or slideVelocity --<< Select the correct velocity to apply the changes to >>--
	local currentY = humanoidRootPart.Position.Y
	local verticalChange = (currentY - previousY); previousY = currentY --<< Compares this frame's height with the last frame's height to get the slope direction >>--
	
	--<< Update the LinearVelocity when the camera turns, so the slide goes in the direction the player is facing >>--
	veloToChange.VectorVelocity = camera.CFrame[lookOrRight] * v
	
	if verticalChange < 0.1 and verticalChange > -0.1 then --<< The user is going forward, the speed will drop at the default speed >>--
		
		if currentMultiplier > 1 then currentMultiplier = math.clamp(currentMultiplier - (Config.SlideSpeedChangeRate.Forward * 2) * deltaTime, 0, Config.MaxSlideSpeedMultiplier) end
		currentMultiplier = math.clamp(currentMultiplier - Config.SlideSpeedChangeRate.Forward * deltaTime, 0, Config.MaxSlideSpeedMultiplier)
		
	elseif verticalChange > 0 then --<< The user is going up, the slide will drop faster >>--
		
		if currentMultiplier > 1 then currentMultiplier = math.clamp(currentMultiplier - (Config.SlideSpeedChangeRate.Forward * 2) * deltaTime, 0, Config.MaxSlideSpeedMultiplier) end
		currentMultiplier = math.clamp(currentMultiplier - Config.SlideSpeedChangeRate.Up * deltaTime, 0, Config.MaxSlideSpeedMultiplier)
		
	else ---<< The user is going down, the slide will speed up >>--
		
		currentMultiplier = math.clamp(currentMultiplier + Config.SlideSpeedChangeRate.Down * deltaTime, 0, Config.MaxSlideSpeedMultiplier)
		
	end
	
	currentMultiplier = math.clamp(currentMultiplier, 0, Config.MaxSlideSpeedMultiplier) --<< Ensures the player isn't going above the max slide speed >>--
	MovementAudio:WaitForChild("Sliding"):WaitForChild("Sliding", 9e9).Volume = (Config.SlideBaseVolume * currentMultiplier) --<< Changes the volume of the slide sound based on the player's sliding speed >>--
	
	if (currentMultiplier < 0.1 or not groundRay) and t == "Slide" then --<< End the slide when there's not enough speed to continue >>--
		
		CancelSlide()
		
	end
	
end

--<< Create the velocity to apply force to the user's HumanoidRootPart, so they will be pushed. (Sliding, dashing) >>--
local function CreateVelocity(dashing: boolean, lookVector: boolean, velocity)
	
	--<< Create an attachment inside the HumanoidRootPart for LinearVelocity >>--
	local attachment = Instance.new("Attachment"); attachment.Parent = humanoidRootPart; if not dashing then attachment.Name = "SlideAttachment" end
	
	if dashing then --<< The user is dashing, create the velocity >>--
		
		dashVelocity = Instance.new("LinearVelocity")
		dashVelocity.Attachment0 = attachment
		dashVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		dashVelocity.MaxAxesForce = Vector3.new(1e5, 0, 1e5)
		dashVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
		dashVelocity.VectorVelocity = lookVector == true and camera.CFrame.LookVector * velocity or camera.CFrame.RightVector * velocity
		dashVelocity.Parent = humanoidRootPart
		
		Debris:AddItem(dashVelocity, 0.3); Debris:AddItem(attachment, 0.3)
		positionCheck = RunService.RenderStepped:Connect(function(deltaTime) dashVelocity.VectorVelocity = lookVector == true and camera.CFrame.LookVector * velocity or camera.CFrame.RightVector * velocity end)
		
	else --<< The user is sliding. Create the velocity for that instead >>--
		
		slideVelocity = Instance.new("LinearVelocity")
		slideVelocity.Attachment0 = attachment
		slideVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		slideVelocity.MaxAxesForce = Vector3.new(1e5, 0, 1e5)
		slideVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
		slideVelocity.VectorVelocity = lookVector == true and camera.CFrame.LookVector * velocity or camera.CFrame.RightVector * velocity
		slideVelocity.Parent = humanoidRootPart
		
		positionCheck = RunService.RenderStepped:Connect(function(deltaTime) HandlePositionCheck(deltaTime, "Slide", lookVector == true and "LookVector" or "RightVector", velocity) end)
		
	end
	
end

--<< Handle the dashing. Plays the animations, creates the velocity >>--
local function HandleDashVelocity()
	
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then --<< The user is holding W, send them forward >>--
		
		dashAnimation:Play() --<< Plays the dash animation >>--
		CreateVelocity(true, true, Config.DashingVelocity) --<< Dashing = true, LookVector = true, Config.DashingVelocity >>--
		
	elseif UserInputService:IsKeyDown(Enum.KeyCode.S) then --<< The user is holding S, send them backward >>--
		
		dashBackAnimation:Play() --<< Plays the back-dash animation >>--
		CreateVelocity(true, true, -Config.DashingVelocity) --<< Dashing = true, LookVector = true, -Config.DashingVelocity >>--
		
	elseif UserInputService:IsKeyDown(Enum.KeyCode.A) then --<< The user is holding A, send them left >>--
		
		dashLeftAnimation:Play() --<< Plays the left-dash animation >>--
		CreateVelocity(true, false, -Config.DashingVelocity) --<< Dashing = true, LookVector = false, -Config.DashingVelocity >>--
		
	elseif UserInputService:IsKeyDown(Enum.KeyCode.D) then --<< The user is holding D, send them right >>--
		
		dashRightAnimation:Play() --<< Plays the right-dash animation >>--
		CreateVelocity(true, false, Config.DashingVelocity) --<< Dashing = true, LookVector = false, Config.DashingVelocity >>--
		
	else --<< The user isn't holding a key, send them forward >>--
		
		dashAnimation:Play() --<< Play the dash animation >>--
		CreateVelocity(true, true, Config.DashingVelocity) --<< Dashing = true, LooKVector = true, Config.DashingVelocity >>--
		
	end
	
end

--<< Handle the sliding. Plays the animations, creates the velocity, sets the HipHeight >>--
local function HandleSlideVelocity()
	
	--<< It's the same thing as HandleDashVelocity(), but it sets the hipheight, plays different animations, and uses a different Velocity >>--
	
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		
		slideAnimation:Play(0.15)
		humanoid.HipHeight = Config.SlideHipHeight.Slide
		CreateVelocity(false, true, (Config.SlidingVelocity * currentMultiplier))
		
	elseif UserInputService:IsKeyDown(Enum.KeyCode.S) then
		
		slideBackAnimation:Play(0.15)
		humanoid.HipHeight = Config.SlideHipHeight.Slide
		CreateVelocity(false, true, (-Config.SlidingVelocity * currentMultiplier))
		
	elseif UserInputService:IsKeyDown(Enum.KeyCode.A) then
		
		slideLeftAnimation:Play(0.15)
		humanoid.HipHeight = Config.SlideHipHeight.Slide
		CreateVelocity(false, false, (-Config.SlidingVelocity * currentMultiplier))
		
	elseif UserInputService:IsKeyDown(Enum.KeyCode.D) then
		
		slideRightAnimation:Play(0.15)
		humanoid.HipHeight = Config.SlideHipHeight.Slide
		CreateVelocity(false, false, (Config.SlidingVelocity * currentMultiplier))
		
	else
		
		slideAnimation:Play(0.15)
		humanoid.HipHeight = Config.SlideHipHeight.Slide
		CreateVelocity(false, true, (Config.SlidingVelocity * currentMultiplier))
		
	end
	
end

--<< Toggles the MouseLock (ShiftLock) >>--
local function ToggleMouseLock(enabled: boolean)
	
	--<< The humanoid isn't alive, can't toggle MouseLock. >>--
	if humanoid.Health <= 0 then return end
	
	Config.MouseLockActive = enabled --<< Kind of self-explanatory in my opinion. >>--
	
	if enabled then --<< enabled == true >>--
		
		mouseLockSpring.t = Vector3.new(2, 0, 0) --<< MouseLockSpring. A RenderStepped loop checks this every few seconds, and sets the camera CFrame based on it >>--
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter --<< Lock the mouse to the center of the screen, so the user can't move it >>--
		mouse.Icon = "rbxasset://textures/MouseLockedCursor.png" --<< Changes the mouse icon to the MouseLocked icon >>--
		
	else --<< enabled == false >>--
		
		mouseLockSpring.t = Vector3.new(0, 0, 0) --<< Resets the MouseLockSpring to 0, so the camera is back to default >>--
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default --<< Resets the MouseBehavior to default, so the player can move their mouse again >>--
		mouse.Icon = "" --<< Resets the mouse icon >>--
		
	end
	
end

--<< Change the crouch state. C = crouch. C while crouching = prone >>--
local function Crouch()
	
	local crouchType
	local isCrouching = Config.CrouchingActive --<< Is the user already crouching >>--
	
	if Config.CrouchingEnabled and Config.ProningEnabled then --<< Both enabled, do whichever is next >>--
		
		--<< Player is crouching & Proning is enabled, the user will prone >>--
		if isCrouching and Config.ProningEnabled then crouchType = "Prone" else crouchType = "Crouch" end
		
		if crouchType == "Crouch" then --<< Either user was standing, or proning was disabled. User will crouch >>--
			
			proneAnimation:Stop(0.2) --<< Stop the proning animation >>--
			crouchAnimation:Play(0.2) --<< Play the crouching animation >>--
			TweenService:Create(humanoid, TweenInfo.new(0.3), {HipHeight = Config.CrouchHipHeight}):Play() --<< Tweens the HipHeight to the CrouchHipHeight >>--
			
			Config.ProningActive = false --<< Proning is no longer active >>--
			Config.CrouchingActive = true --<< Crouching is now active >>--
			
		elseif crouchType == "Prone" then --<< User was crouching & proning is enabled. User will prone >>--
			
			crouchAnimation:Stop(0.2) --<< Stops the crouching animation >>--
			proneAnimation:Play(0.2) --<< Play the proning animation >>--
			TweenService:Create(humanoid, TweenInfo.new(0.3), {HipHeight = Config.ProneHipHeight}):Play() --<< Tweens the HipHeight to the ProneHipHeight >>--
			
			Config.CrouchingActive = false --<< Crouching is no longer active >>--
			Config.ProningActive = true --<< Proning is now active >>--
			
		end
		
	elseif Config.ProningEnabled then --<< Crouching is disabled but proning is enabled >>--
		
		crouchAnimation:Stop(0.2) --<< Stop the crouch animation >>--
		proneAnimation:Play(0.2) --<< Start the prone animation >>--
		TweenService:Create(humanoid, TweenInfo.new(0.3), {HipHeight = Config.ProneHipHeight}):Play() --<< Tweens the HipHeight to the ProneHipHeight >>--
		
		Config.CrouchingActive = false --<< Crouching is no longer active >>--
		Config.ProningActive = true --<< Proning is now active >>--
		
	end
	
end

--<< Stop crouching/proning. If the user is proning, and crouching is enabled, it will make them crouch. If the user is crouching, they will stand, etc >>--
local function StopCrouching()
	
	if Config.ProningActive and Config.CrouchingEnabled then --<< User is proning, toggle to crouch >>--
		
		proneAnimation:Stop(0.2)
		crouchAnimation:Play(0.2)
		
		TweenService:Create(humanoid, TweenInfo.new(0.3), {HipHeight = Config.CrouchHipHeight}):Play()
		
		Config.ProningActive = false
		Config.CrouchingActive = true
		
	elseif Config.ProningActive and not Config.CrouchingEnabled then
		
		proneAnimation:Stop(0.2)
		TweenService:Create(humanoid, TweenInfo.new(0.3), {HipHeight = 0}):Play()
		
		Config.ProningActive = false
		Config.CrouchingActive = false
		
	elseif Config.CrouchingActive then --<< User is crouching, toggle to standing >>--
		
		crouchAnimation:Stop(0.2)
		TweenService:Create(humanoid, TweenInfo.new(0.3), {HipHeight = 0}):Play()
		
		Config.ProningActive = false
		Config.CrouchingActive = false
		
	end
	
end

--<< Player is pressing a key, if the key is found in Config, it will do the respective action. For example, if the user is holding Shift, it will sprint >>--
local function HandleInputBegan(input: InputObject, gameProcessed: boolean)
	
	if gameProcessed then return end --<< The user is typing, in a menu, or something else has processed this request >>--
	
	--<< User clicked the dash key, dashing is enabled & not on cooldown, the user is not sliding, crouching, or proning >>--
	if input.KeyCode == Config.DashKey and (Config.DashingEnabled == true and (Config.DashCooldown == false) and (not Config.SlidingActive and not Config.CrouchingActive and not Config.ProningActive)) then
		
		if Config.DashingActive then return end --<< The user is currently dashing >>--
		if positionCheck and typeof(positionCheck) == "RBXScriptConnection" then positionCheck:Disconnect() end --<< Disconnects the position checker >>--
		
		Config.DashingActive = true; task.delay(0.8, function() Config.DashingActive = false end) --<< Enables DashingActive, waits the cooldown, and disables it again >>--
		Config.DashCooldown = true; task.delay(Config.DashCooldownTime, function() Config.DashCooldown = false end) --<< Enables the cooldown, waits the cooldown time, then disables it again >>--
		
		--<< Plays the dashing sound >>--
		MovementAudio:WaitForChild("Dashing", 9e9):WaitForChild("Dash", 9e9):Play(); task.delay(0.3, function() MovementAudio:WaitForChild("Dashing", 9e9) :WaitForChild("Dash", 9e9):Stop() end)
		
		currentMultiplier = 1 --<< Resets the current speed multiplier >>--
		HandleDashVelocity() --<< Handles dashing velocity >>--
		
		--<< Waits the animation lengths, then stops the animation >>--
		task.delay(0.3, function() dashAnimation:Stop() end)
		task.delay(dashBackAnimation.Length, function() dashBackAnimation:Stop() end)
		task.delay(dashLeftAnimation.Length, function() dashLeftAnimation:Stop() end)
		task.delay(dashRightAnimation.Length, function() dashRightAnimation:Stop() end)
		
		--<< Sliding is enabled, user is not dashing, crouching, or proning. Config allows multiple sliding keys, so I check to see the input is one of them. If it is, slide. If not, continue looking for the input. If there is only 1 key, use that instead >>--
	elseif Config.SlidingEnabled == true and (not Config.DashingActive and not Config.CrouchingActive and not Config.ProningActive) and (Config.SlidingMultipleKeys == true and table.find(Config.SlidingKeys, input.KeyCode) or (not Config.SlidingMultipleKeys and input.KeyCode == Config.SlidingKey)) then
		
		--<< User is on cooldown, currently sliding, or dashing >>--
		if Config.SlidingCooldown == true then return end; if Config.SlidingActive == true then return end; if Config.DashingActive == true then return end
		if positionCheck and typeof(positionCheck) == "RBXScriptConnection" then positionCheck:Disconnect() end
		
		local rayDirection = -humanoidRootPart.CFrame.UpVector * 5 --<< Creates a raycast 5 studs below the HumanoidRootPart >>--
		local groundRay = workspace:Raycast(humanoidRootPart.Position, rayDirection, params) --<< Checks if it hits anything >>--
		
		Config.SlidingActive = true; task.delay(0.8, function() Config.SlidingActive = false end) --<< Enables sliding active, waits the cooldown, disables it again >>--
		Config.SlidingCooldown = true; task.delay(Config.SlidingCooldownTime, function() Config.SlidingCooldown = false end) --<< Enables the sliding cooldown, waits the cooldown, disables it again >>--
		
		--<< Creates the BodyGyro used to align the player to a ramp / the floor, then sets its properties >>--
		alignGyro = Instance.new("BodyGyro"); alignGyro.Parent = humanoidRootPart; alignGyro.MaxTorque = Vector3.new(3e5, 3e5, 3e5); alignGyro.P = 10000
		
		--<< Plays the sliding audio >>--
		MovementAudio:WaitForChild("Sliding", 9e9):WaitForChild("Sliding", 9e9):Play()
		
		currentMultiplier = 1 --<< Resets the current speed multiplier >>--
		HandleSlideVelocity() --<< Creates the sliding velocity >>--
		
		--<< Cancel the slide, the user clicked Space / the configured sliding key >>--
	elseif input.KeyCode == Config.SlideCancelKey and Config.SlidingActive then
		
		local cancelMultiplier = currentMultiplier
		CancelSlide()
		
		--<< Applies force to the HumanoidRootPart when a slide is cancelled, so they get sent slightly forward >>--
		if Config.SlidePushOnCancel == true then
			
			local attachment = Instance.new("Attachment"); attachment.Parent = humanoidRootPart
			local pushVelocity = Instance.new("LinearVelocity"); pushVelocity.Attachment0 = attachment
			
			pushVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			pushVelocity.MaxAxesForce = Vector3.new(1e5, 1e5, 1e5)
			pushVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
			pushVelocity.VectorVelocity = (humanoidRootPart.CFrame.LookVector * (Config.SlidePushVelocity.Forward * cancelMultiplier)) + (humanoidRootPart.CFrame.UpVector * Config.SlidePushVelocity.Up)
			pushVelocity.Parent = humanoidRootPart
			
			Debris:AddItem(pushVelocity, 0.1) --<< Removed after 0.1 seconds >>--
			
		end
		
		--<< The user pressed the sprinting key, sprinting is enabled, the user isn't crouching or proning >>--
	elseif input.KeyCode == Config.SprintingKey and (Config.SprintingEnabled == true and not Config.CrouchingActive and not Config.ProningActive) then
		
		Config.SprintingActive = true --<< Shows the sprinting is active >>--
		if sprintAnimation and humanoid.MoveDirection.Magnitude > 0 then sprintAnimation:Play() end --<< Plays the sprint animation if the player is moving >>--
		
		--<< User pressed the crouch key, toggle crouch/prone >>--
	elseif input.KeyCode == Config.CrouchingKey and (Config.CrouchingEnabled or Config.ProningEnabled) then
		
		Crouch()
		
		--<< User pressed the CancelCrouch key, stop crouching/proning >>--
	elseif input.KeyCode == Config.CancelCrouchKey and (Config.CrouchingEnabled or Config.ProningEnabled) then
		
		StopCrouching()
		
		--<< MouseLock is enabled, has multiple keys and the input is one of them. Or, it is enabled, has 1 key, and the input is that key. >>--
	elseif Config.MouseLockEnabled == true and (Config.MouseLockMultipleKeys == true and table.find(Config.MouseLockKeys, input.KeyCode) or (not Config.MouseLockMultipleKeys and input.KeyCode == Config.MouseLockKey)) then
		
		--<< Toggles the MouseLock >>--
		if Config.MouseLockActive then ToggleMouseLock(false) else ToggleMouseLock(true) end
		
	end
	
end

--<< Input has ended >>--
local function HandleInputEnded(input: InputObject, gameProcessed: boolean)
	
	if gameProcessed then return end
	
	--<< User stopped holding the sprint key, stop sprinting >>--
	if input.KeyCode == Config.SprintingKey then
		
		Config.SprintingActive = false
		if sprintAnimation then sprintAnimation:Stop() end
		
	end
	
end

--<< Make the body visible in first person, and changes the camera slightly so the user can see their body when they look down >>--
local function HandleFirstPersonBody(character: Model)
	
	local invisibleParts = {}; local visibleParts = {}; local decals = {} --<< All parts to make invisible, visible, and any found decals >>--
	
	for _, desc in ipairs(character:GetDescendants()) do --<< Gets all the descendants of the characters once >>--
		
		if desc:IsA("BasePart") then --<< The descendant is a BasePart, possibly a limb or the Handle of an accessory >>--
			
			if desc.Name == "Head" or desc:FindFirstAncestorOfClass("Accessory") then --<< It's the head or an accessory, make it invisible upon using first person >>--
				
				table.insert(invisibleParts, desc)
				
			else --<< Not the head or an accessory, visible on first person >>--
				
				table.insert(visibleParts, desc)
				
			end
			
		elseif desc:IsA("Decal") then --<< Decal (probably face) >>--
			
			table.insert(decals, desc)
			
		end
		
	end
	
	RunService.RenderStepped:Connect(function(deltaTime: number)
		
		if IsInFirstPerson() then --<< The user is in first person, make the head invisible, accessories invisible, and all other body parts visible >>--
			
			for _, part in ipairs(invisibleParts) do part.LocalTransparencyModifier = 1 end
			for _, part in ipairs(visibleParts) do part.LocalTransparencyModifier = 0 end
			for _, decal in ipairs(decals) do decal.Transparency = 1 end
			
			--<< Slight camera offset so it looks a little bit more realistic >>--
			humanoid.CameraOffset = Vector3.new(0, 0, -1)
			
		else
			
			--<< Removes the offset upon leaving first person, and makes the face visible again >>--
			humanoid.CameraOffset = Vector3.new(0, 0, 0); for _, decal in ipairs(decals) do decal.Transparency = 0 end
			
		end
		
	end)
	
end

--<< A player was added to the game. Wait for their character to fully load, then handle the first person body >>--
function MovementHandler:__PlayerAdded(plr: Player) if plr == player then player.CharacterAppearanceLoaded:Connect(function(character: Model) HandleFirstPersonBody(character) end) end end

--<< Called upon game starting, assigns all of the variables, calls all of the functions >>--
function MovementHandler:__init(): ()
	
	if not RunService:IsClient() then return end --<< This script is being ran by the server, return >>--
	
	player = Players.LocalPlayer --<< The player >>--
	camera = workspace.CurrentCamera --<< The player's camera >>--
	mouse = player:GetMouse() --<< The player's mouse >>--
	
	--<< The character and all it's required parts >>--
	character = player.Character or player.CharacterAdded:Wait(); player.CharacterAdded:Connect(function(char: Model) character = char humanoid = char:WaitForChild("Humanoid", 9e9) humanoid:SetAttribute("Stamina", Config.MaxStamina) humanoid:SetAttribute("CanSprint", true) humanoidRootPart = char:WaitForChild("HumanoidRootPart", 9e9) animator = humanoid:FindFirstChild("Animator") or Instance.new("Animator") animator.Parent = humanoid end)
	humanoid = character:FindFirstChild("Humanoid"); if not humanoid then repeat task.wait() humanoid = character:FindFirstChild("Humanoid") until humanoid or not character.Parent end
	humanoidRootPart = character:FindFirstChild("HumanoidRootPart"); if not humanoidRootPart then repeat task.wait() humanoidRootPart = character:FindFirstChild("HumanoidRootPart") until humanoidRootPart end
	rootJoint = humanoidRootPart:WaitForChild("RootJoint", 9e9); rootC0 = rootJoint.C0
	animator = humanoid:FindFirstChild("Animator") or Instance.new("Animator"); animator.Parent = humanoid
	
	--<< All of the animations required for this script >>--
	dashAnimation = animator:LoadAnimation(Animations:WaitForChild("Dashing", 9e9):WaitForChild("Dash", 9e9)); dashAnimation.Priority = Enum.AnimationPriority.Action4
	dashBackAnimation = animator:LoadAnimation(Animations:WaitForChild("Dashing", 9e9):WaitForChild("DashBack", 9e9)); dashBackAnimation.Priority = Enum.AnimationPriority.Action4
	dashLeftAnimation = animator:LoadAnimation(Animations:WaitForChild("Dashing", 9e9):WaitForChild("DashLeft",9e9)); dashLeftAnimation.Priority = Enum.AnimationPriority.Action4
	dashRightAnimation = animator:LoadAnimation(Animations:WaitForChild("Dashing", 9e9):WaitForChild("DashRight", 9e9)); dashRightAnimation.Priority = Enum.AnimationPriority.Action4
	
	slideAnimation = animator:LoadAnimation(Animations:WaitForChild("Sliding", 9e9):WaitForChild("Slide", 9e9)); slideAnimation.Priority = Enum.AnimationPriority.Action4
	slideBackAnimation = animator:LoadAnimation(Animations:WaitForChild("Sliding", 9e9):WaitForChild("SlideBack", 9e9)); slideBackAnimation.Priority = Enum.AnimationPriority.Action4
	slideLeftAnimation = animator:LoadAnimation(Animations:WaitForChild("Sliding", 9e9):WaitForChild("SlideLeft",9e9)); slideLeftAnimation.Priority = Enum.AnimationPriority.Action4
	slideRightAnimation = animator:LoadAnimation(Animations:WaitForChild("Sliding", 9e9):WaitForChild("SlideRight", 9e9)); slideRightAnimation.Priority = Enum.AnimationPriority.Action4
	
	sprintAnimation = Config.SprintingAnimationEnabled and animator:LoadAnimation(Animations:WaitForChild("Sprinting", 9e9):WaitForChild("Sprint", 9e9))
	crouchAnimation = animator:LoadAnimation(Animations:WaitForChild("Crouching", 9e9):WaitForChild("CrouchIdle", 9e9))
	crouchWalkAnimation = animator:LoadAnimation(Animations:WaitForChild("Crouching", 9e9):WaitForChild("CrouchWalk", 9e9))
	proneAnimation = animator:LoadAnimation(Animations:WaitForChild("Crouching", 9e9):WaitForChild("ProneIdle", 9e9))
	proneWalkAnimation = animator:LoadAnimation(Animations:WaitForChild("Crouching", 9e9):WaitForChild("ProneWalk", 9e9))
	
	--<< MouseLockSpring, used for ShiftLock camera >>--
	mouseLockSpring = Spring.new(Vector3.new())
	mouseLockSpring.s = 12
	mouseLockSpring.d = 0.4
	
	previousY = 0
	
	--<< Sets the WalkSpeed to whatever the config sets. Sets the stamina up, and decides if the player can sprint >>--
	humanoid.WalkSpeed = Config.WalkSpeed; humanoid:SetAttribute("Stamina", Config.MaxStamina); humanoid:SetAttribute("CanSprint", true)
	
	--<< Input began / ended, call the functions >>--
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean) HandleInputBegan(input, gameProcessed) end)
	UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessed: boolean) HandleInputEnded(input, gameProcessed) end)
	
	--<< Runs every frame >>--
	RunService.RenderStepped:Connect(function(deltaTime: number)
		
		local canSprint = (not Config.SprintingStaminaEnabled) or (humanoid:GetAttribute("Stamina") > 0.1) --<< The user has enough stamina to sprint >>--
		local isSprinting = Config.SprintingActive == true and humanoid.MoveDirection.Magnitude > 0 and humanoid:GetAttribute("CanSprint") and Config.SprintingEnabled == true and Config.CrouchingActive == false and Config.ProningActive == false and canSprint --<< The user can sprint >>--
		local isCrouching = Config.CrouchingActive == true and humanoid.MoveDirection.Magnitude > 0 and Config.CrouchingEnabled == true and Config.SprintingActive == false and Config.ProningActive == false --<< The user can crouch >>--
		local isProning = Config.ProningActive == true and humanoid.MoveDirection.Magnitude > 0 and Config.ProningEnabled == true and Config.SprintingActive == false and Config.CrouchingActive == false --<< The user can prone >>--
		
		--<< Setup the walking animations (Sprinting, Crouching, Proning) >>--
		if sprintAnimation then if isSprinting and not sprintAnimation.IsPlaying then sprintAnimation:Play(0.15) elseif not isSprinting and sprintAnimation.IsPlaying then sprintAnimation:Stop(0.15) end end
		if crouchWalkAnimation then if isCrouching and not crouchWalkAnimation.IsPlaying then crouchWalkAnimation:Play(0.15) elseif not isCrouching and crouchWalkAnimation.IsPlaying then crouchWalkAnimation:Stop(0.15) end end
		if proneWalkAnimation then if isProning and not proneWalkAnimation.IsPlaying then proneWalkAnimation:Play(0.15) elseif not isProning and proneWalkAnimation.IsPlaying then proneWalkAnimation:Stop(0.15) end end
		
		--<< The user is sprinting, remove stamina >>--
		if isSprinting then
			
			if humanoid.Health > 0 then --<< The humanoid is alive >>--
				
				--<< Tweens the WalkSpeed & FieldOfView to the configured speed and FOV >>--
				TweenService:Create(humanoid, TweenInfo.new(deltaTime * 2), {WalkSpeed = Config.SprintingSpeed}):Play()
				TweenService:Create(camera, TweenInfo.new(1), {FieldOfView = Config.SprintFOV}):Play()
				
				--<< Removes stamina >>--
				humanoid:SetAttribute("Stamina", Math.Lerp(humanoid:GetAttribute("Stamina"), math.clamp((humanoid:GetAttribute("Stamina") - 1), 0, Config.MaxStamina), deltaTime * 5))
				
				--<< Resets the StaminaTick >>--
				staminaTick = tick()
				
			end
			
		else --<< The user is not sprinting, regain stamina >>--
			
			local targetSpeed = Config.WalkSpeed; if Config.ProningActive then targetSpeed = Config.ProneWalkSpeed elseif Config.CrouchingActive then targetSpeed = Config.CrouchWalkSpeed end
			
			--<< Reset the WalkSpeed to the default, crouch speed, or prone speed. Resets the FOV >>--
			TweenService:Create(humanoid, TweenInfo.new(deltaTime * 2), {WalkSpeed = targetSpeed}):Play()
			TweenService:Create(camera, TweenInfo.new(1), {FieldOfView = Config.WalkFOV}):Play()
			
			--<< Regain stamina if the user has stopped sprinting for long enough, and they are still alive >>--
			if tick() - staminaTick > 2 and humanoid.Health > 0 then humanoid:SetAttribute("Stamina", Math.Lerp(humanoid:GetAttribute("Stamina"), math.clamp((humanoid:GetAttribute("Stamina") + 1), 0, Config.MaxStamina), deltaTime * 2.5)) end
			
		end
		
		--<< The user is alive. Apply a slight tilt to the character based on the direction they're walking >>--
		if humanoid.Health > 0 then local moveDirection = humanoidRootPart.CFrame:VectorToObjectSpace(humanoid.MoveDirection) tiltCF = tiltCF:Lerp(CFrame.Angles(math.rad(-moveDirection.Z) * 5, math.rad(-moveDirection.X) * 5, 0), 0.1 * deltaTime * 60) rootJoint.C0 = rootC0 * tiltCF end
		
		--<< The user is not in first person. Set the camera CFrame based on whether they are in MouseLock >>--
		if not IsInFirstPerson() then camera.CFrame = camera.CFrame * CFrame.new(mouseLockSpring.p) end
		--<< Rotate the character with the camera >>--
		if Config.MouseLockActive and not IsInFirstPerson() then local vectorMovement = Vector3.new(camera.CFrame.LookVector.X * 900000, humanoidRootPart.Position.Y, camera.CFrame.LookVector.Z * 900000) humanoidRootPart.CFrame = humanoidRootPart.CFrame:Lerp(CFrame.new(humanoidRootPart.Position, vectorMovement), 0.1) humanoid.AutoRotate = false else if humanoid.Health > 0 then humanoid.AutoRotate = true else humanoid.AutoRotate = false end end
		
	end)
	
end

return MovementHandler
