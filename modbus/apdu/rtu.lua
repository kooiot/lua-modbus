local class = require 'middleclass'
local ecm = require "modbus.ecm"
local buffer = require 'modbus.buffer'

local apdu = class('Modbus_Apdu_RTU_Class')

function apdu:initialize(mode, little_endian, ecm)
	self._mode = mode ~= 'slave' and 'master' or 'slave'
	self._le = little_endian
	self._ecm = ecm or 'CRC'
	self._header_fmt = self._le and '<I1' or '>I1'
	self._header_size = string.packsize(self._header_fmt)
	self._buf = buffer:new(396)

	if self._mode == 'master' then
		self.process = self.master_process
	else
		self.process = self.slave_process
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
	local checknum = ecm.calc(string.sub(data, 1, -3), self._ecm, self._le)
	if checknum ~= string.sub(data, -2) then
		--skynet.error("ECM Checking failed!")
		return nil, "ECM Error!"
	end

	return unit, pdu, unit
end

function apdu:append(data)
	self._buf:append(data)
end

function apdu:current_unit()
	return string.unpack(self._header_fmt, tostring(self._buf))
end

function apdu:master_process(callback)
	local min_size = 5 -- Error Response
	local buf = self._buf

	if buf:len() < min_size then
		return min_size - buf:len()
	end

	local need_len = nil
	while buf:len() >= min_size do
		local fmt = self._le and '<I1I1' or '>I1I1'

		local recv_unit, recv_fc = string.unpack(fmt, tostring(buf))
		--print(os.date(), 'AAAA:', recv_unit, recv_fc)
		local err_flag = (recv_fc & 0x80) == 0x80
		local func = recv_fc & 0x7F

		if err_flag then
			--- Error takes only five bytes
			local unit, pdu = self:unpack(buf:sub(1, 5))
			if unit ~= nil then
				buf:pop(5)
				callback(unit, unit, pdu)
			else
				buf:pop(1)
				callback(recv_unit, nil, pdu)
			end
		else
			if func == 0x01 or func == 0x02 then
				local len = string.unpack('I1', buf:sub(3))
				if len < math.ceil(2000 / 8) then
					local adu_len = 3 + len + 2 
					if adu_len > buf:len() then
						need_len = adu_len - buf:len()
						break
					end

					local unit, pdu = self:unpack(buf:sub(1, adu_len))
					if unit ~= nil then
						buf:pop(adu_len)
						callback(unit, unit, pdu)
					else
						buf:pop(1)
						callback(recv_unit, nil, pdu)
					end
				else
					buf:pop(1)
				end
			elseif func == 0x03 or func == 0x04 then 
				local len = string.unpack('I1', buf:sub(3))
				--print(os.date(), 'LEN', len)
				if len % 2 == 0 then
					local adu_len = 3 + len + 2 
					if adu_len > buf:len() then
						need_len = adu_len - buf:len()
						--print(os.date(), 'NEED_LEN', need_len)
						break
					end

					--print(os.date(), 'ADU_LEN', adu_len)
					local unit, pdu = self:unpack(buf:sub(1, adu_len))
					if unit ~= nil then
						buf:pop(adu_len)
						callback(unit, unit, pdu)
					else
						buf:pop(1)
						callback(recv_unit, nil, pdu)
					end
				else
					buf:pop(1)
				end
			elseif func == 0x05 or func == 0x06 then
				local adu_len = 2 + 4 + 2 
				if adu_len > buf:len() then
					need_len = adu_len - buf:len()
					break
				end

				local unit, pdu = self:unpack(buf:sub(1, adu_len))
				if unit ~= nil then
					buf:pop(adu_len)
					callback(unit, unit, pdu)
				else
					buf:pop(1)
					callback(recv_unit, nil, pdu)
				end
			elseif func == 0x0F or func == 0x10 then
				local adu_len = 2 + 4 + 2 
				if adu_len > buf:len() then
					need_len = adu_len - buf:len()
					break
				end

				local unit, pdu = self:unpack(buf:sub(1, adu_len))
				if unit ~= nil then
					buf:pop(adu_len)
					callback(unit, unit, pdu)
				else
					buf:pop(1)
					callback(recv_unit, nil, pdu)
				end
			else
				buf:pop(1)
			end
		end
	end
	return need_len or (min_size - buf:len())
end

function apdu:slave_process(callback)
	local min_size = 8
	local buf = self._buf

	if buf:len() < min_size then
		return min_size - buf:len()
	end

	local adu = nil
	while buf:len() >= min_size do
		local fmt = self._le and '<I1I1' or '>I1I1'
		local recv_unit, fc = string.unpack(fmt, tostring(buf))

		local need_len = nil
		if fc == 0x01 or fc == 0x02 or fc == 0x03 or fc == 0x04 or fc == 0x05 or fc == 0x06 then
			local adu_len = 2 + 4 + 2 
			if adu_len > buf:len() then
				need_len = adu_len - buf:len()
				break
			end

			local unit, pdu = self:unpack(buf:sub(1, adu_len))
			if unit ~= nil then
				buf:pop(adu_len)
				callback(unit, unit, pdu)
			else
				buf:pop(1)
				callback(recv_unit, nil, pdu)
			end
		elseif fc == 0x0F or fc == 0x10 then
			if buf:len() < 8 then
				need_len = 8 - buf:len()
				break
			end

			local fmt = self._le and '<I2I1' or '<I2I1'
			local len, count = string.unpack(fmt, buf:sub(5))
			local cc = fc == 0x0F and math.ceil(len / 8) or len * 2
			if count == cc then
				local adu_len = 2 + 4 + 1 + count + 2
				if adu_len > buf:len() then
					need_len = adu_len - buf:len()
					break
				end

				local unit, pdu = self:unpack(buf:sub(1, aud_len))
				if unit ~= nil then
					buf:pop(adu_len)
					callback(unit, unit, pdu)
				else
					buf:pop(2)
					callback(recv_unit, nil, pdu)
				end
			else
				buf:pop(2)
			end
		else
			buf:pop(2)
		end
	end
	return need_len or (min_size - buf:len())
end

return apdu
