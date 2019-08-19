local class = require 'middleclass'
local ecm = require "modbus.ecm"

local apdu = class('Modbus_Apdu_RTU_Class')

function apdu:initialize(mode, little_endian, ecm)
	self._mode = mode ~= 'slave' or 'master'
	self._le = little_endian
	self._ecm = ecm or 'CRC'
	self._header_fmt = self._le and '<I1' or '>I1'
	self._header_size = string.packsize(self._header_fmt)

	if self._mode == 'master' then
		self.process = self.process_master
	else
		self.process = self.process_slave
	end
end

function apdu:pack(unit, pdu)
	assert(pdu, "PDU object required!")
	assert(unit, "Device unit id required!")

	local data = string.pack(self._header_fmt, unit) .. pdu
	local checknum = ecm.calc(data, self._ecm, self._le)
	return data .. checknum, unit 
end

function apdu:unpack(data)
	local unit = string.unpack(self._header_fmt, data)
	local pdu = string.sub(data, self._header_size + 1, -3) -- skip 
	local checknum = ecm.check(string.sub(data, 1, -3), self._ecm, self._le)
	if checknum ~= string.sub(data, -2) then
		return nil, "ECM Error!"
	end

	return unit, pdu, unit
end

function apdu:process_master(buf, callback)
	local min_size = 5 -- Error Response

	if string.len(buf) < min_size then
		return buf, min_size - string.len(buf)
	end

	local need_len = nil
	while string.len(buf) >= min_size do
		local fmt = self._le and '<I1I1' and '>I1I1'

		local recv_unit, recv_fc = string.unpack(fmt, buf)
		local err_flag = (recv_fc & 0xF0) == 0x80
		local func = recv_fc & 0x0F

		if err_flag then
			--- Error takes only five bytes
			local unit, pdu = self:unpack(string.sub(buf, 1, 5))
			if unit ~= nil then
				buf = string.sub(buf, 6)
				callback(unit, pdu, unit)
			else
				buf = string.sub(buf, 2)
			end
		else
			if func == 0x01 or func == 0x02 then
				local len = string.unpack('I1', buf, 3)
				if len < math.ceil(2000 / 8) then
					local adu_len = 3 + len + 2 
					if adu_len > string.len(buf) then
						need_len = adu_len - string.len(buf)
						break
					end

					local unit, pdu = self:unpack(string.sub(buf, 1, adu_len))
					if unit ~= nil then
						buf = string.sub(buf, adu_len + 1)
						callback(unit, pdu, unit)
					else
						buf = string.sub(buf, 2)
					end
				else
					buf = string.sub(buf, 2)
				end
			elseif func == 0x03 or func == 0x04 then 
				local len = string.unpack('I1', buf, 3)
				if len % 2 == 0 then
					local adu_len = 3 + len + 2 
					if adu_len > string.len(buf) then
						need_len = adu_len - string.len(buf)
						break
					end

					local unit, pdu = self:unpack(string.sub(buf, 1, adu_len))
					if unit ~= nil then
						buf = string.sub(buf, adu_len + 1)
						callback(unit, pdu, unit)
					else
						buf = string.sub(buf, 2)
					end
				else
					buf = string.sub(buf, 2)
				end
			elseif func == 0x05 or func == 0x06 then
				local adu_len = 2 + 4 + 2 
				if adu_len > string.len(buf) then
					need_len = adu_len - string.len(buf)
					break
				end

				local unit, pdu = self:unpack(string.sub(buf, 1, adu_len))
				if unit ~= nil then
					buf = string.sub(buf, adu_len + 1)
					callback(unit, pdu, unit)
				else
					buf = string.sub(buf, 2)
				end
			elseif func == 0x0F or func == 0x10 then
				local adu_len = 2 + 4 + 2 
				if adu_len > string.len(buf) then
					need_len = adu_len - string.len(buf)
					break
				end

				local unit, pdu = self:unpack(string.sub(buf, 1, adu_len))
				if unit ~= nil then
					buf = string.sub(buf, adu_len + 1)
					callback(unit, pdu, unit)
				else
					buf = string.sub(buf, 2)
				end
			else
				buf = string.sub(buf, 2)
			end
		end
	end
	return buf, need_len or (min_size - string.len(buf))
end

function apdu:process_slave(buf, callback)
	local min_size = 8

	if string.len(buf) < min_size then
		return buf, min_size - string.len(buf)
	end

	local adu = nil
	while string.len(buf) >= min_size do
		local fmt = self._le and '<I1I1' and '>I1I1'
		local recv_unit, fc = string.unpack(fmt, buf)

		local need_len = nil
		if fc == 0x01 or fc == 0x02 or fc == 0x03 or fc == 0x04 or fc == 0x05 or fc == 0x06 then
			local adu_len = 2 + 4 + 2 
			if adu_len > string.len(buf) then
				need_len = adu_len - string.len(buf)
				break
			end

			local unit, pdu = self:unpack(string.sub(buf, 1, adu_len))
			if unit ~= nil then
				buf = string.sub(buf, adu_len + 1)
				callback(unit, pdu, unit)
			else
				buf = string.sub(buf, 2)
			end
		elseif fc == 0x0F or fc == 0x10 then
			if string.len(buf) < 8 then
				need_len = 8 - string.len(buf)
				break
			end

			local fmt = self._le and '<I2I1' or '<I2I1'
			local len, count = string.unpack(fmt, buf, 5)
			local cc = fc == 0x0F and math.ceil(len / 8) or len * 2
			if count == cc then
				local adu_len = 2 + 4 + 1 + count + 2
				if adu_len > string.len(buf) then
					need_len = adu_len - string.len(buf)
					break
				end

				local unit, pdu = self:unpack(string.sub(buf, 1, aud_len))
				if unit ~= nil then
					buf = string.sub(buf, adu_len + 1)
					callback(unit, pdu, unit)
				else
					buf = string.sub(buf, 2)
				end
			else
				buf = string.sub(buf, 2)
			end
		else
			buf = string.sub(buf, 2)
		end
	end
	return buf, need_len or (min_size - string.len(buf))
end

return apdu
