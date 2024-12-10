--[[
	Module Name: ProfileHandlerProfileHandlerSettings
	Description: Stores ProfileHandlerSettings used by the ProfileHandler and ProfileClass
	Written by: Mystifine
	Last Updated: 09/12/2024
]]

local ProfileHandlerSettings = {}

ProfileHandlerSettings.DEBUG_MODE = true;
ProfileHandlerSettings.TRACE_BACK_MESSAGE = false;

ProfileHandlerSettings.MINIMUM_SAVE_INTERVAL = 6;
ProfileHandlerSettings.MINIMUM_LOAD_INTERVAL = 6;

--[[
	Property: AUTO_SAVE_INTERVAL
	Description: Minimum is 6, however I wouldn't recommend it. I would suggest 30+
]]

ProfileHandlerSettings.AUTO_SAVE_INTERVAL = 30; 

--[[
	Property SESSION_LOCK_AUTO_RELEASE
	Description: To avoid data save/load collison, the higher the value the better. 
	Note that this will effect player gameplay experience the longer it is.
	However you need to weigh the value of having their data safe versus them playing the game.
	If you believe their data is more valuable then you should increase the number, otherwise keep
	it at a respective value to AUTO_SAVE_INTERVAL. 
]]
ProfileHandlerSettings.SESSION_LOCK_AUTO_RELEASE = 60 * 5; -- 5 minutes.

return ProfileHandlerSettings
