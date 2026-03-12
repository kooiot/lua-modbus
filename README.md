# lua-modbus

一个完整的 Modbus 协议 Lua 实现，支持 RTU、TCP 和 ASCII 三种传输方式。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lua](https://img.shields.io/badge/Lua-5.1%2B-blue.svg)](https://www.lua.org/)
[![LDoc](https://img.shields.io/badge/docs-lDoc-green.svg)](docs/)

中文 | [English](README_EN.md)

## 特性

- **支持 Modbus TCP、RTU 和 ASCII 协议**
- **支持主站（Master）和从站（Slave）模式**
- **支持标准 Modbus 功能码（0x01-0x10）**
  - `0x01` - 读取线圈（Read Coils）
  - `0x02` - 读取离散输入（Read Discrete Inputs）
  - `0x03` - 读取保持寄存器（Read Holding Registers）
  - `0x04` - 读取输入寄存器（Read Input Registers）
  - `0x05` - 写单个线圈（Write Single Coil）
  - `0x06` - 写单个寄存器（Write Single Register）
  - `0x0F` - 写多个线圈（Write Multiple Coils）
  - `0x10` - 写多个寄存器（Write Multiple Registers）
- **提供 Skynet 框架集成**
- **支持大端序和小端序字节顺序**
- **完整的数据打包和解包功能**

## 目录结构

```
lua-modbus/
├── modbus/
│   ├── pdu/           # 协议数据单元（PDU）处理
│   │   ├── init.lua   # PDU 主要接口
│   │   ├── request.lua
│   │   └── response.lua
│   ├── data/          # 数据打包/解包
│   │   ├── pack.lua   # 数据打包
│   │   └── unpack.lua # 数据解包
│   ├── apdu/          # 应用层协议数据单元
│   │   ├── tcp.lua    # Modbus TCP 协议
│   │   ├── rtu.lua    # Modbus RTU 协议
│   │   └── ascii.lua  # Modbus ASCII 协议
│   ├── master/        # 主站实现
│   │   ├── stream.lua # 通用流接口
│   │   └── skynet.lua # Skynet 框架集成
│   ├── slave/         # 从站实现
│   │   ├── stream.lua # 通用流接口
│   │   └── skynet.lua # Skynet 框架集成
│   ├── buffer.lua     # 流缓冲区
│   ├── code.lua       # 功能码映射
│   ├── exceptions.lua # 异常代码
│   └── ecm.lua        # 错误校验机制
├── docs/              # API 文档
├── config.ld          # lDoc 配置文件
└── README.md
```

## 安装

### 使用 LuaRocks

```bash
luarocks install lua-modbus
```

### 手动安装

1. 克隆仓库：
```bash
git clone https://github.com/yourusername/lua-modbus.git
cd lua-modbus
```

2. 将 `modbus` 目录复制到你的 Lua 路径：
```bash
cp -r modbus /usr/local/share/lua/5.3/
```

或者将项目路径添加到 `LUA_PATH`：
```bash
export LUA_PATH="/path/to/lua-modbus/?.lua;;"
```

## 快速开始

### 主站（Master）模式

#### 通用流接口

```lua
local master = require 'modbus.master.stream'
local pdu = require 'modbus.pdu'

-- 创建流对象
local stream = {
  -- 发送数据
  send = function(data)
    -- 实现 TCP 或串口发送
  end,
  -- 接收数据
  recv = function(len, timeout)
    -- 实现 TCP 或串口接收，返回接收到的数据
  end
}

-- 创建主站（TCP 模式）
local m = master:new('tcp', stream)

-- 创建 PDU 对象
local p = pdu:new()

-- 创建读取保持寄存器请求（功能码 0x03）
-- 从地址 0 开始读取 10 个寄存器
local req = p:make_request(0x03, 0, 10)

-- 发送请求到单元 ID 为 1 的从站
m:request(1, req, function(unit, pdu, key)
  if not pdu then
    print("请求失败:", key)
  else
    print("收到响应，从站:", unit, "PDU长度:", #pdu)
    -- 解析响应数据...
  end
end, 5)  -- 5 秒超时

-- 主处理循环
while running do
  m:run_once(1000)  -- 1 秒超时
end
```

#### Skynet 框架集成

```lua
local skynet = require 'skynet'
local master = require 'modbus.master.skynet'
local pdu = require 'modbus.pdu'

skynet.start(function()
  -- 创建主站
  local m = master:new('tcp', {
    link = 'tcp',
    tcp = {
      host = '127.0.0.1',
      port = 502,
      nodelay = true
    }
  })

  -- 启动主站
  m:start()

  -- 创建 PDU 对象
  local p = pdu:new()

  -- 发送请求
  local req = p:make_request(0x03, 0, 10)
  local resp, err = m:request(1, req, 5000)  -- 5 秒超时

  if err then
    print("请求失败:", err)
  else
    print("收到响应:", #resp)
  end
end)
```

### 从站（Slave）模式

#### 通用流接口

```lua
local slave = require 'modbus.slave.stream'
local pdu = require 'modbus.pdu'

-- 创建流对象
local stream = {
  send = function(data)
    -- 发送数据
  end,
  recv = function(len, timeout)
    -- 接收数据
  end
}

-- 创建从站（RTU 模式）
local s = slave:new('rtu', stream)

-- 创建 PDU 对象
local p = pdu:new()

-- 添加单元 ID 为 1 的设备
s:add_unit(1, function(pdu, response_handler)
  -- 解析请求 PDU
  local fc = string.byte(pdu, 1)  -- 功能码
  local addr = string.unpack('>I2', pdu, 2)  -- 起始地址
  local len = string.unpack('>I2', pdu, 4)   -- 数量

  print(string.format("收到请求: FC=0x%02X, ADDR=%d, LEN=%d", fc, addr, len))

  if fc == 0x03 then
    -- 读取保持寄存器
    -- 这里返回模拟数据
    local values = {1000, 2000, 3000, 4000, 5000}
    local resp = p:make_response(0x03, addr, table.unpack(values))
    response_handler(resp)
  else
    -- 其他功能码...
  end
end)

-- 主处理循环
while running do
  s:run_once(1000)
end
```

#### Skynet 框架集成

```lua
local skynet = require 'skynet'
local slave = require 'modbus.slave.skynet'
local pdu = require 'modbus.pdu'

skynet.start(function()
  -- 创建从站
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

  -- 创建 PDU 对象
  local p = pdu:new()

  -- 添加单元
  s:add_unit(1, function(pdu, response_handler)
    local fc = string.byte(pdu, 1)
    local addr = string.unpack('>I2', pdu, 2)
    local len = string.unpack('>I2', pdu, 4)

    if fc == 0x03 then
      -- 读取保持寄存器
      local values = {1000, 2000, 3000}
      local resp = p:make_response(0x03, addr, table.unpack(values))
      response_handler(resp)
    elseif fc == 0x06 then
      -- 写单个寄存器
      local value = string.unpack('>I2', pdu, 4)
      print(string.format("写寄存器 %d = %d", addr, value))
      local resp = p:make_response(0x06, addr, value)
      response_handler(resp)
    end
  end)

  -- 启动从站
  s:start()
end)
```

## API 文档

完整的 API 文档请参考：[docs/index.html](docs/index.html)

### 核心模块

- **[modbus.pdu](docs/modules/modbus.pdu.html)** - 协议数据单元（PDU）处理
- **[modbus.data.pack](docs/modules/modbus.data.pack.html)** - 数据打包
- **[modbus.data.unpack](docs/modules/modbus.data.unpack.html)** - 数据解包

### 传输层

- **[modbus.apdu.tcp](docs/modules/modbus.apdu.tcp.html)** - Modbus TCP 协议
- **[modbus.apdu.rtu](docs/modules/modbus.apdu.rtu.html)** - Modbus RTU 协议

### 主站/从站

- **[modbus.master.stream](docs/modules/modbus.master.stream.html)** - 通用主站接口
- **[modbus.slave.stream](docs/modules/modbus.slave.stream.html)** - 通用从站接口
- **[modbus.master.skynet](docs/modules/modbus.master.skynet.html)** - Skynet 主站实现
- **[modbus.slave.skynet](docs/modules/modbus.slave.skynet.html)** - Skynet 从站实现

## 数据打包/解包

### 打包数据

```lua
local packer = require 'modbus.data.pack'
local p = packer:new()

-- 打包 16 位无符号整数
local data = p:uint16(1000)

-- 打包多个寄存器值
local values = {1000, 2000, 3000}
local data_list = {}
for _, v in ipairs(values) do
  table.insert(data_list, p:uint16(v))
end
local data = table.concat(data_list)

-- 打包位值
local bits = {true, false, true, true, false}
local data = p:bit(table.unpack(bits))
```

### 解包数据

```lua
local unpacker = require 'modbus.data.unpack'
local u = unpacker:new()

-- 解包 16 位无符号整数
local val, next_pos = u:uint16(data, 1)

-- 解包多个寄存器值
local index = 1
local values = {}
while index <= #data do
  local val
  val, index = u:uint16(data, index)
  table.insert(values, val)
end
```

## 生成文档

使用 [ldoc](https://github.com/lunarmodules/ldoc) 生成 API 文档：

```bash
ldoc -f markdown -d docs -t "lua-modbus API 文档" modbus/
```

生成的文档位于 `docs/` 目录，用浏览器打开 `docs/index.html` 查看。

## 依赖

- **Lua 5.1+** 或 **LuaJIT**
- [middleclass](https://github.com/kikito/middleclass) - Lua 类库

### Skynet 集成需要

- [skynet](https://github.com/cloudwu/skynet) - 在线游戏服务端框架
- [lua-cjson](https://www.kyne.com.au/~mark/software/lua-cjson.php) - JSON 编解码库

## 注意事项

1. **字节序**：Modbus 协议默认使用大端序（Big-Endian），但某些设备可能使用小端序。创建对象时可以通过 `little_endian` 参数指定。

2. **超时处理**：在实际应用中，应根据网络情况设置合适的超时时间。

3. **错误处理**：建议在回调函数中检查返回值，处理超时和错误情况。

4. **串口配置**：使用 RTU/ASCII 模式时，确保串口参数（波特率、数据位、校验位等）与设备匹配。

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 作者

KooIoT

## 贡献

欢迎提交 Issue 和 Pull Request！

## 参考资料

- [Modbus 应用层协议规范](http://www.modbus.org/specs.php)
- [Modbus 协议详解](https://en.wikipedia.org/wiki/Modbus)
