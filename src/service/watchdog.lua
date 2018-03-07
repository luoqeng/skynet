local skynet = require "skynet"
local json = require "cjson"

local gate

local CMD = {}
local SOCKET = {}
local agent = {}
local fd_uid = {}
local uid_fd = {}
local uid_agent = {}

skynet.register_protocol{
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = skynet.tostring
}

local function send_client(fd, v)
    skynet.send(gate, "lua", "send_client", fd, v)
end

function SOCKET.open(fd, addr)
	skynet.error("New client from : " .. addr)
	skynet.call(gate,"lua","accept",fd)
end

local function close_agent(fd)
    local uid = fd_uid[fd]
    if uid then
        fd_uid[fd]=nil
        local a = uid_agent[uid]
        uid_agent[uid] = nil
        uid_fd[uid] = nil
        skynet.call(gate, "lua", "kick", fd)
        -- disconnect never return
        skynet.send(a, "lua", "disconnect")
    end
end

function SOCKET.close(fd)
	skynet.error("socket close",fd)
	close_agent(fd)
end

function SOCKET.error(fd, msg)
	skynet.error("socket error",fd, msg)
	close_agent(fd)
end

function SOCKET.warning(fd, size)
	-- size K bytes havn't send out in fd
	skynet.error("socket warning", fd, size)
end

--玩家连接上来 消息没有转发给client处理 这里有watchdog处理验证
function SOCKET.data(fd, msg)
    local ok, req =  pcall(json.decode, msg)
    if not ok then
        send_client(fd, 0, {"unpack error"})	
        return
    end

    --TODO 登陆验证
	local info = {nickname="xxx", sex=1, score=100}
    local uid = 10000
    local agent = uid_agent[uid]
    local last_fd = uid_fd[uid]
    if agent then
        close_agent(last_fd)
    end
    agent = skynet.newservice("agent")
    fd_uid[fd] = uid
    uid_fd[uid] = fd
    uid_agent[uid] = agent
    skynet.call(agent, "lua", "start", {gate = gate, client = fd, watchdog = skynet.self(), info=info, uid=uid})
end

function CMD.start(conf)
	skynet.call(gate, "lua", "open" , conf)
end

function CMD.close(fd)
	close_agent(fd)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
		skynet.error("watchdog -- > lua:",cmd,subcmd)
		if cmd == "socket" then
			local f = SOCKET[subcmd]
			f(...)
			-- socket api don't need return
		else
			local f = assert(CMD[cmd])
			skynet.ret(skynet.pack(f(subcmd, ...)))
		end
	end)
	gate = skynet.newservice("gatewb")
end)
