--|| Services ||--
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Datastore = {}
local CachedData = {}

--|| Modules ||--
local Configurations = require(script.Parent.Configurations)
local StarterData = require(script.Parent.StarterData)

--| Variables |--
local Updater
if RunService:IsRunning() then --| Preventing parenting PlayerData on command bar
	Updater = script.Parent.Assets.PlayerData.Updater
	script.Parent.Assets.PlayerData.Parent = game.ReplicatedStorage
end

--|| Private Functions 
local function Copy(Table)
	local NewTable = {}
	for Index, Value in next, Table do
		if typeof(Value) == "table" then
			NewTable[Index] = Copy(Value)
		else
			NewTable[Index] = Value
		end
	end
	return NewTable
end

local function GetTimeStamp()
	local Info = os.date("!*t")
	local TimeStamp = "DATE: "..Info.year.."/"..Info.month.."/"..Info.day.." | TIME: "..(Info.hour > 12 and Info.hour - 12 or Info.hour)..":"..(Info.min < 10 and "0"..Info.min or Info.min)..":"..(Info.sec < 10 and "0"..Info.sec or Info.sec).." "..((Info.hour < 12 or Info.hour == 24) and "AM" or "PM")
	return TimeStamp	
end

local function Debug(...)
	if Configurations.Debug then
		warn(script:GetFullName(), "\n", ...)
	end
end

function Datastore:Write(Player, Directory, Value, Number)
	if not Player or not CachedData[Player.UserId] or not CachedData[Player.UserId].Data then warn(script.Name, "Attempted to replicate to a non-existent player") return end
	local Pointer = CachedData[Player.UserId].Data
	local ParentPointer, LastIndex = nil, nil
	local Paths = string.split(Directory, ".")
	
	for i = 1, #Paths do
		ParentPointer = Pointer;
		local WorkingIndex = Pointer[Paths[i]] and Paths[i] or Pointer[tonumber(Paths[i])] and tonumber(Paths[i])
		Pointer = Pointer[WorkingIndex];
		LastIndex = WorkingIndex or Paths[i];
		if not ParentPointer then
			warn(script.Name, "Was unable to locate ", Paths[i], "in", ParentPointer, Pointer);
			return false;	
		end;
	end;
	
	if Number then
		ParentPointer = Pointer;
		LastIndex = Number;
		Pointer = Pointer[Number];
	end
	
	ParentPointer[LastIndex] = Value;
	-- Replicate After Value Has Changed;
	Updater:FireAllClients(Player.UserId.."."..Directory, Value, Number)
end

function Datastore:Get(UserId)
	while CachedData[UserId] and not CachedData[UserId].Data do
		RunService.Stepped:Wait()
	end
	return CachedData[UserId] and CachedData[UserId].Data or nil
end

function Datastore:Save(UserId, SessionEnd)
	if not CachedData[UserId].Data then return end
	if CachedData[UserId].IsSaving then return end
	if not Configurations.StudioSave and RunService:IsStudio() then return end
	
	CachedData[UserId].IsSaving = true
	local PlayerDatastore = DataStoreService:GetDataStore(tostring(UserId))
	
	local Success, Error = nil, nil
	Success, Error = pcall(function()
		PlayerDatastore:UpdateAsync("Data", function(OldData)
			if OldData then
				for Index, Value in next, CachedData[UserId].Data do
					OldData[Index] = Value
				end
				
				for Index, Value in next, OldData do
					if not CachedData[UserId].Data[Index] then
						OldData[Index] = nil
					end
				end
				
				if SessionEnd then
					OldData.SessionData = nil
					Debug(UserId.." Session Ending, removing session data")
				end
				
				return OldData
			end
		end)
	end)

	CachedData[UserId].IsSaving = false
	coroutine.resume(coroutine.create(function()
		Datastore:Backup(UserId)
	end))
	if not Success then
		Debug(UserId.." player data was unable to saved; "..Error)
	else
		Debug(UserId.." player data was saved")
		if SessionEnd then
			Debug(UserId.."'s Session Is Being Ended;")
			--| Clean Up Function
			coroutine.resume(coroutine.create(function()
				local Player = game.Players:GetPlayerByUserId(UserId)
				while Player do
					RunService.Stepped:Wait()
				end
				Debug(UserId.."'s Data has been removed from cache.")
				CachedData[UserId] = nil;
			end))
		end
	end
