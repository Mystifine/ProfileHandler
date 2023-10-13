-- services
local players = game.Players;
local datastoreservice = game:GetService("DataStoreService");

local session_lock_datastore = datastoreservice:GetDataStore("session_lock_data")

local player_datastore = {}

local datastore_settings = require(script.datastore_settings);

local player_data_cache = {};
local player_state_cache = {};

local starter_data_set = false;
local server_shutting_down = false;
local STARTER_DATA

local function deepCopy(value : any)
	local copy = {};

	if typeof(value) ~= "table" then
		copy = value
	else
		for k, v in pairs(value) do 
			copy[k] = deepCopy(v);
		end
	end

	return copy
end

local function output(output_function : Function, ...)
	if datastore_settings.DEBUG_MODE then
		output_function(...);
	end
end

local function waitForDatastoreBudget(request_type : Enum.DataStoreRequestType)
	local budget = datastoreservice:GetRequestBudgetForRequestType(request_type)
	while budget < 0 do 
		budget = datastoreservice:GetRequestBudgetForRequestType(request_type);
		task.wait()
	end
end

local function requestGetDatastoreRequest(userID : number, datastore, request_type : string, key : string?)
	-- we are retrieving the last_data_key for the user
	local success, result
	while (not success and players:GetPlayerByUserId(userID)) do 
		if datastore.ClassName == "OrderedDataStore" then
			waitForDatastoreBudget(Enum.DataStoreRequestType.GetSortedAsync);
		elseif datastore.ClassName == "DataStore" then
			waitForDatastoreBudget(Enum.DataStoreRequestType.GetAsync);
		end	

		success, result = pcall(function()
			local data
			if datastore.ClassName == "OrderedDataStore" then
				data = datastore:GetSortedAsync(false, 1)
			elseif datastore.ClassName == "DataStore" then
				data = datastore:GetAsync(key)
			end

			return data
		end)

		if (not success and players:GetPlayerByUserId(userID)) then
			output(warn, string.format("[%s]: Failed to %s for %d, error: %s", script.Name, request_type, userID, tostring(result)))
			task.wait(60/datastore_settings.REQUEST_PER_MINUTE[request_type])	
		elseif (not success and not players:GetPlayerByUserId(userID)) then
			output(warn, string.format("[%s]: %d user left while trying to %s", script.Name, userID, request_type))
		end
	end
	return success, result;
end

local function requestSetDatastoreRequest(userID : number, datastore, key : string?, value : any)
	local success, result
	local now, timeout = os.clock(), (datastore_settings.SESSION_LOCK_TIMEOUT/2);
	while (not success and os.clock() - now < timeout) do 
		if datastore.ClassName == "OrderedDataStore" then
			waitForDatastoreBudget(Enum.DataStoreRequestType.SetIncrementSortedAsync)
		elseif datastore.ClassName == "DataStore" then
			waitForDatastoreBudget(Enum.DataStoreRequestType.SetIncrementAsync)
		end

		success, result = pcall(function()
			return datastore:SetAsync(key, value);
		end)

		if not success then
			output(warn, string.format("[%s]: Failed to %s for %d, error: %s", script.Name, "SetAsync", userID, tostring(result)))
			task.wait(60/datastore_settings.REQUEST_PER_MINUTE.SetAsync)
		end
	end
	return success, result
end

local function requestUpdateDatastoreRequest(userID : number, datastore, key : string?, callback : Function)
	-- we are retrieving the last_data_key for the user
	local success, result
	while (not success and players:GetPlayerByUserId(userID)) do 
		if datastore.ClassName == "DataStore" then
			waitForDatastoreBudget(Enum.DataStoreRequestType.UpdateAsync);
		elseif datastore.ClassName == "OrderedDataStore" then
			waitForDatastoreBudget(Enum.DataStoreRequestType.UpdateAsync);
		end	

		success, result = pcall(function()
			local data = datastore:UpdateAsync(key, callback)
			return data
		end)

		if (not success and players:GetPlayerByUserId(userID)) then
			output(warn, string.format("[%s]: Failed to %s for %d, error: %s", script.Name, "UpdateAsync", userID, tostring(result)))
			task.wait(60/datastore_settings.REQUEST_PER_MINUTE["UpdateAsync"])	
		elseif (not success and not players:GetPlayerByUserId(userID)) then
			output(warn, string.format("[%s]: %d user left while trying to %s", script.Name, userID, "UpdateAsync"))
		end
	end
	return success, result;
end

