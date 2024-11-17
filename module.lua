local module = {}

--// Settings
local OLD_ENVIRONMENT_RAW_LOAD = true

--// Localization
local setmetatable = setmetatable
local pcall = pcall
local table = table
local debug = debug
local string = string
local coroutine = coroutine
local setfenv = setfenv
local getfenv = getfenv
local require = require
local task = task

--// Init
local Metatable = require(script.Parent.Parent.Libraries.Metatable)
type _function = (...any) -> (...any)

local scheduled_tasks = {}

task.spawn(function()
	while task.wait() do
		for i, new_task in scheduled_tasks do
			scheduled_tasks[i] = nil
			
			task.spawn(new_task)
		end
	end
end)

--// Main
module.hookfunction = function(old: _function, new: _function, old_environment: {any}, run_on_seperate_thread: boolean?)
	if debug.info(old, "s") == "[C]" then
		print("c")
		local name = debug.info(old, "n")
		
		if old_environment[name] then
			old_environment[name] = new
		end
		
		return function(...)
			return old(...)
		end
	else
		local last_trace
		
		local function execute_hook()
			if new then
				local current_trace = {
					debug.info(3, "l"), debug.info(3, "s"), debug.info(3, "n"), debug.traceback()
				}
				
				local equal = true
				for i, v in last_trace or {} do
					if current_trace[i] ~= v then
						equal = false
					end
				end
				
				if not equal or not last_trace then
					if run_on_seperate_thread then
						table.insert(scheduled_tasks, coroutine.wrap(new))
					else
						new()
					end
				end
				
				return current_trace
			end
		end
		
		local function wrap()
			local hooks = {}
			
			for metamethod in Metatable.metamethods do
				hooks[metamethod] = function(self, ...)
					local f = debug.info(2, "f")

					if f == old then
						last_trace = execute_hook()
					end
					
					if metamethod == "__len" then
						return 3
					elseif metamethod == "__tostring" then
						return tostring(getfenv(0))
					end
					
					return wrap()
				end
			end
			
			return setmetatable({}, hooks)
		end
		
		local environment = wrap()
		setfenv(old, environment)
		
		if OLD_ENVIRONMENT_RAW_LOAD then
			for i, v in pairs(old_environment) do -- pairs bypasses __iter
				environment[i] = v
			end
		end
		
		return function(...)
			setfenv(old, old_environment)
			
			local return_value
			if run_on_seperate_thread then
				local vararg = {...}
				local unpack = unpack
				
				table.insert(scheduled_tasks, coroutine.wrap(setfenv(function()
					return_value = {old(unpack(vararg))}
				end, old_environment)))
			else
				return_value = {old(...)}
			end
			
			while not return_value do task.wait() end
			setfenv(old, wrap()) -- insert new hook once old gets executed
			
			return unpack(return_value)
		end
	end
end

return module