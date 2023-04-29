local datastoreservice = game:GetService("DataStoreService");
local runservice = game:GetService("RunService");
local serverstorage = game:GetService('ServerStorage')
local players = game:GetService("Players")
local debris = game:GetService('Debris')

local datastore_module = {};

local data_cache = {};
local objects_cache = {};
local cooldown_log = {};
local before_last_save_functions = {};

local constants = require(script.constants);

local MASTER_KEY = constants.MASTER_KEY;
local STUDIO_SAVE = constants.STUDIO_SAVE;

local datastore = datastoreservice:GetDataStore(MASTER_KEY);

local function debug_output(output_func, ...)
	if constants.DEBUG_MODE then
		output_func(...);
	end
end

local function deep_copy(data : any)
	if data == nil then
		warn(string.format("[%s]: Attempted to deep copy nil value.", script.Name))
	end
	
	local new_data = {};
	for index, value in pairs(data) do 
		if typeof(value) == "table" then
			new_data[index] = deep_copy(value);
		else
			new_data[index] = value;
		end
	end
	return new_data;
end

local function request(player : Player, request_type : string, callback, new_thread : boolean)
	
	if not cooldown_log[player] then
		cooldown_log[player] = {};
		for index, cooldown in pairs(constants.REQUEST_COOLDOWNS) do 
			cooldown_log[player][index] = os.clock() - cooldown;
			cooldown_log[player]["IS_"..index] = false;
		end
	end
	
	if os.clock() - cooldown_log[player][request_type] >= constants.REQUEST_COOLDOWNS[request_type] 
		and not cooldown_log[player]["IS_"..request_type] then
		
		local function commit()
			cooldown_log[player]["IS_"..request_type] = true;
			local success, err, r = pcall(callback)
			cooldown_log[player][request_type] = os.clock();
			cooldown_log[player]["IS_"..request_type] = false;

			if not success then
				debug_output(warn, string.format("\n[%s]: Failed Request Call For %s \n[Request Type]: %s\n[Warning]: %s", script.Name, tostring(player.UserId), request_type, err))
			else
				debug_output(print, string.format("\n[%s]: Success Request Call For %s \n[Request Type]: %s", script.Name, tostring(player.UserId), request_type))
			end
			
			return success, err
		end
		
		if new_thread then
			task.spawn(commit)
		else
			return commit()
		end
	else
		if not constants.IGNORE_COOLDOWN_MESSAGE then
			debug_output(warn, string.format("\n[%s]: Failed Request Call For %s \n[Request Type]: %s\n[Warning]: %s", script.Name, tostring(player.UserId), request_type, "On Cooldown Or Already Reading"))
		end	
		return false, "on cooldown";
	end
end


local total_connections = 0;
function datastore_module:on_change(change_function : any)
	local connection_id = tostring(total_connections + 1);
	total_connections += 1;
	
	self.connections[connection_id] = change_function;
	
	return {
		Disconnect = function()
			self.connections[connection_id] = nil
		end,
	}
end

