--- Modbus 数据解包模块
--
-- 该模块提供将二进制数据解包为 Lua 数据类型的功能，
-- 支持大端序和小端序字节顺序。用于 Modbus 协议的数据解码。
--
-- @module modbus.data.unpack
-- @author [作者名称]
-- @license MIT
-- @release $Id$

-- local basexx = require 'basexx'
local class = require 'middleclass'

--- Modbus 数据解包类
--
-- 提供将二进制字符串解包为各种 Lua 数据类型的方法。
-- 支持有符号/无符号整数、浮点数、位操作等。
--
-- @type Modbus_Data_Unpack_Class
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

--- 初始化数据解包器
--
-- @param little_endian boolean 是否使用小端序字节顺序（true=小端序，false=大端序）
-- @usage
-- local unpacker = require 'modbus.data.unpack'
-- local u = unpacker:new()  -- 默认大端序
-- local u_le = unpacker:new(true)  -- 小端序
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
	-- 将无符号32位整数转换为有符号整数（处理二进制补码）
	-- 范围：-2147483648 到 2147483647
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

--- 解包 8 位有符号整数
--
-- @param data string 二进制数据字符串
-- @param index number 起始位置（可选，默认为 1）
-- @return number 整数值
-- @return number 下一个位置
-- @usage
-- local u = unpacker:new()
-- local val, next_pos = u:int8(data, 1)
function unpacker:int8(data, index) end

--- 解包 8 位无符号整数
--
-- @param data string 二进制数据字符串
-- @param index number 起始位置（可选，默认为 1）
-- @return number 整数值
-- @return number 下一个位置
-- @usage
-- local u = unpacker:new()
-- local val, next_pos = u:uint8(data, 1)
function unpacker:uint8(data, index) end

--- 解包 16 位有符号整数
--
-- @param data string 二进制数据字符串
-- @param index number 起始位置（可选，默认为 1）
-- @return number 整数值
-- @return number 下一个位置
-- @usage
-- local u = unpacker:new()
-- local val, next_pos = u:int16(data, 1)
function unpacker:int16(data, index) end

--- 解包 16 位无符号整数
--
-- @param data string 二进制数据字符串
-- @param index number 起始位置（可选，默认为 1）
-- @return number 整数值
-- @return number 下一个位置
-- @usage
-- local u = unpacker:new()
-- local val, next_pos = u:uint16(data, 1)
function unpacker:uint16(data, index) end

--- 解包 32 位有符号整数
--
-- @param data string 二进制数据字符串
-- @param index number 起始位置（可选，默认为 1）
-- @return number 整数值
-- @return number 下一个位置
-- @usage
-- local u = unpacker:new()
-- local val, next_pos = u:int32(data, 1)
function unpacker:int32(data, index) end

--- 解包 32 位无符号整数
--
-- @param data string 二进制数据字符串
-- @param index number 起始位置（可选，默认为 1）
-- @return number 整数值
-- @return number 下一个位置
-- @usage
-- local u = unpacker:new()
-- local val, next_pos = u:uint32(data, 1)
function unpacker:uint32(data, index) end

--- 解包 64 位有符号整数
--
-- @param data string 二进制数据字符串
-- @param index number 起始位置（可选，默认为 1）
-- @return number 整数值
-- @return number 下一个位置
-- @usage
-- local u = unpacker:new()
-- local val, next_pos = u:int64(data, 1)
function unpacker:int64(data, index) end

--- 解包 64 位无符号整数
--
-- @param data string 二进制数据字符串
-- @param index number 起始位置（可选，默认为 1）
-- @return number 整数值
-- @return number 下一个位置
-- @usage
-- local u = unpacker:new()
-- local val, next_pos = u:uint64(data, 1)
function unpacker:uint64(data, index) end

--- 解包单精度浮点数（32 位）
--
-- @param data string 二进制数据字符串
-- @param index number 起始位置（可选，默认为 1）
-- @return number 浮点数值
-- @return number 下一个位置
-- @usage
-- local u = unpacker:new()
-- local val, next_pos = u:float(data, 1)
function unpacker:float(data, index) end

--- 解包双精度浮点数（64 位）
--
-- @param data string 二进制数据字符串
-- @param index number 起始位置（可选，默认为 1）
-- @return number 浮点数值
-- @return number 下一个位置
-- @usage
-- local u = unpacker:new()
-- local val, next_pos = u:double(data, 1)
function unpacker:double(data, index) end

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

--- 解包 32 位有符号整数（字节交换）
--
-- 解包前交换 2 字节字的字节顺序
--
-- @param data string 二进制数据字符串
-- @param index number 起始位置（可选，默认为 1）
-- @return number 整数值
-- @return number 下一个位置
function unpacker:int32_r(data, index)
	local index = index or 1
	local r_data = data:sub(index + 2, index + 3)..data:sub(index, index + 1)
	local val, ind = self:int32(r_data, 1)
	assert(ind == 5)
	return val, index + 4
end

