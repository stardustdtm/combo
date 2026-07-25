--!strict

--[[
	
	An input sequence handler by StardustDTM
	Written for my (currently on-hold) game "Maledict"
	
	
	
	Usage examples:
	
	local ComboModule = require(path.to.Combo)
	local Combo = ComboModule.new()
	
	Combo:AddSequence({
		Name = "Melee",
		Sequence = {
			{Input = "M1"}
		},
		Priority = 1,
		ClearBuffer = false
	})
	
	Combo:AddSequence({
		Name = "Combo B",
		Sequence = {
			{Input = "M1",},
			{Input = "M1",},
			{Input = "M1", MinDelay = 0.4, MaxDelay = 0.75}
		},
		Priority = 2,
		ClearBuffer = true
	})
	
	Combo:AddSequence({
		Name = "Stinger",
		Sequence = {
			{Input = "M1", Modifiers = {"Forward"}}
		},
		Priority = 3,
		ClearBuffer = true
	})
	
	Combo:GetSignal("Melee"):Connect(function()
		-- Melee logic
	end)
	
	Combo:GetSignal("Combo B"):Connect(function()
		-- Delayed combo ender
	end)
	
	Combo:GetSignal("Stinger"):Connect(function()
		-- Dash attack
	end)
	
	-- I love Devil May Cry if you couldn't tell

]]

-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Signal = require("@self/Signal")

-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------

export type SequenceFrame = {
	Input: string,
	Modifiers: {string}?,
	MinDelay: number?,
	MaxDelay: number?,
}

export type Sequence = {
	Name: string,
	Sequence: {SequenceFrame},
	Priority: number,
	ClearBuffer: boolean?,
}

export type SequenceSignal = {
	Name: string,
	Signal: Signal.Signal
}

export type BufferedInput = {
	Input : string,
	Modifiers  : {string},
	Time  : number,
}

export type Combo = {
	_Buffer: {BufferedInput},
	_Held: {string},
	_Sequences: {Sequence},
	_Signals: {SequenceSignal},

	_Context: InputContext,
	_Player: Player,

	_Enabled: boolean,
	_DisabledTimer: number,

	AddSequence: (self: Combo, Sequence: Sequence) -> (),
	Disable: (self: Combo, Time: number?) -> (),
	Enable: (self: Combo) -> (),
	Destroy: (self: Combo) -> (),
	GetSignal: (self: Combo, Name: string) -> Signal.Signal,
	ClearSequences: (self: Combo) -> (),
	ClearBuffer: (self: Combo) -> (),
	RemoveSequence: (self: Combo, Sequence: string) -> (),
	GetEnabled: (self: Combo) -> boolean,

	_RegisterAction: (self: Combo, Action: string) -> (),
	_CleanBuffer: (self: Combo) -> (),
	_FindSequences: (self: Combo) -> (),
	_CheckModifiers: (self: Combo, Required: {string}?) -> (),
	_CheckForSequence: (self: Combo, Sequence: Sequence) -> (),
	
	_HeartbeatConnection: RBXScriptConnection,
}

local Combo = {}
Combo.__index = Combo

-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------

local Actions = require("@self/Actions")

local Config = require("@self/Config")

-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------

function Combo:_RegisterAction(Action: string)
	local self: Combo = self

	if not self._Enabled then return end

	local CurrentTime = os.clock()

	local Held = table.clone(self._Held)

	if table.find(Held, Action) then
		table.remove(Held, table.find(Held, Action))
	end

	local Input = {
		Input = Action,
		Time = CurrentTime,
		Modifiers = Held
	}

	table.insert(self._Buffer, Input)

	self:_CleanBuffer()
	self:_FindSequences()
end

function Combo:_CleanBuffer()
	local self: Combo = self

	local CurrentTime = os.clock()
	
	for i = #self._Buffer, 1, -1 do
		if CurrentTime - self._Buffer[i].Time > Config.BUFFER_LIFETIME then
			table.remove(self._Buffer, i)
		end
	end

	while #self._Buffer > Config.MAX_BUFFERED_INPUTS do
		table.remove(self._Buffer, 1)
	end
end

function Combo:_FindSequences()
	local self: Combo = self

	local BestSequence: Sequence

	for i, v in self._Sequences do
		if self:_CheckForSequence(v) then
			if not BestSequence or v.Priority > BestSequence.Priority then
				BestSequence = v
			end
		end
	end

	if BestSequence then
		self:GetSignal(BestSequence.Name):Fire()
		if BestSequence.ClearBuffer then
			table.clear(self._Buffer)
		end
	end
end

function Combo:_CheckModifiers(Required: {string}?)
	local self: Combo = self

	if not Required then return true end

	for i, v in Required do
		if not table.find(self._Held, v) then
			return false
		else
			continue
		end
	end

	return true
end

