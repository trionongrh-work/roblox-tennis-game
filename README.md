# Roblox Tennis Game — Modern Pro Arena Blueprint

## Quick Start Guide

### Minimum Setup to Play (5 minutes)

1. **Create Teams** (in Teams service):
   - Team named `Team A` (BrickColor: Bright blue)
   - Team named `Team B` (BrickColor: Bright red)

2. **Create RemoteEvents** (in ReplicatedStorage):
   - RemoteEvent named `ScoreUpdated`
   - RemoteEvent named `HitBall`

3. **Create TennisArena Model** (in Workspace) with these essential parts:
   - `CourtFloor`: Block (78, 1, 36) at position (0, 0.5, 0) — Navy blue, Anchored
   - `Net`: Block (36, 3.5, 0.4) at (0, 2.25, 0) — White, Anchored, CanCollide=true
   - `TennisBall`: Sphere (1, 1, 1) at (0, 3, -20) — Yellow, NOT anchored
     - Set CustomPhysicalProperties: Density=0.5, Friction=0.3, Elasticity=0.85
   - `Detector_SideA`: Block (40, 2, 4) at (0, 1, -51) — Transparent, Anchored, CanCollide=false, CanTouch=true
   - `Detector_SideB`: Block (40, 2, 4) at (0, 1, 51) — Transparent, Anchored, CanCollide=false, CanTouch=true

4. **Create TennisRacket Tool** (in StarterPack):
   - Tool named `TennisRacket` with RequiresHandle=true
   - Add `Handle` part: Block (0.4, 2.5, 0.4) — Any color
   - Add LocalScript with code from `src/StarterPack/TennisRacket/LocalScript.lua`

5. **Add Scripts**:
   - Script in ServerScriptService: `src/ServerScriptService/TennisGame.server.lua`
   - ScreenGui in StarterGui named `ScoreboardGui` with LocalScript: `src/StarterGui/ScoreboardGui/LocalScript.lua`

6. **Test**: Press Play, join a team, pick up the racket, click to swing at the ball!

---

## Repository File Structure

Copy these files into Roblox Studio exactly as shown:

| Repo Path | Studio Location |
|---|---|
| `src/ServerScriptService/TennisGame.server.lua` | **ServerScriptService** → Script named `TennisGame` |
| `src/StarterPack/TennisRacket/LocalScript.lua` | **StarterPack** → Tool named `TennisRacket` → LocalScript |
| `src/StarterGui/ScoreboardGui/LocalScript.lua` | **StarterGui** → ScreenGui named `ScoreboardGui` → LocalScript |

---

## 1) Workspace Hierarchy & Modeling — Exact Part Specifications

Create a **Model** named `TennisArena` in **Workspace** containing all parts below.

### Required Studio Objects in Other Services

Before running the game, create these in the Explorer:

| Service | Type | Name | Notes |
|---|---|---|---|
| **ReplicatedStorage** | RemoteEvent | `ScoreUpdated` | Server → all clients (score data) |
| **ReplicatedStorage** | RemoteEvent | `HitBall` | Client → server (racket hit request) |
| **Teams** | Team | `Team A` | BrickColor: Bright blue |
| **Teams** | Team | `Team B` | BrickColor: Bright red |

### TennisRacket Tool in StarterPack

Create a **Tool** named `TennisRacket` in **StarterPack** with the following structure:

1. **Tool properties:**
   - Name: `TennisRacket`
   - RequiresHandle: true
   - CanBeDropped: false

2. **Handle part (child of Tool):**
   - Name: `Handle`
   - Shape: Block
   - Size: (0.4, 2.5, 0.4)
   - Color: Any (suggest bright cyan or team color)
   - Material: SmoothPlastic

3. **LocalScript (child of Tool):**
   - Paste the contents of `src/StarterPack/TennisRacket/LocalScript.lua`
   - **Animation is optional**: The racket works without a custom animation. It uses a simple visual swing effect by default.
   - To add a custom animation: Upload your animation to Roblox, then set `SWING_ANIM_ID` in the LocalScript to your animation asset ID.

### SpawnLocation Setup

Create spawn locations for each team:

| Service | Type | Name | Position | Properties |
|---|---|---|---|---|
| **Workspace** | SpawnLocation | `SpawnA` | 0, 1, -25 | TeamColor: Bright blue, Duration: 0, Neutral: false |
| **Workspace** | SpawnLocation | `SpawnB` | 0, 1, 25 | TeamColor: Bright red, Duration: 0, Neutral: false |

### TennisArena Parts

