-- =============================================================================
-- LocalScript  (inside Tool "TennisRacket" in StarterPack)
-- Place in: StarterPack > TennisRacket > LocalScript
-- =============================================================================
--
-- Features:
--   • Swing animation triggered on Tool:Activated
--   • Sweet-spot window: hitting the ball during frames 15-25 of the swing
--     produces a faster, straighter shot (Sweet Spot bonus)
--   • Ball proximity check: must be within SWEET_SPOT_RANGE / HIT_RANGE studs
--   • Fires "HitBall" RemoteEvent to server with (direction, isSweetSpot)
--
-- Animation:
--   Replace SWING_ANIM_ID below with your own uploaded animation asset ID.
--   The animation should be ~0.8 s long; frames 15-25 (≈0.3-0.5 s) are the
--   sweet-spot contact window.
--
-- Dependencies:
--   ReplicatedStorage > RemoteEvent "HitBall"
--   Workspace.TennisArena.TennisBall  (tagged "TennisBall")
-- =============================================================================

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local CollectionService= game:GetService("CollectionService")
local RunService       = game:GetService("RunService")

-- ── References ────────────────────────────────────────────────────────────
local tool       = script.Parent          -- the TennisRacket Tool
local player     = Players.LocalPlayer
local character  = player.Character or player.CharacterAdded:Wait()
local humanoid   = character:WaitForChild("Humanoid")
local rootPart   = character:WaitForChild("HumanoidRootPart")

local hitBallRemote = ReplicatedStorage:WaitForChild("HitBall") -- RemoteEvent

-- ── Configuration ──────────────────────────────────────────────────────────
local CFG = {
	SWING_ANIM_ID      = "rbxassetid://0",   -- Optional: replace with your uploaded animation asset ID (0 = no animation)
	ANIM_DURATION      = 0.8,                -- seconds for the full swing
	SWEET_SPOT_START   = 0.30,               -- seconds after swing start
	SWEET_SPOT_END     = 0.50,               -- seconds after swing start
	SWEET_SPOT_RANGE   = 5,                  -- stud radius for sweet-spot detection
	HIT_RANGE          = 8,                  -- stud radius for any valid hit
	SWING_COOLDOWN     = 0.9,                -- seconds before next swing allowed
}

-- ── State ──────────────────────────────────────────────────────────────────
local isSwinging     = false
local swingStartTime = 0
local animTrack      = nil

-- ── Animation Setup ────────────────────────────────────────────────────────
local animator = humanoid:WaitForChild("Animator")

local swingAnimation = Instance.new("Animation")
swingAnimation.AnimationId = CFG.SWING_ANIM_ID

-- Guard: if the animation ID was not set, skip loading to avoid runtime errors
local useAnimation = CFG.SWING_ANIM_ID ~= "rbxassetid://0"

-- Load the track once the tool is equipped (only if a valid animation ID is set)
local function loadAnimTrack()
	if not useAnimation then return end
	if animTrack then animTrack:Stop() end
	animTrack = animator:LoadAnimation(swingAnimation)
	animTrack.Priority = Enum.AnimationPriority.Action
end

-- ── Ball Lookup ─────────────────────────────────────────────────────────────
-- Finds the ball by CollectionService tag at runtime.
local function findBall()
	local tagged = CollectionService:GetTagged("TennisBall")
	return tagged[1]  -- expects exactly one ball in the arena
end

-- ── Hit Detection ───────────────────────────────────────────────────────────
-- Calculates the direction to aim based on where the ball is relative to the player.
-- Adds a slight upward arc (loft) so the ball travels over the net.
local function computeHitDirection(ballPart)
	local toBall = (ballPart.Position - rootPart.Position)
	local horizontal = Vector3.new(toBall.X, 0, toBall.Z).Unit
	-- 15° upward loft so the ball clears the net
	local loft = math.rad(15)
	local dir = Vector3.new(
		horizontal.X * math.cos(loft),
		math.sin(loft),
		horizontal.Z * math.cos(loft)
	)
	return dir.Unit
end

