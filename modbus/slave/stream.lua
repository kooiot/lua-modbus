--- Modbus 从站流模块
--
-- 该模块提供 Modbus 从站（服务器）的流接口实现。
-- 支持 TCP、RTU 和 ASCII 三种传输模式。
--
-- @module modbus.slave.stream
-- @author [作者名称]
-- @license MIT
-- @release $Id$

local class = require 'middleclass'

--- Modbus 从站流类
--
-- 实现了 Modbus 从站的基本功能，包括接收请求、发送响应等。
--
-- @type Modbus_Slave_Stream
local slave = class('Modbus_Slave_Stream')

--- 初始化 Modbus 从站
--
-- @param mode string 传输模式（'tcp', 'rtu', 'ascii'）
-- @param stream table 流对象，需要实现 send() 和 recv() 方法
-- @param little_endian boolean 是否使用小端序字节顺序（可选，默认 false）
-- @usage
-- local slave = require 'modbus.slave.stream'
-- local stream = {
--   send = function(data) ... end,
--   recv = function(len, timeout) ... end
-- }
-- local s = slave:new('tcp', stream)
function slave:initialize(mode, stream, little_endian)
	local m = nil
	if string.lower(mode) == 'tcp' then
		m = require('modbus.apdu.tcp')
		self._apdu = m:new(little_endian)
	end
	if string.lower(mode) == 'rtu' then
		m = require('modbus.apdu.rtu')
		self._apdu = m:new('slave', little_endian)
	end
	if string.lower(mode) == 'ascii' then
		m = require('modbus.apdu.ascii')
		self._apdu = m:new('slave', little_endian)
	end
	self._buf = ''
	self._stream = stream
	self._callbacks = {}
end

--- 添加一个单元（设备）及其回调处理器
--
-- 为指定的单元 ID 注册请求处理回调函数
--
-- @param unit number 单元 ID（从站地址）
-- @param callback function 请求处理回调，签名为 function(pdu, response_handler)
-- @usage
-- s:add_unit(1, function(pdu, response_handler)
--   -- 解析请求 PDU
--   -- 生成响应 PDU
--   response_handler(response_pdu)
-- end)
function slave:add_unit(unit, callback)
	assert(callback and not self._callbacks[unit], "Unit callback already exists or callback is nil!")
	self._callbacks[unit] = callback
end

--- 移除一个单元（设备）
--
-- 移除指定单元 ID 的请求处理回调
--
-- @param unit number 单元 ID（从站地址）
-- @usage
-- s:remove_unit(1)
function slave:remove_unit(unit)
	self._callbacks[unit] = nil
end

function slave:_process(key, unit, pdu)
	assert(key)
	if not unit then
		-- TODO: write 0x8x?
		print(pdu, key)
		return
	end

	local callback = self._callbacks[unit]
	if callback then
		callback(pdu, function(pdu)
			local apdu_raw, key = assert(self._apdu:pack(unit, pdu, key))
			if not apdu_raw then
				return nil, key
			end

			self._stream:send(apdu_raw)
		end)
	else
		-- TODO:
	end
end

--- 执行一次从站处理循环
--
-- 执行一次从站处理循环，包括：
-- 1. 处理缓冲区中的请求
-- 2. 接收新的请求数据
--
-- @param ms number 接收超时时间（毫秒）
-- @usage
-- -- 在主循环中调用
-- while running do
--   s:run_once(1000)  -- 1 秒超时
-- end
function slave:run_once(ms)
	local buf, need_len = self._apdu:process(self._buf, function(key, unit, pdu)
			self:_process(key, unit, pdu)
	end)

	local data = self._stream:recv(need_len, ms)
	if data then
		self._buf, need_len = self._apdu:process(buf..data, function(key, unit, pdu)
			self:_process(key, unit, pdu)
		end)
	end
end

return slave
