-- services
local players = game.Players;
local datastoreservice : DataStoreService = game:GetService("DataStoreService");

local session_lock_datastore : DataStore = datastoreservice:GetDataStore("session_lock_data")

local player_datastore : {} = {}

local datastore_settings = require(script.datastore_settings);

local player_data_cache : {} = {};
local player_state_cache : {} = {};

local starter_data_set : boolean = false;
local server_shutting_down : boolean = false;
local STARTER_DATA

--[[
	deepCopy
	
	@param value any value to deep copy
	@return the deep copied value could be nil
]]
local function deepCopy(value : any) : {}?
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

--[[
	output
	
	@param output_function a callback / function for outputting data
	@param ... additional arguments for printing
	@return nil
]]
local function output(outputFunction : () -> unknown?, ...) : nil
	if datastore_settings.DEBUG_MODE then
		outputFunction(...);
	end
end

--[[
	waitForDatastoreBudget
	
	Yields current thread until there is enough budget to continue

	@param request_type Enum.DataStoreRequestType to yield for
	@return nil
]]
local function waitForDatastoreBudget(request_type : Enum.DataStoreRequestType) : nil
	local budget = datastoreservice:GetRequestBudgetForRequestType(request_type)
	output(print, string.format("[%s Budget]: %d", request_type.Name, budget));
	while budget < 0 do 
		budget = datastoreservice:GetRequestBudgetForRequestType(request_type);
		task.wait()
	end
end

--[[
	requestDatastoreRequest
	
	@param userid the user id 
	@param request_type the datastore request_type to perform, one of the indexes in REQUEST_PER_MINUTE 
	@return boolean, result the success and result of the protected call
]]
local function requestDatastoreRequest(userid : number, request_type : string, datastore_request_type : Enum.DataStoreRequestType, protectedCall : () -> any?, session_end : boolean)
	local success : boolean, result : any? = false, nil; 
	
	-- we will keep trying while we are not successful and session end is true or player exists
	while (not success and (session_end or players:GetPlayerByUserId(userid))) do
		-- make sure we are not going over the limit;
		waitForDatastoreBudget(datastore_request_type);
		
		success, result = pcall(protectedCall);
		
		if not success then
			if (session_end) then
				-- will wait to try again
				output(warn, string.format("[%s]: (Session End) Failed to %s for %d. Request Type: %s, error: %s", script.Name, datastore_request_type.Name, userid, request_type, tostring(result)))
			elseif not session_end and not players:GetPlayerByUserId(userid) then
				output(warn, string.format("[%s]: %d user left while trying to %s", script.Name, userid, datastore_request_type.Name))
			elseif (not session_end and players:GetPlayerByUserId(userid)) then
				-- we will yield if we need the player as its not urget based on session end;
				local yield_duration : number = 60 / datastore_settings.REQUEST_PER_MINUTE[request_type];
				task.wait(yield_duration)
				output(warn, string.format("[%s]: Failed to %s for %d. Request Type: %s, error: %s", script.Name, datastore_request_type.Name, userid, request_type, tostring(result)))
			end
		end
	end
	
	return success, result;
end


--[[
	getDatastore
	
	@param userid the userid to retrieve data from
	@return datastore, ordered_datastore corresponding to provided userid
]]
local function getDatastore(userid : number) : ...any
	local datastore, ordered_datastore = datastoreservice:GetDataStore(userid..datastore_settings.VERSION), datastoreservice:GetOrderedDataStore(userid..datastore_settings.VERSION);
	return datastore, ordered_datastore;
end

--[[
	getESTDate
	
	retrieves time in EST;
	
	@return os.date of time in EST
]]
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

--[[
	formatTimeWithAMPM
	
	@param date_table the os.date table
	@return formatted string with AM/PM
]]
local function formatTimeWithAMPM(date_table) : string
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

--[[
	player_datastore.get
	
	@param player the player object
	@return cached player data
]]
function player_datastore.get(player : Player) : {}?
	local userid : number = player.UserId;
	
	while players:GetPlayerByUserId(userid) and (not player_state_cache[userid] or not player_state_cache[userid].data_loaded) do 
		task.wait()
	end	
	
	return player_data_cache[userid];
end

