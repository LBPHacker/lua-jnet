local check = require("jnet.check")
local util = require("jnet.util")

local BITS = 16
local COMPMAX = 1 << BITS
local COMPMASK = COMPMAX - 1
local FORMAT = "%04x"

local net_i = {}
local net_m = { __index = net_i, jnet_type__ = "jnet.net" }

function net_i:promote_(other, netwb)
	local mt = getmetatable(self)
	if getmetatable(other) == mt then
		return other
	end
	return mt.jnet_promote_new__(other, netwb)
end

function net_i:flip()
	local new_bits = util.numeric_clone(self.bits_)
	local bit = self.all_ - self.netwb_
	local offset = bit % BITS
	local index = #new_bits - bit // BITS
	new_bits[index] = new_bits[index] ~ (1 << offset)
	return self:new_(self.all_, new_bits, self.netwb_)
end

function net_i:longshl_(lhs, amount)
	local new_bits = {}
	local zeroc_rem = self.all_ - amount
	for i = #lhs, 1, -1 do
		local zeroc_sub = math.max(0, math.min(BITS, zeroc_rem))
		assert(lhs[i] & (COMPMASK ~ ((1 << zeroc_sub) - 1)) == 0, "overflow")
		zeroc_rem = zeroc_rem - zeroc_sub
	end
	local move = amount // BITS
	local shift = amount % BITS
	for i = #lhs - move + 1, #lhs do
		new_bits[i] = 0
	end
	local carry = 0
	for i = 1, #lhs - move do
		local shifted = lhs[i + move] << shift
		new_bits[i] = (shifted & COMPMASK) | carry
		carry = (shifted >> BITS) & COMPMASK
	end
	return new_bits
end

function net_i:longadd_(lhs, rhs, rsign)
	local all_rem = self.all_
	local carry = 0
	local new_bits = {}
	for i = #lhs, 1, -1 do
		local all_sub = math.min(BITS, all_rem)
		new_bits[i] = lhs[i] + rsign * (rhs[i] + carry)
		if new_bits[i] >= (1 << all_sub) then
			new_bits[i] = new_bits[i] - rsign * (1 << all_sub)
			carry = 1
		else
			carry = 0
		end
		all_rem = all_rem - all_sub
	end
	assert(carry == 0, rsign == 1 and "overflow" or "underflow")
	return new_bits
end

function net_m:__add(other)
	if type(other) == "number" and other < 0 then
		return self - -other
	end
	other = self:promote_(other, self.netwb_)
	assert(getmetatable(other) == getmetatable(self), "other operand is of the wrong type")
	assert(self.all_ == other.all_, "other operand is of the wrong bit count")
	assert(self.netwb_ == other.netwb_, "other operand is of the wrong network bit count")
	return self:new_(self.all_, self:longadd_(self.bits_, other.bits_, 1), self.netwb_)
end

function net_m:__sub(other)
	if type(other) == "number" and other < 0 then
		return self + -other
	end
	other = self:promote_(other, self.netwb_)
	assert(getmetatable(other) == getmetatable(self), "other operand is of the wrong type")
	assert(self.all_ == other.all_, "other operand is of the wrong bit count")
	assert(self.netwb_ == other.netwb_, "other operand is of the wrong network bit count")
	return self:new_(self.all_, self:longadd_(self.bits_, other.bits_, -1), self.netwb_)
end

function net_m:__div(other)
	assert(check.integer(other), "other operand is not an integer")
	assert(other >= 0 and other <= self.all_, "other operand is out of range")
	return self:new_(self.all_, util.numeric_clone(self.bits_), other)
end

function net_m:__lt(other)
	other = self:promote_(other, self.netwb_)
	assert(getmetatable(other) == getmetatable(self), "other operand is of the wrong type")
	assert(self.all_ == other.all_, "other operand is of the wrong bit count")
	for i = 1, #self.bits_ do
		if self.bits_[i] < other.bits_[i] then
			return true
		end
		if self.bits_[i] > other.bits_[i] then
			return false
		end
	end
	return false
end

function net_m:__eq(other)
	other = self:promote_(other, self.netwb_)
	assert(getmetatable(other) == getmetatable(self), "other operand is of the wrong type")
	assert(self.all_ == other.all_, "other operand is of the wrong bit count")
	if self.netwb_ ~= other.netwb_ then
		return false
	end
	for i = 1, #self.bits_ do
		if self.bits_[i] ~= other.bits_[i] then
			return false
		end
	end
	return true
end

function net_m:__le(other)
	other = self:promote_(other, self.netwb_)
	return self < other or self == other
end

function net_m:__len()
	return self.netwb_
end

