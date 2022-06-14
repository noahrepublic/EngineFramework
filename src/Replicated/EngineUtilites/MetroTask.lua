
local module = {}
module.__index = module

local tasks = {}

-- Functions --

function module.new()
    local self = setmetatable({}, module)
    return self
end