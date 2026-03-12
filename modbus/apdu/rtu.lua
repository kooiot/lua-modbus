--- Modbus RTU APDU 模块
--
-- 该模块实现 Modbus RTU 协议的应用层协议数据单元（APDU）处理。
-- 提供打包、解包和处理 Modbus RTU 帧的功能，支持主站和从站模式。
--
-- @module modbus.apdu.rtu
-- @author [作者名称]
-- @license MIT
-- @release $Id$

local class = require 'middleclass'
local ecm = require "modbus.ecm"
local buffer = require 'modbus.buffer'

--- Modbus RTU APDU 类
--
-- 实现 Modbus RTU 协议的帧处理，支持主站和从站模式。
-- 使用 CRC 校验（默认）或 LRC 校验。
--
-- @type Modbus_Apdu_RTU_Class
local apdu = class('Modbus_Apdu_RTU_Class')

--- 初始化 RTU APDU 对象
--
-- @param mode string 工作模式（'master' 或 'slave'）
-- @param little_endian boolean 是否使用小端序字节顺序（可选，默认 false）
-- @param ecm string 错误校验方法（'CRC' 或 'LRC'，默认 'CRC'）
-- @usage
-- local apdu = require 'modbus.apdu.rtu'
-- local master = apdu:new('master')  -- 主站模式
-- local slave = apdu:new('slave')   -- 从站模式
function apdu:initialize(mode, little_endian, ecm)
	self._mode = mode ~= 'slave' and 'master' or 'slave'
	self._le = little_endian
	self._ecm = ecm or 'CRC'
	self._header_fmt = self._le and '<I1' or '>I1'
	self._header_size = string.packsize(self._header_fmt)
	self._buf = buffer:new(396)

	if self._mode == 'master' then
		self.process = self.master_process
	else
		self.process = self.slave_process
	end
end

--- 打包 RTU APDU
--
-- 将 PDU 打包为完整的 Modbus RTU 帧（添加单元 ID 和校验和）
--
-- @param unit number 单元 ID（从站地址）
-- @param pdu string PDU 数据
-- @return string 完整的 Modbus RTU 帧
-- @return number 单元 ID
function apdu:pack(unit, pdu)
	assert(pdu, "PDU object required!")
	assert(unit, "Device unit id required!")

	local data = string.pack(self._header_fmt, unit) .. pdu
	local checknum = ecm.calc(data, self._ecm, self._le)
	return data .. checknum, unit
end

--- 解包 RTU APDU
--
-- 从 Modbus RTU 帧中解包 PDU（验证校验和）
--
-- @param data string Modbus RTU 帧数据
-- @return number|nil 单元 ID
-- @return string|nil PDU 数据或错误信息
-- @return number 单元 ID（作为 key）
function apdu:unpack(data)
	local unit = string.unpack(self._header_fmt, data)
	local pdu = string.sub(data, self._header_size + 1, -3) -- skip
	local checknum = ecm.calc(string.sub(data, 1, -3), self._ecm, self._le)
	if checknum ~= string.sub(data, -2) then
		--skynet.error("ECM Checking failed!")
		return nil, "ECM Error!"
	end

	return unit, pdu, unit
end

--- 添加数据到缓冲区
--
-- @param data string 接收到的数据
function apdu:append(data)
	self._buf:append(data)
end

--- 获取当前缓冲区的单元 ID
--
-- @return number 单元 ID
function apdu:current_unit()
	return string.unpack(self._header_fmt, tostring(self._buf))
end

