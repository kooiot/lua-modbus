-- modbus data unpack functions
-- local basexx = require 'basexx'
local class = require 'middleclass'

local data = class("Modbus_Data_Unpack_Class")

local be_fmts = {
	int8 = '>i1',
	uint8 = '>I1',
	int16 = '>i2',
	uint16 = '>I2',
	int32 = '>i4',
	uint32 = '>I4',
	float = '>f',
	double = '>d',
	string = '>z',
}

local le_fmts = {
	int8 = '<i1',
	uint8 = '<I1',
	int16 = '<i2',
	uint16 = '<I2',
	int32 = '<i4',
	uint32 = '<I4',
	float = '<f',
	double = '<d',
	string = '<z',
}

function data:initialize(little_endian)
	self._le = little_endian
	self._fmts = self._le and le_fmts or be_fmts
	if string.unpack then
		self._unpack = string.unpack
	else
		local r, struct = pcall(require, 'struct')
		if r then
			self._unpack = struct.unpack
		end
	end
end

local native_unpack = {}

native_unpack.int8 = function (data, index, le)
	local val = string.byte(data, index or 1)
	val = ((val + 128) % 256) - 128
	return val
end

native_unpack.uint8 = function (data, index, le)
	return string.byte(data, index or 1)
end

native_unpack.int16 = function (data, index, le)
	local val = native_unpack.uint16(data, index, le)
	val = ((val + 32768) % 65536) - 32768
	return val
end

native_unpack.uint16 = function (data, index, le)
	local index = index or 1
	local hv = string.byte(data, index)
	local lv = string.byte(data, index + 1)
	return le and lv * 256 + hv or hv * 256 + lv
end

native_unpack.int32 = function (data, index, le)
	local val = native_unpack.uint32(data, index, le)
	val = ((val + 1073741824) % 2147483648) - 1073741824
	return val
end

native_unpack.uint32 = function (data, index, le)
	local index = index or 1
	local hv = native_unpack.uint16(data, index, le)
	local lv = native_unpack.uint16(data, index + 2, le)
	return le and lv * 65536 + hv or hv * 65536 + lv 
end

native_unpack.string = function (data, index, le)
	local e = string.find(data, string.char(0), index, true)
	if e == nil then
		return string.sub(data, index)
	end
	return string.sub(data, index, e - 1)
end

function MAP_FMT(fmt)
	if self._unpack then
		data[fmt] = function(self, data, index)
			self._unpack(self._fmts[fmt], data, index)
		end
	else
		data[fmt] = function(self, data, index)
			return native_unpack[fmt](data, index, self._le)
		end
	end
end

for k, v in pairs(be_fmt) do
	MAP_FMT(k)
end

function data:bit(data, index)
	-- Keep consistency for index start from 1 as string.sub
	local index = (index or 1) - 1
	local val = math.ceil((index + 1) / 8)
	local data = native_unpack.uint8(string.sub(data, val, val))
	local offset = index % 8

	if _VERSION == 'Lua 5.1' or _VERSION == 'Lua 5.2' then
		local bit32 = require 'bit'
		return bit32.band(1, bit32.rshift(data, offset))
	else
		return (1 & (data >> (offset)))
	end
end

function data:raw(data, index, len)
	return string.sub(data, index, index + len)
end

function data:packsize = function (name, len)
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


return data
