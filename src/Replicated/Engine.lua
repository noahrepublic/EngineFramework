
--@noahrepublic

local Engine = {
	Utilities = script.Utilities,
	StartUp = script.StartUp:GetChildren(),
	Services = script.Services:GetChildren(),
	LoadedServices = {}
}
Engine.__index = Engine

local Utilities = script.Utilities

-- Functions --

function Engine.Start()
	for _, v in pairs(Engine.StartUp) do
		local success, msg = pcall(function()
			require(v)
		end)
		if not success then
			warn("Error loading " .. v.Name .. ": " .. msg)
		else
			print("Loaded " .. v.Name)
		end
	end

	for _, v in pairs(Engine.Services) do
		local service = require(v)
		Engine.LoadedServices[v] = service
	end
end

function Engine.Require(name)
	if Utilities[name] then
		return require(Utilities[name])
	elseif Engine.StartUp[name] then
		return require(Engine.StartUp[name])
	else
		warn("Engine.Require: " .. name .. " not found.")
	end
end

return Engine