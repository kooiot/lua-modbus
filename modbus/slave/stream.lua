local class = require 'middleclass'

local slave = class('Modbus_Slave_Stream')

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
end

function slave:add_unit(unit, callback)
	assert(callback and not self._callbacks[unit])
	self._callbacks[unit] = callback
end

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
		cb(pdu, function(pdu)
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

function slave:run_once(ms)
	local now = os.time()
	for k,v in pairs(self._cos) do
		if v.timeout > now() then
			callback(nil, "Timeout")
			self._cos[k] = nil
		end
	end

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