end

function Datastore:Backup(UserId)
	local PlayerBackupDatastore = DataStoreService:GetDataStore(tostring(UserId).." Backup")
	local PlayerPointerDatastore = DataStoreService:GetOrderedDataStore(tostring(UserId))
	if not CachedData[UserId] or not CachedData[UserId].Data then return end -- This means data was not loaded, don't save 
	local Data = Copy(CachedData[UserId].Data)
	
	local Timestamp, Time = GetTimeStamp(), os.time()
	local Success, Error = nil, nil
	Success, Error = pcall(function()
		PlayerPointerDatastore:SetAsync(Timestamp, Time)
	end)
	
	if not Success then
		Debug("Failed to set "..UserId.."'s pointer for backup data;"..Error)
	else
		Debug(UserId.." pointer data was set")
		Success, Error = pcall(function()
			PlayerBackupDatastore:SetAsync(Time, Data)
		end)
		
		if not Success then
			Debug("Failed to create backup data for: "..UserId.."; "..Error)
		else
			Debug("Created back up data for: "..UserId)
		end
	end
end

function Datastore:Remove(UserId) --| This will wipe a player's current data
	local PlayerBackupDatastore = DataStoreService:GetDataStore(tostring(UserId).." Backup")
	
	local Success, Error = pcall(function()
		PlayerBackupDatastore:SetAsync("Data", nil);
	end)
	
	if not Success then
		Debug("Failed to remove "..UserId.."'s data");
	else
		Debug("Successfully removed "..UserId.."'s data");
	end
end

function Datastore:Restore(UserId, VersionHistory) -- Version History Is Obtained Through The Pointer Datastore.
	local PlayerBackupDatastore = DataStoreService:GetDataStore(tostring(UserId).." Backup")
	local PlayerDatastore = DataStoreService:GetDataStore(tostring(UserId))
	local PlayerPointerDatastore = DataStoreService:GetOrderedDataStore(tostring(UserId))
	
	local CurrentPlayerData = nil;
	local Success, Error = pcall(function()
		CurrentPlayerData = PlayerDatastore:GetAsync("Data");
	end)
	
	if Success then
		if CurrentPlayerData then
			--| Creates a back up before overwriting the main file
			local Timestamp, Time = GetTimeStamp(), os.time()
			local Success, Error = nil, nil
			Success, Error = pcall(function()
				PlayerPointerDatastore:SetAsync(Timestamp, Time)
			end)

			if not Success then
				Debug("Failed to set "..UserId.."'s pointer for backup data;"..Error)
			else
				Debug(UserId.." pointer data was set")
				Success, Error = pcall(function()
					PlayerBackupDatastore:SetAsync(Time, CurrentPlayerData)
				end)

				if not Success then
					Debug("Failed to create backup data for: "..UserId.."; "..Error)
				else
					Debug("Created back up data for: "..UserId)
				end
				
				--| Now overwrite the acctual data
				local BackupData
				Success, Error = pcall(function()
					BackupData = PlayerBackupDatastore:GetAsync(VersionHistory);
				end)
				
				if not Success then
					Debug("Failed to get backup data");
					return
				else
					Debug("Backup data has been retrieved");
					Success, Error = pcall(function()
						PlayerDatastore:SetAsync("Data", BackupData)
					end)
					
					if Success then
						Debug("Successfully restored! New Data: ", BackupData, "Old Data: ", CurrentPlayerData)
					end
				end
			end
		end
	end
end

