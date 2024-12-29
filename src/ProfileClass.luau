--[[
	Module Name: ProfileClass
	Description: Module is used to manage profile classes
	Written by: Mystifine
	Last Updated: 17/12/2024
]]

export type Profile = {
	_profile_id : string,
	_datastore_id : string,
	_data_loaded : boolean,
	_data : any?,

	_respect_session_lock : boolean,
	_is_session_end_saving : boolean,
	_is_saving : boolean,
	_last_save : number,
	_is_destroyed : boolean,
	_data_template : {}?,
	_events : {},

	_save_bindable_event : BindableEvent,

	-- methods
	Save : (self : Profile, session_ending : boolean) -> nil;
	Destroy : (self : Profile) -> nil;
	Delete : (self : Profile) -> boolean;
	Load : (self : Profile) -> nil;
	Reconcile : (self : Profile, data : {}?) -> boolean;
	GetData : (self : Profile, path : string?) -> any?;
	SetData : (self : Profile, path : string, data : any?) -> any?;
	IsDestroyed : (self : Profile) -> boolean,
	IsDataLoaded : (self : Profile) -> boolean,
}

local DataStoreService = game:GetService("DataStoreService");

local bindables_container = script.Parent.Bindables;

local ProfileHandlerSettings = require(script.Parent.ProfileHandlerSettings);

local DeepCopy = require(script.Parent.Util.DeepCopy);
local DebugModule = require(script.Parent.Util.DebugModule);

local cached_profiles : {[string] : {[string] : Profile}} = {};

local ProfileClass = {};
ProfileClass.__index = ProfileClass;

local function profileNotLoadedWarning(profile : Profile)
	if not profile._data_loaded then
		DebugModule.warn(string.format(
			"\nDatastore: %s\nProfile: %s\nContent: Profile data has not been loaded. Please call :Load() on profile.",
			profile._datastore_id,
			profile._profile_id
		), ProfileHandlerSettings.TRACE_BACK_MESSAGE);
	end
end

local function profileDestroyedWarning(profile : Profile)
	if profile._is_destroyed then
		DebugModule.warn(string.format(
			"\nDatastore: %s\nProfile: %s\nContent: Profile has been destroyed. Lingering reference.",
			profile._datastore_id,
			profile._profile_id
		), ProfileHandlerSettings.TRACE_BACK_MESSAGE);
	end
end

local function getProfileMetaData()
	return {
		save_version = ProfileHandlerSettings.VERSION;
		last_save_time = os.time();
		session_locked = false;
	}
end

