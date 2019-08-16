-- modbus data pack functions
local class = require 'middleclass'

local data = class("Modbus_Data_Pack_Class")

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
	if string.pack then
		self._pack = string.pack
	else
		local r, struct = pcall(require, 'struct')
		if r then
			self._pack = struct.pack
		end
	end
end

local native_pack = {}

native_pack.int8 = function(val, le)
	-- lua char is unsigned
	local val = (val + 256) % 256
	return string.char(math.floor(val))
end

native_pack.uint8 = function(val, le)
	local val = val % 256
	return string.char(math.floor(val))
end

native_pack.int16 = function(val, le)
	local val = (val + 65536) % 65536
	local hv = math.floor((val / 256) % 256) 
	local lv = math.floor(val % 256)
	return le and string.char(lv, hv) or string.char(hv, lv)
end

native_pack.uint16 = function(val, le)
	local val = val % 65536
	local hv = math.floor((val / 256) % 256) 
	local lv = math.floor(val % 256)
	return le and string.char(lv, hv) or string.char(hv, lv)
end

native_pack.int32 = function(val, le)
	local val = val + 2147483648
	return _M.uint32(val, le)
end

native_pack.uint32 = function(val)
	local val = val % 2147483648
	local hhv, hlv = _M.uint16(math.floor(val / 65536))
	local lhv, llv = _M.uint16(val % 65536)
	return le and string.char(llv, lhv, hlv, hhv) or string.char(hhv, hlv, lhv, llv)
end

native_pack.float = function(value)
	assert(false, "Native convert not support float")
	--[[
	local nibbles = ''
	local n = math.floor(math.abs(value)*256 + 0.13)
	n = value < 0 and 0x10000 - n or n
	for pos = 0, 3 do
	nibbles = nibbles..string.char(n%16)
	n = math.floor(n/16)
	end
	return nibbles
	]]--
end

native_pack.double = function(value)
	assert(false, "Native convert not support double")
end

native_pack.string = function(value)
	return tostring(value) + string.char(0)
end

function MAP_FMT(fmt)
	if self._pack then
		data[fmt] = function(self, val)
			self._pack(self._fmts[fmt], val)
		end
	else
		data[fmt] = function(self, val)
			return native_pack[fmt](val, self._le)
		end
	end
end

for k, v in pairs(be_fmt) do
	MAP_FMT(k)
end

function data:bit(vals)
	local t = {}

	local val = 0
	for i, v in ipairs(vals) do
		if vals[i + 1] == 1 or vals[i + 1] == true then
			val = val + (2 ^ (i % 8))
		end
		if i % 8 == 0 then
			table.insert(t, self:uint8(val))
			val = 0
		end
	end
	if #vals % 8 ~= 0 then
		table.insert(t, self:uint8(val))
	end

	return table.concat(t)
end

function data:raw(value)
	return tostring(value)
end

return data