--[[
	player_datastore.save
	
	@param userid the player userid
	@param session_end boolean indicating session_end
]]
function player_datastore.save(userid : number, session_end : boolean)
	if not player_state_cache[userid] or not player_state_cache[userid].data_loaded then return end;
	if session_end and player_state_cache[userid].session_end_saving then return end;
	if not session_end and player_state_cache[userid].session_end_saving then return end; -- we will not save if we are session end saving
	if not player_data_cache[userid] then return end;

	local data_to_save : {}? = deepCopy(player_data_cache[userid])

	local datastore : DataStore, ordered_datastore : OrderedDataStore = getDatastore(userid)

	if (not session_end and not player_state_cache[userid].is_saving) or session_end then
		player_state_cache[userid].is_saving = true;
		
		if session_end and not player_state_cache[userid].session_end_saving then
			player_state_cache[userid].session_end_saving = true;
		end
		
		local current_time : number = os.time();
		local est_date_time_str : string = formatTimeWithAMPM(getESTDate())

		-- first save to our ordered datastore logs
		local success_ordered_datastore_save : boolean, result : any? = requestDatastoreRequest(userid, "Set", Enum.DataStoreRequestType.SetIncrementSortedAsync, function()
			return ordered_datastore:SetAsync(est_date_time_str, current_time);
		end, session_end)
		
		if success_ordered_datastore_save then
			local success_datastore_save, _ = requestDatastoreRequest(userid, "Set", Enum.DataStoreRequestType.SetIncrementAsync, function()
				return datastore:SetAsync(current_time, data_to_save)
			end, session_end)
			
			-- this is succesful data saving
			if success_datastore_save then
				if not session_end then
					player_state_cache[userid].last_save = os.time()
					player_state_cache[userid].is_saving = false;
					output(print, string.format("[%s]: %d's data has been auto-saved.", script.Name, userid))
				else
					-- initially make reference to player_bindable
					local player_bindable : BindableEvent = player_state_cache[userid].player_bindable

					-- first, we will clear the player server data to prevent any form of manipulation with it
					player_data_cache[userid] = nil;
					player_state_cache[userid] = nil;

					-- next we will request to remove the session lock 
					local success_session_lock_remove : boolean = requestDatastoreRequest(userid, "Remove", Enum.DataStoreRequestType.SetIncrementAsync, function()
						return session_lock_datastore:RemoveAsync(userid);
					end, session_end)

					-- if we ended the session then we will finish with this player
					if success_session_lock_remove then
						-- finally we will signal that we are complete and let the server die
						player_bindable:Fire();
						player_bindable:Destroy();
						
						output(print, string.format("[%s]: %d's session has been ended. Data has been saved.", script.Name, userid))
					end
				end		
			end	
		end
	
	end
end

--[[
	player_datastore.setStarterData
	
	@param starter_data the player starter data 
	@return nil
]]
function player_datastore.setStarterData(starter_data : any)
	STARTER_DATA = deepCopy(starter_data)
	starter_data_set = true;
end

--[[
	player_datastore.getPlayerState
	
	@param userid the player userid
	@param state the player state
]]
function player_datastore.getPlayerState(userid : number, state : string)
	while players:GetPlayerByUserId(userid) and not player_state_cache[userid] do 
		task.wait()
	end
	return player_state_cache[userid][state];
end

