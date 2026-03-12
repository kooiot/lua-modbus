--- Modbus 数据打包模块
--
-- 该模块提供将 Lua 数据类型打包为二进制数据的功能，
-- 支持大端序和小端序字节顺序。用于 Modbus 协议的数据编码。
--
-- @module modbus.data.pack
-- @author [作者名称]
-- @license MIT
-- @release $Id$

local class = require 'middleclass'

--- Modbus 数据打包类
--
-- 提供将各种 Lua 数据类型打包为二进制字符串的方法。
-- 支持有符号/无符号整数、浮点数、位操作等。
--
-- @type Modbus_Data_Pack_Class
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


--- 初始化数据打包器
--
-- @param little_endian boolean 是否使用小端序字节顺序（true=小端序，false=大端序）
-- @usage
-- local packer = require 'modbus.data.pack'
-- local p = packer:new()  -- 默认大端序
-- local p_le = packer:new(true)  -- 小端序
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
	-- 将有符号32位整数转换为无符号表示（二进制补码）
	-- 范围：-2147483648 到 2147483647
	-- 注意：对边界值 -2147483648 的处理依赖于 Lua 的数值精度
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
	return tostring(value) .. string.char(0)
end

--- 打包 8 位有符号整数
--
-- @param val number 整数值（-128 到 127）
-- @return string 1 字节的二进制字符串
-- @usage
-- local p = packer:new()
-- local data = p:int8(-100)
function packer:int8(val) end

--- 打包 8 位无符号整数
--
-- @param val number 整数值（0 到 255）
-- @return string 1 字节的二进制字符串
-- @usage
-- local p = packer:new()
-- local data = p:uint8(200)
function packer:uint8(val) end

--- 打包 16 位有符号整数
--
-- @param val number 整数值（-32768 到 32767）
-- @return string 2 字节的二进制字符串
-- @usage
-- local p = packer:new()
-- local data = p:int16(-1000)
function packer:int16(val) end

--- 打包 16 位无符号整数
--
-- @param val number 整数值（0 到 65535）
-- @return string 2 字节的二进制字符串
-- @usage
-- local p = packer:new()
-- local data = p:uint16(1000)
function packer:uint16(val) end

--- 打包 32 位有符号整数
--
-- @param val number 整数值（-2147483648 到 2147483647）
-- @return string 4 字节的二进制字符串
-- @usage
-- local p = packer:new()
-- local data = p:int32(-100000)
function packer:int32(val) end

--- 打包 32 位无符号整数
--
-- @param val number 整数值（0 到 4294967295）
-- @return string 4 字节的二进制字符串
-- @usage
-- local p = packer:new()
-- local data = p:uint32(100000)
function packer:uint32(val) end

--- 打包 64 位有符号整数
--
-- @param val number 整数值
-- @return string 8 字节的二进制字符串
-- @usage
-- local p = packer:new()
-- local data = p:int64(-100000)
function packer:int64(val) end

--- 打包 64 位无符号整数
--
-- @param val number 整数值
-- @return string 8 字节的二进制字符串
-- @usage
-- local p = packer:new()
-- local data = p:uint64(100000)
function packer:uint64(val) end

--- 打包单精度浮点数（32 位）
--
-- @param val number 浮点数值
-- @return string 4 字节的二进制字符串
-- @usage
-- local p = packer:new()
-- local data = p:float(3.14)
function packer:float(val) end

--- 打包双精度浮点数（64 位）
--
-- @param val number 浮点数值
-- @return string 8 字节的二进制字符串
-- @usage
-- local p = packer:new()
-- local data = p:double(3.14159265)
function packer:double(val) end

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

--- 打包 32 位有符号整数（字节交换）
--
-- 打包后交换 2 字节字的字节顺序
--
-- @param val number 整数值
-- @return string 4 字节的二进制字符串（字节交换）
function packer:int32_r(val)
	local str = self:int32(val)
	return str:sub(3, 4)..str:sub(1, 2)
end

--- 打包 32 位无符号整数（字节交换）
--
-- 打包后交换 2 字节字的字节顺序
--
-- @param val number 整数值
-- @return string 4 字节的二进制字符串（字节交换）
function packer:uint32_r(val)
	local str = self:uint32(val)
	return str:sub(3, 4)..str:sub(1, 2)
end

--- 打包 64 位有符号整数（字节交换）
--
-- 打包后交换 2 字节字的字节顺序
--
-- @param val number 整数值
-- @return string 8 字节的二进制字符串（字节交换）
function packer:int64_r(val)
	local str = self:int64(val)
	return str:sub(7, 8)..str:sub(5, 6)..str:sub(3, 4)..str:sub(1, 2)
end

--- 打包 64 位无符号整数（字节交换）
--
-- 打包后交换 2 字节字的字节顺序
--
-- @param val number 整数值
-- @return string 8 字节的二进制字符串（字节交换）
function packer:uint64_r(val)
	local str = self:uint64(val)
	return str:sub(7, 8)..str:sub(5, 6)..str:sub(3, 4)..str:sub(1, 2)
end

--- 打包单精度浮点数（字节交换）
--
-- 打包后交换 2 字节字的字节顺序
--
-- @param val number 浮点数值
-- @return string 4 字节的二进制字符串（字节交换）
function packer:float_r(val)
	local str = self:float(val)
	return str:sub(3, 4)..str:sub(1, 2)
end

--- 打包双精度浮点数（字节交换）
--
-- 打包后交换 2 字节字的字节顺序
--
-- @param val number 浮点数值
-- @return string 8 字节的二进制字符串（字节交换）
function packer:double_r(val)
	local str = self:double(val)
	return str:sub(7, 8)..str:sub(5, 6)..str:sub(3, 4)..str:sub(1, 2)
end

--- 打包位值
--
-- 将多个位值（布尔值或 0/1）打包为字节数组
--
-- @param ... boolean|number 位值列表（true/1=ON，false/0=OFF）
-- @return string 打包后的二进制字符串
-- @usage
-- local p = packer:new()
-- local data = p:bit(true, false, true, true, false)  -- 5 个位
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

--- 打包原始数据
--
-- 直接返回字符串形式的数据，不做任何转换
--
-- @param value string|number 原始数据
-- @return string 原始数据的字符串形式
-- @usage
-- local p = packer:new()
-- local data = p:raw("\\x00\\x01\\x02")
function packer:raw(value)
	return tostring(value)
end

return packer
