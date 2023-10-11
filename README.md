# Player Datastore Module
Used to save player data. Currently used in my personal projects.

# Installation
1. Create a module for each `.lua` file.
2. Place `datastore_settings.lua` and `reset_data.lua` under `player_datastore.lua`
3. Add a folder called `player_bindables` under `player_datastore.lua`
4. Setup is now down.

# How to use
1. Create your own starter data module
2. Set up your own starter data and initialize using `setStarterData` from `player_datastore.lua`
3. You're done. use `get` passing the player object to retrieve data. Data is automatically saved.
