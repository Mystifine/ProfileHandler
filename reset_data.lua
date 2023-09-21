-- services
local players = game.Players;
local datastoreservice = game:GetService("DataStoreService");

local datastore_settings = require(script.Parent.datastore_settings)

local function output(output_function : Function, ...)
	if datastore_settings.DEBUG_MODE then
		output_function(...);
	end
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


local function waitForDatastoreBudget(request_type : Enum.DataStoreRequestType)
	local budget = datastoreservice:GetRequestBudgetForRequestType(request_type)
	while budget < 0 do 
		budget = datastoreservice:GetRequestBudgetForRequestType(request_type);
		task.wait()
	end
end

local function requestSetDatastoreRequest(userID : number, datastore, key : string?, value : any)
	local success, result
	while not success do 
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

return function(userID : number)
	local current_time = os.time();
	local est_date_time_str = formatTimeWithAMPM(getESTDate())
	local datastore, ordered_datastore = getDatastore(userID)

	local success, result = requestSetDatastoreRequest(userID, ordered_datastore, est_date_time_str.." DATA RESET", current_time)
	if success then
		success, result = requestSetDatastoreRequest(userID, datastore, current_time, "data_reset")
		if success then
			output(print, string.format("[%s]: %d's data has been reset.", script.Name, userID))
		end	
	end
end
