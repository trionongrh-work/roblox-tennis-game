-- =============================================================================
-- LocalScript  (inside ScreenGui "ScoreboardGui" in StarterGui)
-- Place in: StarterGui > ScoreboardGui > LocalScript
-- =============================================================================
--
-- Creates and maintains a professional scoreboard HUD:
--
--   ┌────────────────────────────────────────────────┐
--   │              TENNIS MATCH                      │
--   │  ─────────────────────────────────────────     │
--   │  SETS      Team A   │   Team B                 │
--   │             0       │    0                     │
--   │  ─────────────────────────────────────────     │
--   │  GAMES     Team A   │   Team B                 │
--   │             3       │    2                     │
--   │  ─────────────────────────────────────────     │
--   │  POINTS    Love     │   30                     │
--   │                                                │
--   │             ◉  Team A serving                  │
--   └────────────────────────────────────────────────┘
--
-- Listens to:  ReplicatedStorage > RemoteEvent "ScoreUpdated"
-- =============================================================================

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Wait for the RemoteEvent before doing anything else
local scoreUpdatedRemote = ReplicatedStorage:WaitForChild("ScoreUpdated") -- RemoteEvent

-- ── Color palette ───────────────────────────────────────────────────────────
local COLOR = {
	background  = Color3.fromRGB(15,  20,  35),   -- deep navy
	header      = Color3.fromRGB(22,  88, 180),   -- professional blue
	separator   = Color3.fromRGB(45,  55,  80),
	labelText   = Color3.fromRGB(160, 175, 210),  -- muted silver-blue
	scoreText   = Color3.fromRGB(255, 255, 255),  -- bright white
	teamAAccent = Color3.fromRGB( 50, 140, 255),  -- blue
	teamBAccent = Color3.fromRGB(230,  70,  60),  -- red
	deuce       = Color3.fromRGB(255, 210,  50),  -- gold
	matchOver   = Color3.fromRGB( 60, 220, 100),  -- green
	serving     = Color3.fromRGB(100, 220, 100),
}

-- ── GUI Construction ─────────────────────────────────────────────────────────

-- Retrieve the ScreenGui this script lives in, or create it
local screenGui = script.Parent
if not screenGui:IsA("ScreenGui") then
	-- Fallback: create a new ScreenGui if the script was placed elsewhere
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ScoreboardGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = player.PlayerGui
end

-- Helper: create a Frame
local function makeFrame(name, parent, size, position, color, zIndex)
	local f = Instance.new("Frame")
	f.Name            = name
	f.Size            = size
	f.Position        = position
	f.BackgroundColor3= color or Color3.fromRGB(0, 0, 0)
	f.BorderSizePixel = 0
	f.ZIndex          = zIndex or 1
	f.Parent          = parent
	return f
end

-- Helper: create a TextLabel
local function makeLabel(name, parent, text, size, position, textColor, fontSize, bold, zIndex)
	local l = Instance.new("TextLabel")
	l.Name                = name
	l.Size                = size
	l.Position            = position
	l.Text                = text
	l.TextColor3          = textColor or Color3.fromRGB(255, 255, 255)
	l.BackgroundTransparency = 1
	l.Font                = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	l.TextSize            = fontSize or 16
	l.TextScaled          = false
	l.TextXAlignment      = Enum.TextXAlignment.Center
	l.ZIndex              = zIndex or 2
	l.Parent              = parent
	return l
end

-- ── Main panel ──────────────────────────────────────────────────────────────
-- Anchored top-right, 260 × 290 px
local panel = makeFrame("ScorePanel", screenGui,
	UDim2.new(0, 260, 0, 290),
	UDim2.new(1, -275, 0, 20),
	COLOR.background, 1)
panel.BackgroundTransparency = 0.08

-- Rounded corners
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = panel

-- Subtle drop-shadow via a slightly larger frame behind
local shadow = makeFrame("Shadow", screenGui,
	UDim2.new(0, 266, 0, 296),
	UDim2.new(1, -278, 0, 17),
	Color3.fromRGB(0, 0, 0), 0)
shadow.BackgroundTransparency = 0.55
local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(0, 10)
shadowCorner.Parent = shadow

-- Header bar
local header = makeFrame("Header", panel,
	UDim2.new(1, 0, 0, 34),
	UDim2.new(0, 0, 0, 0),
	COLOR.header, 2)
local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 8)
headerCorner.Parent = header
makeLabel("Title", header, "TENNIS MATCH", UDim2.new(1, 0, 1, 0),
	UDim2.new(0, 0, 0, 0), COLOR.scoreText, 14, true, 3)

-- ── Column headers: "Team A" / "Team B" ────────────────────────────────────
local TEAM_A_X = 0.25
local TEAM_B_X = 0.62
local colHeaderY = 40

makeLabel("ColA", panel, "Team A",
	UDim2.new(0.35, 0, 0, 18), UDim2.new(TEAM_A_X - 0.175, 0, 0, colHeaderY),
	COLOR.teamAAccent, 13, true, 2)
