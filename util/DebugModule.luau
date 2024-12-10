--[[
	Module Name: DebugModule
	Description: Module is used to outputting formatted messages with traceback if needed.
	Written by: Mystifine
	Last Updated: 09/12/2024
]]

local ProfileHandlerSettings = require(script.Parent.Parent.ProfileHandlerSettings);

local DebugModule = {}

DebugModule.print = function(msg : string, trace_back : boolean)
	if not ProfileHandlerSettings.DEBUG_MODE then return end;
	
	print(msg);

	if trace_back then
		print( string.format("\n[DebugTraceback]: %s", debug.traceback()));
	end
end

DebugModule.warn = function(msg : string, trace_back : boolean)
	if not ProfileHandlerSettings.DEBUG_MODE then return end;

	warn(msg);

	if trace_back then
		warn( string.format("\n[DebugTraceback]: %s", debug.traceback()));
	end
end

DebugModule.error = function(msg : string, trace_back : boolean)
	local format_pattern ="%s\n[DebugTraceback]:%s";
	
	if trace_back then
		error( string.format(format_pattern, msg, debug.traceback()));
	else
		error(string.format(format_pattern, msg, ''));
	end
end

return DebugModule
