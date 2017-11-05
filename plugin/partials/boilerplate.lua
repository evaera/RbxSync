-- RSync Boilerplate --
local function mixin(name, automatic)
	if (not automatic) and (name == "autoload" or name == "client" or name == "server") then
		error("RbxSync: Name \"" .. name .. "\" is a reserved name, and is automatically included in every applicable script.")
	end

	local ReplicatedStorage = game:GetService"ReplicatedStorage"
	if not ReplicatedStorage:FindFirstChild("Mixins") then
		return
	end

	if script.Name == "Mixins" and script.Parent == ReplicatedStorage then
		return
	end

	local mixins = require(ReplicatedStorage.Mixins)

	if type(mixins[name]) == "function" then
		return mixins[name](name, script, getfenv(2))
	else
		return mixins[name]
	end
end

mixin("autoload", true)
mixin(game:GetService"Players".LocalPlayer and "client" or "server", true)
-- End Boilerplate --
