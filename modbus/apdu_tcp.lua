
local encode = require 'modbus.encode'
local decode = require 'modbus.decode'
local _M = {}

local transaction_map = {}

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


local function create_header(transaction, length, unit)
	local hv, lv = encode.uint16(transaction)
	transaction = hv .. lv
	hv, lv = encode.uint16(0)
	local protocolId = hv .. lv
	hv, lv = encode.uint16(length)
	length = hv .. lv
	local data =  transaction .. protocolId .. length .. encode.uint8(unit)
	return data
end

function _M.encode(pdu, req)
	if not pdu then
		return nil, 'no pdu object'
	end
	local transaction = req.transaction or (transaction_map[req.unit] or 0) + 1
	transaction_map[req.unit] = transaction
	req.transaction = transaction
	local length = string.len(pdu)
	adu = create_header(transaction, length + 1, req.unit) .. pdu
	return adu 
end

function _M.decode(raw)
	local unit = decode.uint8(raw:sub(1, 1))
	return unit, raw:sub(2)
end

_M.min_packet_len = 8

function _M.check(buf, req)
	if string.len(buf) < 7 then
		return nil, buf, 7 - string.len(buf)
	end

	local adu = nil
	local transaction = req.transaction or transaction_map[req.unit]
	local unit = encode.uint8(req.unit)
	local fc = encode.uint8(req.func)
	local hv, lv = encode.uint16(transaction)
	transaction = hv .. lv
	hv, lv = encode.uint16(0)
	local protocolId = hv .. lv
	local data = transaction .. protocolId
	while string.len(buf) > 7 do
		local b, e = buf:find(data)
		if b and e then
			local raw_fc = buf:sub(e + 4, e + 4)
			if decode.uint8(fc) == decode.uint8(raw_fc) then
				--print(decode.uint8(fc), decode.uint8(raw_fc))
				local len = decode.uint16(buf:sub(e + 1, e + 2))
				if string.len(buf) < len + 6 then
					return nil, buf, len + 6 - string.len(buf)
				end
				adu = buf:sub(e + 3, e + 3 + len)
				return adu, buf:sub(len + 6 + 1)
			else
				if (decode.uint8(buf:sub(e + 4, e + 4)) == decode.uint8(fc) + 0x80) then
					--TODO exception
					print("-----------exception---------------")
				else
					buf = buf:sub(b)
				end
			end
		else
			buf = buf:sub(2)
		end
	end

	return nil, buf, 8 - string.len(buf)
end

return _M
