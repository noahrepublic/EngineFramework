
-- @noahrepublic
-- @version 1.01
-- @date 2022-06-21

--[[ Data Store Handler
    TODO:
    - Add mock data stores for offline
    - Add global data actually do something
]]

-- Services --

local DataStoreService = game:GetService("DataStoreService")

-- @Quenty Signal --

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local ENABLE_TRACEBACK = false

local Signal = {}
Signal.__index = Signal
Signal.ClassName = "Signal"

--[=[
	Returns whether a class is a signal
	@param value any
	@return boolean
]=]
do
	function Signal.isSignal(value)
		return type(value) == "table"
			and getmetatable(value) == Signal
	end

    --[=[
        Constructs a new signal.
        @return Signal<T>
    ]=]
	function Signal.new()
		local self = setmetatable({}, Signal)

		self._bindableEvent = Instance.new("BindableEvent")
		self._argMap = {}
		self._source = ENABLE_TRACEBACK and debug.traceback() or ""

		-- Events in Roblox execute in reverse order as they are stored in a linked list and
		-- new connections are added at the head. This event will be at the tail of the list to
		-- clean up memory.
		self._bindableEvent.Event:Connect(function(key)
			self._argMap[key] = nil

			-- We've been destroyed here and there's nothing left in flight.
			-- Let's remove the argmap too.
			-- This code may be slower than leaving this table allocated.
			if (not self._bindableEvent) and (not next(self._argMap)) then
				self._argMap = nil
			end
		end)

		return self
	end

    --[=[
        Fire the event with the given arguments. All handlers will be invoked. Handlers follow
        @param ... T -- Variable arguments to pass to handler
    ]=]
	function Signal:Fire(...)
		if not self._bindableEvent then
			warn(("Signal is already destroyed. %s"):format(self._source))
			return
		end

		local args = table.pack(...)

		-- TODO: Replace with a less memory/computationally expensive key generation scheme
		local key = HttpService:GenerateGUID(false)
		self._argMap[key] = args

		-- Queues each handler onto the queue.
		self._bindableEvent:Fire(key)
	end

    --[=[
        Connect a new handler to the event. Returns a connection object that can be disconnected.
        @param handler (... T) -> () -- Function handler called when `:Fire(...)` is called
        @return RBXScriptConnection
    ]=]
	function Signal:Connect(handler)
		if not (type(handler) == "function") then
			error(("connect(%s)"):format(typeof(handler)), 2)
		end

		return self._bindableEvent.Event:Connect(function(key)
			-- note we could queue multiple events here, but we'll do this just as Roblox events expect
			-- to behave.

			local args = self._argMap[key]
			if args then
				handler(table.unpack(args, 1, args.n))
			else
				error("Missing arg data, probably due to reentrance.")
			end
		end)
	end

    --[=[
        Wait for fire to be called, and return the arguments it was given.
        @yields
        @return T
    ]=]
	function Signal:Wait()
		local key = self._bindableEvent.Event:Wait()
		local args = self._argMap[key]
		if args then
			return table.unpack(args, 1, args.n)
		else
			error("Missing arg data, probably due to reentrance.")
			return nil
		end
	end

    --[=[
        Disconnects all connected events to the signal. Voids the signal as unusable.
        Sets the metatable to nil.
    ]=]
	function Signal:Destroy()
		if self._bindableEvent then
			-- This should disconnect all events, but in-flight events should still be
			-- executed.

			self._bindableEvent:Destroy()
			self._bindableEvent = nil
		end

		-- Do not remove the argmap. It will be cleaned up by the cleanup connection.

		setmetatable(self, nil)
	end

end

-- Variables --

local DataService = {
	_LoadedData = {
        --[[
            [player] = {
                "current_server" = jobId or nil,
                "data" = {}
            }
        ]]
	},
	_autoSaveList = {}, -- data
	_serviceLock = false,
	_data_store_name = "",
	_data_store_scope = nil, -- [string]
	_data_store_look = "", -- [string] -- _data_store_name .. "\0" .. (_data_store_scope or "")

	_mock_datastores = {}, -- "copy datastore", used for offline purposes / backups / api unavaiable
	_using_mock_datastores = false,

	_forceLoadReady = Signal.new(),
	_bindCloseFinished = Signal.new(),
	_IssueSignal = Signal.new(),
	_CriticalStateSignal = Signal.new(),
	_releaseData = Signal.new(),

	_global_store = nil,
	_data_template = {
		MetaData = {
			ActiveSession = {
				place_id = nil,
				job_id = nil
			},
			MetaTags = {},
			last_update = 0, -- os.time()
			Forceload = false
		},
		Data = {},
		Global = {
            --[[
                [key] = {
                    data = {}, 
                    time_posted = os.time()
                }
            ]]
		}
	}

}
DataService.__index = DataService

local Data = {}
Data.__index = Data