function ProfileClass:Save(session_ending : boolean)
	local profile : Profile = self;
	local datastore : DataStore = DataStoreService:GetDataStore(profile._datastore_id);
		
	-- If the profile has been destroyed then this is illegal.
	if profile._is_destroyed then profileDestroyedWarning(profile) return end;
		
	-- If profile data has not been loaded then this is illegal.
	if not profile._data_loaded then profileNotLoadedWarning(profile) return end;
		
	-- If profile is already in issession_ending then ignore request.
	if profile._is_session_end_saving then return end;

	-- If not session ending and is saving then ignore request.
	if not session_ending and profile._is_saving then return end;

	profile._is_saving = true;
	profile._is_session_end_saving = session_ending or false;

	--[[
		Scenario: Save(false) gets called and then Save(true) gets called right after.
		Save(false) should be cancelled with Save(true) having more priority.
	]]

	local format_string;
	local update_cancelled = false;
	local update_success, update_result;
	while (not update_success) and (not update_cancelled) do 
		update_success, update_result = pcall(function()
			return datastore:UpdateAsync(profile._profile_id, function(old_data : any?)

				if not profile._data.meta_data then
					profile._data.meta_data = getProfileMetaData();
				end

				-- Remove session lock
				if (profile._is_session_end_saving) then
					profile._data.meta_data.session_locked = false;
				end
				
				profile._data.meta_data.last_save_time = os.time();

				return profile._data;
			end)
		end)

		if (not update_success) and (not update_cancelled) then
			format_string = "\nDatastore: %s\nProfile: %s\nContent: Failed to save data due to: %s."
			DebugModule.warn(string.format(format_string, profile._datastore_id, profile._profile_id, tostring(update_result)), true);

			-- The reason retryCooldown is 6 is because 6 is the lowest interval you can save at. 
			-- Saving player data is crucial so we will do it as frequently as possible.
			local retryCooldown = ProfileHandlerSettings.MINIMUM_SAVE_INTERVAL;
			local now = os.clock();
			-- We yield for the duration while checking the isSessionEndSaving property
			-- The reason is because imagine we save(false) and then save(true).
			-- We would want save(true) to overlap save(false) so we will cancel this request.
			while (os.clock() - now < retryCooldown and session_ending == profile._is_session_end_saving) do 
				task.wait();
			end

			-- If isSessionEndSaving is toggled to true (it can only be toggled once) then we need to exit immediately
			if (session_ending ~= profile._is_session_end_saving) then
				update_cancelled = true;
			end
		elseif (update_success) then
			if not profile._is_session_end_saving then
				format_string = "\nDatastore: %s\nProfile: %s\nContent: Profile data has been successfully saved."
			else
				format_string = "\nDatastore: %s\nProfile: %s\nContent: Profile session has been ended and data has been successfully saved."
			end		
			update_result = string.format(format_string, profile._datastore_id, profile._profile_id);
		elseif (update_cancelled) then
			format_string = "\nDatastore: %s\nProfile: %s\nContent: Autosave has been cancelled due to session end saving."
			update_result = string.format(format_string, profile._datastore_id, profile._profile_id);
		end
	end
	
	if not profile._is_session_end_saving then
		profile._is_saving = false;
	else
		if profile._save_bindable_event then
			profile._save_bindable_event:Fire();
		end
		profile:Destroy();
	end

	profile._last_save = os.time();
	DebugModule.print(update_result, ProfileHandlerSettings.TRACE_BACK_MESSAGE);
end

function ProfileClass:Destroy()
	-- Clean up the profile
	local profile : Profile = self;
	local profile_id = profile._profile_id;
	local datastore_id = profile._datastore_id;
	
	-- If the profile is already destroyed then cancel the action
	if profile._is_destroyed then return end;
	
	cached_profiles[datastore_id][profile_id] = nil;

	-- Clean up the cached profiles datastore category if there is no more
	if next(cached_profiles[datastore_id]) == nil then
		cached_profiles[datastore_id] = nil;
	end
	
	profile._is_destroyed = true;
	profile._save_bindable_event = profile._save_bindable_event:Destroy();
	
	local format_string = "\nDatastore: %s\nProfile: %s\nContent: Profile has been cleaned up (Destroyed).";
	DebugModule.print(string.format(format_string, datastore_id, profile_id), ProfileHandlerSettings.TRACE_BACK_MESSAGE)
end

function ProfileClass:Reconcile(data : {}?)
	-- Reconcile will fill missing data fields compared with default data. Not recursive.
	local profile : Profile = self;
	
	-- If the profile has been destroyed then this is illegal.
	if profile._is_destroyed then profileDestroyedWarning(profile) return end;

	-- If profile data has not been loaded then this is illegal.
	if not profile._data_loaded then profileNotLoadedWarning(profile) return end;
	
	if not data then
		local format_string = "\nDatastore: %s\nProfile: %s\nContent: reconcile data is nil.";
		DebugModule.warn(string.format(format_string, profile._datastore_id, profile._profile_id), ProfileHandlerSettings.TRACE_BACK_MESSAGE);
		return;	
	end

	for index, value in pairs(data) do 
		if (profile._data[index] == nil) then
			profile._data[index] = DeepCopy(value);
		end
	end
end

