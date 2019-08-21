local class = require 'middleclass'
local code = require 'modbus.code'
local request = require 'modbus.pdu.request'
local response = require 'modbus.pdu.response'
local data_pack = require 'modbus.data.pack'
local data_unpack = require 'modbus.data.unpack'

local pdu = class("Modbus_Pdu_Class")

function pdu:initialize(little_endian)
	self._le = little_endian
	self._req = request:new(self._le)
	self._resp = response:new(self._le)
	self._data_pack = data_pack:new(self._le)
	self._data_unpack = data_unpack:new(self._le)
end

function pdu:make_req_0x01(fc, addr, len)
	assert(len < 2000 and len > 0, "Invalid quantity(length)")
	return self._req:pack(fc, addr, len)
end

function pdu:make_req_0x02(fc, addr, len)
	assert(len < 2000 and len > 0, "Invalid quantity(length)")
	return self._req:pack(fc, addr, len)
end

function pdu:make_req_0x03(fc, addr, len)
	assert(len < 125 and len > 0, "Invalid quantity(length)")
	return self._req:pack(fc, addr, len)
end

function pdu:make_req_0x04(fc, addr, len)
	assert(len < 125 and len > 0, "Invalid quantity(length)")
	return self._req:pack(fc, addr, len)
end

function pdu:make_req_0x05(fc, addr, value)
	local val = (value == true or tonumber(value) == 1) and 0xFF00 or 0x0000
	return self._req:pack(fc, addr, val)
end

function pdu:make_req_0x06(fc, addr, value)
	return self._req:pack(fc, addr, value)
end

function pdu:make_req_0x0F(fc, addr, ...)
	local values = {...}
	local len = #values
	local data = self._data_pack:bit(values)

	return self._req:pack(fc, addr, len, data)
end

function pdu:make_req_0x10(fc, addr, ...)
	local values = {...}
	local len = #values
	assert(len > 0, "Values missing")

	local data = {}
	for _, v in ipairs(values) do
		if type(v) == 'number' then
			table.insert(data, self._data_pack:uint16(v))
		else
			table.insert(data, tostring(v))
		end
	end

	return self._req:pack(fc, addr, len, table.concat(data))
end

function pdu:make_request(fc, ...)
	assert(fc, "Function Code is required!!")

	local fc = tonumber(fc) or code[fc]

	local func = self['make_req_0x'..string.format("%02X", fc)]
	if func then
		return func(self, fc, ...)
	else
		return nil, "Function code not supported!!"
	end
end

function pdu:make_resp_error(fc, errno)
	return string.pack('I1I1', 0x80 + fc, errno)
end

function pdu:make_resp_0x01(fc, ...)
	local data = self._data_pack:bit(...)

	return self._resp:pack(fc, table.concat(data))
end

function pdu:make_resp_0x02(fc, ...)
	local data = self._data_pack:bit(...)

	return self._resp:pack(fc, table.concat(data))
end

function pdu:make_resp_0x03(fc, ...)
	local values = {...}
	local len = #values
	assert(len > 0, "Values missing")

	local data = {}
	for _, v in ipairs(values) do
		if type(v) == 'number' then
			table.insert(data, self._data_pack:uint16(v))
		else
			table.insert(data, tostring(v))
		end
	end

	return self._resp:pack(fc, addr, table.concat(data))
end

function pdu:make_resp_0x04(fc, ...)
	local values = {...}
	local len = #values
	assert(len > 0, "Values missing")

	local data = {}
	for _, v in ipairs(values) do
		if type(v) == 'number' then
			table.insert(data, self._data_pack:uint16(v))
		else
			table.insert(data, tostring(v))
		end
	end

	return self._resp:pack(fc, addr, table.concat(data))
end

function pdu:make_resp_0x05(fc, addr, value)
	return self._resp:pack(fc, addr, value)
end

function pdu:make_resp_0x06(fc, addr, value)
	return self._resp:pack(fc, addr, value)
end

function pdu:make_resp_0x0F(fc, addr, len)
	return self._resp:pack(fc, addr, len)
end

function pdu:make_resp_0x10(fc, addr, len)
	return self._resp:pack(fc, addr, len)
end

function pdu:make_response(fc, ...)
	assert(fc, "Function Code is required!!")

	local fc = tonumber(fc) or code[fc]
	local err_flag = fc & 0xF0 == 0x80
	fc = fc & 0x0F

	if err_flag then
		return self:make_resp_error(fc, ...)
	end

	local func = self['make_resp_0x'..string.format("02X", fc)]
	if func then
		return func(fc, ...)
	else
		return nil, "Function code not supported!!"
	end
end

return pdu