-- ── Swing Logic ─────────────────────────────────────────────────────────────
local function attemptHit()
	local ballPart = findBall()
	if not ballPart then return end

	local dist = (ballPart.Position - rootPart.Position).Magnitude
	if dist > CFG.HIT_RANGE then return end  -- ball out of reach

	local elapsed    = tick() - swingStartTime
	local isSweetSpot = (elapsed >= CFG.SWEET_SPOT_START)
	                 and (elapsed <= CFG.SWEET_SPOT_END)
	                 and (dist <= CFG.SWEET_SPOT_RANGE)

	local direction = computeHitDirection(ballPart)

	-- Fire to server
	hitBallRemote:FireServer(direction, isSweetSpot)

	-- Visual feedback
	if isSweetSpot then
		-- Flash the tool handle to signal a sweet-spot hit
		local handle = tool:FindFirstChild("Handle")
		if handle then
			local originalColor = handle.Color
			handle.Color = Color3.fromRGB(255, 230, 50)   -- golden flash
			task.delay(0.15, function()
				if handle and handle.Parent then
					handle.Color = originalColor
				end
			end)
		end
	end
end

-- ── Swing Connection ────────────────────────────────────────────────────────
-- RunService.Heartbeat polls for a hit during the swing window.
-- hitRegistered ensures only one hit fires per swing (prevents duplicate RemoteEvent fires).
local swingConnection = nil
local hitRegistered   = false

local function startSwing()
	if isSwinging then return end
	isSwinging     = true
	hitRegistered  = false
	swingStartTime = tick()

	-- Play animation (if a valid animation ID is configured)
	if animTrack and useAnimation then
		animTrack:Stop()
		animTrack:Play()
	else
		-- Fallback: simple visual swing using tool grip manipulation
		local handle = tool:FindFirstChild("Handle")
		if handle and tool.Parent == character then
			local originalC0 = tool.Grip
			-- Swing motion: rotate the racket forward
			local swingC0 = originalC0 * CFrame.Angles(math.rad(-90), 0, 0)
			tool.Grip = swingC0
			-- Return to original position after swing duration
			task.delay(CFG.ANIM_DURATION, function()
				if tool and tool.Parent == character then
					tool.Grip = originalC0
				end
			end)
		end
	end

	-- Poll for hit during the sweet-spot window; fall back to a late hit after the window
	swingConnection = RunService.Heartbeat:Connect(function()
		if hitRegistered then
			-- Hit already registered; wait out the swing duration then clean up
			if (tick() - swingStartTime) > CFG.ANIM_DURATION then
				swingConnection:Disconnect()
				swingConnection = nil
			end
			return
		end

		local elapsed = tick() - swingStartTime

		if elapsed >= CFG.SWEET_SPOT_START and elapsed <= CFG.SWEET_SPOT_END then
			-- Sweet-spot window: attempt hit and mark as registered
			hitRegistered = true
			attemptHit()
		elseif elapsed > CFG.ANIM_DURATION then
			-- Swing ended without sweet-spot hit: attempt a late hit as fallback
			hitRegistered = true
			attemptHit()
			swingConnection:Disconnect()
			swingConnection = nil
		end
	end)

	-- Reset swinging flag after cooldown
	task.delay(CFG.SWING_COOLDOWN, function()
		isSwinging = false
	end)
end

-- ── Tool Events ─────────────────────────────────────────────────────────────
tool.Equipped:Connect(function()
	character  = player.Character
	humanoid   = character and character:FindFirstChildWhichIsA("Humanoid")
	rootPart   = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid then
		animator = humanoid:FindFirstChildWhichIsA("Animator") or humanoid:WaitForChild("Animator")
		loadAnimTrack()
	end
end)

tool.Unequipped:Connect(function()
	if animTrack then
		animTrack:Stop()
	end
	if swingConnection then
		swingConnection:Disconnect()
		swingConnection = nil
	end
	isSwinging = false
end)

-- Activated fires when the player clicks / taps (or presses the tool keybind)
tool.Activated:Connect(function()
	startSwing()
end)