function datastore_module:increment(increment_value : number)
	local userid = self.player.UserId;

	if data_cache[userid] then
		local index_splitted = string.split(self.branch_index, "/")
		local indexed = true;
		local data_memory_reference = data_cache[userid][MASTER_KEY]
		for i = 1, #index_splitted - 1 do 
			local index = index_splitted[i];
			if not data_memory_reference[index] then
				debug_output(warn, string.format("\n[%s]: Failed to index %s because it does not exist", script.Name, index))
				indexed = false;
				break;
			else
				data_memory_reference = data_memory_reference[index];
			end
		end
		
		if not indexed then
			return nil;
		else
			if typeof(data_memory_reference[index_splitted[#index_splitted]]) == "number" then

				data_memory_reference[index_splitted[#index_splitted]] += increment_value;

				for _, change_function in pairs(self.connections) do 
					change_function(data_memory_reference[index_splitted[#index_splitted]])
				end

				if not data_cache[userid].session_end_saving then
					-- we will only attempt to update values if session is not ending. If it is, we will only edit the value.
					request(self.player, "WRITE", function()
						datastore:UpdateAsync(userid, function(old_data)
							local save_data = deep_copy(data_cache[userid][MASTER_KEY])
							save_data.session_updated = os.time()
							return save_data
						end)
					end, true)
				end
				return data_memory_reference[index_splitted[#index_splitted]]
			else
				warn(string.format("[%s]: attempted to increment non-numeric value for '%s', please check :increment() calls.", script.Name, self.branch_index))
				return nil;
			end
		end
	end
end

function datastore_module:set(new_value : any)
	local userid = self.player.UserId;
	
	if data_cache[userid] then
		local index_splitted = string.split(self.branch_index, "/")
		local indexed = true;
		local data_memory_reference = data_cache[userid][MASTER_KEY]
		for i = 1, #index_splitted - 1 do 
			local index = index_splitted[i];
			if not data_memory_reference[index] then
				debug_output(warn, string.format("\n[%s]: Failed to index %s because it does not exist", script.Name, index))
				indexed = false;
				break;
			else
				data_memory_reference = data_memory_reference[index];
			end
		end

		if not indexed then
			return nil;
		else
			data_memory_reference[index_splitted[#index_splitted]] = new_value;
			
			for _, change_function in pairs(self.connections) do 
				change_function(new_value)
			end
			
			if not data_cache[userid].session_end_saving then
				-- we will only attempt to update values if session is not ending. If it is, we will only edit the value.
				request(self.player, "WRITE", function()
					datastore:UpdateAsync(userid, function(old_data)
						local save_data = deep_copy(data_cache[userid][MASTER_KEY])
						save_data.session_updated = os.time()
						return save_data
					end)
				end, true)
			end
			return data_memory_reference[index_splitted[#index_splitted]]
		end
	end
end

function datastore_module:get(default_value : any)
	local userid = self.player.UserId;
	
	if not data_cache[userid] and not self.player:GetAttribute("retrieving_player_data") then
		self.player:SetAttribute("retrieving_player_data", true)
		-- if the user just joined. We will retrieve their masterkey data.	
		local success, error, data
		local in_session = true;
		while (not success or in_session) do 
			
			success, error = request(self.player, "READ", function()
				data = datastore:UpdateAsync(userid, function(old_data)
					if not old_data then
						old_data = {};
						in_session = false;
					elseif (old_data.session_id == nil) or os.time() - old_data.session_updated >= constants.MAX_RETRY_DURATION then
						in_session = false;
					end
					if not in_session then
						old_data.session_id = game.JobId;
						old_data.session_updated = os.time();
					end
					
					if self.player and self.player.Parent == players then
						return old_data;
					else
						debug_output(warn, string.format("[%s] %s left the game while retrieving data. Changes cancelled.", script.Name, tostring(userid)))
						return nil
					end
				end);
			end)
			
			if success and in_session then
				local time_left = constants.MAX_RETRY_DURATION - (os.time() - data.session_updated)
				debug_output(warn, 
					string.format(
						"[%s]: Failed to retrieve %s data because they are session locked (%s second(s) left).", 
						script.Name, 
						tostring(userid), 
						tostring(time_left)
					)
				)
			elseif not success then
				debug_output(warn, string.format("[%s]: Failed to retrieve %s data because %s", script.Name, tostring(userid), error))
			end	
			task.wait();
		end
		
		-- update master key
		data_cache[userid] = {
			[MASTER_KEY] = data,
			session_end_saving = false,
		}
				
		local bindable = Instance.new("BindableEvent");
		bindable.Name = userid.."_session_end_bindable";
		bindable.Parent = script.session_end_bindables;
		
		self.player:SetAttribute("retrieving_player_data", nil)
	elseif self.player:GetAttribute("retrieving_player_data") then
		while self.player:GetAttribute("retrieving_player_data") do 
			task.wait()
		end
	end
	
	if self.player and self.player.Parent == players then
		local index_splitted = string.split(self.branch_index, "/")
		local indexed = true;
		local data_memory_reference = data_cache[userid][MASTER_KEY]
		for i = 1, #index_splitted - 1 do 
			local index = index_splitted[i];
			if not data_memory_reference[index] then
				debug_output(warn, string.format("\n[%s]: Failed to index %s because it does not exist", script.Name, index))
				indexed = false;
				break;
			else
				data_memory_reference = data_memory_reference[index];
			end
		end
		
		if not indexed then
			return nil;
		else
			if not data_memory_reference[index_splitted[#index_splitted]] then
				data_memory_reference[index_splitted[#index_splitted]] = default_value;
			end
			
			return data_memory_reference[index_splitted[#index_splitted]]
		end
	end
end

local function session_end_save(player : Player)
	local userid = player.UserId;
	
	local session_end_bindable = script.session_end_bindables:FindFirstChild(userid.."_session_end_bindable")
	if data_cache[userid] and not data_cache[userid].session_end_saving and session_end_bindable then
		data_cache[userid].session_end_saving = true;
		
		for _, callback in pairs(before_last_save_functions) do 
			callback(player);
		end
		
		local now = os.clock();
		local success, error
		while not success and os.clock() - now < constants.MAX_RETRY_DURATION do 
			success, error = request(player, "WRITE", function()
				datastore:UpdateAsync(userid, function(old_data)
					local data = deep_copy(data_cache[userid][MASTER_KEY])
					data.session_id = nil;
					data.session_updated = nil;
					return data;
				end);
			end)

			if success then
				debug_output(print, string.format("[%s]: Successfully Ended Session Save For %s", script.Name, tostring(userid)))
			end
			
			task.wait();
		end
		
		session_end_bindable:Fire();
		data_cache[userid] = nil;
		cooldown_log[userid] = nil;
		objects_cache[userid] = nil;
		session_end_bindable:Destroy()
	end
end

local function player_added(player : Player)
	player.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			session_end_save(player)
		end
	end)
end

players.PlayerRemoving:Connect(function(player : Player)
	session_end_save(player);
end)
players.PlayerAdded:Connect(player_added);
for _, player in ipairs(players:GetPlayers()) do player_added(player) end;

if not runservice:IsStudio() or STUDIO_SAVE then
	game:BindToClose(function()
		local to_save_counter = #script.session_end_bindables:GetChildren();
		local saved_counter = 0;
		for _, session_end_bindable in pairs(script.session_end_bindables:GetChildren()) do 
			session_end_bindable.Event:Connect(function()
				saved_counter += 1;
			end)
		end
		
		for _, player in pairs(players:GetPlayers()) do 
			task.spawn(session_end_save, player);
		end
		
		while saved_counter < to_save_counter do
			task.wait();
		end
	end)
end

return {
	new = function(branch_index : string, player : Player)
		if not objects_cache[player.UserId] then
			objects_cache[player.UserId] = {};
		end
		
		local data_object = objects_cache[player.UserId][branch_index] or {
			branch_index = branch_index;
			player = player;
			connections = {},
		}
		
		setmetatable(data_object, {__index = datastore_module});
		objects_cache[player.UserId][branch_index] = data_object;
		return data_object
	end,
	remove_data = function(userid : number)
		local success, error = pcall(function()
			datastore:RemoveAsync(userid)
		end)

		if success then
			print(string.format("[%s]: %s's data has been successfully removed.", script.Name, tostring(userid)))
		else
			warn(string.format("[%s]: %s's data has been failed to be removed.", script.Name, tostring(userid)))
		end
	end,
	before_last_save = function(callback)
		table.insert(before_last_save_functions, callback)
	end,
}
