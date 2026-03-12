--- Modbus Skynet 主站模块
--
-- 该模块提供基于 Skynet 框架的 Modbus 主站实现。
-- 支持 TCP 和串口（RTU/ASCII）两种连接方式，自动重连。
--
-- @module modbus.master.skynet
-- @author [作者名称]
-- @license MIT
-- @release $Id$

local class = require 'middleclass'
local skynet = require 'skynet'
local socket = require 'skynet.socket'
local socketdriver = require 'skynet.socketdriver'
local serial = require 'serialdriver'

--- Modbus Skynet 主站类
--
-- 实现了 Modbus 主站的基本功能，包括自动重连、请求管理、超时处理等。
-- 支持 TCP 和串口连接。
--
-- @type Modbus_Master_Skynet
local master = class("Modbus_Master_Skynet")

--- 初始化 Skynet 主站
--
-- @param mode string 传输模式（'tcp', 'rtu', 'ascii'）
-- @param opt table 配置选项
-- @param opt.link string 连接类型（'tcp' 或 'serial'）
-- @param opt.tcp table TCP 配置（host, port, nodelay）
-- @param opt.serial table 串口配置（port, baudrate, data_bits, parity, stop_bits, flow_control）
-- @param little_endian boolean 是否使用小端序字节顺序（可选，默认 false）
-- @usage
-- local master = require 'modbus.master.skynet'
-- local m = master:new('tcp', {
--   link = 'tcp',
--   tcp = { host = '127.0.0.1', port = 502, nodelay = true }
-- })
function master:initialize(mode, opt, little_endian)
	local m = nil
	if string.lower(mode) == 'tcp' then
		m = require('modbus.apdu.tcp')
		self._apdu = m:new(little_endian)
	end
	if string.lower(mode) == 'rtu' then
		m = require('modbus.apdu.rtu')
		self._apdu = m:new('master', little_endian)
	end
	if string.lower(mode) == 'ascii' then
		m = require('modbus.apdu.ascii')
		self._apdu = m:new('master', little_endian)
	end
	assert(self._apdu, "APDU failure!!")

	opt.link = string.lower(opt.link or 'serial')
	self._closing = false
	self._opt = opt
	self._requests = {}
	self._results = {}
end

--- 设置 I/O 回调函数
--
-- 用于调试或监控数据收发
--
-- @param cb function 回调函数，签名为 function(direction, unit, data)
-- @usage
-- m:set_io_cb(function(dir, unit, data)
--   print(dir, unit, data)
-- end)
function master:set_io_cb(cb)
	self._io_cb = cb
end

--- 发送 Modbus 请求
--
-- 发送 Modbus 请求并等待响应（阻塞调用）
--
-- @param unit number 设备单元 ID（从站地址）
-- @param pdu string 协议数据单元（由 modbus.pdu 模块创建）
-- @param timeout number 超时时间（毫秒）
-- @return string|nil 响应 PDU 数据
-- @return string|nil 错误信息
-- @usage
-- local pdu = require 'modbus.pdu'
-- local req = pdu:make_request(0x03, 0, 10)
-- local resp, err = m:request(1, req, 5000)
-- if err then
--   print("请求失败:", err)
-- end
function master:request(unit, pdu, timeout)
	local unit = tonumber(unit)
	assert(unit and pdu, "Unit and PDU are required!")
	local apdu_raw, key = assert(self._apdu:pack(unit, pdu))
	if not apdu_raw then
		return nil, key
	end
	if self._requests[key] then
		return nil, "Key already used!!!"
	end

	local t_left = timeout
	while not self._socket and not self._port and t_left > 0 do
		skynet.sleep(100)
		t_left = t_left - 1000
		if self._closing then
			return nil, "Connection closing!!!"
		end
	end
	if t_left <= 0 then
		return nil, "Not connected!!"
	end

	if self._port then
		--- Serial modbus
		while self._locked do
			skynet.sleep(10)
		end
		self._locked = true
	end

	if self._io_cb then
		self._io_cb('OUT', unit, apdu_raw)
	end

	if self._socket then
		local r, err = socket.write(self._socket, apdu_raw)
	else
		if not self._port then
			return nil, "Not connected!!"
		end
		local r, err = self._port:write(apdu_raw)
	end

	local t = {}
	self._requests[key] = t

	skynet.sleep(timeout / 10, t)

	self._requests[key] = nil

	if self._port then
		self._locked = nil
	end

	local result = self._results[key] or {false, "Timeout"}
	self._results[key] = nil
	return table.unpack(result)