local SETTINGS = {
	AutoSaveData = 0.5 * 60,
	SessionDead = 15 * 60,
	Max_Usage = 0.25, -- %
	IssueState_T = 2 * 60,
	IssueQueue_Max = 5,
	Issue_Check_Interval = 0.5 * 60,
}

-- 

local lastAutoSave = os.clock()

local jobId = game.JobId
local placeId = game.PlaceId

local IsStudio = RunService:IsStudio()

local dataError = false
local ErrorQueue = {}

-- Functions --

if IsStudio then
	task.spawn(function()
		-- Credit to @loleris for this function
		local status, message = pcall(function()
			DataStoreService:GetDataStore("___PS"):SetAsync("___PS", os.time()) 
		end)

		local no_internet = status == false and string.find(message, "ConnectFail", 1, true) ~= nil
		if no_internet then
			warn("DATA: No internet connection. Data will not be saved.")
		end
		if status == false and
			(string.find(message, "403", 1, true) ~= nil or -- Cannot write to DataStore from studio if API access is not enabled
				string.find(message, "must publish", 1, true) ~= nil or -- Game must be published to access live keys
				no_internet == true) then -- No internet access

			DataService._using_mock_datastores = true
			print("API services unavailable - data will not be saved")
		else
			print("API services available - data will be saved")
		end
	end)
end

-- Private:

local function DeepCopyTable(t)
	local copy = {}
	for key, value in pairs(t) do
		if type(value) == "table" then
			copy[key] = DeepCopyTable(value)
		else
			copy[key] = value
		end
	end
	return copy
end

local function Rebuild(target, template)
	for k, v in pairs(template) do
		if type(k) == "string" then
			if target[k] == nil then
				if type(v) == "table" then
					target[k] = DeepCopyTable(v)
				else
					target[k] = v
				end
			elseif type(target[k]) == "table" and type(v) == "table" then
				Rebuild(target[k], v)
			end
		end
	end
end

local function len(t)
	local n = 0

	for _ in pairs(t) do
		n = n + 1
	end
	return n
end

local function validateSession(sessionData, void)
	if sessionData.place_id == placeId and sessionData.job_id == jobId then
		return true
	elseif sessionData.place_id == nil and sessionData.job_id == nil then
		return true -- no session has it, it is free to use
	else
		return false
	end
end

local function GetBudget()
	return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
end

local function NewError(key)
	ErrorQueue[key] = true
	task.delay(SETTINGS.IssueState_T, function()
		ErrorQueue[key] = nil
	end)
	if #ErrorQueue > SETTINGS.IssueQueue_Max then
	DataService._CriticalStateSignal:Fire(true)
	end
end

local function UpdateData(new_data, key)

	local sessionOwned = false
	local corrupted = false

	if validateSession(new_data) then
		if (os.time() - new_data.MetaData.last_update) < 15 then
			print("Already saved in the past 15 seconds, skipping")
			return
		end
		sessionOwned = true
		local success, err
		if DataService._serviceLock then
			new_data.MetaData.sessionData.place_id = nil
			new_data.MetaData.sessionData.job_id = nil
		end
		success, err = pcall(DataService._global_store.UpdateAsync, DataService._global_store, key, function()
			new_data.MetaData.last_update = os.time()
			return new_data
		end)
		if new_data.MetaData.Forceload and success then -- sorry for leaving you on read
			DataService._forceLoadReady:Fire(new_data)
		end
		if not success then
			print("Data did not save... " .. err) -- add RequestIssue() in future
			
			NewError(key)
		else
			print("DATA IS SAVED!!!!")
			DataService._LoadedData[key] = new_data
			DataService._LoadedData[key].MetaData.Key = key
		end
	else
		warn("This data does not belong to this session.")
	end
end

local function SplitQueue(queue)
	local requestAmount = len(queue)
	local budget = GetBudget()
	local split = math.floor(budget / (requestAmount))
	if requestAmount / budget > SETTINGS.Max_Usage then
		split = math.floor(budget / (requestAmount / 2))
	end

	local split_queue = {}
	local current = 1


	for i, v in pairs(queue) do
		if split_queue[current] == nil then
			split_queue[current] = {}
		end
		table.insert(split_queue[current], queue[i])
		if len(split_queue[current]) >= split then
			current = current + 1
		end
	end

	return split_queue
end

local function StartQueue()
	local pending_uploads = DataService._autoSaveList
	local splits = 1 -- table = {{}, {}, ...}
	if not DataService._serviceLock then
		pending_uploads = SplitQueue(pending_uploads)
		splits = #pending_uploads
	else
		pending_uploads = {pending_uploads}
	end

	for i = 1, splits do
		for k, v in pairs(pending_uploads[i]) do
			local data = v
			local key = data.MetaData.Key
			if key then
				local response = UpdateData(data, key)
				if response and CriticalState then
					DataService._CriticalStateSignal:Fire(false)
					CriticalState = false
				end
			end
		end
	end


	print("Queue saved!")
	lastAutoSave = os.clock()
	if DataService._serviceLock then
		DataService._bindCloseFinished:Fire()
	end

	task.delay(SETTINGS.AutoSaveData, StartQueue)
