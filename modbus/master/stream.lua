--- Modbus 主站流模块
--
-- 该模块提供 Modbus 主站（客户端）的流接口实现。
-- 支持 TCP、RTU 和 ASCII 三种传输模式。
--
-- @module modbus.master.stream
-- @author [作者名称]
-- @license MIT
-- @release $Id$

local class = require 'middleclass'

--- Modbus 主站流类
--
-- 实现了 Modbus 主站的基本功能，包括发送请求、接收响应、超时处理等。
--
-- @type Modbus_Master_Stream
local master = class('Modbus_Master_Stream')

--- 初始化 Modbus 主站
--
-- @param mode string 传输模式（'tcp', 'rtu', 'ascii'）
-- @param stream table 流对象，需要实现 send() 和 recv() 方法
-- @param little_endian boolean 是否使用小端序字节顺序（可选，默认 false）
-- @usage
-- local master = require 'modbus.master.stream'
-- local stream = {
--   send = function(data) ... end,
--   recv = function(len, timeout) ... end
-- }
-- local m = master:new('tcp', stream)
function master:initialize(mode, stream, little_endian)
	local m = nil
	if string.lower(mode) == 'tcp' then
		m = require('modbus.apdu.tcp')
		self._apdu = m:new(little_endian)
	end
	if string.lower(mode) == 'rtu' then
		m = require('modbus.apdu.rtu')
		self._apdu = m:new('master', little_endian)
	end
	if string.lower(mode) == 'ascii' then
		m = require('modbus.apdu.ascii')
		self._apdu = m:new('master', little_endian)
	end
	self._cos = {}
	self._buf = ''
	self._stream = stream
end

--- 发送 Modbus 请求
--
-- 发送 Modbus 请求并注册响应回调函数
--
-- @param unit number 设备单元 ID（从站地址）
-- @param pdu string 协议数据单元（由 modbus.pdu 模块创建）
-- @param callback function 响应回调函数，签名为 function(unit, pdu, key)
-- @param timeout number 超时时间（秒）
-- @return boolean|nil 成功返回 true，失败返回 nil
-- @return string|nil 错误信息（如果失败）
-- @usage
-- local pdu = require 'modbus.pdu'
-- local req = pdu:make_request(0x03, 0, 10)  -- 读取 10 个寄存器
-- m:request(1, req, function(unit, pdu, key)
--   if not pdu then
--     print("请求失败:", key)
--   else
--     print("收到响应，从站:", unit)
--   end
-- end, 5)  -- 5 秒超时
function master:request(unit, pdu, callback, timeout)
	assert(pdu and callback, "PDU and callback is required!")

	local apdu_raw, key = assert(self._apdu:pack(unit, pdu))
	if not apdu_raw then
		return nil, key
	end

	--- 发送请求数据
	self._stream:send(apdu_raw)

	--- 保存待处理请求（使用 key 作为索引，通常是 transaction ID 或 unit ID）
	self._cos[key] = {
		callback = callback,
		unit = unit,
		pdu = pdu,
		timeout = os.time() + timeout
	}
	return true
end

function master:_process(unit, pdu, key)
	assert(key)
	if not unit then
		-- print(pdu, key)
		assert(false, pdu, key)
	end

	local co = self._cos[key]
	if not co then
		return
	end

	co.callback(unit, pdu, key)
	self._cos[key] = nil
end

--- 执行一次主站处理循环
--
-- 执行一次主站处理循环，包括：
-- 1. 检查超时的请求
-- 2. 处理缓冲区中的响应数据
-- 3. 接收新数据
--
-- @param ms number 接收超时时间（毫秒）
-- @usage
-- -- 在主循环中调用
-- while running do
--   m:run_once(1000)  -- 1 秒超时
-- end
function master:run_once(ms)
	local now = os.time()
	for k, v in pairs(self._cos) do
		if v.timeout <= now then
			-- 请求超时，调用回调并清理
			v.callback(nil, "Timeout")
			self._cos[k] = nil
		end
	end

	local buf, need_len = self._apdu:process(self._buf, function(unit, pdu, key)
			self:_process(unit, pdu, key)
	end)

	local data = self._stream:recv(need_len, ms)
	if data then
		self._buf, need_len = self._apdu:process(buf..data, function(unit, pdu, key)
			self:_process(unit, pdu, key)
		end)
	end
end

return master
