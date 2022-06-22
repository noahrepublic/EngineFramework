
local OptimizedTables = {}
OptimizedTables.__index = OptimizedTables

-- Functions --

-- Private: 

local function deepFreeze(tbl)
    table.freeze(tbl)
    for _, v in pairs(tbl) do
        if type(v) == "table" and not table.isfrozen(tbl) then
            deepFreeze(v)
        end
    end
end

-- Public:

function OptimizedTables.new(t :table, size :number) -- init
    if size == nil then
        t = t or {}
    else
        t = t or table.create(size)
    end
    return setmetatable({
        _tbl = t,
        _tblInfo = {
            _size = #t
        }
    }, OptimizedTables)
end

function OptimizedTables:__newindex(index, value)
    if self[index] ~= nil then
        error(("'%s' is reserved"):format(tostring(index)), 2)
    end

    local oldVal = self._tbl[index]
    if oldVal == value then
        return
    end
    self._tbl[index] = value
    self._tblInfo._size = self._tblInfo._size + 1
end

function OptimizedTables:__index(index)
    if self._tbl[index] ~= nil then
        return self._tbl[index]
    elseif OptimizedTables[index] ~= nil then
        return OptimizedTables[index]
    else
        return nil
    end
end

function OptimizedTables:Insert(value, index)
    self._tblInfo._size = self._tblInfo._size + 1
    if type(self._tbl[index or self._tblInfo._size]) == "table" then
        table.insert(self._tbl[index or self._tblInfo._size], value)
    else
        self._tbl[index or self._tblInfo._size] = value
    end
end

function OptimizedTables:Remove(index) -- WARNING: THIS FUNCTION DOES NOT KEEP ORDER, DEFAULT TO USING ARRAY[INDEX] = nil
    self._tbl[index] = self._tbl[self._tblInfo._size]
    self._tbl[self._tblInfo._size] = nil
    self._tblInfo._size = self._tblInfo._size - 1
end

function OptimizedTables:Clear()
    for i = 1, self._tblInfo._size do
        self._tbl[i] = nil
    end
    self._tblInfo._size = 0
end

function OptimizedTables:DeepClear() -- WARNING: REMOVES ALLOCATED MEMORY AND MAYBE MORE EXPENSIVE, USE ON TABLES YOU ARE NOT RESUSING
    self._tbl = {}
    self._tblInfo._size = 0
end

function OptimizedTables:Len()
    return self._tblInfo._size
end

function OptimizedTables:Concat(sep :string, i :number, j :number)
    return table.concat(self._tbl, sep, i, j) -- this already is pretty optimized, just made the function for simplicity
end

function OptimizedTables:BinarySearch(value) -- only works in some use cases
    local low = 1
    local high = self._tblInfo._size

    while low <= high do
        local mid = low + math.floor((high - low) / 2)
        local midVal = self._tbl[mid]
        if midVal == value then
            return mid
        end
        if value < midVal then
			high = mid - 1
		elseif midVal < value then
			low = mid + 1
		else
			while mid >= 1 and not (self._tbl[mid] < value or value < self._tbl[mid]) do
				mid -= 1
			end
			return mid + 1
		end

    end
end

function OptimizedTables:Find(value, init :number)
    return table.find(self._tbl, value, init or 1)
end

function OptimizedTables:foreach(func) -- come back to these noah
    for i = 1, self._tblInfo._size do
        func(i, self._tbl[i])
    end
end

function OptimizedTables:foreachi(func) -- come back to these noah
    for i = 1, self._tblInfo._size do
        func(i)
    end
end

function OptimizedTables:foreachv(func) -- come back to these noah
    for i = 1, self._tblInfo._size do
        func(self._tbl[i])
    end
end

function OptimizedTables:Freeze()
    table.freeze(self._tbl)
end

function OptimizedTables:DeepFreeze()
    deepFreeze(self._tbl)
    return self
end

function OptimizedTables:DeepCopy()
    local newTbl = {}
    for i = 1, self._tblInfo._size do
        newTbl[i] = self._tbl[i]
    end
    return setmetatable({
        _tbl = newTbl,
        _tblInfo = {
            _size = self._tblInfo._size
        }
    }, OptimizedTables)
end

function OptimizedTables:Destroy()
    self:DeepClear()
    self._tbl = nil
    self._tblInfo = nil
    self = nil
end

return OptimizedTables