--[[
	Module Name: DeepCopy
	Description: Returns a function to deep copy data.
	Written by: Mystifine
	Last Updated: 09/12/2024
]]

local function deepCopy(data : any?)
	if type(data) ~= "table" then
		return data;
	else
		local new_data = {};
		for i,v in pairs(data) do
			if type(v) == "table" then
				new_data[i] = deepCopy(v);
			else
				new_data[i] = v;
			end
		end
		return new_data;
	end
end

return deepCopy;