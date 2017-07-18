
local encode = require 'modbus.encode'
local decode = require 'modbus.decode'
local _M = {}

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
	transaction = transaction or 0
	unit = req.unit or 1
	local length = string.len(pdu)
	adu = create_header(transaction, length + 1, unit) .. pdu
	return true, adu 
end

function _M.decode(raw)
	local unit = decode.uint8(raw:sub(1, 1))
	return unit, raw:sub(2)
end

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


function _M.check(buf, req)
	if string.len(buf) < 7 then
		return false
	end

	local adu = nil
	local transaction = transaction or 0
	local unit = encode.uint8(req.unit)
	local fc = encode.uint8(req.func)
	local hv, lv = encode.uint16(transaction)
	transaction = hv .. lv
	hv, lv = encode.uint16(0)
	local protocolId = hv .. lv
	local data = transaction .. protocolId
	while string.len(buf) > 7 do
		local b, e = buf:find(data)
		if e then
			local raw_fc = buf:sub(e + 4, e + 4)
			if decode.uint8(fc) == decode.uint8(raw_fc) then
				--print(decode.uint8(fc), decode.uint8(raw_fc))
				local len = decode.uint16(buf:sub(e + 1, e + 2))
				if string.len(buf) < len + 6 then
					return nil, b, e
				end
				adu = buf:sub(e + 3, e + 3 + len)
				return adu
			else
				if (decode.uint8(buf:sub(e + 4, e + 4)) == decode.uint8(fc) + 0x80) then
					--TODO exception
					print("-----------exception---------------")
				else
				--	print("aaaaaaaa", hex_raw(buf), "len = ", string.len(buf))
					buf = buf:sub(b + 1)
				--	print("aaaaaaaa", hex_raw(buf), "len = ", string.len(buf))
				end
			end
		else
			return nil
		end
	end

	return nil
end

return _M
