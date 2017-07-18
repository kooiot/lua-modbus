local pdu = require 'modbus.pdu'
local log = require 'shared.log'
local cmd = require "modbus.code"

local class = {}

local function packet_check(apdu, port_config)
	return function(msg, t, port_config)
		return apdu.check(msg, t, port_config)
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

--ecm, error checking methods
function class:request (t, port_config, ecm) 
	p = pdu[cmd[tonumber(t.tags.request.func)]](t)
	if not p then
		return nil
	end

	local _, apdu_raw = self.apdu.encode(p, port_config)

	--- write to pipe
	-- fiber.await(self.internal.write(apdu_raw))
	self.stream.send(apdu_raw)

	--local raw = fiber.await(self.internal.read())
	local raw = self.stream.read(t, packet_check(self.apdu, port_config), 1000)
	if not raw then
		return nil, 'Packet timeout'
	end

	local unit, pdu_raw = self.apdu.decode(raw)
	return pdu_raw, unit
end

return function (stream, apdu)
	return setmetatable({stream = stream, apdu = apdu, requests = {}, stop = false}, {__index=class})
end

