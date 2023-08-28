local class = require 'middleclass'
local skynet = require 'skynet'
local socket = require 'skynet.socket'
local socketdriver = require 'skynet.socketdriver'
local serial = require 'serialdriver'
local cjson = require 'cjson.safe'

local slave = class("Modbus_Slave_Skynet")

--- 
-- stream_type: tcp/serial
function slave:initialize(mode, opt, little_endian)
	local m = nil
	if string.lower(mode) == 'tcp' then
		m = require('modbus.apdu.tcp')
		self._apdu = m:new(little_endian)
	end
	if string.lower(mode) == 'rtu' then
		m = require('modbus.apdu.rtu')
		self._apdu = m:new('slave', little_endian)
	end
	if string.lower(mode) == 'ascii' then
		m = require('modbus.apdu.ascii')
		self._apdu = m:new('slave', little_endian)
	end
	assert(self._apdu, "APDU failure!!")

	opt.link = string.lower(opt.link or 'serial')
	self._closing = false
	self._opt = opt
	self._callbacks = {}
end

function slave:set_io_cb(cb)
	self._io_cb = cb
end

---
-- callback(key, unit, pdu)
function slave:add_unit(unit, callback)
	assert(callback and not self._callbacks[unit])
	self._callbacks[unit] = callback
end

function slave:remove_unit(unit)
	self._callbacks[unit] = nil
end

function slave:connect_proc()
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

	if self._server_socket then
		self:watch_server_socket()
	end
end

function slave:watch_server_socket()
	while self._server_socket do
		while self._server_socket and not self._socket do
			skynet.sleep(10)
		end
		if not self._server_socket then
			break
		end

		while self._socket and self._server_socket do
			local data, err = socket.read(self._socket)	
			if not data then
				skynet.error("Client socket disconnected", err)
				break
			end
			self:process(data)
		end

		if self._socket then
			local to_close = self._socket
			self._socket = nil
			socket.close(to_close)
		end
	end

	if not self._server_socket then
		skynet.timeout(100, function()
			self:connect_proc()
		end)
	end
end

function slave:start_connect()
	if self._opt.link == 'tcp' then
		local conf = self._opt.tcp
		skynet.error(string.format("Connect to %s:%d", conf.host, conf.port))
		local sock, err = socket.listen(conf.host, conf.port)
		if not sock then
			return nil, string.format("Cannot connect on %s:%d. err: %s", conf.host, conf.port, err or "")
		end
		self._server_socket = sock
		socket.start(sock, function(fd, addr)
			skynet.error(string.format("New connection (fd = %d, %s)",fd, addr))
			--- TODO: Limit client ip/host

			if conf.nodelay then
				socketdriver.nodelay(fd)
			end

			local to_close = self._socket
			socket.start(fd)
			self._socket = fd

			local host, port = string.match(addr, "^(.+):(%d+)$")
			if host and port then
				self._socket_peer = cjson.encode({
					host = host,
					port = port,
				})
			else
				self._socket_peer = addr
			end
			if to_close then
				skynet.error(string.format("Previous socket closing, fd = %d", to_close))
				socket.close(to_close)
			end
		end)
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

function slave:process(data)
	self._apdu:append(data)
	if self._apdu_wait then
		skynet.wakeup(self._apdu_wait)
	end

	if self._io_cb then
		local unit = self._apdu:current_unit()
		self._io_cb('IN', unit, data)
	end
end

function slave:start()
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
				local cb = self._callbacks[unit]
				if cb and unit and pdu then
					cb(pdu, function(pdu)
						local apdu_raw, key = assert(self._apdu:pack(unit, pdu, key))
						if not apdu_raw then
							return nil, key
						end

						if not self._socket and not self._port then
							return
						end

						if self._socket then
							socket.write(self._socket, apdu_raw)
						end
						if self._port then
							self._port:write(apdu_raw)
						end

						if self._io_cb then
							self._io_cb('OUT', unit, apdu_raw)
						end
					end)
				else
					--- TODO: write 0x8X error response
				end
			end)
			self._apdu_wait = {}
			skynet.sleep(1000, self._apdu_wait)
			self._apdu_wait = nil
		end
	end)

	return true
end

function slave:stop()
	self._closing = true
	if self._apdu_wait then
		skynet.wakeup(self._apdu_wait) -- wakeup the process co
	end
	if self._connection_wait then
		skynet.wakeup(self._connection_wait) -- wakeup the process co
	end
end

return slave 