--[[
	playerAdded
	
	@param player the added player
]]
local function playerAdded(player : Player)
	-- wait for starter_data to be set.
	while not starter_data_set do 
		output(warn, string.format("[%s]: Waiting for starter data to be set.", script.Name));
		task.wait()
	end
	
	local userid : number = player.UserId;
	
	local player_bindable : BindableEvent = Instance.new("BindableEvent");
	player_bindable.Name = player.Name;
	player_bindable.Parent = script.player_bindables;
	
	-- we want to create a state_cache for the player.
	player_state_cache[userid] = {
		is_saving = false,
		last_save = os.time(),
		session_end_saving = false,
		data_loaded = false,
		player_bindable = player_bindable;
	}

	-- when a player joins, we should retrieve their data.
	local datastore : DataStore, ordered_datastore : OrderedDataStore = getDatastore(userid);
	
	-- this section will wait until their session data is retrieved AND they are not in session
	local success : boolean, result : any?, is_session_locked : boolean = false, false, false;
	-- while request is not successful and the player still exists or there is session data but player is locked in session we will yield
	while (not success and players:GetPlayerByUserId(userid)) or (success and is_session_locked and players:GetPlayerByUserId(userid)) do 
		success, _ = requestDatastoreRequest(userid, "Set", Enum.DataStoreRequestType.UpdateAsync, function()
			return session_lock_datastore:UpdateAsync(userid, function(old_data : {}?)
				if not old_data then
					-- we do not have a session,
					is_session_locked = false;
					output(print, string.format("[%s]: %d is not session locked. Session has been established.", script.Name, userid))
					return {
						last_update = os.time();
						server = game.JobId;	
					}
				elseif old_data then
					if os.time() - old_data.last_update >= datastore_settings.SESSION_LOCK_TIMEOUT then
						-- you are not in session lock;
						output(print, string.format("[%s]: %d is not session locked. (session timed out)", script.Name, userid))
						is_session_locked = false;
					else
						local time_left : number = datastore_settings.SESSION_LOCK_TIMEOUT - (os.time() - old_data.last_update)
						output(print, string.format("[%s]: %d is session locked. (%d Second(s))", script.Name, userid, time_left))
						-- you are in session lock. 
						is_session_locked = true
					end
				end
			end)
		end)

		-- We can use a small wait because requestDatastoreRequest will yield
		if (is_session_locked) then
			local yield_interval : number = 60 / datastore_settings.REQUEST_PER_MINUTE.Set; -- calculate minimal yield interval for setting
			task.wait(yield_interval); 
		end
	end
		
	-- is the player still in game?
	if players:GetPlayerByUserId(userid) then
		-- we are retrieving the last_data_key for the user
		success, result = requestDatastoreRequest(userid, "GetSorted", Enum.DataStoreRequestType.GetSortedAsync, function()
			return ordered_datastore:GetSortedAsync(false, 1)
		end)

		if players:GetPlayerByUserId(userid) then
			local last_data_key : number? = result:GetCurrentPage()[1] and result:GetCurrentPage()[1].value;
			if not last_data_key then
				-- this means that, the player is a new player to this experience/game.
				player_data_cache[userid] = deepCopy(STARTER_DATA);
			else
				-- this means that the player HAS played the game before.
				success, result = requestDatastoreRequest(userid, "Get", Enum.DataStoreRequestType.GetAsync, function()
					return datastore:GetAsync(last_data_key);
				end)
				if players:GetPlayerByUserId(userid) then
					if result ~= "data_reset" and result then
						player_data_cache[userid] = result;
					elseif result == "data_reset" then
						-- this means that, the player had their data deleted and should use new data.
						player_data_cache[userid] = deepCopy(STARTER_DATA);
					end
				else
					requestDatastoreRequest(userid, "Set",Enum.DataStoreRequestType.SetIncrementAsync, function() 
						return session_lock_datastore:RemoveAsync(userid);
					end)
				end
			end
			player_state_cache[userid].data_loaded = true;
			
			output(print, string.format("[%s]: %d's data has been loaded.", script.Name, userid))
		else
			requestDatastoreRequest(userid, "Set",Enum.DataStoreRequestType.SetIncrementAsync, function() 
				return session_lock_datastore:RemoveAsync(userid);
			end)
		end
	else
		requestDatastoreRequest(userid, "Set",Enum.DataStoreRequestType.SetIncrementAsync, function() 
			return session_lock_datastore:RemoveAsync(userid);
		end)
	end
	
	player.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			player_datastore.save(userid, true);
		end
	end)
end

--[[
	playerRemoving
	
	@param player the player object
	@return the nil type
]]
local function playerRemoving(player : Player)
	local userid : number = player.UserId;
	player_datastore.save(userid, true)
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
	for userid : number, state_data : {} in pairs(player_state_cache) do 
		if state_data.data_loaded then
			total_data_loaded += 1;
			task.spawn(function()
				state_data.player_bindable.Event:Wait();
				saved_data += 1;
			end)
			task.spawn(player_datastore.save, userid, true);
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
			local userid : number = player.UserId;
			if player_state_cache[userid] and (os.time() - player_state_cache[userid].last_save >= datastore_settings.SAVE_FREQUENCY) then
				task.spawn(player_datastore.save, userid, false);			
			end
		end
		task.wait();
	end
end)

return player_datastore

