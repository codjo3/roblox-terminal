# roblox-terminal
Customizable capture point/terminal system for team-based games, managing zone capture mechanics, point accumulation, overtime logic, and win conditions with extensive configuration options and event signals.
Perfect for King of the Hill, Domination, Hardpoint, and custom game modes. Built with ZonePlus integration and fully customizable gameplay mechanics.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Wally](https://img.shields.io/badge/Wally-0.2.4-blue)](https://wally.run/package/codjo3/terminal)

## Installation

### Via Wally
Add to your `wally.toml`:
```toml
[dependencies]
terminal = "codjo3/terminal@0.2.4"
```

Then run:
```bash
wally install
```

### Via Roblox Asset Library
Get the module from the [Roblox Creator Store](https://create.roblox.com/store/asset/13884083754)
### Manual Installation
1. Download the module from this repository
2. Place it in `ServerScriptService` or `ReplicatedStorage`
3. Ensure ZonePlus and Signal packages are installed

## Quick Start
```lua
local Terminal = require(path.to.Terminal)

-- Create a simple King of the Hill terminal
local myTerminal = Terminal.new("Hill A", {
    Teams = {game.Teams.Red, game.Teams.Blue},
    Parts = {workspace.CaptureZone}
})

-- Listen for events
myTerminal.PointsChanged:Connect(function(team, points)
    print(team.Name, "now has", points, "points")
end)

myTerminal.Stopped:Connect(function(winner)
    if winner then
        print(winner.Name, "team wins!")
    end
end)

-- Start the terminal
myTerminal:Start()
```

## API

### Creating a Terminal
```lua
Terminal.new(name: any, settings: Settings): Terminal
```

Creates a new terminal with the specified name and settings.

**Parameters:**
- `name` - Unique identifier (can be any type)
- `settings` - Configuration table (see Settings below)

**Example:**
```lua
local terminal = Terminal.new("Point A", {
    Teams = {game.Teams.Red, game.Teams.Blue},
    Parts = {workspace.PointA},
    PointsNeeded = 1200,
    CaptureTime = 10
})
```

### Getting Existing Terminals

```lua
Terminal.getTerminalFromName(name: any): Terminal?
```

Retrieves a terminal by its name, or returns `nil` if not found.

## Settings

### Core Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `Teams` | `{Team}` | **Required** | Array of teams that can capture (first team is defending team) |
| `Parts` | `{BasePart}` | **Required** | Array of parts that define the capture zone |
| `DefendingTeam` | `Team?` | `Teams[1]` | The team that starts with control |

### Point System

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `Increase` | `number` | `1` | Points earned per second by holding team |
| `Rollback` | `number` | `1` | Points lost per second by non-holding teams |
| `PointsNeeded` | `number` | `1200` | Points required to win (20 minutes at default rate) |

### Capture Mechanics

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `CaptureTime` | `number` | `1` | Seconds required to fully capture the terminal |
| `CaptureStacking` | `boolean` | `false` | Whether multiple players speed up capture |
| `CaptureWhileDead` | `boolean` | `false` | Allow dead players to contribute to capture |

### Gameplay Rules

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `RequireDominanceToIncrease` | `boolean` | `true` | Require other teams at 0 points to earn points |
| `ProgressWhileContested` | `boolean` | `true` | Continue earning points when contested |

### Overtime Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `OvertimeThreshold` | `number` | `0` | Seconds until overtime starts (0 = disabled) |
| `OvertimeIncrease` | `number` | `1` | Point earn rate during overtime |
| `OvertimeRollback` | `number` | `1` | Point loss rate during overtime |
| `OvertimePointsNeeded` | `number` | `120` | Points to win during overtime |
| `OvertimeDefenderWinFullDominance` | `boolean` | `true` | Defenders win if they reach full capture in overtime |

## Methods

### Start
```lua
terminal:Start(...): nil
```

Starts the terminal and begins tracking capture progress.

**Signals Fired:** `Started` (with passed parameters)

**Example:**
```lua
terminal:Start("Round 1", os.time())
```

### Pause
```lua
terminal:Pause(...): nil
```

Pauses the terminal without resetting progress.

**Signals Fired:** `OnPaused` (with passed parameters)

**Example:**
```lua
terminal:Pause("Intermission")

-- Resume by setting Paused to false
if terminal.Active then
    terminal.Paused = false
end
```

### Stop
```lua
terminal:Stop(...): nil
```

Stops the terminal and resets all progress.

**Signals Fired:** `Stopped` (with winner team and passed parameters)

**Example:**
```lua
terminal:Stop() -- Force stop, no winner
```

### Destroy
```lua
terminal:Destroy(): nil
```

Destroys the terminal and cleans up all resources.

**Signals Fired:** `Destroying`

## Events (Signals)

### Game State Events

| Event | Parameters | Description |
|-------|-----------|-------------|
| `Started` | `...any` | Fired when terminal starts |
| `OnPaused` | `...any` | Fired when terminal pauses |
| `Stopped` | `winner: Team?, ...any` | Fired when terminal stops |
| `Destroying` | `terminal, ...any` | Fired before terminal is destroyed |

### Gameplay Events

| Event | Parameters | Description |
|-------|-----------|-------------|
| `ContestedChanged` | `contested: boolean` | Fired when contestation state changes |
| `OvertimeEntered` | None | Fired when overtime begins |
| `PointsChanged` | `team: Team, points: number` | Fired when team points change |
| `CapturingChanged` | `team: Team, progress: number` | Fired when capture progress changes |
| `HolderAdded` | `team: Team` | Fired when team captures the terminal |
| `HolderRemoved` | `team: Team` | Fired when team loses control |
| `ElapsedChanged` | `elapsed: number` | Fired each frame with elapsed time |

**Example:**
```lua
terminal.HolderAdded:Connect(function(team)
    print(team.Name, "captured the terminal!")
end)

terminal.PointsChanged:Connect(function(team, points)
    -- Update UI
    updateScoreboard(team, points)
end)
```

## Game Mode Examples

### King of the Hill

Single point, one team must reach target score.

```lua
local hill = Terminal.new("The Hill", {
    Teams = {game.Teams.Red, game.Teams.Blue},
    Parts = {workspace.Hill},
    
    PointsNeeded = 1200,  -- 20 minutes
    Increase = 1,
    Rollback = 1,
    
    CaptureTime = 5,
    RequireDominanceToIncrease = true,
    ProgressWhileContested = false
})

hill:Start()
```

### Domination (3 Points)

Multiple terminals, first team to capture all three wins.

```lua
local function createDominationPoint(name, parts)
    return Terminal.new(name, {
        Teams = {game.Teams.Red, game.Teams.Blue},
        Parts = parts,
        
        PointsNeeded = 100,
        Increase = 5,
        Rollback = 0,
        
        CaptureTime = 8,
        RequireDominanceToIncrease = false,
        ProgressWhileContested = true,
        CaptureStacking = true
    })
end

local pointA = createDominationPoint("A", {workspace.PointA})
local pointB = createDominationPoint("B", {workspace.PointB})
local pointC = createDominationPoint("C", {workspace.PointC})

-- Start all points
pointA:Start()
pointB:Start()
pointC:Start()

-- Track total captures
local captures = {[game.Teams.Red] = 0, [game.Teams.Blue] = 0}

for _, point in {pointA, pointB, pointC} do
    point.Stopped:Connect(function(winner)
        if winner then
            captures[winner] = captures[winner] + 1
            if captures[winner] >= 3 then
                print(winner.Name, "wins the match!")
            end
        end
    end)
end
```

### Hardpoint (Rotating)

Single point that moves location over time.

```lua
local locations = {workspace.Point1, workspace.Point2, workspace.Point3}
local currentIndex = 1

local function createHardpoint()
    if currentTerminal then
        currentTerminal:Destroy()
    end
    
    currentTerminal = Terminal.new("Hardpoint", {
        Teams = {game.Teams.Red, game.Teams.Blue},
        Parts = {locations[currentIndex]},
        
        PointsNeeded = 250,
        Increase = 1,
        Rollback = 0,
        
        CaptureTime = 3,
        RequireDominanceToIncrease = false,
        ProgressWhileContested = true,
        
        OvertimeThreshold = 60,  -- Rotate every 60 seconds
        OvertimePointsNeeded = 0  -- Force rotation
    })
    
    currentTerminal.Stopped:Connect(function(winner)
        currentIndex = (currentIndex % #locations) + 1
        task.wait(5)  -- Brief intermission
        createHardpoint()
    end)
    
    currentTerminal:Start()
end

createHardpoint()
```

### Payload/Escort

Attacking team must maintain control to move payload.

```lua
local payload = Terminal.new("Payload", {
    Teams = {game.Teams.Attackers, game.Teams.Defenders},
    Parts = {workspace.PayloadZone},
    DefendingTeam = game.Teams.Defenders,
    
    PointsNeeded = 3000,  -- Distance to travel
    Increase = 2,
    Rollback = 1,
    
    CaptureTime = 5,
    RequireDominanceToIncrease = true,
    ProgressWhileContested = false,
    
    OvertimeThreshold = 300,  -- 5 minute time limit
    OvertimeIncrease = 5,      -- Faster in overtime
    OvertimePointsNeeded = 3000,
    OvertimeDefenderWinFullDominance = true
})

-- Move payload part based on progress
payload.PointsChanged:Connect(function(team, points)
    if team == game.Teams.Attackers then
        workspace.Payload.Position = calculatePosition(points)
    end
end)

payload:Start()
```

### Tug of War

Teams compete for a single shared progress bar.

```lua
local tugOfWar = Terminal.new("Tug of War", {
    Teams = {game.Teams.Red, game.Teams.Blue},
    Parts = {workspace.CenterZone},
    
    PointsNeeded = 1000,
    Increase = 2,
    Rollback = 2,
    
    CaptureTime = 0.1,  -- Instant capture
    RequireDominanceToIncrease = false,
    ProgressWhileContested = false,
    CaptureStacking = true
})

tugOfWar:Start()
```

## Properties

### Read-Only State Properties

```lua
terminal.Name          -- Terminal identifier
terminal.Active        -- boolean: Is terminal running?
terminal.Paused        -- boolean: Is terminal paused?
terminal.Overtime      -- boolean: Is overtime active?
terminal.Contested     -- boolean: Multiple teams in zone?
terminal.Holders       -- {Team}: Teams currently holding
terminal.Elapsed       -- number: Seconds elapsed
```

### Team Data

```lua
terminal.PlayingTeams  -- Table of team data
-- Structure: {
--   [Team] = {
--     Points: number,
--     Capturing: number,  -- 0 to CaptureTime
--     InZone: {Player}
--   }
-- }
```

**Example:**
```lua
local redTeamPoints = terminal.PlayingTeams[game.Teams.Red].Points
local blueCapturing = terminal.PlayingTeams[game.Teams.Blue].Capturing

print("Red points:", redTeamPoints)
print("Blue capture progress:", (blueCapturing / terminal.CaptureTime * 100) .. "%")
```

## UI Integration Example

```lua
local function updateUI(terminal)
    for team, data in terminal.PlayingTeams do
        local teamFrame = playerGui.Scoreboard[team.Name]
        
        -- Update points bar
        teamFrame.PointsBar.Size = UDim2.fromScale(
            data.Points / terminal.PointsNeeded, 1
        )
        
        -- Update capture progress
        teamFrame.CaptureBar.Size = UDim2.fromScale(
            data.Capturing / terminal.CaptureTime, 1
        )
        
        -- Update player count
        teamFrame.PlayerCount.Text = #data.InZone
    end
end

terminal.PointsChanged:Connect(function()
    updateUI(terminal)
end)

terminal.CapturingChanged:Connect(function()
    updateUI(terminal)
end)

terminal.ContestedChanged:Connect(function(contested)
    playerGui.Contested.Visible = contested
end)
```

## Important Notes

### Prerequisites (Automatically Checked)
1. **Unique names** - Terminals cannot share the same name
2. **At least 1 team** - Must provide at least one team
3. **At least 1 part** - Must provide at least one BasePart for the zone

### Best Practices
- **Server-side only** - This module should only run on the server
- **Don't modify after init** - Don't change `Teams` or `Parts` after creation
- **Clean up properly** - Call `:Destroy()` when done with a terminal
- **Check Active state** - Always check `terminal.Active` before resuming from pause

## Dependencies
- **ZonePlus** - For zone detection and player tracking
- **Signal** - For event handling (GoodSignal or similar)

## Contributing
1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Links
- [Wally Package](https://wally.run/package/codjo3/terminal)
- [Roblox Asset Library](https://create.roblox.com/store/asset/13884083754)
- [ZonePlus Documentation](https://devforum.roblox.com/t/zone/1017701)