end


local function BindToClose()
	if not IsStudio then -- no point in waiting, using mock datastores
		DataService._serviceLock = true
		task.spawn(StartQueue)
		print("Starting save sequence...")
		DataService._bindCloseFinished:Wait()
		print("Save sequence finished! Shutting down...")
	end
end


-- Public:

function DataService:LoadDataStore(datastore_name, template, scope)
	local err, success = pcall(function() -- temporary, until critical state is finished
		if scope then
			DataService._global_store = DataStoreService:GetDataStore(datastore_name, scope)
		else
			DataService._global_store = DataStoreService:GetDataStore(datastore_name)
		end
	end)

	if not template then error("No data template was provided.") return end -- TODO: Add feature to continue
	DataService._data_template.Data = DeepCopyTable(template)

	if not DataService._global_store then
		error("DataStore not found: " .. datastore_name)
	end
	DataService._data_store_name = datastore_name
	DataService._data_store_scope = scope
	DataService._data_store_look = datastore_name .. "\0" .. (scope or "")
end

function DataService:LoadData(key, method, rebuild) -- method = "forceload", "default"
	if not IsStudio and not DataService._using_mock_datastores then
		rebuild = rebuild or true
		method = method or "default"
		local current_data = DataService._global_store:GetAsync(key) -- FUTURE ME: ADD SAFETY, pcall, checks, etc.

		if current_data == nil then
			current_data = DeepCopyTable(DataService._data_template)
			current_data.MetaData.last_update = os.time()
			current_data.MetaData.Forceload = false
			print("Data not found, creating new data.")
		else
			print("Data found, loading.")
		end
		if rebuild then
			Rebuild(current_data, DataService._data_template)
		end
		if validateSession(current_data) then
			current_data.MetaData.ActiveSession.place_id = placeId
			current_data.MetaData.ActiveSession.job_id = jobId
			DataService._LoadedData[key] = current_data
			DataService._LoadedData[key].MetaData.Key = key

			DataService._autoSaveList[key] = current_data -- do i reference the profile or the data?
			DataService._autoSaveList[key].MetaData.Key = key 
		else
			if method == "forceload" then
				current_data.MetaData.Forceload = true
				repeat
					task.wait()
				until current_data.MetaData.ActiveSession.place_id == nil and current_data.MetaData.ActiveSession.job_id == nil
				current_data.MetaData.ActiveSession.place_id = placeId
				current_data.MetaData.ActiveSession.job_id = jobId
				current_data.MetaData.Forceload = false
				DataService._LoadedData[key] = current_data
				DataService._LoadedData[key].MetaData.Key = key
				DataService._autoSaveList[key] = current_data
				DataService._autoSaveList[key].MetaData.Key = key
			else
				print("Server does not have access to this data. READ ONLY")
			end
		end
		return setmetatable(DataService._LoadedData[key], Data)
    else
        print("Offline Mode, switching to mock datastores")
        local current_data = DeepCopyTable(DataService._data_template)
		current_data.MetaData.last_update = os.time()
		current_data.MetaData.Forceload = false

        DataService._mock_datastores[key] = current_data
        DataService._mock_datastores[key].MetaData.Key = key

        return setmetatable(DataService._mock_datastores[key], Data)
	end

end

function Data:Release()
	self.MetaData.Forceload = false
	self.MetaData.ActiveSession.place_id = nil
	self.MetaData.ActiveSession.job_id = nil
	UpdateData(self, self.MetaData.Key)
	DataService._releaseData:Fire(self.MetaData.Key)
	DataService._autoSaveList[self.MetaData.Key] = nil
	DataService._LoadedData[self.MetaData.Key] = nil
end

function Data:ListenToRelease(callback) -- [function]
	DataService._releaseData:Connect(function(key)
		if self.MetaData.Key == key then
			callback()
		end
	end)
end

function Data:SetGlobal(name, data :table)
    if not self.MetaData.Global then
        self.MetaData.Global = {}
    end
    self.MetaData.Global[name] = {
        Data = data,
        Time_posted = os.time()
    }
    return self.MetaData.Global[name]
end

function Data:GetGlobal(name)
    return self.MetaData.Global[name]
end

function Data:RemoveGlobal(name)
	self.MetaData.Global[name] = nil
end
    

DataService._forceLoadReady:Connect(function(data)
	print("Forceload ready!")
	data.MetaData.Forceload = false
	data:Release()
end)

DayaService._CriticalStateSignal:Connect(function(state)
    dataError = state
    DataService._using_mock_datastores = state -- but we continue the queue just incase
end)


game:BindToClose(BindToClose)

if not IsStudio and not DataService._using_mock_datastores then
    task.delay(SETTINGS.AutoSaveData, StartQueue)
end


return DataService