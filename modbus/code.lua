local Cmd = {}

local make_code = function(name, code)
	Cmd[name] = code
	Cmd[code] = name
end

--Read Only
make_code("ReadCoilStatus", 0x01)
make_code("ReadInputStatus", 0x02)
make_code("ReadHoldingRegisters", 0x03)
make_code("ReadInputRegisters", 0x04)

--Write Only
make_code("ForceSingleCoil", 0x05)
make_code("PresetSingleRegister", 0x06)
make_code("ForceMultipleCoils", 0x0F)
make_code("PresetMultipleRegs", 0x10)

return Cmd

