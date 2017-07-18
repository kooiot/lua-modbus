local pdu = require 'modbus.pdu'
local log = require 'shared.log'
local cmd = require "modbus.code"

local class = {}

local function packet_check(apdu, req)
	local req = req
	return function(msg)
		return apdu.check(msg, req)
	end
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

-- Request {
--ecm, error checking methods
--unit, unit address
--func, modbus function code
--addr, start address
--len, length
--
function class:request (req) 
	local func = req.func
	if type(req.func) == 'string' then
		req.func = cmd[func]
	end
	p = pdu[cmd[tonumber(req.func)]](req)
	if not p then
		return nil
	end

	local _, apdu_raw = self._apdu.encode(p, req)

	--- write to pipe
	-- fiber.await(self.internal.write(apdu_raw))
	self._stream.send(apdu_raw)

	--local raw = fiber.await(self.internal.read())
	local raw = self._stream.read(req, packet_check(self._apdu, req), 1000)
	if not raw then
		return nil, 'Packet timeout'
	end

	local unit, pdu_raw = self._apdu.decode(raw)
	return pdu_raw, unit
end

return function (stream, apdu)
	return setmetatable({_stream = stream, _apdu = apdu}, {__index=class})
end

