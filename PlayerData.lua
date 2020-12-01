local RunService = game:GetService("RunService")
local Players = game.Players

local Updater = script.Updater

local PlayerData = {}
local Methods = {}
--| Module Returns Methods, however, when attempting to index playerdata, it'll search PlayerData.
Methods.__index = PlayerData;

--| Local Functions
local function GetPointerFromString(Str, Number)
	local Pointer = PlayerData;
	local ParentPointer = nil;
	local IndexOrder = string.split(Str, ".");
	local CurrentIndex = nil;
	
	for i = 1, #IndexOrder do
		ParentPointer = Pointer;
		local WorkingIndex = Pointer[IndexOrder[i]] and IndexOrder[i] or Pointer[tonumber(IndexOrder[i])] and tonumber(IndexOrder[i])
		Pointer = Pointer[WorkingIndex];
		CurrentIndex = WorkingIndex or IndexOrder[i];
	end

	if Number then
		CurrentIndex = Number;
		ParentPointer = Pointer;
		Pointer = Pointer[CurrentIndex];
	end
	return Pointer, ParentPointer, CurrentIndex;
end

local function Connect(Directory, Number, Callback, Folder)
	local Pointer, ParentPointer, Index = GetPointerFromString(Directory, Number);
	if ParentPointer then
		local BindableEvent = Instance.new("BindableEvent");
		BindableEvent.Name = 
			(Directory == "" and "self") 
			or Number and "self."..Directory.."."..Number
			or "self."..Directory;
		BindableEvent.Parent = Folder;
		BindableEvent.Event:Connect(Callback)
		return {
			Disconnect = function()
				BindableEvent:Destroy();
			end
		}
	end
end

--| Public Functions

--| Events;
function Methods:IndexAdded(Directory, Function, Number)
	return Connect(Directory, Number, Function, script.IndexAddedConnections)
end

function Methods:IndexRemoved(Directory, Function, Number)
	return Connect(Directory, Number, Function, script.IndexRemovedConnections)
end

function Methods:IndexChanged(Directory, Function, Number)
	return Connect(Directory, Number, Function, script.IndexChangedConnections)
end

-- Methods
function Methods:WaitFor(Index)
	if not Index then warn("Was unable to WaitFor a non-existent index") return end
	Index = tostring(Index)
	local Start = os.clock();
	while not PlayerData[Index] do
		RunService.Stepped:Wait()
		if os.clock() - Start >= 30 then
			warn(script.Name, "Infinite yield possible on ", Index, "Elapsed Time: ", os.clock() - Start)
		end
	end
	return PlayerData[Index]
end

function Methods:Update(Index, Value, Number)
	local DirectoryValue, ParentDirectory, LastIndex = GetPointerFromString(Index, Number);
	local Condition = 
		(DirectoryValue == nil or type(DirectoryValue) == "nil") and "IndexAdded"
		or (DirectoryValue ~= nil and type(DirectoryValue) ~= "nil" and Value == nil) and "IndexRemoved"
		or (DirectoryValue ~= Value) and "IndexChanged";
	local EventName = Index == "" and "self" or "self."..Index
	if Condition == "IndexAdded" then
		local SplittedEventName = string.split(EventName, ".");
		EventName = nil
		for i = 1, #SplittedEventName-1 do
			EventName = EventName and EventName.."."..SplittedEventName[i] or SplittedEventName[i]; 
		end
		local Bindable = script[Condition.."Connections"]:FindFirstChild(EventName)
		if Bindable then
			Bindable:Fire(LastIndex, Value);
		end
	elseif Condition == "IndexRemoved" then
		local SplittedEventName = string.split(EventName, ".");
		EventName = nil
		for i = 1, #SplittedEventName-1 do
			EventName = EventName and EventName.."."..SplittedEventName[i] or SplittedEventName[i]; 
		end
		local Bindable = script[Condition.."Connections"]:FindFirstChild(EventName)
		if Bindable then
			Bindable:Fire(LastIndex, ParentDirectory[LastIndex]);
		end
	elseif  Condition == "IndexChanged" then
		local Bindable = script[Condition.."Connections"]:FindFirstChild(EventName)
		if Bindable then
			Bindable:Fire(ParentDirectory[LastIndex], Value);
		end
	end
	ParentDirectory[LastIndex] = Value;
end

Updater.OnClientEvent:Connect(function(Index, Value, Number)
	Methods:Update(Index, Value, Number)
end)

--| Prevents Memory Leaks
Players.PlayerRemoving:Connect(function(Player)
	if PlayerData[tostring(Player.UserId)] then
		PlayerData[tostring(Player.UserId)] = nil;
	end
end)

return Methods
