local function shallow_clone(tbl)
	local new_tbl = {}
	for key, value in pairs(tbl) do
		new_tbl[key] = value
	end
	return new_tbl
end

local function mt_clone(mt, jnet_type)
	local new_mt = shallow_clone(mt)
	new_mt.__index = shallow_clone(mt.__index)
	new_mt.jnet_type__ = jnet_type
	return new_mt
end

local function numeric_clone(tbl)
	local new_tbl = {}
	for i = 1, #tbl do
		new_tbl[i] = tbl[i]
	end
	return new_tbl
end

return {
	shallow_clone = shallow_clone,
	mt_clone = mt_clone,
	numeric_clone = numeric_clone,
}
