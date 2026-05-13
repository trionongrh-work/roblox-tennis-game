# Roblox Tennis Game — Modern Pro Arena Blueprint

## 1) Build Instructions (Studio Setup)

1. **Create court root**
   - Add a `Model` named `TennisArena`.
   - Add a centered base part named `CourtBase` and size it to:
     - **Length (Z): 78 studs**
     - **Width (X): 36 studs**
     - **Height (Y): 1 stud**

2. **Apply hard-court colors (Modern Pro Arena)**
   - Inner court color: **navy blue** (service boxes + playable center)
   - Outer court color: **forest green**
   - Use `SmoothPlastic` (or a subtle hard-court texture if you already use texture IDs in your project).

3. **Court markings**
   - Use thin white parts/decals for lines (`0.1–0.2` stud thickness visually).
   - Doubles width: **36 studs** (full width).
   - Singles width: **27 studs** (centered, so `4.5` studs inset per side from doubles lines).
   - Baselines at each end of the 78-stud length.
   - Service line and center service line per standard tennis layout.

4. **Net**
   - Add `Net` part at court center (midpoint on length axis).
   - Set height to **3.5 studs**.
   - Recommended size: `36 x 3.5 x 0.4` (X,Y,Z if net spans width).

5. **Runoff / movement clearance**
   - Add at least **20 studs** behind each baseline.
   - Practical full play zone length: `78 + 20 + 20 = 118 studs`.

6. **Arena dressing (optimized low-poly)**
   - Add simple, blocky spectator stands around play zone.
   - Add one digital scoreboard mesh/part showing **Home vs Away**.
   - Add 4 large floodlight towers (corners of arena footprint).
   - Keep meshes low-poly and reuse materials/colors for performance.

---

## 2) Visual Breakdown (Style Guide)

- **Theme:** Modern Pro Arena, clean and professional.
- **Palette:**
  - Inner court: navy blue
  - Outer court/runoff: forest green
  - Lines/net tape: white
  - Stands/lights: dark neutral grays
- **Roblox style target:** blocky but polished (simple forms, strong silhouettes, minimal clutter).
- **Performance notes:**
  - Prefer primitive parts over high-triangle meshes where possible.
  - Use `Anchored` static environment assets.
  - Keep light count reasonable (4 large floodlights + ambient lighting).

---

## 3) OutBounds / KillZone Setup (Touched Detection)

Create invisible boundary parts around the playable area:

- `OutBounds_Left`, `OutBounds_Right`, `OutBounds_Back_Home`, `OutBounds_Back_Away`
- Optional: `OutBounds_Net` (if ball into net should trigger dead ball)

Properties:
- `Transparency = 1`
- `CanCollide = false`
- `CanTouch = true`
- `Anchored = true`
- Tag with `CollectionService` tag like `"OutBounds"`

### Server Script Concept

```lua
-- ServerScriptService/OutBoundsHandler.server.lua
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local pointScoredEvent = ServerStorage:WaitForChild("PointScored") -- BindableEvent (server-only scoring signal)

local function isBall(part)
	return part and (CollectionService:HasTag(part, "TennisBall") or part:GetAttribute("IsTennisBall") == true)
end

local function onOutBoundsTouched(zone, hitPart)
	if not isBall(hitPart) then
		return
	end

	-- Server-authoritative ball metadata pattern:
	-- hitPart:SetAttribute("LastHitTeam", "Home"/"Away")
	local lastHitTeam = hitPart:GetAttribute("LastHitTeam")
	if not lastHitTeam then
		return
	end

	local scoringTeam = (lastHitTeam == "Home") and "Away" or "Home"
	pointScoredEvent:Fire(scoringTeam)
end

for _, zone in ipairs(CollectionService:GetTagged("OutBounds")) do
	zone.Touched:Connect(function(hitPart)
		onOutBoundsTouched(zone, hitPart)
	end)
end
```

---

## 4) Core 1v1 / 2v2 Scoring Script (15, 30, 40, Game)

