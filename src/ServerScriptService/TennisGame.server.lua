-- =============================================================================
-- TennisGame.server.lua
-- Place in: ServerScriptService
-- =============================================================================
--
-- Required Workspace hierarchy (TennisArena model):
--
--   CourtFloor       Part   Size (78, 1, 36)   Position (0, 0.5, 0)   Anchored
--   Net              Part   Size (36, 3.5, 0.4) Position (0, 2.25, 0)  Anchored
--   Detector_SideA   Part   Size (40, 2, 4)    Position (0, 1, -51)   Transparent/Anchored/CanCollide=false
--   Detector_SideB   Part   Size (40, 2, 4)    Position (0, 1,  51)   Transparent/Anchored/CanCollide=false
--   TennisBall       Part   Shape=Ball Size(1,1,1) Position (0, 3, -20)
--                           CustomPhysicalProperties: Density=0.5 Friction=0.3 Elasticity=0.85
--                           Tag (CollectionService): "TennisBall"
--
-- Required ReplicatedStorage objects (create manually in Studio):
--   RemoteEvent  "ScoreUpdated"   — server → all clients: current score data
--   RemoteEvent  "HitBall"        — client → server: racket hit request
--
-- =============================================================================

local Players         = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Teams           = game:GetService("Teams")

-- ── Remote Events (create these in ReplicatedStorage in Studio) ────────────
local scoreUpdatedRemote = ReplicatedStorage:WaitForChild("ScoreUpdated") -- RemoteEvent
local hitBallRemote      = ReplicatedStorage:WaitForChild("HitBall")      -- RemoteEvent
assert(scoreUpdatedRemote:IsA("RemoteEvent"), "ScoreUpdated must be a RemoteEvent in ReplicatedStorage")
assert(hitBallRemote:IsA("RemoteEvent"),      "HitBall must be a RemoteEvent in ReplicatedStorage")

-- ── Arena Parts ────────────────────────────────────────────────────────────
local arena      = workspace:WaitForChild("TennisArena")
local detectorA  = arena:WaitForChild("Detector_SideA")
local detectorB  = arena:WaitForChild("Detector_SideB")
local ball       = arena:WaitForChild("TennisBall")

-- ── Configuration ──────────────────────────────────────────────────────────
local CFG = {
	ballRespawnDelay  = 2,       -- seconds to wait before respawning the ball
	gamesPerSet       = 6,       -- games needed to win a set (with 2-game lead)
	setsToWinMatch    = 2,       -- sets needed to win the match
	hitImpulseNormal  = 80,      -- base impulse magnitude
	hitImpulseSweet   = 130,     -- sweet-spot impulse magnitude
	hitBallMaxRange   = 8,       -- max stud distance for a valid racket hit
	matchResetDelay   = 6,       -- seconds after match-over before resetting
}

-- Respawn CFrames: Side A serves from z=-20, Side B from z=+20
local SPAWN_CF = {
	TeamA = CFrame.new(0, 3, -20),
	TeamB = CFrame.new(0, 3,  20),
}

-- Tennis rally-point → display label
local POINT_LABEL = { [0]="Love", [1]="15", [2]="30", [3]="40" }

-- ── Match State ─────────────────────────────────────────────────────────────
-- Supports 1v1 and 2v2; team membership is determined by Roblox Teams service.
-- Name your Roblox Teams "Team A" and "Team B" in Studio.
local state = {
	rallyActive = false,
	serving     = "TeamA",   -- "TeamA" or "TeamB"
	teams = {
		TeamA = { rallyPoints = 0, games = 0, sets = 0 },
		TeamB = { rallyPoints = 0, games = 0, sets = 0 },
	},
}

-- ── Helpers ────────────────────────────────────────────────────────────────

-- Returns true if `part` is the tennis ball
local function isBall(part)
	return part ~= nil and CollectionService:HasTag(part, "TennisBall")
end

-- Returns "TeamA" or "TeamB" for a given Player, or nil if unassigned
local function getTeamOfPlayer(player)
	local team = player.Team
	if team == nil then return nil end
	local name = team.Name
	if name == "Team A" then return "TeamA"
	elseif name == "Team B" then return "TeamB"
	end
	return nil
end

-- Builds the display label for one side's rally points (handles Deuce/Advantage)
local function getPointDisplay(ownPoints, oppPoints)
	if ownPoints >= 3 and oppPoints >= 3 then
		if ownPoints == oppPoints then
			return "40"      -- both at deuce; getScoreText will show "Deuce" separately
		elseif ownPoints > oppPoints then
			return "Advantage"
		else
			return "40"      -- trailing side during opponent's advantage
		end
	end
	return POINT_LABEL[math.min(ownPoints, 3)] or "Love"
end

-- Returns true if `team` has won the current game
local function hasWonGame(ownPoints, oppPoints)
	return ownPoints >= 4 and (ownPoints - oppPoints) >= 2
end

-- Returns true if `team` has won the current set
local function hasWonSet(ownGames, oppGames)
	if ownGames >= 6 and (ownGames - oppGames) >= 2 then return true end
	if ownGames == 7 and oppGames <= 6              then return true end  -- 7-5 or tiebreak 7-6
	return false
end

