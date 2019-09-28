local class = require 'middleclass'
local basexx = require 'basexx'
local ecm = require "modbus.ecm"
local buffer = require 'modbus.buffer'

local apdu = class('Modbus_Apdu_ASCII_Class')

function apdu:initialize(little_endian, ecm)
	self._le = little_endian
	self._ecm = ecm or 'LRC'
	self._buf = buffer:new(1024)
end

--- transcation is optional
function apdu:pack(unit, pdu, transaction)
	assert(pdu, "PDU object required!")
	assert(unit, "Device unit id required!")

	local adu = string.pack('I1', unit)..pdu
	local checksum = ecm.calc(adu, self._ecm, self._le)

	return ':'..basexx.to_hex(adu..checksum)..'\r\n', unit
end

---
-- Return unit, pdu 
function apdu:unpack(buf)
	if buf:sub(1, 1) ~= ':' then
		return nil, "Incorrect packet starter!"
	end

	local index = buf:find('\r\n', 1, true)
	if not index then
		return nil, "No end found!"
	end

	local pdu, err = basexx.from_hex(buf:sub(2, index - 1))
	if not pdu then
		buf:pop(1)
		return nil, err
	end

	local checksum = ecm.calc(string.sub(pdu, 1, -2), self._ecm, self._le)

	if checksum ~= string.sub(pdu, -1) then
		--print(basexx.to_hex(checksum), basexx.to_hex(string.sub(pdu, -1)))
		buf:pop(1)
		return nil, "ECM Error!"
	end
	local unit = string.unpack('I1', pdu)

	buf:pop(index + 2)

	return unit, string.sub(pdu, 2, -2), unit
end

function apdu:append(data)
	self._buf:append(data)
end

function apdu:current_unit()
	local buf = self._buf

	if buf:sub(1, 1) ~= ':' then
		return nil, "Incorrect packet starter!"
	end

	if buf:len() < 3 then
		return nil, "No enough data"
	end

	local pdu = basexx.from_hex(buf:sub(2, 3))

	local unit = string.unpack('I1', pdu)

	return unit
end

function apdu:process(callback)
	local need_len = nil
	local buf = self._buf

	while buf:len() > 9 do
		local si = buf:find(':', 1, true)
		if not si then
			buf:clear()
			break
		end

		if si > 1 then
			buf:pop(si - 1)
		end

		local ei = buf:find('\r\n', 1, true)
		if not ei then
			need_len = 1 -- at less one byte more
			break
		end

		local unit, pdu, transaction = self:unpack(buf)
		if unit then
			callback(transaction, unit, pdu)
		else
			need_len = 1 -- at less one byte more
			break
		end
	end

	return need_len or (9 - buf:len())
end

return apdu