local function requestRemoveDatastoreRequest(userID : number, datastore, key : string?)
	local success, result
	while not success do 
		if datastore.ClassName == "OrderedDataStore" then
			waitForDatastoreBudget(Enum.DataStoreRequestType.SetIncrementSortedAsync)
		elseif datastore.ClassName == "DataStore" then
			waitForDatastoreBudget(Enum.DataStoreRequestType.SetIncrementAsync)
		end

		success, result = pcall(function()
			return datastore:RemoveAsync(key);
		end)

		if not success then
			output(warn, string.format("[%s]: Failed to %s for %d, error: %s", script.Name, "RemoveAsync", userID, tostring(result)))
			task.wait(60/datastore_settings.REQUEST_PER_MINUTE.RemoveAsync)
		end
	end
	return success, result
end

local function getDatastore(userID : number)
	local datastore, ordered_datastore = datastoreservice:GetDataStore(userID..datastore_settings.VERSION), datastoreservice:GetOrderedDataStore(userID..datastore_settings.VERSION);
	return datastore, ordered_datastore;
end

local function getESTDate()
	local utc_time = os.time()

	-- First, calculate the time zone difference in seconds
	local est_offset_seconds = -5 * 60 * 60 -- Eastern Standard Time (UTC-5)

	-- If daylight saving time is in effect, use Eastern Daylight Time (EDT) which is UTC-4
	local now = os.time() -- Get current time (time right now)
	local is_dst = os.date("*t", now).isdst -- Check if daylight saving time is in effect
	if is_dst then
		est_offset_seconds = est_offset_seconds + 60 * 60 -- Eastern Daylight Time (UTC-4)
	end

	-- Add the time zone difference to the UTC time to get the EST time in seconds
	local est_time = utc_time + est_offset_seconds

	-- Convert the EST time in seconds back to a table with date components
	local est_date = os.date("!*t", est_time)
	return est_date;
end

local function formatTimeWithAMPM(date_table)
	local am_pm = "AM"
	local hour = date_table.hour

	if hour >= 12 then
		am_pm = "PM"
	end

	if hour == 0 then
		hour = 12
	elseif hour > 12 then
		hour = hour - 12
	end

	return string.format("%d-%02d-%02d %02d:%02d:%02d %s",
		date_table.year, date_table.month, date_table.day, hour, date_table.min, date_table.sec, am_pm)
end

function player_datastore.get(player : Player)
	local userID = player.UserId;
	
	while players:GetPlayerByUserId(userID) and (not player_state_cache[userID] or not player_state_cache[userID].data_loaded) do 
		task.wait()
	end	
	
	return player_data_cache[userID];
end

function player_datastore.save(userID : number, session_end : boolean)
	if not player_state_cache[userID] or not player_state_cache[userID].data_loaded then return end;
	if session_end and player_state_cache[userID].session_end_saving then return end;
	if not player_data_cache[userID] then return end;

	local data_to_save = deepCopy(player_data_cache[userID])

	local datastore, ordered_datastore = getDatastore(userID)

	if (not session_end and not player_state_cache[userID].is_saving) or session_end then
		player_state_cache[userID].is_saving = true;
		
		if session_end and not player_state_cache[userID].session_end_saving then
			player_state_cache[userID].session_end_saving = true;
		end
		
		local current_time = os.time();
		local est_date_time_str = formatTimeWithAMPM(getESTDate())

		local success, result = requestSetDatastoreRequest(userID, ordered_datastore, est_date_time_str, current_time)
		if success then
			success, result = requestSetDatastoreRequest(userID, datastore, current_time, data_to_save)
			if success then
				if not session_end then
					output(print, string.format("[%s]: %d's data has been auto-saved.", script.Name, userID))
				else
					output(print, string.format("[%s]: %d's session is ending. Data has been saved.", script.Name, userID))
				end		
			end	
		end
		if not session_end then
			player_state_cache[userID].last_save = os.time()
			player_state_cache[userID].is_saving = false;
		else
			player_state_cache[userID].player_bindable:Fire();
			player_state_cache[userID].player_bindable:Destroy();
			player_data_cache[userID] = nil;
			player_state_cache[userID] = nil;
			local success = requestRemoveDatastoreRequest(userID, session_lock_datastore, userID)
			if success then
				output(print, string.format("[%s]: %d's session has been ended.", script.Name, userID))
			end	
		end
	end
end

function player_datastore.setStarterData(starter_data : any)
	STARTER_DATA = deepCopy(starter_data)
	starter_data_set = true;
end

function player_datastore.getPlayerState(userID : number, state : string)
	while players:GetPlayerByUserId(userID) and not player_state_cache[userID] do 
		task.wait()
	end
	return player_state_cache[userID][state];
end