function Datastore:Load(UserId)
	-- Datastores 
	local PlayerBackupDatastore = DataStoreService:GetDataStore(tostring(UserId).." Backup")
	local PlayerDatastore = DataStoreService:GetDataStore(tostring(UserId))
	local PlayerPointerDatastore = DataStoreService:GetOrderedDataStore(tostring(UserId))
	
	coroutine.resume(coroutine.create(function()
		local Player = game.Players:GetPlayerByUserId(UserId)
		if Player then
			local Unpacker = script.Parent.Assets.Unpacker:Clone()
			Unpacker.Parent = Player:WaitForChild"PlayerGui"
		end
	end))
	
	CachedData[UserId] = {
		LastSave = os.clock(),
		IsSaving = false,
	}	
	
	local Success, Error = nil, nil
	while CachedData[UserId] and not CachedData[UserId].Data do
		Success, Error = pcall(function()
			PlayerDatastore:UpdateAsync("Data", function(OldData)
				if OldData == nil then -- If OldData doesn't exist
					OldData = {}
					for Index, Value in next, StarterData do
						OldData[Index] = Copy(Value.Data)
					end
					CachedData[UserId].Data = OldData
					OldData.SessionData = {game.JobId, os.time()}
					Debug(UserId.." had no data to begin with; locking session")
					return OldData
				else -- If There Was Previous Data
					if not OldData.SessionData 
						or OldData.SessionData[1] == game.JobId 
						or os.time() - OldData.SessionData[2] >= 10 then
						for Index, Value in next, StarterData do
							if not OldData[Index] then
								OldData[Index] = Value
							end
						end
						CachedData[UserId].Data = OldData
						OldData.SessionData = {game.JobId, os.time()}
						Debug(UserId.." had previous data; locking session")
						return OldData
					else
						Debug(UserId.." is in a session, unable to load.")
						return nil -- Cancel it
					end
				end
			end)
		end)
		
		if not Success or CachedData[UserId] and not CachedData[UserId].Data then
			Debug("Loading data was unsucccessful or was in session, yielding 6 and reiterating")
			wait(6)
		end
	end
	
	local Player = game.Players:GetPlayerByUserId(UserId)
	if not Success then
		if Player then
			Player:Kick("We couldn't load your data, in order to prevent deleting your data we must kick you. If this is occuring multiple times please contact Mystifine#4924")
		end
		Debug(UserId.." player data was unable to loaded; "..Error)
	else
		coroutine.resume(coroutine.create(function()
			if Player then
				--| Initial Replication To Local Player;
				for _, Client in next, game.Players:GetPlayers() do
					local FilteredData = {}
					local Data = CachedData[Client.UserId].Data
					if Data then
						for Index, Data in next, Data do
							if not StarterData[Index]
								or not StarterData[Index].Replication
								or StarterData[Index].Replication == "Global"
								or StarterData[Index].Replication == "Local" and Client.UserId == Player.UserId then
								FilteredData[Index] = Data;
							end
						end
						Updater:FireClient(Player, tostring(Client.UserId), FilteredData)
					end
				end
				
				--| Replicate New Player Data to Other Player's
				for _, Client in next, game.Players:GetPlayers() do
					local FilteredData = {}
					local Data = CachedData[UserId].Data
					if Data then
						for Index, Data in next, Data do
							if not StarterData[Index]
								or not StarterData[Index].Replication
								or StarterData[Index].Replication == "Global"
								or StarterData[Index].Replication == "Local" and Client.UserId == Player.UserId then
								FilteredData[Index] = Data;
							end
						end
						Updater:FireClient(Player, tostring(UserId), FilteredData)
					end
				end
			end
			
			--| Replication To Other Users.
			
			Datastore:Backup(UserId)
		end))
		Debug(UserId.." player data was loaded")
	end
end

local function GetIndexCount(Table)
	local Count = 0;
	for _, _ in next, Table do
		Count += 1;
	end
	return Count;
end

game:BindToClose(function()
	for _, Player in ipairs(game.Players:GetPlayers()) do
		Datastore:Save(Player.UserId, true)
	end
	if Configurations.StudioSave and RunService:IsStudio() or not RunService:IsStudio() then
		--| Will Yield Until All Players Are GONE
		while GetIndexCount(CachedData) > 0 do
			RunService.Stepped:Wait()
		end
	end
end)

coroutine.resume(coroutine.create(function()
	while true do				
		for UserId, Data in next, CachedData do			
			if os.clock() - Data.LastSave >= 10 and Configurations.AutoSave then
				coroutine.resume(coroutine.create(function()
					Datastore:Save(UserId)
					Data.LastSave = os.clock()
				end))
			end
		end
		RunService.Stepped:Wait()
	end
end))

return Datastore
