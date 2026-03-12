--- Modbus 协议数据单元（PDU）模块
--
-- 该模块提供用于创建 Modbus 请求和响应的函数，
-- 遵循 Modbus 协议规范。支持所有标准功能码，
-- 用于读写线圈、离散输入和寄存器。
--
-- @module modbus.pdu
-- @author [作者名称]
-- @license MIT
-- @release $Id$

local class = require 'middleclass'
local code = require 'modbus.code'
local request = require 'modbus.pdu.request'
local response = require 'modbus.pdu.response'
local data_pack = require 'modbus.data.pack'
local data_unpack = require 'modbus.data.unpack'

--- Modbus PDU 类
--
-- 提供用于创建 Modbus 协议数据单元（PDU）的方法，
-- 包括请求和响应。支持大端序和小端序字节顺序。
--
-- @type Modbus_Pdu_Class
local pdu = class("Modbus_Pdu_Class")

--- 初始化 PDU 对象
--
-- @param little_endian boolean 是否使用小端序字节顺序（true=小端序，false=大端序）
-- @usage
-- local pdu_mod = require 'modbus.pdu'
-- local pdu = pdu_mod:new()  -- 默认大端序
-- local pdu_le = pdu_mod:new(true)  -- 小端序
function pdu:initialize(little_endian)
	self._le = little_endian
	self._req = request:new(self._le)
	self._resp = response:new(self._le)
	self._data_pack = data_pack:new(self._le)
	self._data_unpack = data_unpack:new(self._le)
end

--- 创建读取线圈请求（功能码 0x01）
--
-- 用于读取远程设备的线圈状态（开/关）
--
-- @param fc number 功能码（0x01）
-- @param addr number 起始线圈地址（0-65535）
-- @param len number 要读取的线圈数量（1-2000）
-- @return string 请求 PDU 数据
-- @usage
-- local pdu = require 'modbus.pdu'
-- local p = pdu:new()
-- local req = p:make_req_0x01(0x01, 0, 10)  -- 读取地址 0 开始的 10 个线圈
-- @see make_req_0x02
function pdu:make_req_0x01(fc, addr, len)
	assert(len < 2000 and len > 0, "Invalid quantity(length)")
	return self._req:pack(fc, addr, len)
end

--- 创建读取离散输入请求（功能码 0x02）
--
-- 用于读取远程设备的离散输入状态
--
-- @param fc number 功能码（0x02）
-- @param addr number 起始输入地址（0-65535）
-- @param len number 要读取的输入数量（1-2000）
-- @return string 请求 PDU 数据
-- @usage
-- local pdu = require 'modbus.pdu'
-- local p = pdu:new()
-- local req = p:make_req_0x02(0x02, 0, 10)  -- 读取地址 0 开始的 10 个离散输入
function pdu:make_req_0x02(fc, addr, len)
	assert(len < 2000 and len > 0, "Invalid quantity(length)")
	return self._req:pack(fc, addr, len)
end

--- 创建读取保持寄存器请求（功能码 0x03）
--
-- 用于读取远程设备的保持寄存器值
--
-- @param fc number 功能码（0x03）
-- @param addr number 起始寄存器地址（0-65535）
-- @param len number 要读取的寄存器数量（1-125）
-- @return string 请求 PDU 数据
-- @usage
-- local pdu = require 'modbus.pdu'
-- local p = pdu:new()
-- local req = p:make_req_0x03(0x03, 0, 10)  -- 读取地址 0 开始的 10 个寄存器
function pdu:make_req_0x03(fc, addr, len)
	assert(len < 125 and len > 0, "Invalid quantity(length)")
	return self._req:pack(fc, addr, len)
end

--- 创建读取输入寄存器请求（功能码 0x04）
--
-- 用于读取远程设备的输入寄存器值
--
-- @param fc number 功能码（0x04）
-- @param addr number 起始寄存器地址（0-65535）
-- @param len number 要读取的寄存器数量（1-125）
-- @return string 请求 PDU 数据
-- @usage
-- local pdu = require 'modbus.pdu'
-- local p = pdu:new()
-- local req = p:make_req_0x04(0x04, 0, 10)  -- 读取地址 0 开始的 10 个输入寄存器
function pdu:make_req_0x04(fc, addr, len)
	assert(len < 125 and len > 0, "Invalid quantity(length)")
	return self._req:pack(fc, addr, len)
