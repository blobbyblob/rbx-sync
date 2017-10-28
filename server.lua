--[[

Listens for HTTP PUT requests from clients.

Properties:
	OnHttpReceived (function(client, protocol, headers, content) -> nil): a callback function for when HTTP requests are received.
	Socket (read-only): the server's socket.
	Port (number): the port number to bind this server to. Updating this resets the socket.
	Timeout (number): the number of seconds one should wait when listening on the server socket. Updating this resets the socket.

Methods:
	Listen(): listens for incoming connections and serves them.

--]]

local socket = require("socket");
local PORT = 605;

local Server = require("class").new("Server");

Server._Server = false;
Server._Port = 605;
Server.OnHttpReceived = function(client, protocol, headers, content)
	print("Received message: " .. content);
end;
Server._Timeout = 0;

Server.Get.Socket = "_Server";
function Server.Set:Port(v)
	self._Port = v;
	self:_ResetSocket();
end
Server.Get.Port = "_Port";
function Server.Set:Timeout(v)
	self._Timeout = v;
	self:_ResetSocket();
end
Server.Get.Timeout = "_Timeout";

function Server:_ResetSocket()
	if self._Server then
		self._Server:close();
	end
	self._Server = assert(socket.tcp());
	assert(self._Server:bind("*", self._Port));
	assert(self._Server:listen(32));
	assert(self._Server:settimeout(self._Timeout));
end

local function read(client, length)
	local msg, err = client:receive(length);
	if not msg and err == 'timeout' then
		coroutine.yield();
		return read(length);
	elseif msg then
		return msg;
	else
		print("Error Reading Client: " .. err);
	end
end

function Server:Listen()
	local client, errmsg = self._Server:accept();
	local retval;
	if client then
		--Get the protocol.
		local protocol = read(client);
		--Read headers.
		local readingHeaders = true;
		local headers = {};
		while readingHeaders do
			local header = read(client);
			local key, value = header:match("([^:]+): (.*)");
			if key then
				headers[key:lower()] = value;
			else
				readingHeaders = false;
			end
		end

		--Read content
		local data, errmsg = read(client, tonumber(headers["content-length"]));
		--Fire a callback.
		self.OnHttpReceived(client, protocol, headers, data);
	end
end

function Server:Destroy()
	self._Server:close();
end

function Server.new()
	local self = setmetatable({}, Server.Meta);
	self:_ResetSocket();
	return self;
end

return Server;
