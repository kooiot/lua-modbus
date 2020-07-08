-- modbus data pack functions
local class = require 'middleclass'

local packer = class("Modbus_Data_Pack_Class")

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

local data_pack = string.pack
if not data_pack then
	local r, struct = pcall(require, 'struct')
	if r then
		data_pack = struct.pack
	end
end


function packer:initialize(little_endian)
	self._le = little_endian
	self._fmts = self._le and le_fmts or be_fmts
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
	local val = val + 0xFFFFFFFF + 1
	return native_pack.uint32(val, le)
end

--[[
native_pack.int32_r = function(val, le)
	local val = val + 0xFFFFFFFF + 1
	return native_pack.uint32_r(val, le)
end
--]]

native_pack.uint32 = function(val, le)
	local val = val % (0xFFFFFFFF + 1)
	local hhv, hlv = native_pack.uint16(math.floor(val / 65536), le)
	local lhv, llv = native_pack.uint16(val % 65536, le)
	return le and string.char(llv, lhv, hlv, hhv) or string.char(hhv, hlv, lhv, llv)
end

--[[
native_pack.uint32_r = function(val, le)
	local val = val % (0xFFFFFFFF + 1)
	local hhv, hlv = native_pack.uint16(math.floor(val / 65536), le)
	local lhv, llv = native_pack.uint16(val % 65536, le)
	return le and string.char(hhv, hlv, lhv, llv) or string.char(llv, lhv, hlv, hhv) 
end
]]--

native_pack.float = function(value, le)
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

native_pack.int64 = function(value, le)
	assert(false, "Native convert not support int64")
end

native_pack.uint64 = function(value, le)
	assert(false, "Native convert not support uint64")
end

native_pack.double = function(value)
	assert(false, "Native convert not support double")
end

native_pack.string = function(value)
	return tostring(value) + string.char(0)
end

local function MAP_FMT(fmt)
	if data_pack then
		packer[fmt] = function(self, val)
			return data_pack(self._fmts[fmt], val)
		end
	else
		packer[fmt] = function(self, val)
			return native_pack[fmt](val, self._le)
		end
	end
end

for k, v in pairs(be_fmts) do
	MAP_FMT(k)
end

function packer:int32_r(val)
	local str = self:int32(val)
	return str:sub(3, 4)..str:sub(1, 2)
end

function packer:uint32_r(val)
	local str = self:uint32(val)
	return str:sub(3, 4)..str:sub(1, 2)
end

function packer:int64_r(val)
	local str = self:int64(val)
	return str:sub(7, 8)..str:sub(5, 6)..str:sub(3, 4)..str:sub(1, 2)
end

function packer:uint64_r(val)
	local str = self:uint64(val)
	return str:sub(7, 8)..str:sub(5, 6)..str:sub(3, 4)..str:sub(1, 2)
end

function packer:float_r(val)
	local str = self:float(val)
	return str:sub(3, 4)..str:sub(1, 2)
end

function packer:double_r(val)
	local str = self:double(val)
	return str:sub(7, 8)..str:sub(5, 6)..str:sub(3, 4)..str:sub(1, 2)
end

function packer:bit(...)
	local t = {}
	local vals = {...}

	local val = 0
	for i, v in ipairs(vals) do
		if v == 1 or v == true then
			val = val + (2 ^ ( (i - 1) % 8))
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

function packer:raw(value)
	return tostring(value)
end

return packer
