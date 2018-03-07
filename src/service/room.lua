local skynet = require "skynet"
local json = require "cjson"
local sparrow = require "sparrow"

local room_id
local game
local client = {} --source => chairid
local handle = {}

local function ready(source, req) 
    game:ready(client[source])
end

local function trustee(source, req) 
    game:trustee(client[source], req.trustee)
end

local function kick(source, req)
    local owner = client[source]
    if owner ~= game.room_owner then 
        skynet.error("Permission Denied")
        return 
    end

    game:kick(req.chairid)
end

local function listen(source, req)
    game:listen(client[source])
end

local function out_card(source, req)
    game:out_card(client[source], req.card_data)
end

local function operate_card(source, req)
    game:operate_card(client[source], req.operate_code, operate_card)
end

local function leave(source, req)
    local client_fd = game.player[client[source]].client_fd
    if not game:leave(client[source]) then
        return
    end

    local room_mgr = skynet.uniqueservice "room_mgr"
    skynet.call(room_mgr, "lua", "leave", room_id, client[source])
    skynet.call(con_info.gate, "lua", "forward", client_fd, 0, source)
    client[source] = nil
end

handle.ready = ready
handle.trustee = trustee
handle.kick = kick
handle.listen = listen
handle.out_card = out_card
handle.operate_card = operate_card
handle.leave = leave

skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT,
	unpack = skynet.tostring,
    dispatch = function (_, address, msg, ...)
        -- verify request
        if not client[address] then
            skynet.error("Client not found")
            return
        end

        local ok, req =  pcall(json.decode, msg)
        if ok and handle[req.cmd] then
            handle[req.cmd](address, req)
        else
            skynet.error("Invalid command")
        end
    end
}

local CMD = {}
function CMD.enter(user_info, con_info)
    if not game then
        game = sparrow.new()
    end

    local player = {
        profile = {
            uid = con_info.uid,
            nickname = user_info.nickname,
            sex = user_info.sex,
        },
        score = user_info.score,
        gate = con_info.gate,
        watchdog = con_info.watchdog,
        client = con_info.client,
        client_fd = con_info.fd
    }

    local ret = false
    local chairid = game:enter(player)
    if chairid >=1 and chairid <=4 then
        client[con_info.client] = chairid
        skynet.call(con_info.gate, "lua", "forward", con_info.fd, con_info.client)
        ret = true
    end

    return ret, chairid 
end

function CMD.offline(room_pos)
    -- TODO disconnect
end

function CMD.start(roomid)
	room_id = roomid
end

skynet.start(function()
    skynet.dispatch("lua",function(session,source,cmd,...)
        local f = assert(CMD[cmd])
        skynet.ret(skynet.pack(f(...)))
    end)
end)
