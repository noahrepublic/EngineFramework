
-- Services --

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Variables --

local Engine = require(ReplicatedStorage:FindFirstChild("Common"):FindFirstChild("Engine"))

Engine.Start()

local Data = Engine.Require("Data")

local template = {
    ["Hi"] = 1
}

Data:LoadDataStore("DataServiceTest_1", template)

game.Players.PlayerAdded:Connect(function(player)
	local profile = Data:LoadData("Player_"..player.UserId, "forceload")
	profile:ListenToRelease(function()
		print("PROFILE RELEASED")
	end)
	profile.Data.Hi = 2
	print(profile)
end)