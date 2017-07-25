local pdu = require 'modbus.pdu'
local code = require "modbus.code"

local class = {}

local function packet_check(apdu, req)
	local req = req
	return function(msg)
		return apdu.check(msg, req)
	end
end

-- Request {
--ecm, error checking methods
--unit, unit address
--func, modbus function code
--addr, start address
--len, length
--
function class:request (req, timeout) 
	if type(req.func) == 'string' then
		req.func = code[req.func]
	end
	req.unit = req.unit or self._unit
	req.ecm = req.ecm or "crc"
	p = pdu[code[tonumber(req.func)]](req)
	if not p then
		return nil
	end

	local apdu_raw = assert(self._apdu.encode(p, req))

	--- write to pipe
	self._stream.send(apdu_raw)

	local raw, err = self._stream.read(packet_check(self._apdu, req), timeout)
	if not raw then
		return nil, err or "unknown"
	end

	local unit, pdu_raw = self._apdu.decode(raw)
	return pdu_raw, unit
end

return function (stream, apdu, unit)
	return setmetatable({_stream = stream, _apdu = apdu, _unit=unit}, {__index=class})
end

