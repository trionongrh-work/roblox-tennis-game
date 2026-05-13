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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local pointScoredEvent = ReplicatedStorage:WaitForChild("PointScored") -- BindableEvent (server-only scoring signal)

local function isBall(part)
	return part and part.Name == "TennisBall"
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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create in Studio (ReplicatedStorage):
-- BindableEvent named "PointScored" (server receives team that won the rally)
-- RemoteEvent named "ScoreUpdated" (server broadcasts score text/state)

local pointScoredEvent = ReplicatedStorage:WaitForChild("PointScored")
local scoreUpdatedEvent = ReplicatedStorage:WaitForChild("ScoreUpdated")

local SCORE_STEPS = {0, 15, 30, 40}

local matchState = {
	mode = "2v2", -- "1v1" or "2v2"
	teams = {
		Home = {players = {}, pointIndex = 1, games = 0},
		Away = {players = {}, pointIndex = 1, games = 0},
	}
}

local function isValidTeamName(teamName)
	return teamName == "Home" or teamName == "Away"
end

local function resetPoints()
	matchState.teams.Home.pointIndex = 1
	matchState.teams.Away.pointIndex = 1
end

local function getScoreText()
	local h = SCORE_STEPS[matchState.teams.Home.pointIndex]
	local a = SCORE_STEPS[matchState.teams.Away.pointIndex]
	return string.format("%d - %d", h, a)
end

local function awardPoint(teamName)
	if not isValidTeamName(teamName) then return end
	local team = matchState.teams[teamName]

	if team.pointIndex < #SCORE_STEPS then
		team.pointIndex += 1
	else
		-- Reached Game (after 40 -> Game)
		team.games += 1
		resetPoints()
	end

	scoreUpdatedEvent:FireAllClients({
		mode = matchState.mode,
		homePoints = SCORE_STEPS[matchState.teams.Home.pointIndex],
		awayPoints = SCORE_STEPS[matchState.teams.Away.pointIndex],
		homeGames = matchState.teams.Home.games,
		awayGames = matchState.teams.Away.games,
		scoreText = getScoreText(),
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
- `ClockTime = 19.0` (evening match under floodlights)
- `ExposureCompensation = 0.05`
- `Ambient = Color3.fromRGB(70, 78, 92)`
- `OutdoorAmbient = Color3.fromRGB(90, 98, 112)`

Optional polish:
- Add subtle `ColorCorrectionEffect` (slight contrast/saturation boost).
- Keep post-processing light for mobile performance.
