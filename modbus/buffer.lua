local class = require 'middleclass'

local buffer = class("Modbus_Stream_Buffer")

function buffer:initialize(max_size)
	self._max_size = max_size or 1394
	self._buf = ''
end

function buffer:sub(s, e)
	return string.sub(self._buf, s, e)
end

function buffer:append(data)
	self._buf = self._buf .. data
	if string.len(self._buf) > self._max_size then
		self._buf = string.sub(self._buf, 0 - self._max_size)
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
