local skynet = require "skynet"
local httpd = require "http.httpd"
local websocket = require "websocket"
local socket = require "skynet.socket"
local socketdriver = require "skynet.socketdriver"
local sockethelper = require "http.sockethelper"
local json = require "cjson"

local nodelay = false
local client_number = 0
local maxclient	-- max client
local listenfd -- listen socket
local watchdog
local connection = {}	-- fd -> connection : { fd , client, agent , ip, mode }
local forwarding = {}	-- agent -> connection

local handler = {}

function handler.open(source, conf)
    watchdog = conf.watchdog or source
end

function handler.on_open(ws)
    skynet.error(string.format("Client connected: %s", ws.addr))
    ws:send_text("Hello websocket !")

    local fd = ws.fd
    local addr = ws.addr

    if client_number >= maxclient then
        ws:close()
        return
    end
    if nodelay then
        socketdriver.nodelay(fd)
    end
    client_number = client_number + 1

    local c = {
        fd = fd,
        ip = addr,
        ws = ws,
    }
    connection[fd] = c
    skynet.send(watchdog, "lua", "socket", "open", fd, addr)
end

local function unforward(c)
    if c.agent then
        forwarding[c.agent] = nil
        c.agent = nil
        c.client = nil
    end
end

local function close_fd(fd)
    local c = connection[fd]
    if c then
        unforward(c)
        connection[fd] = nil
        client_number = client_number - 1
    end
end

function handler.on_message(ws, msg)
    skynet.error("Received a message from client:\n"..msg)

    -- recv a package, forward it
    local sz = string.length(msg)
    local fd = ws.fd
    local c = connection[fd]
    local agent = c.agent
    if agent then
        skynet.redirect(agent, c.client, "client", 1, msg, sz)
    else
        skynet.send(watchdog, "lua", "socket", "data", fd, msg)
    end

end

function handler.on_error(ws, msg)
    skynet.error("Error. Client may be force closed.")
    -- do not need close.
    -- ws:close()

    local fd = ws.fd
    close_fd(fd)
    skynet.send(watchdog, "lua", "socket", "error", fd, msg)
end

function handler.on_close(ws, code, reason)
    skynet.error(string.format("Client disconnected: %s", ws.addr))
    -- do not need close.
    -- ws:close

    local fd = ws.fd
    close_fd(fd)
    skynet.send(watchdog, "lua", "socket", "close", fd)
end 

--function handler.warning(fd, size)
--skynet.send(watchdog, "lua", "socket", "warning", fd, size)
--end


local CMD = {}

function CMD.forward(source, fd, client, address)
    local c = assert(connection[fd])
    unforward(c)
    c.client = client or 0
    c.agent = address or source
    forwarding[c.agent] = c
end

function CMD.accept(source, fd)
    local c = assert(connection[fd])
    unforward(c)
end

function CMD.kick(source, fd)
    local c = connection[fd]
    if c and c.ws then
        c.ws:close()
    end
end

function CMD.open(source, conf)
    assert(not socket)
    local address = conf.address or "0.0.0.0"
    local port = assert(conf.port)
    maxclient = conf.maxclient or 1024
    nodelay = conf.nodelay
    skynet.error(string.format("Listen on %s:%d", address, port))

    local fd = assert(socket.listen(address, port))
    listenfd = fd
    socket.start(fd , function(fd, addr)
        socket.start(fd)
        pcall(handle_socket, fd, addr)
    end)

    if handler.open then
        return handler.open(source, conf)
    end

    --skynet.newservice("debug_console", "0.0.0.0", 8000)
end

function CMD.close()
    assert(listenfd)
    socketdriver.close(listenfd)
end

function CMD.send_client(source, fd, v)
    local c = connection[fd]
    if c and c.ws then
        ws:send_binary(json.encode(v))
    end
end

local function handle_socket(fd, addr)
    -- limit request body size to 8192 (you can pass nil to unlimit)
    local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(fd), 8192)
    if code then
        if url == "/ws" then
            local ws = websocket.new(fd, addr, header, handler)
            ws:start()
        end
    end
end

skynet.start(function()
    skynet.dispatch("lua", function (_, address, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(address, ...)))
        end
    end)
end)

