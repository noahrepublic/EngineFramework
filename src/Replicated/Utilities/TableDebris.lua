
-- Variables --

local TableDebris = {}
TableDebris.ClassName = "TableDebris"
TableDebris.__index = TableDebris

-- Class Functions --

-- init
function TableDebris.new(tbl)
	return setmetatable({
		_table = tbl,
		_len = #tbl,
	}, TableDebris)
end

function TableDebris.isTableDebris(value)
	return type(value) == "table" and value.ClassName == "TableDebris"
end

-- 

function TableDebris:__index(index)
	if self._table[index] ~= nil then
		return self._table[index]
	else
		return TableDebris[index] -- (?) correct me please
	end
end

function TableDebris:__newindex(index, newItem)
	if TableDebris[index] ~= nil then
		error(("'%s' is reserved"):format(tostring(index)), 2)
	end
	
	local tbl = self._table
	local oldTbl = tbl[index]
	if tbl == oldTbl then
		return
	end
	
	tbl[index] = newItem
	
end

function TableDebris:AddItem(item, lifespan, index) -- for tabledebris objects
	if index then
		self._table[index] = item
		task.delay(lifespan, function()
			self._table[index] = nil
		end)
	else
		local len = self._len
		table.insert(self._table, len + 1, item)
		task.delay(lifespan, function()
			self._table[len+1] = nil
		end)
	end
	self._len += 1
end

function TableDebris.AddDebris(tbl, item, lifespan, index) -- for non custom object, just normal tables.
	if index then
		tbl[index] = item
		task.delay(lifespan, function()
			tbl[index] = nil
		end)
	else
		local len = #tbl
		table.insert(tbl, len + 1, item)
		task.delay(lifespan, function()
			tbl[len+1] = nil
		end)
	end
end

return TableDebris