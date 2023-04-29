local constants = {}

constants.MASTER_KEY = "DATA";

constants.DEBUG_MODE = true;
constants.IGNORE_COOLDOWN_MESSAGE = true;
constants.STUDIO_SAVE = true;

constants.MAX_RETRY_DURATION = 40;

-- ROBLOX COOLDOWNS ARE 6 SECONDS BETWEEN REQUESTS. YOU DON'T NEED SUCH A SHORT COOLDOWN.
constants.REQUEST_COOLDOWNS = {
	WRITE = 10, 
	READ = 10,	
}

return constants
