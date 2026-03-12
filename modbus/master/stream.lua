local class = require 'middleclass'

local master = class('Modbus_Master_Stream')

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

function master:request(unit, pdu, callback, timeout)
	-- 发送 Modbus 请求并注册回调
	-- unit: 设备单元 ID
	-- pdu: 协议数据单元
	-- callback: 响应回调函数 function(unit, pdu, key)
	-- timeout: 超时时间（秒）
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

function master:run_once(ms)
	-- 执行一次主站处理循环
	-- 1. 检查超时的请求
	-- 2. 处理缓冲区中的响应数据
	-- 3. 接收新数据
	-- ms: 接收超时时间（毫秒）
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