end

function master:connect_proc()
	local connect_gap = 100 -- one second
	while not self._closing do
		self._connection_wait = {}
		skynet.sleep(connect_gap, self._connection_wait)
		self._connection_wait = nil
		if self._closing then
			break
		end

		local r, err = self:start_connect()
		if r then
			break
		end

		connect_gap = connect_gap * 2
		if connect_gap > 64 * 100 then
			connect_gap = 100
		end
		skynet.error("Wait for retart connection", connect_gap)
	end

	if self._socket then
		self:watch_client_socket()
	end
end

function master:watch_client_socket()
	while self._socket and not self._closing do
		local data, err = socket.read(self._socket)	
		if not data then
			skynet.error("Socket disconnected", err)
			break
		end
		self:process(data)
	end

	if self._socket then
		local to_close = self._socket
		self._socket = nil
		socket.close(to_close)
	end

	if self._closing then
		return
	end

	--- reconnection
	skynet.timeout(100, function()
		self:connect_proc()
	end)
end

function master:start_connect()
	if self._opt.link == 'tcp' then
		local conf = self._opt.tcp
		skynet.error(string.format("Connecting to %s:%d", conf.host, conf.port))
		local sock, err = socket.open(conf.host, conf.port)
		if not sock then
			local err = string.format("Cannot connect to %s:%d. err: %s", conf.host, conf.port, err or "")
			skynet.error(err)
			return nil, err
		end
		skynet.error(string.format("Connected to %s:%d", conf.host, conf.port))

		if conf.nodelay then
			socketdriver.nodelay(sock)
		end

		self._socket = sock
		return true
	end
	if self._opt.link == 'serial' then
		local opt = self._opt.serial
		local port = serial:new(opt.port, opt.baudrate or 9600, opt.data_bits or 8, opt.parity or 'NONE', opt.stop_bits or 1, opt.flow_control or "OFF")
		skynet.error("Open serial port:"..opt.port)
		local r, err = port:open()
		if not r then
			skynet.error("Failed open serial port:"..opt.port..", error: "..err)
			return nil, err
		end

		port:start(function(data, err)
			-- Recevied Data here
			if data then
				self:process(data)
			else
				skynet.error(err)
				port:close()
				self._port = nil
				skynet.timeout(100, function()
					self:connect_proc()
				end)
			end
		end)

		self._port = port
		return true
	end
	return false, "Unknown Link Type"
end

function master:process(data)
	--local basexx = require 'basexx'
	--print(os.date(), 'IN:', basexx.to_hex(data))
	self._apdu:append(data)
	if self._apdu_wait then
		skynet.wakeup(self._apdu_wait)
	end

	if self._io_cb then
		local unit = self._apdu:current_unit()
		self._io_cb('IN', unit, data)
	end
end


--- 启动主站
--
-- 启动连接并开始处理响应数据
--
-- @return boolean|nil 成功返回 true，失败返回 nil
-- @return string|nil 错误信息
-- @usage
-- local ok, err = m:start()
-- if not ok then print(err) end
function master:start()
	if self._socket or self._port then
		return nil, "Already started"
	end

	self._closing = false

	skynet.timeout(100, function()
		self:connect_proc()
	end)

	skynet.fork(function()
		while not self._closing do
			self._apdu:process(function(key, unit, pdu)
				assert(key)
				local req_co = self._requests[key]
				if req_co then
					local err_flag = false
					if unit then
						local fc = string.unpack('I1', pdu)
						err_flag = fc & 0x80 ~= 0
						if err_flag then
							self._results[key] = {false, pdu, key}
						else
							self._results[key] = {pdu}
						end
					else
						self._results[key] = {false, pdu, key}
					end

					skynet.wakeup(req_co)
				else
					skynet.error('Coroutine for key: '..key..' missing!')
				end
			end)
			self._apdu_wait = {}
			skynet.sleep(1000, self._apdu_wait)
			self._apdu_wait = nil
		end
	end)
	return true
end

--- 停止主站
--
-- 停止连接并清理资源
--
-- @usage
-- m:stop()
function master:stop()
	self._closing = true
	if self._apdu_wait then
		skynet.wakeup(self._apdu_wait) -- wakeup the process co
	end
	if self._connection_wait then
		skynet.wakeup(self._connection_wait) -- wakeup the process co
	end
	for k, v in pairs(self._requests) do
		skynet.wakeup(v)
	end
	self._requests = {}
	self._results = {}
end

return master 
