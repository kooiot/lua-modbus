
local encode = require 'modbus.encode'
local decode = require 'modbus.decode'
local ECM = require "modbus.ErrorCheckingMethods"
local _M = {}

local function create_header(unit)
	local data = encode.uint8(unit)
	return data
end

function _M.encode(pdu, port_config)
	if not pdu then
		return nil, 'no pdu object'
	end
	unit = port_config.unit or 1
	local adu = create_header(unit) .. pdu
	local checknum = ECM.check(adu, port_config.ecm)
	return true, adu .. checknum 
end

function _M.decode(raw)
	local unit = decode.uint8(raw:sub(1, 1))
	return unit, raw:sub(2, -3)
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


function _M.check(buf, t, port_config)
	if string.len(buf) < 4 then
		return nil
	end

	local adu = nil
	local unit = encode.uint8(port_config.unit)
	local func = tonumber(t.tags.request.func)
	while string.len(buf) > 4 do
		if func == 0x01 or func == 0x02 then
			local len = math.ceil(tonumber(t.tags.request.len) / 8)
			local data = unit .. encode.uint8(t.tags.request.func) .. encode.uint8(len)
			local b, e = buf:find(data)
			if e then
				if e + len + 2 > #buf then
					return nil
				end

				adu = buf:sub(b, e + len + 2)
				local checknum = ECM.check(adu:sub(1, -3), port_config.ecm)
				if checknum == adu:sub(-2, -1) then
					return adu
				end
			end
		elseif func == 0x03 or func == 0x04 then 
			local len = t.tags.request.len * 2
			local data = unit .. encode.uint8(t.tags.request.func) .. encode.uint8(len)
			local b, e = buf:find(data)
			if e then
				if e + len + 2 > #buf then
					return nil
				end

				adu = buf:sub(b, e + len + 2)
				local checknum = ECM.check(adu:sub(1, -3), port_config.ecm)
				if checknum == adu:sub(-2, -1) then
					return adu
				end
			end
		elseif func == 0x05 or func == 0x06 then
			local hv, lv = encode.uint16(t.tags.request.addr)
			local addr = hv .. lv
			local data = unit .. encode.uint8(t.tags.request.func) .. addr
			local b, e = buf:find(data)
			if e then
				if e + 4 > #buf then
					return nil
				end

				adu = buf:sub(b, e + 4)
				local checknum = ECM.check(adu:sub(1, -3), port_config.ecm)
				if checknum == adu:sub(-2, -1) then
					return adu
				end
			end
		elseif func == 0x0F or func == 0x10 then
			local hv, lv = encode.uint16(t.tags.request.addr)
			local addr = hv .. lv
			hv, lv = encode.uint16(t.tags.request.len)
			local len = hv .. lv
			local data = unit .. encode.uint8(t.tags.request.func) .. addr .. len
			local b, e = buf:find(data)
			if e then
				if e + 2 > #buf then
					return nil
				end

				adu = buf:sub(b, e + 2)
				local checknum = ECM.check(adu:sub(1, -3), port_config.ecm)
				if checknum == adu:sub(-2, -1) then
					return adu
				end
			end
		else
			return nil
		end
		buf = buf:sub(2)
	end
	return nil
end

return _M