```lua
-- ServerScriptService/TennisScoring.server.lua
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create in Studio:
-- ServerStorage/BindableEvent named "PointScored" (server receives team that won the rally)
-- ReplicatedStorage/RemoteEvent named "ScoreUpdated" (server broadcasts score text/state)

local pointScoredEvent = ServerStorage:WaitForChild("PointScored")
local scoreUpdatedRemote = ReplicatedStorage:WaitForChild("ScoreUpdated") -- RemoteEvent
assert(pointScoredEvent:IsA("BindableEvent"), "PointScored must be a BindableEvent")
assert(scoreUpdatedRemote:IsA("RemoteEvent"), "ScoreUpdated must be a RemoteEvent")

local SCORE_TEXT = {"0", "15", "30", "40"}

local matchState = {
	mode = "2v2", -- "1v1" or "2v2"
	teams = {
		Home = {players = {}, rallyPoints = 0, games = 0},
		Away = {players = {}, rallyPoints = 0, games = 0},
	}
}

local function isValidTeamName(teamName)
	return teamName == "Home" or teamName == "Away"
end

local function resetPoints()
	matchState.teams.Home.rallyPoints = 0
	matchState.teams.Away.rallyPoints = 0
end

local function getDisplayPoints(teamPoints, otherPoints)
	if teamPoints >= 3 and otherPoints >= 3 then
		if teamPoints == otherPoints then
			return "40" -- Deuce shown as 40-40 on board text below
		elseif teamPoints == otherPoints + 1 then
			return "Ad"
		end
		return "40"
	end
	return SCORE_TEXT[math.min(teamPoints + 1, 4)]
end

local function hasGameWon(teamPoints, otherPoints)
	return teamPoints >= 4 and (teamPoints - otherPoints) >= 2
end

local function getScoreText(homePoints, awayPoints)
	if homePoints >= 3 and awayPoints >= 3 and homePoints == awayPoints then
		return "Deuce"
	end

	local homeText = getDisplayPoints(homePoints, awayPoints)
	local awayText = getDisplayPoints(awayPoints, homePoints)
	return string.format("%s - %s", homeText, awayText)
end

local function awardPoint(teamName)
	if not isValidTeamName(teamName) then return end
	local home = matchState.teams.Home
	local away = matchState.teams.Away

	if teamName == "Home" then
		home.rallyPoints += 1
	else
		away.rallyPoints += 1
	end

	if hasGameWon(home.rallyPoints, away.rallyPoints) then
		home.games += 1
		resetPoints()
	elseif hasGameWon(away.rallyPoints, home.rallyPoints) then
		away.games += 1
		resetPoints()
	end

	scoreUpdatedRemote:FireAllClients({
		mode = matchState.mode,
		homePoints = home.rallyPoints,
		awayPoints = away.rallyPoints,
		homeGames = matchState.teams.Home.games,
		awayGames = matchState.teams.Away.games,
		scoreText = getScoreText(home.rallyPoints, away.rallyPoints),
	})
end

pointScoredEvent.Event:Connect(function(teamName)
	awardPoint(teamName)
end)

-- Optional: if clients ever need to request a score action, use a separate
-- RemoteEvent and validate player-team ownership before calling awardPoint.
```

### Team assignment concept
- **1v1:** `Home.players = {PlayerA}`, `Away.players = {PlayerB}`
- **2v2:** `Home.players = {PlayerA, PlayerB}`, `Away.players = {PlayerC, PlayerD}`
- Keep same scoring function; only player-to-team validation changes by mode.

---

## 5) Recommended Lighting (Professional Court Look)

Set in `Lighting`:

- `Technology = Future`
- `Brightness = 2.2`
- `EnvironmentDiffuseScale = 0.35`
- `EnvironmentSpecularScale = 0.65`
- `GlobalShadows = true`
- `ShadowSoftness = 0.2`
- `ClockTime = 20.5` (night match under floodlights)
- `ExposureCompensation = 0.05`
- `Ambient = Color3.fromRGB(70, 78, 92)`
- `OutdoorAmbient = Color3.fromRGB(90, 98, 112)`

Optional polish:
- Add subtle `ColorCorrectionEffect` (slight contrast/saturation boost).
- Keep post-processing light for mobile performance.