function net_m:__pow(other)
	assert(check.integer(other), "other operand is not an integer")
	assert(other >= -self.all_ and other <= self.all_, "other operand is out of range")
	local netwb = self.netwb_ + other
	assert(netwb >= 0 and netwb <= self.all_, "resulting network bit count is out of range")
	return self:new_(self.all_, util.numeric_clone(self.bits_), netwb)
end

function net_m:__div(other)
	assert(check.integer(other), "other operand is not an integer")
	assert(other >= 0 and other <= self.all_, "other operand is out of range")
	local bits = util.numeric_clone(self.bits_)
	local clear_rem = self.all_ - other
	for i = #bits, 1, -1 do
		local clear_sub = math.max(0, math.min(BITS, clear_rem))
		bits[i] = bits[i] & (COMPMASK ~ ((1 << clear_sub) - 1))
		clear_rem = clear_rem - clear_sub
	end
	return self:new_(self.all_, bits, other)
end

function net_m:__mul(other)
	if type(other) == "number" and other < 0 then
		other = self:promote_(-other, self.all_)
		return self - self:new_(self.all_, self:longshl_(other.bits_, self.all_ - self.netwb_), self.netwb_)
	end
	other = self:promote_(other, self.all_)
	return self + self:new_(self.all_, self:longshl_(other.bits_, self.all_ - self.netwb_), self.netwb_)
end

function net_i:first(netwb)
	netwb = netwb or self.all_
	assert(check.integer(netwb), "argument #1 is not an integer")
	assert(netwb >= self.netwb_ and netwb <= self.all_, "argument #1 is out of range")
	return self:new_(self.all_, util.numeric_clone(self.bits_), netwb)
end

function net_i:contains(other)
	other = self:promote_(other, self.netwb_)
	return other >= self:first(other.netwb_) and other <= self:last(other.netwb_)
end

function net_i:last(netwb)
	netwb = netwb or self.all_
	assert(check.integer(netwb), "argument #1 is not an integer")
	assert(netwb >= self.netwb_ and netwb <= self.all_, "argument #1 is out of range")
	local bits = util.numeric_clone(self.bits_)
	local hostb_rem = self.all_ - self.netwb_
	local clear_rem = self.all_ - netwb
	for i = #bits, 1, -1 do
		local hostb_sub = math.max(0, math.min(BITS, hostb_rem))
		local clear_sub = math.max(0, math.min(BITS, clear_rem))
		bits[i] = bits[i] | ((1 << hostb_sub) - 1)
		bits[i] = bits[i] & (COMPMASK ~ ((1 << clear_sub) - 1))
		hostb_rem = hostb_rem - hostb_sub
		clear_rem = clear_rem - clear_sub
	end
	return self:new_(self.all_, bits, netwb)
end

function net_i:bit(bit)
	assert(check.integer(bit), "argument #1 is not an integer")
	assert(bit >= 0 and bit < self.all_, "argument #1 is out of range")
	local offset = bit % BITS
	local index = #self.bits_ - bit // BITS
	return self.bits_[index] & (1 << offset) > 0
end

local function new(all, bits, netwb)
	if type(bits) == "number" then
		bits = { bits }
	end
	assert(check.integer(all), "argument #1 is not an integer")
	assert(all >= 1, "argument #1 is out of range")
	assert(type(bits) == "table", "argument #2 is not a table")
	local expected_length = math.ceil(all / BITS)
	assert(#bits == expected_length, "argument #2 is of the wrong length")
	assert(check.integer(netwb), "argument #3 is not an integer")
	assert(netwb >= 0 and netwb <= all, "argument #3 is out of range")
	local all_rem = all
	local hostb_rem = all - netwb
	for i = expected_length, 1, -1 do
		assert(check.integer(bits[i]), "argument #2 has non-integer components")
		local all_sub = math.min(BITS, all_rem)
		local hostb_sub = math.max(0, math.min(BITS, hostb_rem))
		assert(bits[i] < (1 << all_sub) and bits[i] >= 0, "argument #2 has out of range components")
		assert(bits[i] & ((1 << hostb_sub) - 1) == 0, "non-zero host bits")
		all_rem = all_rem - all_sub
		hostb_rem = hostb_rem - hostb_sub
	end
	return setmetatable({
		all_ = all,
		bits_ = bits,
		netwb_ = netwb,
	}, net_m)
end

function net_i:new_(...)
	return setmetatable(new(...), getmetatable(self))
end

function net_m:__tostring()
	local collect = {}
	for i = 1, #self.bits_ do
		table.insert(collect, FORMAT:format(self.bits_[i]))
	end
	local repr = table.concat(collect, ".")
	if self.netwb_ < self.all_ then
		repr = repr .. "/" .. self.netwb_
	end
	return repr
end

net_m.jnet_promote_new__ = new
net_m.jnet_base__ = net_m

return {
	new = new,
	net_m = net_m,
}
