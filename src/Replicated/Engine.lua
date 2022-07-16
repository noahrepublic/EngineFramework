
--@noahrepublic

local Engine = {
	Utilities = script.Parent.Utilities,
	StartUp = script.Parent.StartUp,
	Services = script.Parent.Services,
	LoadedServices = {}
}
Engine.__index = Engine

local Utilities = script.Parent.Utilities

-- Functions --

function Engine.Require(name)
	if Utilities:FindFirstChild(name) then
		return require(Utilities[name])
	elseif Engine.Services:FindFirstChild(name) then
		return require(Engine.StartUp[name])
	else
		for _, module in pairs(Utilities:GetDescendants()) do
			if module.Name == name then
				return require(module)
			end
		end
		warn("Engine.Require: " .. name .. " not found.")
	end
end

return Engine