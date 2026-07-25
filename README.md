# Combo
Input sequences made easy
---

Combo is a lightweight library designed to provide an easy way to add input sequences to your Roblox game. On initialization, it automatically starts listening for the actions defined in its configuration, and allows you to easily define sequences using said actions.

---
### What does this do?

Simply put, it allows you to easily define and manage input sequences. You can also use it as just a general input manager.

Combo records the actions defined in its configuration, as well as the time between inputs. When it detects you've inputted a previously-defined sequence, it fires that sequence's signal, which can be grabbed through the `GetSignal()` function.

---
### API Reference

#### Types
```lua
type SequenceFrame = {
	Input: string,
	Modifiers: {string}?,
	MinDelay: number?,
	MaxDelay: number?,
}
```
```lua
type Sequence = {
	Name: string,
	Sequence: {SequenceFrame},
	Priority: number,
	ClearBuffer: boolean?,
}
```
```lua
type SequenceSignal = {
	Name: string,
	Signal: Signal.Signal
}

type BufferedInput = {
	Input : string,
	Modifiers  : {string},
	Time  : number,
}
```
```lua
type Combo = {
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
```
#### Methods

```lua
Combo.new(): Combo

-- Creates and starts a new Combo instance
```

```lua
Combo:AddSequence(Sequence: Sequence)

-- Registers an input sequence to the detection system
```

```lua
Combo:Disable(Time: Number?)

-- Disables sequence detection. If a number is specified, starts a timer for when sequence detection is reenabled
```

```lua
Combo:GetSignal(Name: string): Signal?

-- Returns a signal tied to the input sequence of the given name. If no signal is found, returns nil
```

```lua
Combo:ClearSequences()

-- Clears the current Combo instance's sequence registry
```

```lua
Combo:ClearBuffer()

-- Clears the current Combo instance's input memory
```

```lua
Combo:RemoveSequence(Sequence: string)

-- Removes a sequence from the Combo instance's registry
```

```lua
Combo:Destroy()

-- Deletes the current Combo instance
```

```lua
Combo:GetEnabled()

-- Returns whether the current Combo instance is enabled
```