--- 主站模式处理函数
--
-- RTU 主站响应处理，解析缓冲区中的完整帧并调用回调。
-- 最小包长：5 字节（Unit ID(1) + Func Code(1) + Exception Code(1) + CRC(2)）
--
-- @param callback function 回调函数，签名为 function(unit, key, pdu)
-- @return number|nil 需要的额外字节数
-- @usage
-- -- 由 initialize() 自动设置
-- local need_len = apdu:master_process(function(unit, key, pdu)
--   print("收到响应:", unit, pdu)
-- end)
function apdu:master_process(callback)
	local min_size = 5
	local buf = self._buf

	if buf:len() < min_size then
		return min_size - buf:len()
	end

	local need_len = nil
	while buf:len() >= min_size do
		local fmt = self._le and '<I1I1' or '>I1I1'

		local recv_unit, recv_fc = string.unpack(fmt, tostring(buf))
		-- 检查是否为异常响应（功能码最高位为1）
		local err_flag = (recv_fc & 0x80) == 0x80
		local func = recv_fc & 0x7F

		if err_flag then
			--- 异常响应固定 5 字节：[Unit ID(1)] [Error Code(1)] [Exception Code(1)] [CRC(2)]
			local unit, pdu = self:unpack(buf:sub(1, 5))
			if unit ~= nil then
				buf:pop(5)
				callback(unit, unit, pdu)
			else
				-- CRC 校验失败，跳过 1 字节继续同步
				buf:pop(1)
				callback(recv_unit, nil, pdu)
			end
		else
			-- 正常响应处理
			if func == 0x01 or func == 0x02 then
				-- Read Coils (0x01) / Read Discrete Inputs (0x02)
				-- 响应：[Unit ID(1)] [Func Code(1)] [Byte Count(1)] [Coils(N)] [CRC(2)]
				local len = string.unpack('I1', buf:sub(3))
				-- Modbus 规范：最多读取 2000 个 coils，即最多 250 字节
				if len <= math.ceil(2000 / 8) then
					local adu_len = 3 + len + 2
					if adu_len > buf:len() then
						need_len = adu_len - buf:len()
						break
					end

					local unit, pdu = self:unpack(buf:sub(1, adu_len))
					if unit ~= nil then
						buf:pop(adu_len)
						callback(unit, unit, pdu)
					else
						buf:pop(1)
						callback(recv_unit, nil, pdu)
					end
				else
					-- 长度超出规范，跳过 1 字节重新同步
					buf:pop(1)
				end
			elseif func == 0x03 or func == 0x04 then
				-- Read Holding Registers (0x03) / Read Input Registers (0x04)
				-- 响应：[Unit ID(1)] [Func Code(1)] [Byte Count(1)] [Registers(N*2)] [CRC(2)]
				local len = string.unpack('I1', buf:sub(3))
				-- 寄存器数据必须是偶数字节（每个寄存器 2 字节）
				if len % 2 == 0 then
					local adu_len = 3 + len + 2
					if adu_len > buf:len() then
						need_len = adu_len - buf:len()
						break
					end

					local unit, pdu = self:unpack(buf:sub(1, adu_len))
					if unit ~= nil then
						buf:pop(adu_len)
						callback(unit, unit, pdu)
					else
						buf:pop(1)
						callback(recv_unit, nil, pdu)
					end
				else
					-- 长度异常（非偶数），跳过 1 字节重新同步
					buf:pop(1)
				end
			elseif func == 0x05 or func == 0x06 then
				-- Write Single Coil (0x05) / Write Single Register (0x06)
				-- 响应：[Unit ID(1)] [Func Code(1)] [Addr(2)] [Value/Output(2)] [CRC(2)]
				local adu_len = 8
				if adu_len > buf:len() then
					need_len = adu_len - buf:len()
					break
				end

				local unit, pdu = self:unpack(buf:sub(1, adu_len))
				if unit ~= nil then
					buf:pop(adu_len)
					callback(unit, unit, pdu)
				else
					buf:pop(1)
					callback(recv_unit, nil, pdu)
				end
			elseif func == 0x0F or func == 0x10 then
				-- Write Multiple Coils (0x0F) and Write Multiple Registers (0x10)
				-- Response format: [Unit ID(1)] [Func Code(1)] [Starting Addr(2)] [Quantity(2)] [CRC(2)]
				-- Total fixed length: 8 bytes (no data payload in response)
				local adu_len = 8
				if adu_len > buf:len() then
					need_len = adu_len - buf:len()
					break
				end

				local unit, pdu = self:unpack(buf:sub(1, adu_len))
				if unit ~= nil then
					buf:pop(adu_len)
					callback(unit, unit, pdu)
				else
					buf:pop(1)
					callback(recv_unit, nil, pdu)
				end
			else
				buf:pop(1)
			end
		end
	end
	return need_len or (min_size - buf:len())
end

--- 从站模式处理函数
--
-- RTU 从站请求处理，解析缓冲区中的完整帧并调用回调。
-- 最小包长：8 字节（Unit ID(1) + Func Code(1) + Addr(2) + Quantity/Value(2) + CRC(2)）
--
-- @param callback function 回调函数，签名为 function(unit, key, pdu)
-- @return number|nil 需要的额外字节数
-- @usage
-- -- 由 initialize() 自动设置
-- local need_len = apdu:slave_process(function(unit, key, pdu)
--   print("收到请求:", unit, pdu)
-- end)
function apdu:slave_process(callback)
	local min_size = 8
	local buf = self._buf

	if buf:len() < min_size then
		return min_size - buf:len()
	end

	local adu = nil
	while buf:len() >= min_size do
		local fmt = self._le and '<I1I1' or '>I1I1'
		local recv_unit, fc = string.unpack(fmt, tostring(buf))

		local need_len = nil
		if fc == 0x01 or fc == 0x02 or fc == 0x03 or fc == 0x04 or fc == 0x05 or fc == 0x06 then
			-- 简单请求（固定 8 字节）：
			-- - Read: [Unit ID(1)] [Func Code(1)] [Addr(2)] [Quantity(2)] [CRC(2)]
			-- - Write Single: [Unit ID(1)] [Func Code(1)] [Addr(2)] [Value(2)] [CRC(2)]
			local adu_len = 8
			if adu_len > buf:len() then
				need_len = adu_len - buf:len()
				break
			end

			local unit, pdu = self:unpack(buf:sub(1, adu_len))
			if unit ~= nil then
				buf:pop(adu_len)
				callback(unit, unit, pdu)
			else
				-- CRC 校验失败，跳过 1 字节重新同步
				buf:pop(1)
				callback(recv_unit, nil, pdu)
			end
		elseif fc == 0x0F or fc == 0x10 then
			-- Write Multiple Coils (0x0F) and Write Multiple Registers (0x10) Request
			-- Request format: [Unit ID(1)] [Func Code(1)] [Addr(2)] [Quantity(2)] [Byte Count(1)] [Data(N)] [CRC(2)]
			-- Minimum header size: 8 bytes (without data payload)
			if buf:len() < 8 then
				need_len = 8 - buf:len()
				break
			end

			local fmt = self._le and '<I2I1' or '>I2I1'
			local len, count = string.unpack(fmt, buf:sub(5))
			local cc = fc == 0x0F and math.ceil(len / 8) or len * 2
			if count == cc then
				-- Calculate full request length: 2(header) + 4(addr+quantity) + 1(byte count) + count(data) + 2(crc)
				local adu_len = 2 + 4 + 1 + count + 2
				if adu_len > buf:len() then
					need_len = adu_len - buf:len()
					break
				end

				local unit, pdu = self:unpack(buf:sub(1, adu_len))
				if unit ~= nil then
					buf:pop(adu_len)
					callback(unit, unit, pdu)
				else
					buf:pop(2)
					callback(recv_unit, nil, pdu)
				end
			else
				buf:pop(2)
			end
		else
			buf:pop(2)
		end
	end
	return need_len or (min_size - buf:len())
end

return apdu
