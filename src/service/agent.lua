local skynet = require "skynet"

local WATCHDOG
local CMD = {}
local client_fd
local user_info 
local handle={}
local gate
local room
local room_idx
local room_pos
local uid

local function send_client(v)
    skynet.send(gate, "lua", "send_client", client_fd, v)
end

--进入房间
local function enter_room(req)
    local room_id  
    if type(req) == "table" then
        room_id = req.room_id
    end
    local con_info = {
        fd = client_fd,
        watchdog = WATCHDOG,
        gate = gate,
        uid = uid,
        client = skynet.self()
    }
    local room_mgr = skynet.uniqueservice"room_mgr"
    skynet.error("agent enter_room", room_mgr, "room_id:", room_id)
    local ret, idx, pos, src = skynet.call(room_mgr, "lua", "enter", user_info, con_info, room_id)
    --skynet.error("----",json.encode(ret))
    room_idx = idx
    room_pos = pos
    room = src
    if not ret then
        room_idx = nil
        room_pos = nil
        room = nil
        send_client({ false, "Enter room failed" })
    end
end

local function offline()
    if room then
        local ret = skynet.call(room, "lua", "offline", room_pos)
        room_idx = nil
        room_pos = nil
    end
end

handle.enter_room = enter_room

skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT,
	unpack = skynet.tostring,
    dispatch = function (_, _, msg, ...)
        local ok, req =  pcall(json.decode, msg)
        if ok and handle[req.cmd] then
            handle[req.cmd](req)
        else
            send_client({ false, "Invalid command" })
        end
    end
}

function CMD.start(conf)
	local fd = conf.client
	gate = conf.gate
	WATCHDOG = conf.watchdog
	user_info = conf.info
	uid = conf.uid
	client_fd = fd
	skynet.call(gate, "lua", "forward", fd)
	send_client "Welcome to skynet"
end

function CMD.disconnect()
	offline()
	skynet.error("agent exit!")
	skynet.exit()
end

skynet.start(function()
    skynet.dispatch("lua",function(_,_,cmd,...)
        local f = CMD[cmd]
        skynet.ret(skynet.pack(f(...)))
    end)
end)
