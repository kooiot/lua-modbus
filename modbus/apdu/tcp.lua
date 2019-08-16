local class = require 'middleclass'

local apdu = class('Modbus_Apdu_TCP_Class')

local function hex_raw(raw)
	if not raw then
		return ""
	end
	if (string.len(raw) > 1) then
		return string.format("%02X ", string.byte(raw:sub(1, 1)))..hex_raw(raw:sub(2))
	else
		return string.format("%02X ", string.byte(raw:sub(1, 1)))
	end
end

function apdu:initialize(little_endian)
	self._le = little_endian
	self._header_fmt = self._le and '<I2I2I2I1' or '>I2I2I2I1'
	self._transaction_map = {}
end

function apdu:create_header(transaction, length, unit)
	local transaction = transaction ~= nil and transaction or ((self._transaction_map[unit] or 0) + 1)
	if transaction > 0xFFFF then
		transaction = 0
	end

	self._transaction_map[unit] = transaction

	return string.pack(self._header_fmt, transaction, 0, length + 1, unit)
end

function apdu:unpack_header(data)
	local transaction, protocol_id, length, unit = string.unpack(self._header_fmt, data)
	if not transaction then
		return nil, protocol_id
	end
	if protocol_id ~= 0 then
		return nil, "Protocol ID incorrect"
	end

	return transcation, length - 1, unit
end

function apdu:packsize_header()
	return string.packsize(self._header_fmt)
end

--- transcation is optional
function apdu:pack(unit, pdu, transaction)
	assert(pdu, "PDU object required!")
	assert(unit, "Device unit id required!")

	local data = self:create_header(transaction, string.len(pdu), unit) .. pdu
	return data, transaction
end

---
-- Return unit, pdu, transaction and left data
function apdu:unpack(data)
	if string.len(data) < self:min_packsize() then
		return nil, self:min_packsize() - string.len(data)
	end

	local transaction, length, unit = self:unpack_header(data)
	if not transaction then
		return nil, length
	end
	assert(transaction, length, unit)

	if string.len(data) < self:packsize_header() + length then
		return nil, "not enough data"
	end

	local si = self:packsize_header() + 1
	local ei = si + length
	local pdu = string.sub(data, ei)

	return unit, pdu, transaction, string.sub(data, ei + 1)
end

function apdu:min_packsize()
	return self:packsize_header() + 1
end

function apdu:processs(buf, callback)
	local min_packsize = self:min_packsize()
	local need_len = nil

	while string.len(buf) >= min_packsize do
		--- Start from index 3
		local pid_index = string.find(data, '\0\0', 3, true)
		if not pid_index then
			buf = string.sub(buf, -2)
			break
		end
		local buf = string.sub(buf, pid_index - 2)

		if string.len(data) < min_packsize then
			break
		end

		local unit, pdu, transaction, new_buf = self:unpack(buf)
		if unit then
			callback(unit, pdu, transaction)
			buf = new_buf
		else
			need_len = 1 -- at less one byte more
			break
		end
	end

	return buf, need_len or (min_packsize - string.len(buf))
end

return _M
