-- modbus encode functions

local _M = {}

_M.int8 = function(val)
	-- lua char is unsigned
	local val = (val + 256) % 256
	return string.char(math.floor(val))
end

_M.uint8 = function(val)
	local val = val % 256
	return string.char(math.floor(val))
end

_M.int16 = function(val)
	local val = (val + 65536) % 65536
	local hv = math.floor((val / 256) % 256) 
	local lv = math.floor(val % 256)
	return string.char(hv), string.char(lv)
end

_M.uint16 = function(val)
	local val = val % 65536
	local hv = math.floor((val / 256) % 256) 
	local lv = math.floor(val % 256)
	return string.char(hv), string.char(lv)
end

_M.int32 = function(val)
	local val = val + 2147483648
	return _M.uint32(val)
end

_M.uint32 = function(val)
	local val = val % 2147483648
	local hhv, hlv = _M.uint16(math.floor(val / 65536))
	local lhv, llv = _M.uint16(val % 65536)
	return hhv, hlv, lhv, llv
end

_M.string = function(val)
	return val.tostring()
end

return _M
