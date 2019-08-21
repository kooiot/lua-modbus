local _M = {}

local CRC = function(adu)
	local crc;

	local function initCrc()
		crc = 0xffff;
	end
	local function updCrc(byte)
		if _VERSION == 'Lua 5.3' then
			crc = crc ~ byte
			for i = 1, 8 do
				local j = crc & 1
				crc = crc >> 1
				if j ~= 0 then
					crc = crc ~ 0xA001
				end
			end
		else
			local bit32 = require 'bit'
			crc = bit32.bxor(crc, byte);
			for i = 1, 8 do
				local j = bit32.band(crc, 1);
				crc = bit32.rshift(crc, 1);
				if j ~= 0 then
					crc = bit32.bxor(crc, 0xA001);
				end
			end
		end
	end

	local function getCrc(adu)
		initCrc();
		for i = 1, #adu  do
			updCrc(adu:byte(i));
		end
		return crc;
	end
	return getCrc(adu);
end

local LRC = function(adu)
	local uchLRC = 0
	local len = string.len(adu)
	for i = 1, len do
		uchLRC = uchLRC + string.byte(adu, i)
	end
	--uchLRC =  ( - uchLRC ) % 0x100
	uchLRC = uchLRC % 256
	uchLRC =  (( ~ uchLRC )  + 1 ) % 256

	return uchLRC
end

_M.calc = function(adu, checkmode, switch) 
	local checkmode = string.lower(checkmode) or "crc"

	local checknum = 0
	if checkmode == "crc" then
		-- CRC is little endian by default(in standard)
		local fmt = switch and '>I2' or '<I2'
		checknum = CRC(adu)
		return string.pack(fmt, checknum), checknum
	elseif checkmode == "lrc" then
		checknum = LRC(adu)
		return string.pack('I1', checknum), checknum
	end
	assert(false, "checkmode "..(checkmode or 'nil').." not supported")
end

return _M
