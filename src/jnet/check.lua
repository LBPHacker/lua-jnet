local function integer(thing)
	return type(thing) == "number" and math.floor(thing) == thing and math.abs(thing) < math.huge
end

return {
	integer = integer,
}
