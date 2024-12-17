# ProfileHandler

## Overview
`ProfileHandler` is a robust module for managing user profiles in Roblox. It leverages Roblox's DataStore service to handle data storage, autosaving, session locking, and data reconciliation. The system is designed to ensure data integrity and efficiency, even during server shutdowns.

- **Author**: Mystifine  
- **Last Updated**: 17/12/2024

---

## Table of Contents
1. [Features](#features)
2. [Dependencies](#dependencies)
3. [Modules](#modules)
4. [API Reference](#api-reference)
    - [ProfileHandler Module](#profilehandler-module)
    - [ProfileClass Module](#profileclass-module)
5. [Setup](#setup)
    - [Installation](#installation)
    - [Directory Setup](#directory-setup)
6. [Examples](#examples)
    - [Data Handler](#data-handler)
    - [Data Template](#data-template)
7. [License](#license)

---

## Features
- **Automatic Saving**: Periodically saves profiles based on a configurable interval.
- **Session Locking**: Ensures that only one session can access a profile at a time to prevent data corruption.
- **Event-Driven**: Uses bindable events for server shutdown safety and autosaving.
- **Data Reconciliation**: Automatically fills in missing data fields based on a template.
- **Utilities**: Includes functions for loading, editing, and deleting user profiles.

---

## Dependencies
The `ProfileHandler` module relies on the following dependencies:
- `ProfileHandlerSettings`: Contains configuration settings like autosave intervals.
- `ProfileClass`: Manages individual profile instances.
- `DebugModule`: For logging and debugging.
- `DeepCopy`: Utility for creating deep copies of data templates.

---

## Modules

### ProfileHandler
This is the main module for managing profiles. It provides methods for creating, reading, editing, and managing profiles during server lifecycle events.

### ProfileClass
Handles individual profile instances. It provides methods to manipulate and save profile data.

---

## API Reference

### ProfileHandler Module

#### **Functions**
1. **`ProfileHandler.newProfile(datastore_id, profile_id, respect_session_lock, data_template)`**
   - **Description**: Creates a new profile.
   - **Parameters**:
     - `datastore_id (string)`: The datastore ID.
     - `profile_id (string)`: The unique profile identifier.
     - `respect_session_lock (boolean)`: Whether to respect session locks.
     - `data_template (table?)`: The default data structure for the profile.
   - **Returns**: A `Profile` instance.

2. **`ProfileHandler.getProfile(datastore_id, profile_id)`**
   - **Description**: Retrieves a cached profile.
   - **Parameters**:
     - `datastore_id (string)`: The datastore ID.
     - `profile_id (string)`: The unique profile identifier.
   - **Returns**: A `Profile` instance or `nil`.

3. **`ProfileHandler.updateProfileAsync(datastore_id, profile_id, transformationFunction)`**
   - **Description**: Edits the profile data using a transformation function.
   - **Parameters**:
     - `datastore_id (string)`
     - `profile_id (string)`
     - `transformationFunction (function)`: A function that modifies the profile data.
   - **Returns**: `(boolean, any?)`.
  
4. **`ProfileHandler.getProfileAsync(datastore_id, profile_id)`**
   - **Description**: Retrieves profile data through UpdateAsync
   - **Parameters**:
     - `datastore_id (string)`
     - `profile_id (string)`
   - **Returns**: `(boolean, any?)`.

---

### ProfileClass Module

#### **Profile Properties**
- `_profile_id (string)`: Unique profile identifier.
- `_datastore_id (string)`: Datastore ID associated with the profile.
- `_data_loaded (boolean)`: Whether the profile data is loaded.
- `_data (table?)`: The profile's data.
- `save_bindable_event (BindableEvent)`: Event for signaling saves.

#### **Profile Methods**
1. **`Profile:Save(session_ending)`**
   - **Description**: Saves the profile data to the datastore.
   - **Parameters**:
     - `session_ending (boolean)`: Whether this save is during a session ending.
   - **Returns**: `nil`.

2. **`Profile:Destroy()`**
   - **Description**: Cleans up the profile instance.
   - **Returns**: `nil`.

3. **`Profile:Delete()`**
   - **Description**: Deletes the profile from the datastore.
   - **Returns**: `boolean`.

4. **`Profile:GetData(path)`**
   - **Description**: Retrieves data from the profile using a path.
   - **Parameters**:
     - `path (string?)`: Path to the data field.
   - **Returns**: The data at the specified path.

5. **`Profile:SetData(path, value)`**
   - **Description**: Sets data in the profile at the specified path.
   - **Parameters**:
     - `path (string?)`: Path to the data field.
     - `value (any)`: The value to set.

6. **`Profile:IsDestroyed()`**
   - **Description**: Checks if the profile has been destroyed.
   - **Returns**: `boolean`.

7. **`Profile:IsDataLoaded()`**
   - **Description**: Checks if the profile data has been loaded.
   - **Returns**: `boolean`.

8. **`Profile:Reconcile(data_template)`**
   - **Description**: Fills in missing fields in the profile data based on a data template.
   - **Parameters**:
     - `data_template (table)`: A table with the default structure and values.
   - **Returns**: `boolean` indicating success.

---

## Setup

### Installation
1. You can either create modules inside of Roblox Studio and copy and paste the code for each file or you can press the green code button on the main repository page and download as a zip.

![image](https://github.com/user-attachments/assets/cc0cd3da-4d4d-46ec-a24e-e9e373ec59cc)

### Directory Setup
2. Once you have installed the files, Place the `ProfileHandler.lua` module in `ServerStorage` in your Roblox game.
3. Place `ProfileClass.lua` and `ProfileHandlerSettings.lua` and `util` folder and `bindables` folder in `ProfileHandler.lua`.
4. Ensure all dependencies are correctly set up (e.g., DataStoreService permissions).
5. Configure `ProfileHandlerSettings`:
   - Set `AUTO_SAVE_INTERVAL` and other constants as needed.
7. Use `ProfileHandler.newProfile` to create and manage profiles. 

What it should look like:

![image](https://github.com/user-attachments/assets/14fa1fe0-6a20-4a39-8e28-e3e5bb48f005)

## Directory Structure

- `bindables/`: Contains BindableEvent modules for inter-script communication.
- `util/`: Includes utility modules for debugging, resetting data, and deep copying tables.
- `src/ProfileClass.lua`: Core class for managing player profiles.
- `src/ProfileHandlerSettings.lua`: Configuration for the profile handler.
- `src/ProfileHandler.lua`: Core module that relies on ProfileClass.lua.

---

## Examples
It is recommended to cache profiles into tables. The ProfileHandler does internally cache and clean this data which you can use `ProfileHandler.getProfile()` to retrieve. Please do your best to use `:SetData()` and `:GetData()` to update and retrieve data.
### Data Handler
Commonly developers enjoy using instances as a way to change data as it is the convenient common method taught to many newer scripters. Below is a setup that will allow developers to instantiate one layer of data and have it be updated to the profile.
```lua
local players = game.Players;
local serverstorage = game.ServerStorage;

local ProfileHandler = require(serverstorage.ProfileHandler);

local player_data_template = require(serverstorage.player_data_template);

local getProfileData = game.ReplicatedStorage.getProfileData;

local player_data_handler = {}

local player_profiles = {};

local function playerAdded(player : Player)
	local profile = ProfileHandler.newProfile("player_data", player.UserId, true, player_data_template);
	profile:Reconcile(player_data_template);
		
	player_profiles[player] = profile;
	
	-- additional setup

	local DATA_TYPE_TO_INSTANCE = {
		string = "StringValue",
		number = "NumberValue",
		boolean = "BoolValue"
	}

	local profile_data = profile:GetData();
	for data_name, data_value in pairs(profile_data) do 
		local data_type = typeof(data_value);
		if DATA_TYPE_TO_INSTANCE[data_type] then
			local obj = Instance.new(DATA_TYPE_TO_INSTANCE[data_type]);
			obj.Name = data_name;
			obj.Value = data_value;
			obj.Parent = player;
			
			obj:GetPropertyChangedSignal("Value"):Connect(function()
				profile:SetData(data_name, obj.Value)				
			end)
		end
	end
	
	-- conditions stuff
	if not profile_data.conditions.GAVE_STARTER_ITEMS then
		-- give the items;
		profile_data.conditions.GAVE_STARTER_ITEMS = true;
	end
	
	local DATA_LOADED = Instance.new("BoolValue");
	DATA_LOADED.Value = true;
	DATA_LOADED.Name = "DATA_LOADED";
	DATA_LOADED.Parent = player;
end


local function playerRemoving(player : Player)
	local profile = player_profiles[player];
	if profile then
		profile:Save(true);
		profile:Destroy();
	end
	player_profiles[player] = nil;
end

function player_data_handler._establishConnections()
	players.PlayerAdded:Connect(playerAdded)
	players.PlayerRemoving:Connect(playerRemoving)
	
	getProfileData.OnServerInvoke = function(player : Player, ...)
		local arguments = {...};
		local DATA_LOADED = player:WaitForChild("DATA_LOADED");
		local profile = player_profiles[player];
		
		if profile then
			local data = profile.data;
			for i = 1, #arguments do 
				local argument = arguments[i];
				
				data = data[argument];
				
				if data == nil then
					return data;
				end
			end
			return data;
		end
	end
end


function player_data_handler.main()
	player_data_handler._establishConnections();
end

return player_data_handler

```

### Data Template
It is also crucial to setup a data template. This is a good example of something someone may do
```lua
local player_data_template = {}

player_data_template.level = 1;
player_data_template.exp = 0;
player_data_template.max_exp = 1000;

player_data_template.inventory = {};

player_data_template.conditions = {};

return player_data_template
```
## License

[MIT License](LICENSE)
