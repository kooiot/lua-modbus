local class = require 'middleclass'
local buffer = require 'modbus.buffer'

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
	-- self._transaction_map = {}
	self._buf = buffer:new(1024)
end

function apdu:create_header(transaction, length, unit)
	local transaction = transaction ~= nil and transaction or ((self._transaction_map[unit] or 0) + 1)
	transaction = transaction % 0x10000

	-- self._transaction_map[unit] = transaction

	return string.pack(self._header_fmt, transaction, 0, length + 1, unit), transaction
end

function apdu:unpack_header(data)
	local transaction, protocol_id, length, unit = string.unpack(self._header_fmt, data)
	if not transaction then
		return nil, protocol_id
	end
	if protocol_id ~= 0 then
		return nil, "Protocol ID incorrect"
	end

	return transaction, length - 1, unit
end

function apdu:packsize_header()
	return string.packsize(self._header_fmt)
end

--- transaction is optional
function apdu:pack(unit, pdu, transaction)
	assert(pdu, "PDU object required!")
	assert(unit, "Device unit id required!")

	local data, trans = self:create_header(transaction, string.len(pdu), unit)
	return data .. pdu, trans
end

---
-- Return unit, pdu, transaction
function apdu:unpack(buf)
	if buf:len() < self:min_packsize() then
		return nil, self:min_packsize() - buf:len()
	end

	local transaction, length, unit = self:unpack_header(tostring(buf))
	if not transaction then
		return nil, length
	end
	assert(transaction and length and unit)

	if buf:len() < self:packsize_header() + length then
		return nil, "not enough data"
	end

	local si = self:packsize_header() + 1
	local ei = si + length
	local pdu = buf:sub(si, ei)

	buf:pop(ei)

	return unit, pdu, transaction
end

function apdu:min_packsize()
	return self:packsize_header() + 1
end

function apdu:append(data)
	self._buf:append(data)
end

function apdu:current_unit()
	local buf = self._buf

	if buf:len() < self:min_packsize() then
		-- print('nil')
		return nil
	end

	local transaction, length, unit = self:unpack_header(tostring(buf))

	return transaction and unit or nil
end

function apdu:process(callback)
	-- TCP APDU 处理循环
	-- MBAP Header: [Transaction ID(2)] [Protocol ID(2)] [Length(2)] [Unit ID(1)]
	-- Protocol ID 必须为 0x0000
	local min_packsize = self:min_packsize()
	local need_len = nil
	local buf = self._buf

	while buf:len() >= min_packsize do
		-- 从索引 3 开始查找协议标识符 0x0000
		-- 这用于同步到正确的帧起始位置
		local pid_index = buf:find('\0\0', 3, true)
		if not pid_index then
			-- 未找到协议标识符，保留最后 3 字节（可能是部分 Protocol ID）
			buf:pop(buf:len() - 3)
			break
		end

		if pid_index > 3 then
			-- 找到了协议标识符，但不在位置 3，说明前面有无效数据
			-- 移除无效数据，保留从 Protocol ID 开始的数据
			buf:pop(pid_index - 3)
		end

		if buf:len() < min_packsize then
			break
		end

		local unit, pdu, transaction = self:unpack(buf)
		if unit then
			callback(transaction, unit, pdu)
		else
			need_len = 1 -- 至少还需要 1 字节
			break
		end
	end

	return need_len or (min_packsize - buf:len())
end

return apdu
