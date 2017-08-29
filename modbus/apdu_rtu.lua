
local encode = require 'modbus.encode'
local decode = require 'modbus.decode'
local ecm = require "modbus.ecm"
local _M = {}

local function create_header(unit)
	local data = encode.uint8(unit)
	return data
end

function _M.encode(pdu, req)
	if not pdu then
		return nil, 'no pdu object'
	end
	local adu = create_header(req.unit) .. pdu
	local checknum = ecm.check(adu, req.ecm)
	return adu .. checknum 
end

function _M.decode(raw)
	local unit = decode.uint8(raw:sub(1, 1))
	return unit, raw:sub(2, -3)
end

_M.min_packet_len = 5

function _M.check(buf, req)
	if string.len(buf) <= 4 then
		return nil, buf, 4 - string.len(buf)
	end

	local adu = nil
	local unit = encode.uint8(req.unit)
	local func = tonumber(req.func)
	while string.len(buf) > 4 do
		if func == 0x01 or func == 0x02 then
			local len = math.ceil(tonumber(req.len) / 8)
			local data = unit .. encode.uint8(req.func) .. encode.uint8(len)
			local b, e = buf:find(data)
			if e then
				if e + len + 2 > string.len(buf) then
					return nil, buf, e + len + 2 - string.len(buf)
				end

				adu = buf:sub(b, e + len + 2)
				local checknum = ecm.check(adu:sub(1, -3), req.ecm)
				if checknum == adu:sub(-2, -1) then
					return adu, buf:sub(e + len + 2 + 1)
				end
			end
		elseif func == 0x03 or func == 0x04 then 
			local len = req.len * 2
			local data = unit .. encode.uint8(req.func) .. encode.uint8(len)
			local b, e = buf:find(data)
			if e then
				if e + len + 2 > string.len(buf) then
					return nil, buf, e + len + 2 - string.len(buf)
				end

				adu = buf:sub(b, e + len + 2)
				local checknum = ecm.check(adu:sub(1, -3), req.ecm)
				if checknum == adu:sub(-2, -1) then
					return adu, buf:sub( e + len + 2 + 1)
				end
			end
		elseif func == 0x05 or func == 0x06 then
			local hv, lv = encode.uint16(req.addr)
			local addr = hv .. lv
			local data = unit .. encode.uint8(req.func) .. addr
			local b, e = buf:find(data)
			if e then
				if e + 4 > string.len(buf) then
					return nil, buf, e + 4 - string.len(buf)
				end

				adu = buf:sub(b, e + 4)
				local checknum = ecm.check(adu:sub(1, -3), req.ecm)
				if checknum == adu:sub(-2, -1) then
					return adu, buf:sub(e + 4 + 1)
				end
			end
		elseif func == 0x0F or func == 0x10 then
			local hv, lv = encode.uint16(req.addr)
			local addr = hv .. lv
			hv, lv = encode.uint16(req.len)
			local len = hv .. lv
			local data = unit .. encode.uint8(req.func) .. addr .. len
			local b, e = buf:find(data)
			if e then
				if e + 2 > string.len(buf) then
					return nil, buf, e + 2 - string.len(buf)
				end

				adu = buf:sub(b, e + 2)
				local checknum = ecm.check(adu:sub(1, -3), req.ecm)
				if checknum == adu:sub(-2, -1) then
					return adu, buf:sub(e + 2 + 1)
				end
			end
		else
			return nil, buf, 1
		end
		buf = buf:sub(2)
	end
	return nil, buf, 1
end

return _M
