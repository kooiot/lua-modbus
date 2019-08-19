
local _M = {}

_M.ILLEGAL_FUNCION		= 0x01
_M.ILLEGAL_DATA_ADDR	= 0x02
_M.ILLEGAL_DATA_VAL		= 0x03
_M.SRV_DEV_FAIL			= 0x04
_M.ACKNOWLEDGE			= 0x05
_M.SRV_DEV_BUSY			= 0x06
_M.MEM_PARITY_ERR		= 0x07
_M.GW_PATH_UNAVAIL		= 0x0A
_M.GW_TARGET_DEV_FAIL_TO_RESP = 0x0B

_M.to_string = function(ec)
	for k, v in pairs(_M) do
		if v == tostring(ec) then
			return k
		end
	end
	return nil, "UNKNOWN"
end
