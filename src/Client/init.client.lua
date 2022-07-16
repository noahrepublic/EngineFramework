
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TimeFlder = ReplicatedStorage:FindFirstChild("Common"):FindFirstChild("Utilities").Time

local sync_request = TimeFlder:WaitForChild("TimeSyncRequest")
local delay_request = TimeFlder:WaitForChild("TimeDelayRequest")

local TimeSync = require(TimeFlder:FindFirstChild("TimeSync"))
local timer = TimeSync:Sync()
print(timer)

timer.Synced:Connect(function()
	print("SYNCED TIME!", timer.offset, "PING: ", timer.network_interval * 2000)
end)