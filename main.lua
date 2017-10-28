--[[

Request:
	read
	<filename> 
Response:
	<file contents>

Request:
	write
	<filename>
	<file contents...>
Response: none

Request:
	parse
	<directory>
	<depth> # The file system depth one should traverse. A value of 0 means indefinite recursion.
Response:
	<file1>
	<file2>
	...

--]]

local server = require('server').new();
local socket = require("socket");
local lfs = require("lfs");

local ROOT = lfs.currentdir() .. "/../";
local SERVER_TIMEOUT = 3600;

local function dirtree(dir, maxdepth)
	assert(dir and dir ~= "", "directory parameter is missing or empty")
	if string.sub(dir, -1) == "/" then
		dir=string.sub(dir, 1, -2)
	end

	local function yieldtree(dir, depth)
		for entry in lfs.dir(dir) do
			if entry ~= "." and entry ~= ".." and entry:sub(1, 1) ~= '.' and depth > 0 then
				entry = dir .. "/" .. entry;
				local attr = lfs.attributes(entry);
				coroutine.yield(entry, attr);
				if attr.mode == "directory" then
					yieldtree(entry, depth - 1);
				end
			end
		end
	end

	return coroutine.wrap(function() yieldtree(dir, maxdepth == 0 and math.huge or maxdepth) end)
end

local Commands = {};

function Commands.read(client, data)
	local filepath = data:match("^([^\r\n]+)");
	print("Request to read " .. filepath .. " received");
	local f = io.open(ROOT .. filepath, "r");
	local t = f:read("*all");
	f:close();
	return t;
end

local function CreateDirectoryTree(filepath)
	local parser = filepath:gmatch("[^/]+");
	local n = parser();
	local dir = ROOT;
	while n ~= nil do
		dir = dir .. n;
		n = parser();
		if n then
			local results = lfs.attributes(dir);
			if not results then
				print("Making directory: " .. dir);
				lfs.mkdir(dir);
			end
		end
		dir = dir .. "/";
	end
end

function Commands.write(client, data)
	local filepath, tail = data:match("^([^\r\n]+)\r?\n?([%a%A]+)");
	print("Request to write " .. filepath .. " received (data length " .. #tail .. ")");
	local f = io.open(ROOT .. filepath, "w");
	if not f then
		CreateDirectoryTree(filepath);
		f = io.open(ROOT .. filepath, "w");
	end
	f:write(tail);
	f:close();
	return true;
end

function Commands.parse(client, data)
	local parser = data:gmatch("%S+");
	local directory = parser();
	local depth = tonumber(parser());
	print("Request to parse " .. directory .. " received (depth " .. (depth or 'nil') .. ")");
	local t = {};
	for i, v in dirtree("../" .. directory, depth or 0) do
		table.insert(t, i:sub(4));
	end
	return table.concat(t, "\n");
end

local function Route(client, data)
	local op = data:match("^[^\n\r]+");
	if Commands[op] then
		return Commands[op](client, data:match("^[^\r\n]+[\r\n]+([%a%A]+)$"));
	else
		return false;
	end
end

function server.OnHttpReceived(client, protocol, headers, data)
	local payload = Route(client, data);
	local response;
	if payload then
		if type(payload) ~= "string" then
			payload = "";
		end
		response = {
			"HTTP/1.1 200 OK";
			"Connection: close";
			"Content-Length: " .. #payload;
			"";
			payload;
		};
	else
		response = {
			"HTTP/1.1 400 Bad Request";
			"Connection: close";
			"Content-Length: 0";
			"";
			"";
		};
	end

	local msg = table.concat(response, "\r\n");
	assert(client:send(msg));
	assert(client:close());
end

while true do
	local ready, _, err = socket.select({server.Socket}, {}, SERVER_TIMEOUT)
	if err == 'timeout' then
		break;
	end
	server:Listen();
end
