-- modbus decode functions
--
local bit32 = require 'shared.compat.bit'

local _M = {}

_M.int8 = function (data)
	val = string.byte(data)
	val = ((val + 128) % 256) - 128
	return val
end

_M.uint8 = function (data)
	return string.byte(data)
end

_M.int16 = function (data, option)
	hv = string.byte(data)
	lv = string.byte(data, 2)
	val = hv * 256 + lv
	val = ((val + 32768) % 65536) - 32768
	return val
end

_M.uint16 = function (data, option)
	hv = string.byte(data)
	hl = string.byte(data, 2)
	val = hv * 256 + hl
	return val
end

_M.int32 = function (data)
	val = _M.uint32(data)
	val = ((val + 1073741824) % 2147483648) - 1073741824
	return val
end

_M.uint32 = function (data)
	hv = _M.uint16(data)
	hl = _M.uint16(string.sub(data, 2, 2))
	return hv * 65536 + hl
end

_M.string = function (data, len)
	return string.sub(data, 1, len)
end

_M.bit = function (raw, addr, index)
	val = math.ceil(index / 8)
	data = decode.uint8(raw:sub(val, val))
	return bit32.band(1, bit32.rshift(data, index % 8))
end

_M.byte = function (raw, addr, index)
	--[[
	data = raw:sub(addr)
	return string.byte(data, index)
	]]--
	return string.byte(raw, addr + index)
end

_M.get_len = function (name, len)
	if name == 'string' then
		return len
	end
	if name == 'bit' then
		return 1
	end
	return len or math.floor(name:sub(5) / 8)
end

return _M
