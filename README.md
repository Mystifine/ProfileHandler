# ProfileHandler

## Overview
`ProfileHandler` is a robust module for managing user profiles in Roblox. It leverages Roblox's DataStore service to handle data storage, autosaving, session locking, and data reconciliation. The system is designed to ensure data integrity and efficiency, even during server shutdowns.

- **Author**: Mystifine  
- **Last Updated**: 13/12/2024

---

## Table of Contents
1. [Features](#features)
2. [Dependencies](#dependencies)
3. [Modules](#modules)
4. [API Reference](#api-reference)
    - [ProfileHandler Module](#profilehandler-module)
    - [ProfileClass Module](#profileclass-module)
5. [Setup](#setup)
6. [Examples](#examples)
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

3. **`ProfileHandler.editProfile(datastore_id, profile_id, transformationFunction)`**
   - **Description**: Edits the profile data using a transformation function.
   - **Parameters**:
     - `datastore_id (string)`
     - `profile_id (string)`
     - `transformationFunction (function)`: A function that modifies the profile data.
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
     - `path (string)`: Path to the data field.
     - `value (any)`: The value to set.

---

## Setup

### Installation
1. You can either create modules inside of Roblox Studio and copy and paste the code for each file or you can press the green code button on the main repository page and download as a zip.

![image](https://github.com/user-attachments/assets/cc0cd3da-4d4d-46ec-a24e-e9e373ec59cc)

2. Once you have installed the files, Place the `ProfileHandler.lua` module in `ServerStorage` in your Roblox game.
3. Place `ProfileClass.lua` and `ProfileHandlerSettings.lua` and `util` folder and `bindables` folder in `ProfileHandler.lua`.
4. Ensure all dependencies are correctly set up (e.g., DataStoreService permissions).
5. Configure `ProfileHandlerSettings`:
   - Set `AUTO_SAVE_INTERVAL` and other constants as needed.
7. Use `ProfileHandler.newProfile` to create and manage profiles. Head to #

## Directory Structure

- `bindables/`: Contains BindableEvent modules for inter-script communication.
- `util/`: Includes utility modules for debugging, resetting data, and deep copying tables.
- `src/ProfileClass.lua`: Core class for managing player profiles.
- `src/ProfileHandlerSettings.lua`: Configuration for the profile handler.
- `src/ProfileHandler.lua`: Core module that relies on ProfileClass.lua.

---

## Examples

### Creating a New Profile
```lua
local ProfileHandler = require(game.ServerScriptService.ProfileHandler)

local datastore_id = "PlayerDataStore"
local profile_id = "Player123"
local data_template = {level = 1, experience = 0}

local profile = ProfileHandler.newProfile(datastore_id, profile_id, true, data_template)
if profile then
    print("Profile created successfully!")
end
```

## License

[MIT License](LICENSE)
