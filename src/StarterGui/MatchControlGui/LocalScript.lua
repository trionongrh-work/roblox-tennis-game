-- =============================================================================
-- LocalScript  (inside ScreenGui "MatchControlGui" in StarterGui)
-- Place in: StarterGui > MatchControlGui > LocalScript
-- =============================================================================
--
-- Simple match control UI:
--   - Shows a "Reset Match" button in the corner
--   - Only visible to players on Team A or Team B
--   - Fires a RemoteEvent to request match reset
-- =============================================================================

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Wait for the RemoteEvent
local resetMatchRemote = ReplicatedStorage:WaitForChild("ResetMatch", 10)
if not resetMatchRemote then
	warn("[MatchControlGui] ResetMatch RemoteEvent not found in ReplicatedStorage")
	return
end

-- ── GUI Construction ─────────────────────────────────────────────────────────

-- Retrieve the ScreenGui this script lives in, or create it
local screenGui = script.Parent
if not screenGui:IsA("ScreenGui") then
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MatchControlGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = player.PlayerGui
end

-- Create reset button (bottom-left corner)
local resetButton = Instance.new("TextButton")
resetButton.Name = "ResetButton"
resetButton.Size = UDim2.new(0, 140, 0, 40)
resetButton.Position = UDim2.new(0, 15, 1, -55)
resetButton.Text = "Reset Match"
resetButton.Font = Enum.Font.GothamBold
resetButton.TextSize = 14
resetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
resetButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
resetButton.BorderSizePixel = 0
resetButton.Parent = screenGui

-- Rounded corners
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = resetButton

-- Button click handler
resetButton.MouseButton1Click:Connect(function()
	-- Fire server request
	resetMatchRemote:FireServer()
	-- Visual feedback
	resetButton.Text = "Resetting..."
	task.wait(1)
	resetButton.Text = "Reset Match"
end)

-- Only show button if player is on a team
local function updateVisibility()
	local team = player.Team
	if team and (team.Name == "Team A" or team.Name == "Team B") then
		resetButton.Visible = true
	else
		resetButton.Visible = false
	end
end

-- Update visibility on team change
player:GetPropertyChangedSignal("Team"):Connect(updateVisibility)
updateVisibility()
