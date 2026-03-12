--- LDoc 配置文件
--
-- 用于生成 lua-modbus 项目的 API 文档
--
-- 使用方法:
--   ldoc config.ld
--
-- 生成的文档将输出到 'docs/' 目录

project = 'lua-modbus'
title = 'lua-modbus API 文档'
description = [[
lua-modbus 是一个完整的 Modbus 协议 Lua 实现，支持 RTU、TCP 和 ASCII 三种传输方式。

## 特性

- 支持 Modbus TCP、RTU 和 ASCII 协议
- 支持主站（Master）和从站（Slave）模式
- 支持标准 Modbus 功能码（0x01-0x10）
- 提供 Skynet 框架集成
- 支持大端序和小端序字节顺序
- 完整的数据打包和解包功能

## 快速开始

### 主站模式

```lua
local master = require 'modbus.master.stream'
local pdu = require 'modbus.pdu'

-- 创建主站
local stream = {
  send = function(data) ... end,
  recv = function(len, timeout) ... end
}
local m = master:new('tcp', stream)

-- 创建请求
local p = pdu:new()
local req = p:make_request(0x03, 0, 10)  -- 读取 10 个寄存器

-- 发送请求
m:request(1, req, function(unit, pdu, key)
  if not pdu then
    print("请求失败:", key)
  else
    print("收到响应")
  end
end, 5)

-- 处理循环
while running do
  m:run_once(1000)
end
```

### 从站模式

```lua
local slave = require 'modbus.slave.stream'

-- 创建从站
local s = slave:new('tcp', stream)

-- 添加单元
s:add_unit(1, function(pdu, response_handler)
  -- 处理请求
  -- 生成响应
  response_handler(response_pdu)
end)

-- 处理循环
while running do
  s:run_once(1000)
end
```

## 模块说明

### 核心模块
- `modbus.pdu` - 协议数据单元（PDU）处理
- `modbus.data.pack` - 数据打包
- `modbus.data.unpack` - 数据解包

### 传输层
- `modbus.apdu.tcp` - Modbus TCP 协议
- `modbus.apdu.rtu` - Modbus RTU 协议
- `modbus.apdu.ascii` - Modbus ASCII 协议

### 主站/从站
- `modbus.master.stream` - 通用主站接口
- `modbus.slave.stream` - 通用从站接口
- `modbus.master.skynet` - Skynet 主站实现
- `modbus.slave.skynet` - Skynet 从站实现

### 辅助模块
- `modbus.buffer` - 流缓冲区
- `modus.exceptions` - Modbus 异常代码
- `modbus.ecm` - 错误校验机制
- `modbus.code` - 功能码映射
]]

-- 文件匹配模式
file = './modbus'
-- 排除的文件
exclude = {'test', 'examples'}

-- 输出目录
dir = 'docs'

-- 主题
format = 'markdown'
style = '!fixed'

-- 其他选项
all = false
-- no_summary = false
-- sort_modules = true

-- 带有描述的模块
topics = [[
README.md
LICENSE
]]

-- 自定义样式
-- template = 'templates/'

-- 其他语言支持（中文）
no_lua_userdata = true