function ProfileClass:Delete() : boolean
	local profile : Profile = self;
	local datastore : DataStore = DataStoreService:GetDataStore(profile._datastore_id);

	local delete_success, delete_result = pcall(function()
		datastore:RemoveAsync(profile._profile_id);
	end)

	if not delete_success then
		local format_string = "\nDatastore: %s\nProfile: %s\nContent: Failed to delete profile due to: %s."
		DebugModule.warn(string.format(format_string, profile._datastore_id, profile._profile_id, delete_result), ProfileHandlerSettings.TRACE_BACK_MESSAGE);
	else
		-- Clean up the profile if we deleted the data successfully.
		profile:Destroy();
		local format_string = "\nDatastore: %s\nProfile: %s\nContent: Successfully deleted profile."
		DebugModule.print(string.format(format_string, profile._datastore_id, profile._profile_id), ProfileHandlerSettings.TRACE_BACK_MESSAGE);
	end
	
	return delete_success;
end

function ProfileClass:GetData(path : string?) : any?
	local profile : Profile = self;
	
	-- If the profile has been destroyed then this is illegal.
	if profile._is_destroyed then profileDestroyedWarning(profile) return end;

	-- If profile data has not been loaded then this is illegal.
	if not profile._data_loaded then profileNotLoadedWarning(profile) return end;

	local data = profile._data;
	
	if path then
		local splitted_string = string.split(path, ".");
		
		for i = 1, #splitted_string do 
			local str = splitted_string[i];
			
			if not data[str] then
				local format_string = "\nDatastore: %s\nProfile: %s\nContent: Failed to retrieve data. '%s' is not a valid property.";
				DebugModule.print(string.format(
					format_string, 
					profile._datastore_id, profile._profile_id, str
				),ProfileHandlerSettings.TRACE_BACK_MESSAGE);
				break;
			else
				data = data[str];
			end
		end
	end			
	
	return data;
end

