local class = require 'middleclass'

local buffer = class("Modbus_Stream_Buffer")

function buffer:initialize(max_size)
	self._max_size = max_size or 1394
	if self._max_size <= 0 then
		self._max_size = 1394
	end
	self._buf = ''
end

function buffer:sub(s, e)
	return string.sub(self._buf, s, e)
end

function buffer:append(data)
	self._buf = self._buf .. data
	-- 当缓冲区超过最大大小时，丢弃最旧的数据（保留最后 max_size 字节）
	-- 注意：这会导致数据丢失，应该通过日志或监控来检测缓冲区溢出
	if string.len(self._buf) > self._max_size then
		self._buf = string.sub(self._buf, -self._max_size)
	end
end

function buffer:find(...)
	return string.find(self._buf, ...)
end

function buffer:match(...)
	return string.match(self._buf, ...)
end

function buffer:gmatch(...)
	return string.gmatch(self._buf, ...)
end

function buffer:__tostring()
	return self._buf
end

function buffer:pop(len)
	assert(len > 0)
	-- 从缓冲区头部移除指定长度的数据
	-- 注意：如果 len 超过缓冲区长度，会返回空字符串（不会报错）
	self._buf = string.sub(self._buf, len + 1)
end

function buffer:clear()
	self._buf = ''
end

function buffer:len()
	return string.len(self._buf)
end

function buffer:max()
	return self._max_size
end

return buffer
