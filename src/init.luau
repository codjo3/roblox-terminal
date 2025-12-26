-- jaydonbocco/JaydonsFault
--[[

Terminal.getTerminalFromName(name)
	-- will either return a TerminalBase with the name given or nil
	-- if a terminal with the name given does not exist

Terminal.new(name, { ... }): TerminalBase?
	-- a name can be any type, not just a string
	-- settings for the terminal is documented if you scroll down a bit
	-- returns a TerminalBase

TerminalBase:Start(...): nil
	-- if it starts, you can use the TerminalBase.Started signal 
	-- to know when it has loaded, and it will return the parameters it was given

TernimalBase:Stop(...): nil
	-- if it stops, you can use the TerminalBase.Stopped signal
	-- to know when it has stopped, and it will return the winner (nil if there wasn't one) the parameters it was given

TerminalBase:Pause(...): nil
	-- if it stops, you can use the TerminalBase.OnPaused signal
	-- to know when it has paused, and it will return the parameters it was given

To resume the terminal, do `TerminalBase.Paused = false`, but check if TerminalBase.Active is true first

PREREQUESITES WHEN MAKING A TERMINAL (The code automatically checks these):
-- 1. Terminals can't have the same name
-- 2. At least 1 Team must be given
-- 3. At least 1 BasePart must be given

So a terminal with the minimal amount of required information looks like this:
local minimalTerminal = Terminal.new("Minimal Terminal", {
	Teams = {game:GetService("Teams").Red},
	Parts = {workspace:WaitForChild("Part")}
})

NOTICES
-- The teams and the parts inside the terminal should not be changed after initialized or else the code breaks!
		-- with that being said, it would be a great idea if the terminal ran on the server!

]]

local Packages = script:WaitForChild("Packages")
local Zone = require(Packages:WaitForChild("ZonePlus"))
local Signal = require(Packages:WaitForChild("Signal"))

local Terminals = {}
local Terminal = {}
Terminal.__index = Terminal

export type Settings = {
	Increase: number?,
	Rollback: number?,
	PointsNeeded: number?,

	RequireDominanceToIncrease: boolean?,
	ProgressWhileContested: boolean?,

	CaptureWhileDead: boolean?,
	CaptureStacking: boolean?,
	CaptureTime: number?,

	OvertimeThreshold: number?,
	OvertimeIncrease: number?,
	OvertimeRollback: number?,
	OvertimePointsNeeded: number?,
	OvertimeDefenderWinFullDominance: boolean?,

	DefendingTeam: Team?,
	Teams: { Team },
	Parts: { BasePart },
}

export type Terminal = {
	-------------------------------------------
	-- SETTINGS

	Increase: number, -- Determines the rate at which the dominant team earns points per second.
	Rollback: number, -- Controls the rate at which points decrease for non-dominant teams per second.
	PointsNeeded: number, -- Sets the threshold of points required for a team to win the game.

	RequireDominanceToIncrease: boolean, -- Determines whether other teams need to have zero points for the dominant team to earn points.
	ProgressWhileContested: boolean, -- Specifies whether the dominant team continues to earn points even when the terminal is contested by other teams.

	CaptureWhileDead: boolean, -- Controls whether progress is still made towards capturing the terminal while players are in a "dead" state.
	CaptureStacking: boolean, -- Determines whether each team's progress contributes to capturing the terminal individually.
	-- (e.g., for game modes like Domination)
	CaptureTime: number, -- Sets the duration it takes to fully capture the terminal.

	OvertimeThreshold: number, -- Specifies the duration in seconds until overtime is triggered.
	OvertimeIncrease: number, -- Determines the rate at which points increase during overtime.
	OvertimeRollback: number, -- Controls the rate at which points decrease for non-dominant teams during overtime.
	OvertimePointsNeeded: number, -- Sets the threshold of points required for a team to win during overtime.
	OvertimeDefenderWinFullDominance: boolean, -- Enables automatic victory for defenders if they fully capture the terminal during overtime.

	Name: any,
	DefendingTeam: Team,
	Teams: { Team },
	Parts: { BasePart },

	-------------------------------------------
	-- States

	Active: boolean,
	Paused: boolean,
	Overtime: boolean,
	Contested: boolean,

	Zone: any,
	PlayingTeams: { [Team]: { Points: number, Capturing: number, InZone: { Player } } },
	Holders: { Team },
	Elapsed: number,

	-------------------------------------------
	-- Functions

	getTerminalFromName: (string) -> Terminal?,
	new: (string, Settings) -> Terminal,

	Start: (Terminal, any) -> any,
	Pause: (Terminal, any) -> any,
	Stop: (Terminal, any) -> any,

	-------------------------------------------
	-- Signal

	Started: RBXScriptSignal,
	OnPaused: RBXScriptSignal,
	Stopped: RBXScriptSignal,

	ContestedChanged: RBXScriptSignal,
	OvertimeEntered: RBXScriptSignal,

	PointsChanged: RBXScriptSignal,
	CapturingChanged: RBXScriptSignal,
	HolderAdded: RBXScriptSignal,
	HolderRemoved: RBXScriptSignal,
	ElapsedChanged: RBXScriptSignal,
	Destroying: RBXScriptSignal,
}

function Terminal.getTerminalFromName(name: any): Terminal?
	return Terminals[name]
end

function Terminal.new(name: any, settings: Settings): Terminal
	if Terminals[name] then
		error("Terminal with name " .. name .. " already exists.")
	end

	if
		not settings
		or not settings.Teams
		or not settings.Teams[1]
		or typeof(settings.Teams[1]) ~= "Instance"
		or settings.Teams[1].ClassName ~= "Team"
	then
		error("At least 1 team must be declared to create a terminal. (First team declared is the defending team)")
	end

	if not settings.Parts or not settings.Parts[1] then
		error("At least 1 part for the terminal must be given.")
	end

	-- Initialize
	local self = setmetatable({}, Terminal)
	Terminals[name] = self
	self.Name = name

	-- Game States
	self.Increase = math.max(0, settings.Increase or 1)
	self.Rollback = math.max(0, settings.Rollback or 1)
	self.PointsNeeded = math.max(0, settings.PointsNeeded or 1200)

	self.RequireDominanceToIncrease = if settings.RequireDominanceToIncrease == nil
		then true
		else settings.RequireDominanceToIncrease
	self.ProgressWhileContested = if settings.ProgressWhileContested == nil
		then true
		else settings.ProgressWhileContested

	self.CaptureWhileDead = if settings.CaptureWhileDead == nil then false else settings.CaptureWhileDead
	self.CaptureStacking = if settings.CaptureStacking == nil then false else settings.CaptureStacking
	self.CaptureTime = math.max(0, settings.CaptureTime or 1)

	self.OvertimeThreshold = math.max(0, settings.OvertimeThreshold or 0)
	self.OvertimeIncrease = math.max(0, settings.OvertimeIncrease or 1)
	self.OvertimeRollback = math.max(0, settings.OvertimeRollback or 1)
	self.OvertimePointsNeeded = math.max(0, settings.OvertimePointsNeeded or 120)
	self.OvertimeDefenderWinFullDominance = if settings.OvertimeDefenderWinFullDominance == nil
		then true
		else settings.OvertimeDefenderWinFullDominance

	self.DefendingTeam = settings.DefendingTeam or settings.Teams[1]
	self.Teams = settings.Teams -- constant value!
	self.Parts = settings.Parts -- constant value!

	-- States
	self.Active = false
	self.Paused = false
	self.Overtime = false
	self.Contested = false

	self.Zone = nil
	self.PlayingTeams = {}
	self.Holders = {}
	self.Elapsed = 0

	for _, team: Team in ipairs(self.Teams) do
		self.PlayingTeams[team] = {
			Points = 0,
			Capturing = 1 / #self.Teams,
			InZone = {},
		}
	end

	-- Signals
	self.Started = Signal.new()
	self.OnPaused = Signal.new()
	self.Stopped = Signal.new()

	self.ContestedChanged = Signal.new()
	self.OvertimeEntered = Signal.new()

	self.PointsChanged = Signal.new()
	self.CapturingChanged = Signal.new()
	self.HolderAdded = Signal.new()
	self.HolderRemoved = Signal.new()
	self.ElapsedChanged = Signal.new()
	self.Destroying = Signal.new()

	return self :: any
end

function Terminal:Start(...)
	if self.Active then
		return
	end

	self.Active = true
	self.Paused = false
	self.Overtime = false
	self.Contested = false

	self.Zone = ZonePlus.new(self.Parts, self.CaptureWhileDead)
	self.PlayingTeams = {}
	self.Holders = {}
	self.Elapsed = 0

	local startingCapturingTime = self.CaptureTime / #self.Teams
	for _, team: Team in ipairs(self.Teams) do
		self.PlayingTeams[team] = {
			Points = 0,
			Capturing = startingCapturingTime,
			InZone = {},
		}

		self.PointsChanged:Fire(team, 0)
		self.CapturingChanged:Fire(team, startingCapturingTime)
	end

	-- Zone Connections
	self.Connections = {}
	local function playerExited(player: Player)
		for team, info in pairs(self.PlayingTeams) do
			local newTable = {}

			for i, p in ipairs(info.InZone) do
				if p ~= player then
					table.insert(newTable, p)
				end
			end

			self.PlayingTeams[team].InZone = newTable
		end

		if not self.Connections[player] then
			return
		end

		for _, connection in self.Connections[player] do
			if connection.Connected then
				connection:Disconnect()
			end
		end
	end

	local function playerEntered(player: Player)
		if player.Team and table.find(self.Teams, player.Team) then
			local humanoid = player.Character.Humanoid
			if not self.CaptureWhileDead and humanoid.Health <= 0 then
				return
			end

			table.insert(self.PlayingTeams[player.Team].InZone, player)
			if self.CaptureWhileDead then
				self.Connections[player] = {
					player:GetPropertyChangedSignal("Team"):Connect(function()
						playerExited(player)
						playerEntered(player)
					end),
				}
			else
				self.Connections[player] = {
					humanoid.Died:Connect(function()
						playerExited(player)
					end),

					player:GetPropertyChangedSignal("Team"):Connect(function()
						playerExited(player)
						playerEntered(player)
					end),
				}
			end
		end
	end

	self.Zone.playerEntered:Connect(playerEntered)
	self.Zone.playerExited:Connect(playerExited)

	-- Functions
	local winner: Team?
	local function isGameOver()
		if not self.Active then
			winner = nil
			return true
		end

		for team, info in pairs(self.PlayingTeams) do
			if info.Points >= self.PointsNeeded then
				winner = team
				return true
			end
		end

		return false
	end

	local function isOvertimeOver()
		if not self.Active then
			winner = nil
			return true
		end

		if
			self.OvertimeDefenderWinFullDominance
			and self.DefendingTeam
			and self.PlayingTeams[self.DefendingTeam].Capturing == self.CaptureTime
		then
			local allTeamsZero = true

			if not self.RequireDominanceToIncrease or self.OvertimeRollback > 0 then
				for team, info in pairs(self.PlayingTeams) do
					if team ~= self.DefendingTeam and info.Points > 0 then
						allTeamsZero = false
						break
					end
				end
			end

			if allTeamsZero then
				winner = self.DefendingTeam
				return true
			end
		end

		local winners = {}

		for team, info in pairs(self.PlayingTeams) do
			if info.Points >= self.OvertimePointsNeeded then
				table.insert(winners, team)
			end
		end

		if #winners == 0 or self.Contested then
			return false
		end

		if #winners == 1 then
			winner = winners[1]
			return true
		end

		for _, team in ipairs(winners) do
			if self.PlayingTeams[team].Capturing >= self.CaptureTime then
				winner = team
				return true
			end
		end

		return false
	end

	-- Thread
	self.thread = task.spawn(function()
		while
			not isGameOver()
			and (not self.Overtime or self.OvertimeThreshold == 0 or self.Elapsed < self.OvertimeThreshold)
		do
			local dt = task.wait()

			if self.Paused then
				continue
			end

			-- Check Contested
			local oldContested = self.Contested
			self.Contested = false

			do
				local c = 0
				for team, info in pairs(self.PlayingTeams) do
					if #info.InZone > 0 then
						c += 1
						if c > 1 then
							self.Contested = true
							break
						end
					end
				end
			end

			if self.Contested ~= oldContested then
				self.ContestedChanged:Fire(self.Contested)
			end

			-- Increment Capture Progress
			local pplInZone = 0
			for team, info in pairs(self.PlayingTeams) do
				pplInZone += #info.InZone
			end

			if self.CaptureStacking then
				for team, info in pairs(self.PlayingTeams) do
					local oldValue = info.Capturing
					local newValue = math.clamp(
						info.Capturing + dt * (#info.InZone - (pplInZone - #info.InZone) / (#self.Teams - 1)),
						0,
						self.CaptureTime
					)
					self.PlayingTeams[team].Capturing = newValue

					if oldValue ~= newValue then
						self.CapturingChanged:Fire(team, newValue)
					end
				end
			else
				for team, info in pairs(self.PlayingTeams) do
					local oldValue = info.Capturing
					local newValue = math.clamp(
						info.Capturing + dt * (math.sign(#info.InZone - (pplInZone - #info.InZone) / (#self.Teams - 1))),
						0,
						self.CaptureTime
					)
					self.PlayingTeams[team].Capturing = newValue

					if oldValue ~= newValue then
						self.CapturingChanged:Fire(team, newValue)
					end
				end
			end

			-- Determine Holders
			if not self.Contested or self.ProgressWhileContested then
				for team, info in pairs(self.PlayingTeams) do
					if info.Capturing == self.CaptureTime then
						if not table.find(self.Holders, team) then
							table.insert(self.Holders, team)
							self.HolderAdded:Fire(team)
						end
					elseif not self.ProgressWhileContested or info.Capturing == 0 then
						local i = table.find(self.Holders, team)
						if i then
							table.remove(self.Holders, i)
							self.HolderRemoved:Fire(team)
						end
					end
				end
			end

			-- Award Points
			for team, info in pairs(self.PlayingTeams) do
				if not table.find(self.Holders, team) then
					local oldValue = info.Points
					local newValue = math.max(info.Points - dt * self.Rollback, 0)
					self.PlayingTeams[team].Points = newValue

					if oldValue ~= newValue then
						self.PointsChanged:Fire(team, newValue)
					end
					continue
				end

				if not self.RequireDominanceToIncrease then
					local oldValue = info.Points
					local newValue = math.min(info.Points + dt * self.Increase, self.PointsNeeded)
					self.PlayingTeams[team].Points = newValue

					if oldValue ~= newValue then
						self.PointsChanged:Fire(team, newValue)
					end
					continue
				end

				local allTeamsZero = true

				for otherTeam, otherInfo in pairs(self.PlayingTeams) do
					if team ~= otherTeam and otherInfo.Points > 0 then
						allTeamsZero = false
						break
					end
				end

				if allTeamsZero then
					local oldValue = info.Points
					local newValue = math.min(info.Points + dt * self.Increase, self.PointsNeeded)
					self.PlayingTeams[team].Points = newValue

					if oldValue ~= newValue then
						self.PointsChanged:Fire(team, newValue)
					end
				end
			end

			-- Increment
			self.Elapsed += dt
			self.ElapsedChanged:Fire(self.Elapsed)
		end

		for team, info in pairs(self.PlayingTeams) do
			if info.Capturing == self.CaptureTime then
				return self:Stop(team) -- game won
			end
		end

		if isGameOver() or self.OvertimeThreshold == 0 or self.Elapsed < self.OvertimeThreshold then
			return self:Stop(winner) -- game ended
		end

		self.Overtime = true
		self.OvertimeEntered:Fire()
		while not isOvertimeOver() do
			local dt = task.wait()

			if self.Paused then
				continue
			end

			-- Check Contested
			local oldContested = self.Contested
			self.Contested = false

			do
				local c = 0
				for team, info in pairs(self.PlayingTeams) do
					if #info.InZone > 0 then
						c += 1
						if c > 1 then
							self.Contested = true
							break
						end
					end
				end
			end

			if self.Contested ~= oldContested then
				self.ContestedChanged:Fire(self.Contested)
			end

			-- Increment Capture Progress
			local pplInZone = 0
			for team, info in pairs(self.PlayingTeams) do
				pplInZone += #info.InZone
			end

			if self.CaptureStacking then
				for team, info in pairs(self.PlayingTeams) do
					local oldValue = info.Capturing
					local newValue = math.clamp(
						info.Capturing + dt * (#info.InZone - (pplInZone - #info.InZone) / (#self.Teams - 1)),
						0,
						self.CaptureTime
					)
					self.PlayingTeams[team].Capturing = newValue

					if oldValue ~= newValue then
						self.CapturingChanged:Fire(team, newValue)
					end
				end
			else
				for team, info in pairs(self.PlayingTeams) do
					local oldValue = info.Capturing
					local newValue = math.clamp(
						info.Capturing + dt * (math.sign(#info.InZone - (pplInZone - #info.InZone) / (#self.Teams - 1))),
						0,
						self.CaptureTime
					)
					self.PlayingTeams[team].Capturing = newValue

					if oldValue ~= newValue then
						self.CapturingChanged:Fire(team, newValue)
					end
				end
			end

			-- Determine Holders
			if not self.Contested or self.ProgressWhileContested then
				for team, info in pairs(self.PlayingTeams) do
					if info.Capturing == self.CaptureTime then
						if not table.find(self.Holders, team) then
							table.insert(self.Holders, team)
							self.HolderAdded:Fire(team)
						end
					elseif not self.ProgressWhileContested or info.Capturing == 0 then
						local i = table.find(self.Holders, team)
						if i then
							table.remove(self.Holders, i)
							self.HolderRemoved:Fire(team)
						end
					end
				end
			end

			-- Award Points
			for team, info in pairs(self.PlayingTeams) do
				if not table.find(self.Holders, team) then
					local oldValue = info.Points
					local newValue = math.max(info.Points - dt * self.OvertimeRollback, 0)
					self.PlayingTeams[team].Points = newValue

					if oldValue ~= newValue then
						self.PointsChanged:Fire(team, newValue)
					end
					continue
				end

				if not self.RequireDominanceToIncrease then
					local oldValue = info.Points
					local newValue = math.min(info.Points + dt * self.OvertimeIncrease, self.OvertimePointsNeeded)
					self.PlayingTeams[team].Points = newValue

					if oldValue ~= newValue then
						self.PointsChanged:Fire(team, newValue)
					end
					continue
				end

				local allTeamsZero = true

				for otherTeam, otherInfo in pairs(self.PlayingTeams) do
					if team ~= otherTeam and otherInfo.Points > 0 then
						allTeamsZero = false
						break
					end
				end

				if allTeamsZero then
					local oldValue = info.Points
					local newValue = math.min(info.Points + dt * self.OvertimeIncrease, self.OvertimePointsNeeded)
					self.PlayingTeams[team].Points = newValue

					if oldValue ~= newValue then
						self.PointsChanged:Fire(team, newValue)
					end
				end
			end

			-- Increment
			self.Elapsed += dt
			self.self.ElapsedChanged:Fire(self.Elapsed)
		end

		return self:Stop(winner) -- game ended
	end)

	self.Started:Fire(...)
end

function Terminal:Pause(...)
	if self.Active and not self.Paused then
		self.Paused = true
		self.OnPaused:Fire(...)
	end
end

function Terminal:Stop(...)
	if self.Active then
		self.Active = false
		self.Overtime = false
		self.Paused = false

		if self.Zone then
			self.Zone:destroy()
		end

		for _, connections in self.Connections do
			for _, connection in connections do
				if connection.Connected then
					connection:Disconnect()
				end
			end
		end

		self.Stopped:Fire(...)

		self.PlayingTeams = {}
		self.Holders = {}
		self.Elapsed = 0
	end
end

function Terminal:Destroy(...)
	self.Destroying:Fire(self, ...)
	Terminals[self.Name] = nil
	self = nil
end

return Terminal
