--@https://github.com/noahrepublic/EngineFramework/blob/main/src/Replicated/Utilities/Signal.lua

--@noahrepublic
--@created 07/15/22
--@updated 07/15/22


local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

-- Connection Functions --
-- Public:

--[[ Connection.new()
    Creates a new connection object.
    @returns Connection
]]

function Connection.new(signal, callback)
	return setmetatable({
		_signal_object = signal,
        _signal = signal._signal,
        _listener = callback,
        _connection = signal._signal.Event:Connect(callback),

        Connected = true
    }, Connection)
end

--[[ Connection:Disconnect()
    Disconnects the connection from the parent signal object.
    Returns:
        Connection
]]

function Connection:Disconnect()
	print(self.Connected)
    assert(self.Connected, "Connection is not connected")
    self.Connected = false
	self._connection:Disconnect()
	print(self)
    self._signal_object._listeners[self._listener] = nil
    return self
end

Connection.Destroy = Connection.Disconnect -- alias

--[[ Connection:Wait()
    Waits for the connection to be fired.
    Returns: 
        The return value of the callback.    
]]

function Connection:Wait()
    assert(self.Connected, "Connection is not connected")
    return self._connection.Event:Wait()
end

-- Signal Functions --
-- Public:

function Signal.new()
    return setmetatable({
        _listeners = {},
        _signal = Instance.new("BindableEvent")
    }, Signal)
end

--[[ Signal:Connect()
    Connects a listener to the signal.
    Params:
        listener: The function to connect.
    Returns:
        The listener's connection.
]]

function Signal:Connect(callback)
    assert(type(callback) == "function", "Callback must be a function.")
    local connection = Connection.new(self, callback)
    self._listeners[callback] = connection
    return connection
end

--[[ Signal:DisconnectListeners()
    Disconnects all listeners from the signal.
]]

function Signal:DisconnectListeners()
    for _, listener in pairs(self._listeners) do
        listener:Disconnect()
        listener = nil
    end
end

--[[ Signal:Fire()
    Fires the signal.
    Params:
        ...: The arguments to pass to the listeners.
]]

function Signal:Fire(...)
    self._signal:Fire(...)
end

--[[ Signal:ShortConnect() 
    Temporary connects a listener to the signal until the next fire.
    Params:
        listener: The function to connect.
    Returns:
        The listener's connection.
]]

function Signal:ShortConnect(callback)
    assert(type(callback) == "function", "Callback must be a function.")
    local connection = Connection.new(self, function() end)
    local new_callback = function(...)
        callback(...)
        connection._connection:Disconnect()
        connection._signal_object._listeners[callback] = nil
        connection.Connected = false
    end
    self._listeners[callback] = connection
    connection._connection = self._signal.Event:Connect(new_callback)
    return connection
end

return Signal
