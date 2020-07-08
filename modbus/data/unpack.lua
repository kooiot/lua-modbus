-- modbus data unpack functions
-- local basexx = require 'basexx'
local class = require 'middleclass'

local unpacker = class("Modbus_Data_Unpack_Class")

local be_fmts = {
	int8 = '>i1',
	uint8 = '>I1',
	int16 = '>i2',
	uint16 = '>I2',
	int32 = '>i4',
	uint32 = '>I4',
	int64 = '>i8',
	uint64 = '>I8',
	float = '>f',
	double = '>d',
}

local le_fmts = {
	int8 = '<i1',
	uint8 = '<I1',
	int16 = '<i2',
	uint16 = '<I2',
	int32 = '<i4',
	uint32 = '<I4',
	int64 = '<i8',
	uint64 = '<I8',
	float = '<f',
	double = '<d',
}

local data_unpack = string.unpack
if not data_unpack then
	local r, struct = pcall(require, 'struct')
	if r then
		data_unpack = struct.unpack
	end
end

function unpacker:initialize(little_endian)
	self._le = little_endian
	self._fmts = self._le and le_fmts or be_fmts
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

--[[
native_unpack.int32_r = function (data, index, le)
	local val = native_unpack.uint32_r(data, index, le)
	val = ((val + 1073741824) % 2147483648) - 1073741824
	return val
end
]]--

native_unpack.uint32 = function (data, index, le)
	local index = index or 1
	local hv = native_unpack.uint16(data, index, le)
	local lv = native_unpack.uint16(data, index + 2, le)
	return le and lv * 65536 + hv or hv * 65536 + lv
end

--[[
native_unpack.uint32_r = function (data, index, le)
	local index = index or 1
	local hv = native_unpack.uint16(data, index, le)
	local lv = native_unpack.uint16(data, index + 2, le)
	return le and hv * 65536 + lv or lv * 65536 + hv
end
]]--

native_unpack.string = function (data, index, le)
	local e = string.find(data, string.char(0), index, true)
	if e == nil then
		return string.sub(data, index)
	end
	return string.sub(data, index, e - 1)
end

native_unpack.float = function (data, index, le)
	assert(false, "float is not supported!")
end

native_unpack.double = function (data, index, le)
	assert(false, "double is not supported!")
end

local function MAP_FMT(fmt)
	if data_unpack then
		unpacker[fmt] = function(self, data, index)
			return data_unpack(self._fmts[fmt], data, index)
		end
	else
		unpacker[fmt] = function(self, data, index)
			return native_unpack[fmt](data, index, self._le)
		end
	end
end

for k, v in pairs(be_fmts) do
	MAP_FMT(k)
end

function unpacker:int32_r(data, index)
	local index = index or 1
	local r_data = data:sub(index + 2, index + 3)..data:sub(index, index + 1)
	local val, ind = self:int32(r_data, 1)
	assert(ind == 5)
	return val, index + 4
end

function unpacker:uint32_r(data, index)
	local index = index or 1
	local r_data = data:sub(index + 2, index + 3)..data:sub(index, index + 1)
	local val, ind = self:uint32(r_data, 1)
	assert(ind == 5)
	return val, index + 4
end

function unpacker:int64_r(data, index)
	local index = index or 1
	local r_data = data:sub(index + 6, index + 7)..data:sub(index + 4, index + 5)..data:sub(index + 2, index + 3)..data:sub(index, index + 1)
	local val, ind = self:int64(r_data, 1)
	assert(ind == 9)
	return val, index + 8
end


function unpacker:uint64_r(data, index)
	local index = index or 1
	local r_data = data:sub(index + 6, index + 7)..data:sub(index + 4, index + 5)..data:sub(index + 2, index + 3)..data:sub(index, index + 1)
	local val, ind = self:uint64(r_data, 1)
	assert(ind == 9)
	return val, index + 8
end


function unpacker:float_r(data, index)
	local index = index or 1
	local r_data = data:sub(index + 2, index + 3)..data:sub(index, index + 1)
	local val, ind = self:float(r_data, 1)
	assert(ind == 5)
	return val, index + 4
end

function unpacker:double_r(data, index)
	local index = index or 1
	local r_data = data:sub(index + 6, index + 7)..data:sub(index + 4, index + 5)..data:sub(index + 2, index + 3)..data:sub(index, index + 1)
	local val, ind = self:double(r_data, 1)
	assert(ind == 9)
	return val, index + 8
end

function unpacker:bit(data, index)
	-- Keep consistency for index start from 1 as string.sub
	local data_index = math.ceil( (index or 1) / 8 )
	local val = native_unpack.uint8(string.sub(data, data_index, data_index))
	local offset = (index - 1) % 8

	if _VERSION == 'Lua 5.1' or _VERSION == 'Lua 5.2' then
		local bit32 = require 'bit'
		return bit32.band(1, bit32.rshift(val, offset))
	else
		return (1 & (val >> (offset)))
	end
end

function unpacker:raw(data, index, len)
	return string.sub(data, index, index + len)
end

function unpacker:packsize(name, len)
	if name == 'string' then
		return len
	end
	if name == 'bit' then
		return 1
	end
	if len then
		return len
	end
	local dlen = string.match('%(d+)')
	return math.floor(tonumber(dlen) / 8)
end


return unpacker
