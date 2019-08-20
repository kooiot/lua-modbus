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
	assert(pdu and callback, "PDU and callbak is required!")

	local apdu_raw, key = assert(self._apdu:pack(unit, pdu))
	if not apdu_raw then
		return nil, key
	end

	--- write to pipe
	self._stream:send(apdu_raw)

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
		print(pdu, key)
	end

	local co = self._cos[key]
	if not co then
		return
	end

	co.callback(unit, pdu, key)
end

function master:run_once(ms)
	local now = os.time()
	for k,v in pairs(self._cos) do
		if v.timeout > now() then
			callback(nil, "Timeout")
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