function ProfileClass:SetData(path : string, value : any) : any?
	
	local profile : Profile = self;

	-- If the profile has been destroyed then this is illegal.
	if profile._is_destroyed then profileDestroyedWarning(profile) return end;

	-- If profile data has not been loaded then this is illegal.
	if not profile._data_loaded then profileNotLoadedWarning(profile) return end;

	local data = profile._data;

	local splitted_string = string.split(path, ".");

	local index = 1;
	-- The reason we do -1 is because we want the parent to set the value
	while (index < #splitted_string - 1) do 
		local str = splitted_string[index];

		if not data[str] then
			local format_string = "\nDatastore: %s\nProfile: %s\nContent: Failed to retrieve data. '%s' is not a valid property.";
			DebugModule.print(string.format(
				format_string, 
				profile._datastore_id, profile._profile_id, str
				), ProfileHandlerSettings.TRACE_BACK_MESSAGE);
			return;
		end

		index += 1;
	end

	-- We should now be at the last element
	data[splitted_string[#splitted_string]] = value;
	return data[splitted_string[#splitted_string]];
end

function ProfileClass:IsDestroyed() : boolean
	local profile : Profile = self;
	return profile._is_destroyed;
end

function ProfileClass:IsDataLoaded() : boolean
	local profile : Profile = self;
	return profile._data_loaded;
end

function ProfileClass:Load() : nil
	local profile : Profile = self;

	local datastore : DataStore = DataStoreService:GetDataStore(profile._datastore_id);

	-- Retrive the profile data
	local update_success, update_result
	
	local session_locked = false;
	local session_lock_cooldown = 0;
	local format_string;
	
	while ((not update_success) or (session_locked)) and (not profile._is_destroyed) do 
		
		update_success, update_result = pcall(function()
			return datastore:UpdateAsync(profile._profile_id, function(old_data)

				-- If there is no existing data, we will set the 'old' data to the data template data
				if not old_data then
					old_data = profile._data;
				end

				local return_result = nil;

				-- Create meta data if it doesn't exist.
				if not old_data.meta_data then
					old_data.meta_data = getProfileMetaData()
				end

				-- Everything else depends on session lock respect
				if profile._respect_session_lock then
					
					-- If the data has no session lock or the session lock timer ran out we are allowed to retrieve the data
					if (not old_data.meta_data.session_locked) or (os.time() - old_data.meta_data.last_save_time >= ProfileHandlerSettings.SESSION_LOCK_AUTO_RELEASE) then
						old_data.meta_data.last_save_time = os.time();
						old_data.meta_data.session_locked = true;
						
						session_locked = false;
						return_result = old_data;
					else
						-- Otherwise session is locked;
						session_locked = true;
						session_lock_cooldown = ProfileHandlerSettings.SESSION_LOCK_AUTO_RELEASE - (os.time() - old_data.meta_data.last_save_time);
						return_result = nil; 
					end
				
				else
					-- Return the retrieved data if we do not respect session lock
					return_result = old_data;
				end
				
				return return_result;
			end);
		end)

		-- If the session is locked we will force another iteration
		if session_locked then
			format_string = "\nDatastore: %s\nProfile: %s\nContent: Session is locked for %s second(s)."
			update_result = string.format(format_string, profile._datastore_id, profile._profile_id, session_lock_cooldown);
		elseif (not update_success) then
			format_string = "\nDatastore: %s\nProfile: %s\nContent: Failed to retrieve data due to: %s.";
			update_result = string.format(format_string, profile._datastore_id, profile._profile_id, tostring(update_result));
		end
		
		if (session_locked or not update_success) then
			DebugModule.warn(update_result, ProfileHandlerSettings.TRACE_BACK_MESSAGE);	
			task.wait(ProfileHandlerSettings.MINIMUM_LOAD_INTERVAL);
		end		
	end

	-- If the profile has been destroyed, we will cancel the loading
	if (profile._is_destroyed) then
		DebugModule.warn(string.format(
			"\nDatastore: %s\nProfile: %s\nContent: Profile has been destroyed, loading data has been cancelled.",
			profile._datastore_id,
			profile._profile_id
		), ProfileHandlerSettings.TRACE_BACK_MESSAGE);
	else
		profile._data = update_result;
		profile._data_loaded = true;

		local format_string = "\nDatastore: %s\nProfile: %s\nContent: Successfully loaded data.";
		DebugModule.print(string.format(
			format_string,
			profile._datastore_id,
			profile._profile_id
		), ProfileHandlerSettings.TRACE_BACK_MESSAGE)		
	end
end

function ProfileClass.newProfile(datastore_id : string, profile_id : string, respect_session_lock : boolean?, data : {}?) : Profile
	-- Initialize all attributes/properties.
	local profile : Profile = setmetatable({}, ProfileClass);
	profile._profile_id = profile_id;
	profile._datastore_id = datastore_id;
	profile._data = DeepCopy(data) or {};
	profile._data_loaded = false;
	
	profile._events = {};
	profile._is_destroyed = false;
	profile._respect_session_lock = respect_session_lock;
	profile._is_saving = false;
	profile._is_session_end_saving = false;
	profile._data_template = data;
	profile._last_save = os.time();
	
	-- Create save bindable for signaling saves
	local save_bindable_event = Instance.new("BindableEvent");
	save_bindable_event.Name = string.format("%s.%s", datastore_id, profile_id);
	save_bindable_event.Parent = bindables_container;
	profile._save_bindable_event = save_bindable_event;
	
	if not cached_profiles[datastore_id] then
		cached_profiles[datastore_id] = {};
	end
	
	if not cached_profiles[datastore_id][profile_id] then
		cached_profiles[datastore_id][profile_id] = profile;
	end
	
	return profile;
end

function ProfileClass.getProfile(datastore_id : string, profile_id : string) : Profile?
	if not cached_profiles[datastore_id] then
		DebugModule.warn(string.format(
			"[ProfileClass]: '%s' does not exist in cached profiles.", 
			datastore_id
		), ProfileHandlerSettings.TRACE_BACK_MESSAGE);
		return
	end
	
	return cached_profiles[datastore_id][profile_id];
end

function ProfileClass.getCachedProfiles() : {[string] : {[string] : Profile}}
	return cached_profiles;
end

return ProfileClass