| Name | Shape | Size (X, Y, Z) | Position (X, Y, Z) | Color | Material | Notes |
|---|---|---|---|---|---|---|
| `CourtFloor` | Block | 78, 1, 36 | 0, 0.5, 0 | Navy blue `(20, 46, 120)` | SmoothPlastic | Anchored |
| `Net` | Block | 36, 3.5, 0.4 | 0, 2.25, 0 | White | Neon | Anchored, CanCollide = **true** |
| `Detector_SideA` | Block | 40, 2, 4 | 0, 1, −51 | any | SmoothPlastic | Anchored, Transparency=1, CanCollide=**false**, CanTouch=**true** |
| `Detector_SideB` | Block | 40, 2, 4 | 0, 1, 51 | any | SmoothPlastic | Anchored, Transparency=1, CanCollide=**false**, CanTouch=**true** |
| `Detector_Left` | Block | 2, 2, 80 | −20, 1, 0 | any | SmoothPlastic | Anchored, Transparency=1, CanCollide=**false**, CanTouch=**true** |
| `Detector_Right` | Block | 2, 2, 80 | 20, 1, 0 | any | SmoothPlastic | Anchored, Transparency=1, CanCollide=**false**, CanTouch=**true** |
| `TennisBall` | **Sphere** | 1, 1, 1 | 0, 3, −20 | Yellow `(255, 220, 50)` | SmoothPlastic | **Not** anchored; see physics below |

### TennisBall — CustomPhysicalProperties

Open the `TennisBall` part → Properties → **CustomPhysicalProperties = true**, then set:

| Property | Value | Reason |
|---|---|---|
| **Density** | `0.50` | Lighter than default so impulse travels well |
| **Friction** | `0.30` | Low friction for fast court slide |
| **FrictionWeight** | `1.0` | Default |
| **Elasticity** | `0.85` | High bounce, like a pressurized tennis ball |
| **ElasticityWeight** | `1.0` | Default |

Add a **CollectionService tag** `"TennisBall"` to the part (via the Tag Editor plugin or Script).

### Court Markings (decorative parts, Anchored, CanCollide = false)

| Part | Size (X, Y, Z) | Position (X, Y, Z) | Color |
|---|---|---|---|
| `Line_Baseline_A` | 36, 0.1, 0.3 | 0, 1.05, −39 | White |
| `Line_Baseline_B` | 36, 0.1, 0.3 | 0, 1.05, 39 | White |
| `Line_Service_A` | 27, 0.1, 0.3 | 0, 1.05, −21 | White |
| `Line_Service_B` | 27, 0.1, 0.3 | 0, 1.05, 21 | White |
| `Line_Center` | 0.3, 0.1, 42 | 0, 1.05, 0 | White |
| `Line_Side_Left` | 0.3, 0.1, 78 | −18, 1.05, 0 | White |
| `Line_Side_Right` | 0.3, 0.1, 78 | 18, 1.05, 0 | White |

---

## 3) Build Instructions (Studio Setup)

1. **Create court root**
   - Add a `Model` named `TennisArena`.
   - Add a centered base part named `CourtFloor` and size it to:
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
   - Add one digital scoreboard mesh/part showing **Team A vs Team B**.
   - Add 4 large floodlight towers (corners of arena footprint).
   - Keep meshes low-poly and reuse materials/colors for performance.

---

## 4) Visual Breakdown (Style Guide)

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

## 5) OutBounds / KillZone Setup (Touched Detection)

> **Note:** The actual game implementation in `src/ServerScriptService/TennisGame.server.lua`
> uses `Detector_SideA` and `Detector_SideB` directly with `Touched` events — no extra boundary
> parts or BindableEvents are required. The section below documents an alternative pattern for
> reference only.

The `TennisGame` script handles out-of-bounds automatically:
- `Detector_SideA` (at z = −51): ball touches it → **Team B** scores (Team A failed to return)
- `Detector_SideB` (at z = +51): ball touches it → **Team A** scores (Team B failed to return)

For additional out-of-bounds coverage (side tramlines), you can optionally add:
- `OutBounds_Left` / `OutBounds_Right` — transparent parts along the side tramlines
- `CanCollide = false`, `CanTouch = true`, `Transparency = 1`, `Anchored = true`
- Tag with CollectionService tag `"OutBounds"` and extend the touch handler in `TennisGame.server.lua`.

---

## 6) Core Server Logic Reference

The full server script is in `src/ServerScriptService/TennisGame.server.lua`.
Key design points:

- **Teams:** uses Roblox `Teams` service; name your teams `"Team A"` and `"Team B"` in Studio.
  - 1v1: one player on each team.
  - 2v2: two players on each team.
- **`TeamA`** (key `"TeamA"`) defends from the z-negative side (z = −39 baseline).
- **`TeamB`** (key `"TeamB"`) defends from the z-positive side (z = +39 baseline).
- **Scoring:** Love → 15 → 30 → 40 → Deuce → Advantage → Game; first to 6 games wins a set;
  first to 2 sets wins the match.
- **Ball respawn:** happens automatically after each point; serving alternates each game.

### Team assignment (set this up in Teams service in Studio)

| Roblox Team Name | Internal key | Side | Spawn position |
|---|---|---|---|
| `Team A` | `TeamA` | z < 0 | (0, 3, −20) |
| `Team B` | `TeamB` | z > 0 | (0, 3, +20) |

---

## 7) Recommended Lighting (Professional Court Look)

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
