local ipv4 = require("jnet.ipv4")
local ipv6 = require("jnet.ipv6")
local set = require("jnet.set")
local net = require("jnet.net")

local any_funcs = { set.new, ipv4.new, ipv6.new, net.new }
local function any(...)
	local ok, err
	for i = 1, #any_funcs do
		ok, err = pcall(any_funcs[i], ...)
		if ok then
			return err
		end
	end
	error(err)
end

return setmetatable({
	set = set.new,
	net = net.new,
	range = set.range,
	ipv4 = ipv4.new,
	ipv6 = ipv6.new,
	any = any,
}, {
	__call = function(_, ...)
		return any(...)
	end,
})
