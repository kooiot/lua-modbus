local class = require 'middleclass'

local request = class('Modbus_Pdu_Request_Class')

function request:initialize(little_endian)
	self._le = little_endian
end

local function pack_addr_len(le, fc, addr, len)
	assert(fc ~= nil, "Function code cannot be empty!")
	assert(addr ~= nil, "Register address cannot be empty!")
	assert(len ~= nil, "Register length cannot be empty!")

	local fmt = le and '<I1I2I2' or '>I1I2I2'
	return string.pack(fmt, fc, addr, len)
end

local function unpack_addr_len(le, pdu)
	local fmt = le and '<I1I2I2' or '>I1I2I2'
	local fmt_len = string.packsize(fmt)
	assert(string.len(pdu) == fmt_len, "PDU length invalid!")

	--- Return fc, addr, len
	return string.unpack(fmt, pdu)
end

local function packsize_addr_len(le, raw)
	return string.packsize('>I1I2I2')
end

local function pack_addr_data(le, fc, addr, data)
	assert(fc ~= nil, "Function code cannot be empty!")
	assert(addr ~= nil, "Register address cannot be empty!")
	assert(data ~= nil, "Data cannot be empty!")

	local fmt = le and '<I1I2I2' or '>I1I2I2'
	return string.pack(fmt, fc, addr, data)
end

local function unpack_addr_data(le, pdu)
	local fmt = le and '<I1I2I2' or '>I1I2I2'
	local fmt_len = string.packsize(fmt)
	assert(string.len(pdu) >= fmt_len, "PDU length invalid!")

	--- Return fc, addr, data
	return string.unpack(fmt, pdu)
end

local function packsize_addr_data(le, raw)
	return string.packsize('>I1I2I2')
end

local function pack_addr_len_data(le, fc, addr, len, data)
	assert(fc ~= nil, "Function code cannot be empty!")
	assert(addr ~= nil, "Register address cannot be empty!")
	assert(len ~= nil, "Register length cannot be empty!")
	assert(data ~= nil, "Data cannot be empty!")

	local count = fc == 0x0F and math.ceil(len / 8) or len * 2
	local fmt = le and '<I1I2I2I1' or '>I1I2I2I1'
	return string.pack(fmt, fc, addr, len, count)..data
end

local function unpack_addr_len_data(le, pdu)
	local fmt = le and '<I1I2I2I1' or '>I1I2I2I1'
	local fmt_len = string.packsize(fmt)
	assert(string.len(pdu) > fmt_len)

	local fc, addr, len, count = string.unpack(fmt, pdu)
	local cc = fc == 0x0F and math.ceil(len / 8) or len * 2
	assert(cc == count)
	local data = string.sub(pdu, fmt_len + 1)
	assert(count == string.len(data), "Byte Count not match real data length")

	--- return fc, addr, len, data
	return fc, addr, len, data
end

local function packsize_addr_len_data(le, raw)
	return string.packsize('>I1I2I2I1')
end

local UNPACK_MAP = {}

UNPACK_MAP[0x01] = unpack_addr_len
UNPACK_MAP[0x02] = unpack_addr_len
UNPACK_MAP[0x03] = unpack_addr_len
UNPACK_MAP[0x04] = unpack_addr_len

UNPACK_MAP[0x05] = unpack_addr_data
UNPACK_MAP[0x06] = unpack_addr_data

UNPACK_MAP[0x0F] = unpack_addr_len_data
UNPACK_MAP[0x10] = unpack_addr_len_data

function request:unpack(pdu)
	local fc = string.unpack('>I1', pdu)
	local func = UNPACK_MAP[fc]
	if not func then
		return nil, "Function code not supported"
	end

	return func(self._le, pdu)
end

local PACK_MAP = {}

PACK_MAP[0x01] = pack_addr_len
PACK_MAP[0x02] = pack_addr_len
PACK_MAP[0x03] = pack_addr_len
PACK_MAP[0x04] = pack_addr_len

PACK_MAP[0x05] = pack_addr_data
PACK_MAP[0x06] = pack_addr_data

PACK_MAP[0x0F] = pack_addr_len_data
PACK_MAP[0x10] = pack_addr_len_data

function request:pack(fc, ...)
	local func = PACK_MAP[fc]
	assert(func, "Request code "..fc.." not supported")
	return func(self._le, fc, ...)
end

local PACKSIZE_MAP = {}
PACKSIZE_MAP[0x01] = packsize_addr_len
PACKSIZE_MAP[0x02] = packsize_addr_len
PACKSIZE_MAP[0x03] = packsize_addr_len
PACKSIZE_MAP[0x04] = packsize_addr_len


PACKSIZE_MAP[0x05] = packsize_addr_data
PACKSIZE_MAP[0x06] = packsize_addr_data

PACKSIZE_MAP[0x0F] = packsize_addr_len_data
PACKSIZE_MAP[0x10] = packsize_addr_len_data

function request:packsize(fc, raw)
	local func = PACKSIZE_MAP[fc]
	assert(func, "Request code "..fc.." not supported")
	return func(self._le, fc, raw)
end

return request
