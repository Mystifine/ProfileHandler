--[[
	Module Name: ProfileHandler
	Description: Module is used to handle data in Roblox.
	Written by: Mystifine
	Last Updated: 22/12/2024
]]

export type ProfileHandler = {
	newProfile : (datastore_id : string, profile_id : string, respect_session_lock : boolean, data : {}?) -> Profile;
	getProfileAsync : (datastore_id : string, profile_id : string) -> (boolean, any?);
	updateProfileAsync : (datastore_id : string, profile_id : string, transformationFunction : (old_data : any?) -> any?) -> (boolean, any?);
	getProfile : (datastore_id : string, profile_id : string) -> Profile?;	
};

-- SERVICES
local DataStoreService = game:GetService("DataStoreService");

-- MODULES
local ProfileHandlerSettings = require(script.ProfileHandlerSettings);
local ProfileClass = require(script.ProfileClass);
local DebugModule = require(script.Util.DebugModule);
local DeepCopy = require(script.Util.DebugModule)

export type Profile = ProfileClass.Profile;

-- VARS
local bindable_storage = script.Bindables;

-- SERVER STATE
local SERVER_CLOSING = false;

local ProfileHandler = {}

function ProfileHandler.getProfileAsync(datastore_id : string, profile_id : string) : (boolean, any?)
	local datastore : DataStore = DataStoreService:GetDataStore(datastore_id);

	local read_success, read_result = pcall(function()
		return datastore:GetAsync(profile_id);
	end)

	return read_success, read_result;
end

function ProfileHandler.updateProfileAsync(datastore_id : string, profile_id : string, transformationFunction : (old_data : any?) -> any?) : (boolean, any?)
	local datastore : DataStore = DataStoreService:GetDataStore(datastore_id);

	local edit_success, edit_result = pcall(function()
		return datastore:UpdateAsync(profile_id, transformationFunction);
	end)

	return edit_success, edit_result;
end

function ProfileHandler.getProfile(datastore_id : string, profile_id : string)
	return ProfileClass.getProfile(datastore_id, profile_id)
end

function ProfileHandler.newProfile(datastore_id : string, profile_id : string, respect_session_lock : boolean, data : {}?) : ProfileClass.Profile?
	-- If the server is closing, ignore new profile request.
	if SERVER_CLOSING then return end; 
	
	local profile : ProfileClass.Profile = ProfileClass.newProfile(datastore_id, profile_id, respect_session_lock, data);
	profile:Load();
	
	return profile;
end

task.spawn(function()
	while true do 
		local cached_profiles = ProfileClass.getCachedProfiles();
		for datastore_id : string, datastore_profiles in pairs(cached_profiles) do
			for profile_id : string, profile : ProfileClass.Profile in pairs(datastore_profiles) do 
				if (os.time() - profile._last_save >= ProfileHandlerSettings.AUTO_SAVE_INTERVAL) and profile._data_loaded then
					profile:Save(false);
				end
			end
		end
		
		task.wait(1);
	end
end)

game:BindToClose(function()
	SERVER_CLOSING = true;
	
	local cached_profiles = ProfileClass.getCachedProfiles();
	local total_bindable_count = 0;
	local bindable_signals = 0;
	
	-- Count the amount of bindables to listen to
	for _, datastore_profiles in pairs(cached_profiles) do 
		for profile_id : string, profile : ProfileClass.Profile in pairs(datastore_profiles) do 
			if profile._data_loaded then
				total_bindable_count += 1;
				profile.save_bindable_event.Event:Connect(function()
					bindable_signals += 1;
				end)
				
				task.spawn(function()
					profile:Save(true);
				end)		
			end
		end
	end
	
	while (bindable_signals ~= total_bindable_count) do 
		task.wait();
	end
end)

return ProfileHandler :: ProfileHandler
