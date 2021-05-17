local net = require("jnet.net")
local check = require("jnet.check")
local util = require("jnet.util")

local ipv4_m = util.mt_clone(net.net_m, "jnet.ipv4")

local function new(bits, netwb)
	if type(bits) == "number" then
		assert(check.integer(bits), "argument #1 is not an integer")
		if not (bits >= 0x80000000 and bits <= 0x7FFFFFFF) then
			assert(bits >= 0x00000000 and bits < 0xFFFFFFFF, "argument #1 is out of range")
		end
		bits = { (bits >> 16) & 0xFFFF, bits & 0xFFFF }
	end
	if type(bits) == "string" then
		netwb = 32
		local strbody, strnetwb = bits:match("^(.*)/(%d+)$")
		if strbody then
			local strnetwbnum = tonumber(strnetwb)
			assert(check.integer(strnetwbnum), "mask is not an integer")
			assert(strnetwbnum >= 0 and strnetwbnum <= 32, "mask is out of range")
			netwb = strnetwbnum
			bits = strbody
		end
		local octets = { bits:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$") }
		assert(octets[1], "unrecognized format")
		for i = 1, 4 do
			octets[i] = tonumber(octets[i])
			assert(check.integer(octets[i]), "non-integer component")
			assert(octets[i] >= 0 and octets[i] <= 255, "out of range component")
		end
		bits = { (octets[1] << 8) + octets[2], (octets[3] << 8) + octets[4] }
	end
	return setmetatable(net.new(32, bits, netwb or 32), ipv4_m)
end

function ipv4_m:__tostring()
	local collect = {}
	for i = 1, 2 do
		table.insert(collect, ("%i"):format(self.bits_[i] >> 8))
		table.insert(collect, ("%i"):format(self.bits_[i] & 0xFF))
	end
	local repr = table.concat(collect, ".")
	if self.netwb_ < self.all_ then
		repr = repr .. "/" .. self.netwb_
	end
	return repr
end

ipv4_m.jnet_promote_new__ = new
ipv4_m.jnet_base__ = net.net_m

return setmetatable({
	new = new,
}, {
	__call = function(_, ...)
		return new(...)
	end,
})