end

--- 创建写单个线圈请求（功能码 0x05）
--
-- 用于写入单个线圈的状态（开或关）
--
-- @param fc number 功能码（0x05）
-- @param addr number 线圈地址（0-65535）
-- @param value boolean|number 线圈值（true/1=ON，false/0=OFF）
-- @return string 请求 PDU 数据
-- @usage
-- local pdu = require 'modbus.pdu'
-- local p = pdu:new()
-- local req = p:make_req_0x05(0x05, 0, true)  -- 将地址 0 的线圈设置为 ON
function pdu:make_req_0x05(fc, addr, value)
	local val = (value == true or tonumber(value) == 1) and 0xFF00 or 0x0000
	return self._req:pack(fc, addr, val)
end

--- 创建写单个寄存器请求（功能码 0x06）
--
-- 用于写入单个寄存器的值
--
-- @param fc number 功能码（0x06）
-- @param addr number 寄存器地址（0-65535）
-- @param value number 寄存器值（16 位）
-- @return string 请求 PDU 数据
-- @usage
-- local pdu = require 'modbus.pdu'
-- local p = pdu:new()
-- local req = p:make_req_0x06(0x06, 0, 1000)  -- 将地址 0 的寄存器设置为 1000
function pdu:make_req_0x06(fc, addr, value)
	return self._req:pack(fc, addr, value)
end

--- 创建写多个线圈请求（功能码 0x0F）
--
-- 用于写入多个线圈的状态
--
-- @param fc number 功能码（0x0F）
-- @param addr number 起始线圈地址（0-65535）
-- @param ... boolean|number 线圈值列表（true/1=ON，false/0=OFF）
-- @return string 请求 PDU 数据
-- @usage
-- local pdu = require 'modbus.pdu'
-- local p = pdu:new()
-- local req = p:make_req_0x0F(0x0F, 0, true, false, true)  -- 写入地址 0 开始的 3 个线圈
function pdu:make_req_0x0F(fc, addr, ...)
	local values = {...}
	local len = #values
	local data = self._data_pack:bit(values)

	return self._req:pack(fc, addr, len, data)
end

