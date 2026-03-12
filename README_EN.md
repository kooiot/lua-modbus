# lua-modbus

A complete Modbus protocol implementation in Lua, supporting RTU, TCP and ASCII transmission modes.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lua](https://img.shields.io/badge/Lua-5.1%2B-blue.svg)](https://www.lua.org/)
[![LDoc](https://img.shields.io/badge/docs-lDoc-green.svg)](docs/)

[中文文档](README.md) | English

## Features

- **Support for Modbus TCP, RTU and ASCII protocols**
- **Support for Master and Slave modes**
- **Support for standard Modbus function codes (0x01-0x10)**
  - `0x01` - Read Coils
  - `0x02` - Read Discrete Inputs
  - `0x03` - Read Holding Registers
  - `0x04` - Read Input Registers
  - `0x05` - Write Single Coil
  - `0x06` - Write Single Register
  - `0x0F` - Write Multiple Coils
  - `0x10` - Write Multiple Registers
- **Skynet framework integration**
- **Support for both big-endian and little-endian byte orders**
- **Complete data packing and unpacking functionality**

## Project Structure

```
lua-modbus/
├── modbus/
│   ├── pdu/           # Protocol Data Unit (PDU) handling
│   │   ├── init.lua   # Main PDU interface
│   │   ├── request.lua
│   │   └── response.lua
│   ├── data/          # Data packing/unpacking
│   │   ├── pack.lua   # Data packing
│   │   └── unpack.lua # Data unpacking
│   ├── apdu/          # Application Protocol Data Unit
│   │   ├── tcp.lua    # Modbus TCP protocol
│   │   ├── rtu.lua    # Modbus RTU protocol
│   │   └── ascii.lua  # Modbus ASCII protocol
│   ├── master/        # Master implementation
│   │   ├── stream.lua # Generic stream interface
│   │   └── skynet.lua # Skynet framework integration
│   ├── slave/         # Slave implementation
│   │   ├── stream.lua # Generic stream interface
│   │   └── skynet.lua # Skynet framework integration
│   ├── buffer.lua     # Stream buffer
│   ├── code.lua       # Function code mapping
│   ├── exceptions.lua # Exception codes
│   └── ecm.lua        # Error check mechanism
├── docs/              # API documentation
├── config.ld          # lDoc configuration file
└── README.md
```

## Installation

### Using LuaRocks

```bash
luarocks install lua-modbus
```

### Manual Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/lua-modbus.git
cd lua-modbus
```

2. Copy the `modbus` directory to your Lua path:
```bash
cp -r modbus /usr/local/share/lua/5.3/
```

Or add the project path to `LUA_PATH`:
```bash
export LUA_PATH="/path/to/lua-modbus/?.lua;;"
```

## Quick Start

### Master Mode

#### Generic Stream Interface

```lua
local master = require 'modbus.master.stream'
local pdu = require 'modbus.pdu'

-- Create stream object
local stream = {
  -- Send data
  send = function(data)
    -- Implement TCP or serial sending
  end,
  -- Receive data
  recv = function(len, timeout)
    -- Implement TCP or serial receiving, return received data
  end
}

-- Create master (TCP mode)
local m = master:new('tcp', stream)

-- Create PDU object
local p = pdu:new()

-- Create read holding registers request (function code 0x03)
-- Read 10 registers starting from address 0
local req = p:make_request(0x03, 0, 10)

-- Send request to slave with unit ID 1
m:request(1, req, function(unit, pdu, key)
  if not pdu then
    print("Request failed:", key)
  else
    print("Received response, slave:", unit, "PDU length:", #pdu)
    -- Parse response data...
  end
end, 5)  -- 5 seconds timeout

-- Main processing loop
while running do
  m:run_once(1000)  -- 1 second timeout
end
```

#### Skynet Framework Integration

```lua
local skynet = require 'skynet'
local master = require 'modbus.master.skynet'
local pdu = require 'modbus.pdu'

skynet.start(function()
  -- Create master
  local m = master:new('tcp', {
    link = 'tcp',
    tcp = {
      host = '127.0.0.1',
      port = 502,
      nodelay = true
    }
  })

  -- Start master
  m:start()

  -- Create PDU object
  local p = pdu:new()

  -- Send request
  local req = p:make_request(0x03, 0, 10)
  local resp, err = m:request(1, req, 5000)  -- 5 seconds timeout

  if err then
    print("Request failed:", err)
  else
    print("Received response:", #resp)
  end
end)
```

### Slave Mode

#### Generic Stream Interface

```lua
local slave = require 'modbus.slave.stream'
local pdu = require 'modbus.pdu'

-- Create stream object
local stream = {
  send = function(data)
    -- Send data
  end,
  recv = function(len, timeout)
    -- Receive data
  end
}

-- Create slave (RTU mode)
local s = slave:new('rtu', stream)

-- Create PDU object
local p = pdu:new()

-- Add device with unit ID 1
s:add_unit(1, function(pdu, response_handler)
  -- Parse request PDU
  local fc = string.byte(pdu, 1)  -- Function code
  local addr = string.unpack('>I2', pdu, 2)  -- Starting address
  local len = string.unpack('>I2', pdu, 4)   -- Quantity

  print(string.format("Received request: FC=0x%02X, ADDR=%d, LEN=%d", fc, addr, len))

  if fc == 0x03 then
    -- Read holding registers
    -- Return mock data here
    local values = {1000, 2000, 3000, 4000, 5000}
    local resp = p:make_response(0x03, addr, table.unpack(values))
    response_handler(resp)
  else
    -- Other function codes...
  end
end)

-- Main processing loop
while running do
  s:run_once(1000)
end
```

#### Skynet Framework Integration

```lua
local skynet = require 'skynet'
local slave = require 'modbus.slave.skynet'
local pdu = require 'modbus.pdu'

skynet.start(function()
  -- Create slave
  local s = slave:new('rtu', {
    link = 'serial',
    serial = {
      port = '/dev/ttyUSB0',
      baudrate = 9600,
      data_bits = 8,
      parity = 'NONE',
      stop_bits = 1,
      flow_control = 'OFF'
    }
  })

  -- Create PDU object
  local p = pdu:new()

  -- Add unit
  s:add_unit(1, function(pdu, response_handler)
    local fc = string.byte(pdu, 1)
    local addr = string.unpack('>I2', pdu, 2)
    local len = string.unpack('>I2', pdu, 4)

    if fc == 0x03 then
      -- Read holding registers
      local values = {1000, 2000, 3000}
      local resp = p:make_response(0x03, addr, table.unpack(values))
      response_handler(resp)
    elseif fc == 0x06 then
      -- Write single register
      local value = string.unpack('>I2', pdu, 4)
      print(string.format("Write register %d = %d", addr, value))
      local resp = p:make_response(0x06, addr, value)
      response_handler(resp)
    end
  end)

  -- Start slave
  s:start()
end)
```

## API Documentation

For complete API documentation, see: [docs/index.html](docs/index.html)

### Core Modules

- **[modbus.pdu](docs/modules/modbus.pdu.html)** - Protocol Data Unit (PDU) handling
- **[modbus.data.pack](docs/modules/modbus.data.pack.html)** - Data packing
- **[modbus.data.unpack](docs/modules/modbus.data.unpack.html)** - Data unpacking

### Transport Layer

- **[modbus.apdu.tcp](docs/modules/modbus.apdu.tcp.html)** - Modbus TCP protocol
- **[modbus.apdu.rtu](docs/modules/modbus.apdu.rtu.html)** - Modbus RTU protocol

### Master/Slave

- **[modbus.master.stream](docs/modules/modbus.master.stream.html)** - Generic master interface
- **[modbus.slave.stream](docs/modules/modbus.slave.stream.html)** - Generic slave interface
- **[modbus.master.skynet](docs/modules/modbus.master.skynet.html)** - Skynet master implementation
- **[modbus.slave.skynet](docs/modules/modbus.slave.skynet.html)** - Skynet slave implementation

## Data Packing/Unpacking

### Packing Data

```lua
local packer = require 'modbus.data.pack'
local p = packer:new()

-- Pack 16-bit unsigned integer
local data = p:uint16(1000)

-- Pack multiple register values
local values = {1000, 2000, 3000}
local data_list = {}
for _, v in ipairs(values) do
  table.insert(data_list, p:uint16(v))
end
local data = table.concat(data_list)

-- Pack bit values
local bits = {true, false, true, true, false}
local data = p:bit(table.unpack(bits))
```

### Unpacking Data

```lua
local unpacker = require 'modbus.data.unpack'
local u = unpacker:new()

-- Unpack 16-bit unsigned integer
local val, next_pos = u:uint16(data, 1)

-- Unpack multiple register values
local index = 1
local values = {}
while index <= #data do
  local val
  val, index = u:uint16(data, index)
  table.insert(values, val)
end
```

## Generating Documentation

Use [ldoc](https://github.com/lunarmodules/ldoc) to generate API documentation:

```bash
ldoc -f markdown -d docs -t "lua-modbus API Documentation" modbus/
```

The generated documentation is located in the `docs/` directory. Open `docs/index.html` in a browser to view.

## Dependencies

- **Lua 5.1+** or **LuaJIT**
- [middleclass](https://github.com/kikito/middleclass) - Lua class library

### For Skynet Integration

- [skynet](https://github.com/cloudwu/skynet) - Online game server framework
- [lua-cjson](https://www.kyne.com.au/~mark/software/lua-cjson.php) - JSON encoder/decoder

## Notes

1. **Byte Order**: Modbus protocol uses big-endian by default, but some devices may use little-endian. You can specify byte order when creating objects with the `little_endian` parameter.

2. **Timeout Handling**: In production, set appropriate timeout values based on network conditions.

3. **Error Handling**: It's recommended to check return values in callback functions and handle timeout and error conditions.

4. **Serial Configuration**: When using RTU/ASCII mode, ensure serial parameters (baudrate, data bits, parity, etc.) match your device settings.

## License

MIT License - See [LICENSE](LICENSE) file for details

## Author

KooIoT

## Contributing

Issues and Pull Requests are welcome!

## References

- [Modbus Application Protocol Specification](http://www.modbus.org/specs.php)
- [Modbus Protocol Wikipedia](https://en.wikipedia.org/wiki/Modbus)
