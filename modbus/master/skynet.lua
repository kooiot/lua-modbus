local skynet = require 'skynet'
local class = require 'middleclass'
local code = require "modbus.code"
local pdu = require 'modbus.encode.pdu'

local client = class("Modbus_Skynet_Master")

local function packet_check(apdu, req)
	local req = req
	return function(msg)
		return apdu.check(msg, req)
	end
end

local function compose_message(apdu, req, unit)
	if type(req.func) == 'string' then
		req.func = code[req.func]
	end
	req.unit = req.unit or unit

	p = pdu[code[tonumber(req.func)]](req)
	if not p then
		return nil
	end

	local apdu_raw = assert(apdu.encode(p, req))
	return apdu_raw
end

local function make_read_response(apdu, req, timeout, cb)
	return function(sock)
		local start = skynet.now()
		local pdu = nil
		local buf = ""
		local need_len = apdu.min_packet_len
		local check = packet_check(apdu, req)

		while true do
			local t = (timeout // 10) - (skynet.now() - start)
			if t <= 0 then
				break
			end

			local str, err = sock:read(need_len, t)
			if not str then
				return false, err
			end
			if cb then
				cb("IN", str)
			end

			buf = buf..str
			adu, buf, need_len = check(buf)
			if adu then
				local unit, pdu = apdu.decode(adu)
				if unit == req.unit then
					return true, pdu
				else
					return false, "Unit error"
				end
			end
		end
		return false, "timeout"
	end
end

function client:initialize(sc, opt, apdu, unit)
	local channel = sc.channel(opt)
	self._chn = channel
	self._unit = unit or 1
	self._apdu = apdu
end

function client:connect(only_once)
	return self._chn:connect(only_once)
end

function client:set_io_cb(cb)
	self._data_cb = cb
end

function client:request(req, timeout)
	local cb = self._data_cb
	local msg = compose_message(self._apdu, req, self._unit)
	if cb then
		cb("OUT", msg)
	end
	return self._chn:request(msg, make_read_response(self._apdu, req, timeout, cb))
end

function client:close()
	if self._chn then
		self._chn:close()
		self._chn = nil
	end
end

return client
