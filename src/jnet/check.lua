local function integer(thing)
	return math.type(thing) == 'integer'
end

return {
	integer = integer,
}
