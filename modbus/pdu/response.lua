local class = require 'middleclass'

local response = class('Modbus_Pdu_Response_Class')

function response:initialize(little_endian)
	self._le = little_endian
end

local function pack_len_data(le, fc, data)
	local data = tostring(data)
	local fmt = le and '<I1s1' or '>I1s1'
	return string.pack(fmt, data)
end

local function unpack_len_data(le, pdu)
	local fmt = le and '<I1s1' or '>I1s1'
	-- Return fc, data
	return string.unpack(fmt, pdu)
end

local function packsize_len_data(raw)
	if not raw then
		return 3
	else
		local fc, len = string.unpack('>I1I1')
		return len + 2
	end
end

local function pack_addr_data(le, fc, addr, data)
	local data = tostring(data)

	local fmt = le and '<I1I2I2' or '>I1I2I2'
	return string.pack(fmt, fc, addr, data)
end

local function unpack_addr_data(le, pdu)
	local fmt = le and '<I1I2I2' or '>I1I2I2'
	local fmt_len = string.packsize(fmt)
	assert(string.len(pdu) >= fmt_len, "PDU length invalid!")

	-- Return fc, addr, data
	return string.unpack(fmt, pdu)
end

local function packsize_addr_data()
	return string.packsize('>I1I2I2')
end

local function pack_addr_len(le, fc, addr, len)
	local fmt = le and '<I1I2I2' or '>I1I2I2'
	return string.pack(fmt, fc, addr, len)
end

local function unpack_addr_len(le, pdu)
	local fmt = le and '<I1I2I2' or '>I1I2I2'

	-- Return fc, addr, len
	return string.unpack(fmt, pdu)
end

local function packsize_addr_len()
	return string.packsize('>I1I2I2')
end

local UNPACK_MAP = {}

UNPACK_MAP[0x01] = unpack_len_data
UNPACK_MAP[0x02] = unpack_len_data
UNPACK_MAP[0x03] = unpack_len_data
UNPACK_MAP[0x04] = unpack_len_data

UNPACK_MAP[0x05] = unpack_addr_data
UNPACK_MAP[0x06] = unpack_addr_data

UNPACK_MAP[0x0F] = unpack_addr_len
UNPACK_MAP[0x10] = unpack_addr_len

function response:unpack(pdu)
	local fc = string.unpack('>I1', pdu)
	local func = UNPACK_MAP[fc]
	if not func then
		return nil, "Function code not supported"
	end

	--- return fc, data
	--- return fc, addr, data
	--- return fc, addr, len
	return func(self._le, pdu)
end

local PACK_MAP = {}

PACK_MAP[0x01] = pack_len_data
PACK_MAP[0x02] = pack_len_data
PACK_MAP[0x03] = pack_len_data
PACK_MAP[0x04] = pack_len_data

PACK_MAP[0x05] = pack_addr_data
PACK_MAP[0x06] = pack_addr_data

PACK_MAP[0x0F] = pack_addr_len
PACK_MAP[0x10] = pack_addr_len

function response:pack(fc, ...)
	local func = PACK_MAP[fc]
	assert(func, "Request code "..fc.." not supported")
	return func(self._le, fc, ...)
end

local PACKSIZE_MAP = {}
PACKSIZE_MAP[0x01] = packsize_len_data
PACKSIZE_MAP[0x02] = packsize_len_data
PACKSIZE_MAP[0x03] = packsize_len_data
PACKSIZE_MAP[0x04] = packsize_len_data


PACKSIZE_MAP[0x05] = packsize_addr_data
PACKSIZE_MAP[0x06] = packsize_addr_data

PACKSIZE_MAP[0x0F] = packsize_addr_len
PACKSIZE_MAP[0x10] = packsize_addr_len

function response:packsize(fc, raw)
	local func = PACKSIZE_MAP[fc]
	assert(func, "Request code "..fc.." not supported")
	return func(self._le, fc, raw)
end

return response
