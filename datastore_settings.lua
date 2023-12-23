local datastore_settings : {} = {}

datastore_settings.VERSION = 0; -- changing the version will wipe EVERYONE and basically reset all datastore. When using the Datastore editor, include the version at the end of the userid.
datastore_settings.DEBUG_MODE = true;
datastore_settings.SAVE_FREQUENCY = 15;
datastore_settings.SESSION_LOCK_TIMEOUT = 120; -- note this always has to be bigger than SAVE_FREQUENCY
datastore_settings.REQUEST_PER_MINUTE = {
	GetSorted = 2, -- GetSortedAsync
	GetVersion = 2, -- GetVersionAsync
	Get = 10, -- GetAsync
	Set = 10, -- SetAsync, IncrementAsync, UpdateAsync, RemoveAsync
	List = 2, -- ListDataStoreAsync, ListKeysAsync, ListVersionAsync
	Remove = 2, -- RemoveVersionAsync
}

return datastore_settings