--- 解包 32 位无符号整数（字节交换）
--
-- 解包前交换 2 字节字的字节顺序
--
-- @param data string 二进制数据字符串
-- @param index number 起始位置（可选，默认为 1）
-- @return number 整数值
-- @return number 下一个位置
function unpacker:uint32_r(data, index)
	local index = index or 1
	local r_data = data:sub(index + 2, index + 3)..data:sub(index, index + 1)
	local val, ind = self:uint32(r_data, 1)
	assert(ind == 5)
	return val, index + 4
end

--- 解包 64 位有符号整数（字节交换）
--
-- 解包前交换 2 字节字的字节顺序
--
-- @param data string 二进制数据字符串
-- @param index number 起始位置（可选，默认为 1）
-- @return number 整数值
-- @return number 下一个位置
function unpacker:int64_r(data, index)
	local index = index or 1
	local r_data = data:sub(index + 6, index + 7)..data:sub(index + 4, index + 5)..data:sub(index + 2, index + 3)..data:sub(index, index + 1)
	local val, ind = self:int64(r_data, 1)
	assert(ind == 9)
	return val, index + 8
end


--- 解包 64 位无符号整数（字节交换）
--
-- 解包前交换 2 字节字的字节顺序
--
-- @param data string 二进制数据字符串
-- @param index number 起始位置（可选，默认为 1）
-- @return number 整数值
-- @return number 下一个位置
function unpacker:uint64_r(data, index)
	local index = index or 1
	local r_data = data:sub(index + 6, index + 7)..data:sub(index + 4, index + 5)..data:sub(index + 2, index + 3)..data:sub(index, index + 1)
	local val, ind = self:uint64(r_data, 1)
	assert(ind == 9)
	return val, index + 8
end


--- 解包单精度浮点数（字节交换）
--
-- 解包前交换 2 字节字的字节顺序
--
-- @param data string 二进制数据字符串
-- @param index number 起始位置（可选，默认为 1）
-- @return number 浮点数值
-- @return number 下一个位置
function unpacker:float_r(data, index)
	local index = index or 1
	local r_data = data:sub(index + 2, index + 3)..data:sub(index, index + 1)
	local val, ind = self:float(r_data, 1)
	assert(ind == 5)
	return val, index + 4
end

--- 解包双精度浮点数（字节交换）
--
-- 解包前交换 2 字节字的字节顺序
--
-- @param data string 二进制数据字符串
-- @param index number 起始位置（可选，默认为 1）
-- @return number 浮点数值
-- @return number 下一个位置
function unpacker:double_r(data, index)
	local index = index or 1
	local r_data = data:sub(index + 6, index + 7)..data:sub(index + 4, index + 5)..data:sub(index + 2, index + 3)..data:sub(index, index + 1)
	local val, ind = self:double(r_data, 1)
	assert(ind == 9)
	return val, index + 8
end

--- 解包位值
--
-- 从字节中提取单个位（索引从 1 开始）
--
-- @param data string 二进制数据字符串
-- @param index number 位索引（从 1 开始）
-- @return number 位值（0 或 1）
-- @usage
-- local u = unpacker:new()
-- local bit = u:bit(data, 1)  -- 获取第 1 位
function unpacker:bit(data, index)
	local data_index = math.ceil( (index or 1) / 8 )
	local val = native_unpack.uint8(string.sub(data, data_index, data_index))
	local offset = (index - 1) % 8

	-- Lua 5.3+ 支持原生位运算，5.1/5.2 需要使用 bit 库
	if _VERSION == 'Lua 5.1' or _VERSION == 'Lua 5.2' then
		-- 注意：如果环境中没有 'bit' 库会报错，需要提前检查
		local bit32 = require 'bit'
		return bit32.band(1, bit32.rshift(val, offset))
	else
		return (1 & (val >> (offset)))
	end
end

--- 解包原始数据
--
-- 直接返回指定长度的原始字符串
--
-- @param data string 二进制数据字符串
-- @param index number 起始位置
-- @param len number 数据长度
-- @return string 原始数据字符串
-- @usage
-- local u = unpacker:new()
-- local raw = u:raw(data, 1, 10)  -- 获取从位置 1 开始的 10 字节
function unpacker:raw(data, index, len)
	return string.sub(data, index, index + len - 1)
end

--- 计算数据类型的字节大小
--
-- 根据格式名称计算数据类型的字节大小
--
-- @param name string 格式名称（如 'int16', 'uint32' 等）
-- @param len number 数据长度（可选）
-- @return number 字节大小
-- @usage
-- local u = unpacker:new()
-- local size = u:packsize('int16')  -- 返回 2
-- local size2 = u:packsize('string', 10)  -- 返回 10
function unpacker:packsize(name, len)
	-- 根据格式名称计算数据类型的字节大小
	if name == 'string' then
		return len
	end
	if name == 'bit' then
		return 1
	end
	if len then
		return len
	end
	-- 从格式名称中提取位数（如 'int16' -> 16）
	local dlen = tonumber(string.match(name, '(%d+)'))
	assert(dlen, 'not found length from format name')
	return math.floor(dlen / 8)
end


return unpacker
