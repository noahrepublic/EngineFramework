
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
    Data:LoadData("Player_"..player.UserId)
end)