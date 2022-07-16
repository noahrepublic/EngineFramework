
--@noahrepublic
--@creation 07/15/22
--@lastmodified 07/15/22
--@version 1.0

local RunService = game:GetService("RunService")

local Timer = {
    sync_request = nil,
    delay_request = nil,
}
Timer.__index = Timer

local recursive_delay = 5

-- Functions --

-- Public:

function Timer:Run(sync_request, delay_request)
    assert(not Timer.sync_request and not Timer.delay_request, "Timer already initialized.")
    assert(sync_request, "sync_request is nil")
    assert(delay_request, "delay_request is nil")
    
    Timer.sync_request = sync_request
    Timer.delay_request = delay_request

    if RunService:IsServer() then
        Timer.sync_request.OnServerEvent:Connect(function(player)
            Timer.sync_request:FireClient(player, Timer:GetTime())
        end)
        Timer.delay_request.OnServerInvoke = function(_, client_timer)
            return Timer:GetTime() - client_timer
        end

        Timer._Stop = Instance.new("BindableEvent").Event

        Timer.Active = true
        Timer.Stop:Connect(function()
            Timer.Active = false
        end)
        
        task.delay(recursive_delay, function()
            while Timer.Active do
                Timer.sync_request:FireAllClients(Timer:GetTime())
                task.wait(recursive_delay)
            end
        end)
        
        function Timer:Stop()
            Timer._Stop:Fire()
        end

        return Timer
    elseif RunService:IsClient() then
        Timer._SyncedEvent = Instance.new("BindableEvent")
        Timer.Synced = Timer._SyncedEvent.Event
        Timer.Synced:Connect(function()
            Timer.last_sync = Timer:GetTime()
        end)
        Timer.sync_request.OnClientEvent:Connect(function(server_timer)
            local server_client = Timer:GetTime() - server_timer

            local client_server = Timer.delay_request:InvokeServer(Timer:GetTime())

            Timer.offset = (server_client - client_server)/2
            Timer.network_interval = (server_client + client_server)/2

            Timer._SyncedEvent:Fire()
        end)

        Timer.sync_request:FireServer()

        Timer.offset = 0
        Timer.network_interval = 0
        Timer.last_sync = 0

        return Timer
    end
    
end

function Timer:GetTime()
    return tick()
end

return Timer