local function playerAdded(player : Player)
	-- wait for starter_data to be set.
	while not starter_data_set do 
		output(warn, string.format("[%s]: Waiting for starter data to be set.", script.Name));
		task.wait()
	end
	
	local userID = player.UserId;
	
	local player_bindable = Instance.new("BindableEvent");
	player_bindable.Name = player.Name;
	player_bindable.Parent = script.player_bindables;
	
	-- we want to create a state_cache for the player.
	player_state_cache[userID] = {
		is_saving = false,
		last_save = os.time(),
		session_end_saving = false,
		data_loaded = false,
		player_bindable = player_bindable;
	}

	-- when a player joins, we should retrieve their data.
	local datastore, ordered_datastore = getDatastore(userID);
	
	-- this section will wait until their session data is retrieved AND they are not in session
	local success, is_session_locked = false, false;
	-- while request is not successful and the player still exists or there is session data but player is locked in session we will yield
	while (not success and players:GetPlayerByUserId(userID)) or (success and is_session_locked and players:GetPlayerByUserId(userID)) do 
		success, _ = requestUpdateDatastoreRequest(userID, session_lock_datastore, userID, function(old_data : {})
			if not old_data then
				-- we do not have a session,
				is_session_locked = false;
				output(print, string.format("[%s]: %d is not session locked. Session has been established.", script.Name, userID))
				return {
					last_update = os.time();
					server = game.JobId;	
				}
			elseif old_data then
				if os.time() - old_data.last_update >= datastore_settings.SESSION_LOCK_TIMEOUT then
					-- you are not in session lock;
					output(print, string.format("[%s]: %d is not session locked. (session timed out)", script.Name, userID))
					is_session_locked = false;
				else
					output(print, string.format("[%s]: %d is session locked.", script.Name, userID))
					-- you are in session lock.
					is_session_locked = true
				end
			end
		end);

		-- we want to wait depending on the situation. If they are session locked we will wait longer because it is unlikely timeout has occured
		if (is_session_locked) then
			task.wait(datastore_settings.SAVE_FREQUENCY)
		else
			task.wait();
		end
	end
		
	-- is the player still in game?
	if players:GetPlayerByUserId(userID) then
		-- we are retrieving the last_data_key for the user
		local success, result = requestGetDatastoreRequest(userID, ordered_datastore, "GetSortedAsync")
		if players:GetPlayerByUserId(userID) then
			local last_data_key = result:GetCurrentPage()[1] and result:GetCurrentPage()[1].value;
			if not last_data_key then
				-- this means that, the player is a new player to this experience/game.
				player_data_cache[userID] = deepCopy(STARTER_DATA);
			else
				-- this means that the player HAS played the game before.
				local success, result = requestGetDatastoreRequest(userID, datastore, "GetAsync", last_data_key)
				if players:GetPlayerByUserId(userID) then
					if result ~= "data_reset" and result then
						player_data_cache[userID] = result;
					elseif result == "data_reset" then
						-- this means that, the player had their data deleted and should use new data.
						player_data_cache[userID] = deepCopy(STARTER_DATA);
					end
				else
					requestRemoveDatastoreRequest(userID, session_lock_datastore, userID)
				end
			end
			player_state_cache[userID].data_loaded = true;
			
			output(print, string.format("[%s]: %d's data has been loaded.", script.Name, userID))
		else
			requestRemoveDatastoreRequest(userID, session_lock_datastore, userID)
		end
	else
		requestRemoveDatastoreRequest(userID, session_lock_datastore, userID)
	end
	
	player.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			player_datastore.save(userID, true);
		end
	end)
end

local function playerRemoving(player : Player)
	local userID = player.UserId;
	player_datastore.save(userID, true)
end

players.PlayerRemoving:Connect(playerRemoving)
players.PlayerAdded:Connect(playerAdded)
for _, player in ipairs(players:GetPlayers()) do 
	task.spawn(playerAdded, player);
end

game:BindToClose(function()
	server_shutting_down = true;
	
	-- log the total data loaded players as well as the initiate saving from bind to close.
	local total_data_loaded = 0;
	local saved_data = 0;
	for userID, state_data in pairs(player_state_cache) do 
		if state_data.data_loaded then
			total_data_loaded += 1;
			task.spawn(function()
				state_data.player_bindable.Event:Wait();
				saved_data += 1;
			end)
			task.spawn(player_datastore.save, userID, true);
		end
	end
	
	-- yield until all the data of the players are saved
	while saved_data ~= total_data_loaded do 
		task.wait()
	end
end)

-- auto save mechanic
task.spawn(function()
	-- we only auto-save if the server is not shutting down.
	while not server_shutting_down do 
		for _, player in ipairs(players:GetPlayers()) do
			local userID = player.UserId;
			if player_state_cache[userID] and (os.time() - player_state_cache[userID].last_save >= datastore_settings.SAVE_FREQUENCY) then
				task.spawn(player_datastore.save, userID, false);			
			end
		end
		task.wait();
	end
end)

return player_datastore

