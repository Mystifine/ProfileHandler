--[[
	Module Name: ResetData
	Description: Deletes an entry of a datastore using a profile id
	Written by: Mystifine
	Last Updated: 09/12/2024
]]

local DataStoreService = game:GetService("DataStoreService")

return function(datastore_id : string, profile_id : string)
	local datastore = DataStoreService:GetDataStore(datastore_id);
	
	local success, err = pcall(function()
		datastore:RemoveAsync(profile_id);
	end)
	
	if not success then
		warn(string.format("[%s]: Failed to resetData for %s datastore | %s access key. Error message: %s", script.Name, datastore_id, profile_id, err));
	else
		print(string.format("[%s]: Successfully resetted data for %s datastore | %s access key.", script.Name, datastore_id, profile_id))
	end
end