function Combo:_CheckForSequence(Sequence: Sequence)
	local self: Combo = self

	local CheckedSequence = Sequence.Sequence
	local Buffer = self._Buffer

	local BufferCount = #Buffer

	if BufferCount < 1 then return false end

	local PreviousMatchTime: number? = nil

	for i = #CheckedSequence, 1, -1 do
		local Input = CheckedSequence[i]

		local Matched = false

		local BufferInput = Buffer[BufferCount]

		if not BufferInput then return false end

		if BufferInput.Input == Input.Input then
			if Input.Modifiers and not self:_CheckModifiers(Input.Modifiers) then
				return false
			end

			if PreviousMatchTime then
				local Delay = PreviousMatchTime - BufferInput.Time
				local NextFrame = CheckedSequence[i + 1]

				if NextFrame and NextFrame.MinDelay and Delay < NextFrame.MinDelay then
					return false
				end
				if NextFrame and NextFrame.MaxDelay and Delay > NextFrame.MaxDelay then
					return false
				end
			end

			PreviousMatchTime = BufferInput.Time
			Matched = true
		end

		BufferCount -= 1

		if not Matched then
			return false
		end
	end

	return true
end

-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------

--[[
	Creates and starts a new Combo instance
]]
function Combo.new(): Combo
	if not RunService:IsClient() then
		error("Combo should only be used on the client")
	end

	local self = setmetatable({}, Combo) :: Combo

	self._Enabled = true

	self._Buffer = {}
	self._Held = {}
	self._Sequences = {}
	self._Signals = {}
	self._Player = Players.LocalPlayer
	self._DisabledTimer = 0
	

	local Context = Instance.new("InputContext")
	Context.Parent = workspace
	self._Context = Context

	for i: string, v: {Enum.KeyCode} in Actions do
		local Action: InputAction = Context:FindFirstChild(i)
		
		if not Action then
			Action = Instance.new("InputAction", Context)
			Action.Name = i
		end

		for i2, v2: Enum.KeyCode in v do
			if not Action:FindFirstChild(v2.Name) then
				local Binding = Instance.new("InputBinding", Action)
				Binding.Name = v2.Name
				Binding.KeyCode = v2
			end
		end

		Action.Pressed:Connect(function()
			table.insert(self._Held, Action.Name)
			self:_RegisterAction(Action.Name)
		end)

		Action.Released:Connect(function()
			local Held = table.find(self._Held, Action.Name)
			if not Held then return end
			table.remove(self._Held, Held)
		end)
	end

	self._HeartbeatConnection = RunService.Heartbeat:Connect(function(Delta)
		if not self._Enabled and self._DisabledTimer > 0 then
			self._DisabledTimer = math.max(0, self._DisabledTimer - Delta)
			if self._DisabledTimer == 0 then
				self._Enabled = true
			end
		end
	end)

	return self
end

--[[
	Registers an input sequence to the detection system
]]
function Combo:AddSequence(Sequence: Sequence)
	local self: Combo = self

	table.insert(self._Sequences, Sequence)

	local SequenceSignal = {
		Name = Sequence.Name,
		Signal = Signal.new()
	} :: SequenceSignal

	table.insert(self._Signals, SequenceSignal)

	return SequenceSignal
end

--[[
	Disables sequence detection. If a number is specified, starts a timer for when sequence detection is reenabled
]]
function Combo:Disable(Time: number?)
	local self: Combo = self

	if Time then
		self._DisabledTimer = Time
	end
	
	self._Enabled = false
end

function Combo:Enable()
	local self: Combo = self

	self._DisabledTimer = 0
	self._Enabled = true
end

--[[
	Returns a signal tied to the input sequence of the given name. If no signal is found, returns nil
]]
function Combo:GetSignal(Name: string): Signal.Signal?
	local self: Combo = self

	for i, v in self._Signals do
		if v.Name == Name then
			return v.Signal
		else
			continue
		end
	end

	warn(`Couldn't find signal "`..Name..`"`)
	return nil
end

--[[
	Clears the current Combo instance's sequence registry
]]
function Combo:ClearSequences()
	local self: Combo = self
	
	table.clear(self._Sequences)
	table.clear(self._Signals)
end

--[[
	Clears the current Combo instance's input memory
]]
function Combo:ClearBuffer()
	local self: Combo = self

	table.clear(self._Buffer)
end

--[[
	Removes a sequence from the Combo instance's registry
]]
function Combo:RemoveSequence(Sequence: string)
	local self: Combo = self

	local Removed: number?
	
	for i, v in self._Sequences do
		if v.Name == Sequence then
			Removed = table.find(self._Sequences, v)
		end
	end
	
	if Removed then
		table.remove(self._Sequences, Removed)
	end
end

--[[
	Deletes the current Combo instance
]]
function Combo:Destroy()
	local self: Combo = self

	self._Context:ClearAllChildren()
	self._Context:Destroy()
	self:ClearSequences()
	self._HeartbeatConnection:Disconnect()
	table.clear(self._Buffer)
end

--[[
	Returns whether the current Combo instance is enabled
]]
function Combo:GetEnabled(Name: string): boolean
	local self: Combo = self
	
	return self._Enabled
end

-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------

return Combo