makeLabel("ColB", panel, "Team B",
	UDim2.new(0.35, 0, 0, 18), UDim2.new(TEAM_B_X - 0.175, 0, 0, colHeaderY),
	COLOR.teamBAccent, 13, true, 2)

-- Separator
local function makeSep(parent, yPos)
	local s = makeFrame("Sep", parent,
		UDim2.new(0.9, 0, 0, 1), UDim2.new(0.05, 0, 0, yPos),
		COLOR.separator, 2)
	s.BackgroundTransparency = 0.4
	return s
end
makeSep(panel, 61)

-- ── Rows ──────────────────────────────────────────────────────────────────
-- Each row: label on left, Team A value, Team B value
local ROW_H = 56    -- height per row in px
local ROW_START_Y = 66

local function makeRow(parent, rowLabel, rowIndex)
	local yBase = ROW_START_Y + (rowIndex - 1) * ROW_H

	-- Row label (Sets / Games / Points)
	local lbl = makeLabel(rowLabel.."Label", parent, rowLabel,
		UDim2.new(0.22, 0, 0, 16), UDim2.new(0.02, 0, 0, yBase),
		COLOR.labelText, 11, false, 2)
	lbl.TextXAlignment = Enum.TextXAlignment.Left

	-- Team A value
	local valA = makeLabel(rowLabel.."A", parent, "—",
		UDim2.new(0.30, 0, 0, 28), UDim2.new(TEAM_A_X - 0.15, 0, 0, yBase + 12),
		COLOR.scoreText, 22, true, 2)

	-- Divider
	makeFrame(rowLabel.."Div", parent,
		UDim2.new(0, 1, 0, 36), UDim2.new(0.5, 0, 0, yBase + 8),
		COLOR.separator, 2)

	-- Team B value
	local valB = makeLabel(rowLabel.."B", parent, "—",
		UDim2.new(0.30, 0, 0, 28), UDim2.new(TEAM_B_X - 0.15, 0, 0, yBase + 12),
		COLOR.scoreText, 22, true, 2)

	makeSep(parent, yBase + ROW_H - 2)

	return valA, valB
end

local setsA,   setsB   = makeRow(panel, "SETS",   1)
local gamesA,  gamesB  = makeRow(panel, "GAMES",  2)
local pointsA, pointsB = makeRow(panel, "POINTS", 3)

-- ── Serving indicator ───────────────────────────────────────────────────────
local servingLabel = makeLabel("Serving", panel, "● Team A serving",
	UDim2.new(1, -20, 0, 20), UDim2.new(0, 10, 0, ROW_START_Y + 3 * ROW_H + 4),
	COLOR.serving, 12, false, 2)
servingLabel.TextXAlignment = Enum.TextXAlignment.Left

-- ── Match-over banner ───────────────────────────────────────────────────────
local matchOverBanner = makeFrame("MatchOverBanner", screenGui,
	UDim2.new(0, 340, 0, 60),
	UDim2.new(0.5, -170, 0.5, -30),
	Color3.fromRGB(20, 20, 20), 10)
matchOverBanner.BackgroundTransparency = 0.15
matchOverBanner.Visible = false
local matchOverCorner = Instance.new("UICorner")
matchOverCorner.CornerRadius = UDim.new(0, 12)
matchOverCorner.Parent = matchOverBanner

local matchOverText = makeLabel("Text", matchOverBanner, "MATCH OVER",
	UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
	COLOR.matchOver, 28, true, 11)

-- ── Score Update Handler ────────────────────────────────────────────────────
local function updateHUD(data)
	-- Rally points (already strings like "Love", "15", "30", "40", "Advantage")
	pointsA.Text = data.teamAPoints or "Love"
	pointsB.Text = data.teamBPoints or "Love"

	-- Deuce highlight
	if data.isDeuce then
		pointsA.Text = "Deuce"
		pointsB.Text = "Deuce"
		pointsA.TextColor3 = COLOR.deuce
		pointsB.TextColor3 = COLOR.deuce
	else
		pointsA.TextColor3 = COLOR.scoreText
		pointsB.TextColor3 = COLOR.scoreText
	end

	-- Games and sets (numeric; tostring needed here)
	gamesA.Text = tostring(data.teamAGames or 0)
	gamesB.Text = tostring(data.teamBGames or 0)
	setsA.Text  = tostring(data.teamASets  or 0)
	setsB.Text  = tostring(data.teamBSets  or 0)

	-- Serving indicator
	if data.serving == "TeamA" then
		servingLabel.Text      = "● Team A serving"
		servingLabel.TextColor3 = COLOR.teamAAccent
	else
		servingLabel.Text      = "● Team B serving"
		servingLabel.TextColor3 = COLOR.teamBAccent
	end

	-- Match-over banner
	if data.matchOver then
		local winName = (data.winner == "TeamA") and "Team A" or "Team B"
		matchOverText.Text    = winName .. " wins the match! 🏆"
		matchOverBanner.Visible = true
		-- Hide banner after a few seconds
		task.delay(5, function()
			matchOverBanner.Visible = false
		end)
	else
		matchOverBanner.Visible = false
	end
end

scoreUpdatedRemote.OnClientEvent:Connect(updateHUD)
