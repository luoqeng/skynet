local skynet = require"skynet"
local skynet = require "skynet.manager"
local queue = require"skynet.queue"

local cs = queue()
local rooms = {}
local rooms_agent_count = {}
local room_number = 16

local function create_rooms()
	for i = 1, room_number do
		rooms[i] = skynet.newservice "room"
		skynet.call(rooms[i], "lua", "start", i)
		rooms_agent_count[i] = 0
	end
end

local function enter_room(user_info, con_info, room_id)
    local ret = false
    local idx
    local pos
    local src
    if room_id then 
        --进入指定room_id的房间
        if rooms[room_id] and rooms_agent_count[room_id] < 3 then
            ret, pos = skynet.call(rooms[room_id], "lua", "enter", user_info, con_info)
            if not ret then
                break
            end
            idx = room_id
            src = rooms[room_id]
            rooms_agent_count[room_id] = rooms_agent_count[room_id] + 1
        end
    else	
        --没有指定roomid表示随机进入
        for i = 1, #rooms do
            if rooms_agent_count[i] < 3 then
                skynet.error("room_mgr:", i, user_info.nickname, rooms_agent_count[i])
                ret, pos = skynet.call(rooms[i], "lua", "enter", user_info, con_info)
                if not ret then
                    break
                end
                idx = i
                src = rooms[room_id]
                rooms_agent_count[i] = rooms_agent_count[i] + 1
                break
            end
        end
    end
    return ret, idx, pos, src
end

local function leave_room(room_id, room_pos)
	--skynet.call(rooms[room_id],"lua","leave",room_pos)
	rooms_agent_count[room_id] = rooms_agent_count[room_id] - 1
end

local CMD={}

function CMD.enter(user_info, con_info, room_id)
	return cs(enter_room, user_info, con_info, room_id)
end

function CMD.leave(room_idx, room_pos)
	return cs(leave_room, room_idx, room_pos)
end

skynet.start(function()
    create_rooms()
    skynet.dispatch("lua",function(_,address,cmd,...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        end
    end)
end)
