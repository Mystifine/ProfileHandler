# ProfileHandler

This is a Roblox project for managing player profiles with data persistence and session locks. The project is modular and includes utilities for debugging, data management, and configuration.

## Directory Structure

- `bindables/`: Contains BindableEvent modules for inter-script communication.
- `util/`: Includes utility modules for debugging, resetting data, and deep copying tables.
- `src/ProfileClass.lua`: Core class for managing player profiles.
- `src/ProfileHandlerSettings.lua`: Configuration for the profile handler.
- `src/ProfileHandler.lua`: Core module that relies on ProfileClass.lua.

## How to Use

1. Place the `ProfileHandler.lua` module in `ServerStorage` in your Roblox game.
2. Place `ProfileClass.lua` and `ProfileHandlerSettings.lua` and `util` folder and `bindables` folder in `ProfileHandler.lua`.
2. Ensure all dependencies are correctly set up (e.g., DataStoreService permissions).
3. Use `ProfileHandler.newProfile` to create and manage profiles.

## Utilities

- **DebugModule**: Logging and warning utilities.
- **DeepCopy**: Provides a deep copy function for tables.
- **ResetData**: Contains logic for resetting player data to default.

## License

[MIT License](LICENSE)
