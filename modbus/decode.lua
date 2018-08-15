-- modbus decode functions
--
--local basexx = require 'basexx'

local _M = {}

_M.int8 = function (data, index)
	local val = string.byte(data, index or 1)
	val = ((val + 128) % 256) - 128
	return val
end

_M.uint8 = function (data, index)
	return string.byte(data, index or 1)
end

_M.int16 = function (data, index)
	local val = _M.uint16(data, index)
	val = ((val + 32768) % 65536) - 32768
	return val
end

_M.uint16 = function (data, index)
	local index = index or 1
	local hv = string.byte(data, index)
	local lv = string.byte(data, index + 1)
	return hv * 256 + lv
end

_M.int32 = function (data, index)
	local val = _M.uint32(data, index)
	val = ((val + 1073741824) % 2147483648) - 1073741824
	return val
end

_M.uint32 = function (data, index)
	local index = index or 1
	local hv = _M.uint16(data, index)
	local lv = _M.uint16(data, index + 2)
	return hv * 65536 + lv 
end

_M.string = function (data, index, len)
	return string.sub(data, index, len)
end

_M.bit = function (raw, index)
	-- Keep consistency for index start from 1 as string.sub
	local index = (index or 1) - 1
	local val = math.ceil((index + 1) / 8)
	local data = _M.uint8(raw:sub(val, val))
	if _VERSION == 'Lua 5.3'then
		return (1 & (data >> (index % 8)))
	else
		local bit32 = require 'bit'
		return bit32.band(1, bit32.rshift(data, index % 8))
	end
end

_M.byte = function (raw, addr)
	return string.byte(raw, addr)
end

_M.get_len = function (name, len)
	if name == 'string' then
		return len
	end
	if name == 'bit' then
		return 1
	end
	if len then
		return len
	end
	local len = string.match('%(d+)$')
	return math.floor(tonumber(len) / 8)
end

return _M