--- 创建写多个寄存器请求（功能码 0x10）
--
-- 用于写入多个寄存器的值
--
-- @param fc number 功能码（0x10）
-- @param addr number 起始寄存器地址（0-65535）
-- @param ... number|string 寄存器值列表（每个值会被编码为 2 字节），支持预编码的字符串
-- @return string 请求 PDU 数据
-- @usage
-- local pdu = require 'modbus.pdu'
-- local p = pdu:new()
-- local req = p:make_req_0x10(0x10, 0, 1000, 2000, 3000)  -- 写入地址 0 开始的 3 个寄存器
function pdu:make_req_0x10(fc, addr, ...)
	local values = {...}

	local data = {}
	for _, v in ipairs(values) do
		if type(v) == 'number' then
			table.insert(data, self._data_pack:uint16(v))
		else
			-- 支持预编码的字符串
			table.insert(data, tostring(v))
		end
	end

	local val = table.concat(data)
	assert(#val % 2 == 0, "Register data length must be even")

	return self._req:pack(fc, addr, math.floor(#val / 2), val)
end

--- 创建 Modbus 请求（通用方法）
--
-- 根据功能码自动调用对应的请求创建方法
--
-- @param fc number|string 功能码（数字或名称）
-- @param ... 参数列表（根据功能码不同而不同）
-- @return string|nil 请求 PDU 数据，如果功能码不支持则返回 nil
-- @return string|nil 错误信息（如果失败）
-- @usage
-- local pdu = require 'modbus.pdu'
-- local p = pdu:new()
-- local req, err = p:make_request(0x03, 0, 10)  -- 读取 10 个寄存器
-- if not req then print(err) end
function pdu:make_request(fc, ...)
	assert(fc, "Function Code is required!!")

	local fc = tonumber(fc) or code[fc]

	local func = self['make_req_0x'..string.format("%02X", fc)]
	if func then
		return func(self, fc, ...)
	else
		return nil, "Function code not supported!!"
	end
end

--- 创建 Modbus 错误响应
--
-- 用于创建异常响应
--
-- @param fc number 原始功能码
-- @param errno number 异常代码（见 modbus.exceptions）
-- @return string 错误响应 PDU 数据
-- @usage
-- local pdu = require 'modbus.pdu'
-- local p = pdu:new()
-- local err_resp = p:make_resp_error(0x03, 0x02)  -- 功能码 0x03，异常码 0x02（非法数据地址）
function pdu:make_resp_error(fc, errno)
	return string.pack('I1I1', 0x80 + fc, errno)
end

--- 创建读取线圈响应（功能码 0x01）
--
-- 用于创建读取线圈的响应数据
--
-- @param fc number 功能码（0x01）
-- @param addr number 地址（通常不使用，保持兼容性）
-- @param ... boolean|number 线圈值列表（true/1=ON，false/0=OFF）
-- @return string 响应 PDU 数据
-- @usage
-- local pdu = require 'modbus.pdu'
-- local p = pdu:new()
-- local resp = p:make_resp_0x01(0x01, 0, true, false, true)  -- 3 个线圈的响应
function pdu:make_resp_0x01(fc, addr, ...)
	local data = self._data_pack:bit(...)

	return self._resp:pack(fc, addr, table.concat(data))
end

--- 创建读取离散输入响应（功能码 0x02）
--
-- 用于创建读取离散输入的响应数据
--
-- @param fc number 功能码（0x02）
-- @param addr number 地址（通常不使用，保持兼容性）
-- @param ... boolean|number 输入值列表（true/1=ON，false/0=OFF）
-- @return string 响应 PDU 数据
-- @usage
-- local pdu = require 'modbus.pdu'
-- local p = pdu:new()
-- local resp = p:make_resp_0x02(0x02, 0, true, false, true)  -- 3 个离散输入的响应
function pdu:make_resp_0x02(fc, addr, ...)
	local data = self._data_pack:bit(...)

	return self._resp:pack(fc, addr, table.concat(data))
end

--- 创建读取保持寄存器响应（功能码 0x03）
--
-- 用于创建读取保持寄存器的响应数据
--
-- @param fc number 功能码（0x03）
-- @param addr number 地址（通常不使用，保持兼容性）
-- @param ... number|string 寄存器值列表，支持预编码的字符串
-- @return string 响应 PDU 数据
-- @usage
-- local pdu = require 'modbus.pdu'
-- local p = pdu:new()
-- local resp = p:make_resp_0x03(0x03, 0, 1000, 2000, 3000)  -- 3 个寄存器的响应
function pdu:make_resp_0x03(fc, addr, ...)
	local values = {...}
	local len = #values
	assert(len > 0, "Values missing")

	local data = {}
	for _, v in ipairs(values) do
		if type(v) == 'number' then
			table.insert(data, self._data_pack:uint16(v))
		else
			table.insert(data, tostring(v))
		end
	end

	return self._resp:pack(fc, addr, table.concat(data))
end

--- 创建读取输入寄存器响应（功能码 0x04）
--
-- 用于创建读取输入寄存器的响应数据
--
-- @param fc number 功能码（0x04）
-- @param addr number 地址（通常不使用，保持兼容性）
-- @param ... number|string 寄存器值列表，支持预编码的字符串
-- @return string 响应 PDU 数据
-- @usage
-- local pdu = require 'modbus.pdu'
-- local p = pdu:new()
-- local resp = p:make_resp_0x04(0x04, 0, 1000, 2000, 3000)  -- 3 个输入寄存器的响应
function pdu:make_resp_0x04(fc, addr, ...)
	local values = {...}
	local len = #values
	assert(len > 0, "Values missing")

	local data = {}
	for _, v in ipairs(values) do
		if type(v) == 'number' then
			table.insert(data, self._data_pack:uint16(v))
		else
			table.insert(data, tostring(v))
		end
	end

	return self._resp:pack(fc, addr, table.concat(data))
end

--- 创建写单个线圈响应（功能码 0x05）
--
-- 用于创建写单个线圈的响应数据
--
-- @param fc number 功能码（0x05）
-- @param addr number 线圈地址
-- @param value number 线圈值（0xFF00 或 0x0000）
-- @return string 响应 PDU 数据
-- @usage
-- local pdu = require 'modbus.pdu'
-- local p = pdu:new()
-- local resp = p:make_resp_0x05(0x05, 0, 0xFF00)  -- 地址 0 的线圈 ON
function pdu:make_resp_0x05(fc, addr, value)
	return self._resp:pack(fc, addr, value)
end

--- 创建写单个寄存器响应（功能码 0x06）
--
-- 用于创建写单个寄存器的响应数据
--
-- @param fc number 功能码（0x06）
-- @param addr number 寄存器地址
-- @param value number 寄存器值（16 位）
-- @return string 响应 PDU 数据
-- @usage
-- local pdu = require 'modbus.pdu'
-- local p = pdu:new()
-- local resp = p:make_resp_0x06(0x06, 0, 1000)  -- 地址 0 的寄存器值为 1000
function pdu:make_resp_0x06(fc, addr, value)
	return self._resp:pack(fc, addr, value)
end

--- 创建写多个线圈响应（功能码 0x0F）
--
-- 用于创建写多个线圈的响应数据
--
-- @param fc number 功能码（0x0F）
-- @param addr number 起始线圈地址
-- @param len number 实际写入的线圈数量
-- @return string 响应 PDU 数据
-- @usage
-- local pdu = require 'modbus.pdu'
-- local p = pdu:new()
-- local resp = p:make_resp_0x0F(0x0F, 0, 10)  -- 从地址 0 开始写入了 10 个线圈
function pdu:make_resp_0x0F(fc, addr, len)
	return self._resp:pack(fc, addr, len)
end

--- 创建写多个寄存器响应（功能码 0x10）
--
-- 用于创建写多个寄存器的响应数据
--
-- @param fc number 功能码（0x10）
-- @param addr number 起始寄存器地址
-- @param len number 实际写入的寄存器数量
-- @return string 响应 PDU 数据
-- @usage
-- local pdu = require 'modbus.pdu'
-- local p = pdu:new()
-- local resp = p:make_resp_0x10(0x10, 0, 10)  -- 从地址 0 开始写入了 10 个寄存器
function pdu:make_resp_0x10(fc, addr, len)
	return self._resp:pack(fc, addr, len)
end

--- 创建 Modbus 响应（通用方法）
--
-- 根据功能码自动调用对应的响应创建方法，支持错误响应
--
-- @param fc number 功能码（可以是错误响应，如 0x83）
-- @param addr number 地址或异常代码
-- @param ... 参数列表（根据功能码不同而不同）
-- @return string|nil 响应 PDU 数据，如果功能码不支持则返回 nil
-- @return string|nil 错误信息（如果失败）
-- @usage
-- local pdu = require 'modbus.pdu'
-- local p = pdu:new()
-- local resp, err = p:make_response(0x03, 0, 1000, 2000)  -- 读取寄存器响应
-- local err_resp = p:make_response(0x83, 0x02)  -- 错误响应
function pdu:make_response(fc, addr, ...)
	assert(fc, "Function Code is required!!")
	assert(addr, "Address is required!!")

	local fc = tonumber(fc) or code[fc]
	local err_flag = fc & 0xF0 == 0x80
	fc = fc & 0x0F

	if err_flag then
		return self:make_resp_error(fc, addr, ...)
	end

	local func = self['make_resp_0x'..string.format("%02X", fc)]
	if func then
		return func(fc, addr, ...)
	else
		return nil, "Function code not supported!!"
	end
end

return pdu