-- ── Score Broadcasting ──────────────────────────────────────────────────────
local function broadcastScore(extra)
	local a = state.teams.TeamA
	local b = state.teams.TeamB
	local isDeuce = (a.rallyPoints >= 3 and b.rallyPoints >= 3 and a.rallyPoints == b.rallyPoints)

	local payload = {
		teamAPoints  = getPointDisplay(a.rallyPoints, b.rallyPoints),
		teamBPoints  = getPointDisplay(b.rallyPoints, a.rallyPoints),
		teamAGames   = a.games,
		teamBGames   = b.games,
		teamASets    = a.sets,
		teamBSets    = b.sets,
		serving      = state.serving,
		isDeuce      = isDeuce,
		matchOver    = false,
		winner       = nil,
	}
	if extra then
		for k, v in pairs(extra) do payload[k] = v end
	end
	scoreUpdatedRemote:FireAllClients(payload)
end

-- ── Ball Respawn ────────────────────────────────────────────────────────────
local function respawnBall(servingTeam)
	task.wait(CFG.ballRespawnDelay)
	local cf = SPAWN_CF[servingTeam] or SPAWN_CF.TeamA
	ball.CFrame                    = cf
	ball.AssemblyLinearVelocity    = Vector3.zero
	ball.AssemblyAngularVelocity   = Vector3.zero
	ball:SetAttribute("LastHitTeam", nil)
	state.rallyActive = true
end

-- ── Full Match Reset ────────────────────────────────────────────────────────
local function resetMatch()
	state.serving = "TeamA"
	state.rallyActive = false
	state.teams.TeamA = { rallyPoints = 0, games = 0, sets = 0 }
	state.teams.TeamB = { rallyPoints = 0, games = 0, sets = 0 }
	broadcastScore()
	respawnBall(state.serving)
end

-- ── Point Award ─────────────────────────────────────────────────────────────
local function awardPoint(winnerTeamKey)
	if not state.rallyActive then return end
	state.rallyActive = false

	local loserTeamKey = (winnerTeamKey == "TeamA") and "TeamB" or "TeamA"
	local winner = state.teams[winnerTeamKey]
	local loser  = state.teams[loserTeamKey]

	winner.rallyPoints += 1

	-- ── Game won? ────────────────────────────────────────────────────────
	if hasWonGame(winner.rallyPoints, loser.rallyPoints) then
		winner.games += 1
		state.teams.TeamA.rallyPoints = 0
		state.teams.TeamB.rallyPoints = 0
		-- Serve alternates each game
		state.serving = loserTeamKey

		-- ── Set won? ─────────────────────────────────────────────────────
		if hasWonSet(winner.games, loser.games) then
			winner.sets += 1
			state.teams.TeamA.games = 0
			state.teams.TeamB.games = 0

			-- ── Match won? ───────────────────────────────────────────────
			if winner.sets >= CFG.setsToWinMatch then
				broadcastScore({ matchOver = true, winner = winnerTeamKey })
				task.delay(CFG.matchResetDelay, resetMatch)
				return
			end
		end
	end

	broadcastScore()
	respawnBall(state.serving)
end

-- ── Detector Touch Logic ────────────────────────────────────────────────────
-- Detector_SideA is at Team A's baseline (z = -51).
-- If the ball crosses it, Team A failed to return → Team B wins the point.
detectorA.Touched:Connect(function(hit)
	if isBall(hit) then
		awardPoint("TeamB")
	end
end)

-- Detector_SideB is at Team B's baseline (z = +51).
-- If the ball crosses it, Team B failed to return → Team A wins the point.
detectorB.Touched:Connect(function(hit)
	if isBall(hit) then
		awardPoint("TeamA")
	end
end)

-- ── Racket Hit (from RacketHandler / client RemoteEvent) ────────────────────
-- Clients fire HitBall with (direction: Vector3, isSweetSpot: boolean)
-- The server validates the request and applies impulse to the ball.
hitBallRemote.OnServerEvent:Connect(function(player, direction, isSweetSpot)
	if not state.rallyActive then return end
	if typeof(direction) ~= "Vector3" then return end

	-- Validate direction is a unit vector (allow slight floating-point drift)
	local dirLength = direction.Magnitude
	if dirLength < 0.5 or dirLength > 2 then
		warn(player.Name, "sent invalid hit direction magnitude:", dirLength)
		return
	end

	-- Validate the ball is within range of the player's character root
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if (ball.Position - root.Position).Magnitude > CFG.hitBallMaxRange then
		return  -- too far away to be a valid hit
	end

	-- Determine impulse strength
	local impulse = isSweetSpot and CFG.hitImpulseSweet or CFG.hitImpulseNormal
	local normalDir = direction.Unit

	-- Apply impulse (resets current velocity first for consistent feel)
	ball.AssemblyLinearVelocity = Vector3.zero
	ball:ApplyImpulse(normalDir * impulse)

	-- Tag the ball with the hitting team so detectors can determine who scored
	local teamKey = getTeamOfPlayer(player)
	if teamKey then
		ball:SetAttribute("LastHitTeam", teamKey)
	end
end)

-- ── Startup ─────────────────────────────────────────────────────────────────
state.rallyActive = true
broadcastScore()
print("[TennisGame] Server ready — rally active.")
