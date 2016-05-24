local _G = _G
module(...)

local tasks = {} -- scheduled tasks. a list. local stored = safe.

-- priority  task with bigger this value will be execute earlier
-- interval  if is nil, will be called on every update
function add(func, interval, once, priority)
	priority = priority or 0
	once = once or false
	local task = {func = func, interval = interval, clock = 0.0, once, priority = priority}
	_G.table.insert(tasks, task)
	_G.table.sort(tasks, function(a,b) return a.priority>b.priority end)
	return task
end

function update(dt)
	for k,v in _G.ipairs(tasks) do
		if not v.interval then
			v.func(v)
		else
			local now = v.clock + dt
			if now >= v.interval then
				v.func(v) -- delta time = v.interval
				if v.once then
					remove(v.func)
				else
					now = now - v.interval
				end
			end
			v.clock = now
		end
	end
end

function remove(func) -- remove ALL tasks pointed to `func`
	for i,v in ipairs(tasks) do
		if v.func == func then
			tasks[k] = nil
		end
	end
end

function clear()
	tasks = {}
end
