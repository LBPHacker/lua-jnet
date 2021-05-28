local net = require("jnet.net")
local check = require("jnet.check")
local util = require("jnet.util")

local ipv6_m = util.mt_clone(net.net_m, "jnet.ipv6")

local function new(bits, netwb)
	if type(bits) == "string" then
		netwb = 128
		local strbody, strnetwb = bits:match("^(.*)/(%d+)$")
		if strbody then
			local strnetwbnum = tonumber(strnetwb)
			assert(check.integer(strnetwbnum), "mask is not an integer")
			assert(strnetwbnum >= 0 and strnetwbnum <= 128, "mask is out of range")
			netwb = strnetwbnum
			bits = strbody
		end
		local groups = {}
		for group in bits:gmatch("[^:]*") do
			table.insert(groups, group:lower())
		end
		if groups[1] == "" and groups[2] == "" then
			table.remove(groups, 1)
		end
		if groups[#groups - 1] == "" and groups[#groups] == "" then
			table.remove(groups, #groups)
		end
		local has_empty = false
		for i = 1, #groups do
			if groups[i] == "" then
				assert(not has_empty, "multiple empty groups")
				has_empty = i
				groups[i] = false
			else
				assert(not groups[i]:find("[^a-f0-9]") and #groups[i] <= 4, "unrecognized format")
				groups[i] = tonumber("0x" .. groups[i])
			end
		end
		assert(#groups <= 8 and (not has_empty or #groups < 8), "too many groups")
		if has_empty then
			table.remove(groups, has_empty)
			for i = #groups + 1, 8 do
				table.insert(groups, has_empty, 0)
			end
		end
		bits = groups
	end
	return setmetatable(net.new(128, bits, netwb or 128), ipv6_m)
end

function ipv6_m:__tostring()
	local collect = {}
	local last_srun
	local last_srun_size
	local curr_srun
	local function close_srun(i)
		if curr_srun then
			local size = i - curr_srun
			if not last_srun or last_srun_size < size then
				last_srun = curr_srun
				last_srun_size = size
			end
			curr_srun = nil
		end
	end
	for i = 1, 8 do
		if self.bits_[i] == 0 then
			curr_srun = curr_srun or i
		else
			close_srun(i)
		end
	end
	close_srun(9)
	for i = 1, 8 do
		table.insert(collect, ("%x"):format(self.bits_[i]))
	end
	if last_srun then
		for i = 1, last_srun_size do
			table.remove(collect, last_srun)
		end
		table.insert(collect, last_srun, "")
	end
	if collect[#collect] == "" then
		table.insert(collect, "")
	end
	if collect[1] == "" then
		table.insert(collect, 1, "")
	end
	local repr = table.concat(collect, ":")
	if self.netwb_ < self.all_ then
		repr = repr .. "/" .. self.netwb_
	end
	return repr
end

ipv6_m.jnet_promote_new__ = new
ipv6_m.jnet_base__ = net.net_m

return setmetatable({
	new = new,
}, {
	__call = function(_, ...)
		return new(...)
	end,
})
