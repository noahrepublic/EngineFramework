
--@noahrepublic
--@creation 07/15/22
--@lastmodified 07/15/22
--@version 1.0

local RunService = game:GetService("RunService")

local TimeSync = {}
TimeSync.__index = TimeSync

local TimeFlder = script.Parent

local sync_request
local delay_request

if RunService:IsServer() then
    sync_request = Instance.new("RemoteEvent")
    delay_request = Instance.new("RemoteFunction")
    sync_request.Name = "TimeSyncRequest"
    delay_request.Name = "TimeDelayRequest"
    sync_request.Parent = TimeFlder
    delay_request.Parent = TimeFlder
else
    sync_request = TimeFlder:FindFirstChild("TimeSyncRequest")
    delay_request = TimeFlder:FindFirstChild("TimeDelayRequest")
end

-- Functions --
-- Public:

function TimeSync:Sync()
    local timer = require(TimeFlder.Timer):Run(sync_request, delay_request)
    return timer
end

return TimeSync