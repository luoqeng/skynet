local skynet = require "skynet"

local max_client = 64

skynet.start(function()
    skynet.error("Server start")
	if not skynet.getenv "daemon" then
		local console = skynet.newservice("console")
	end
    skynet.newservice("debug_console", "127.0.0.1", 8000)
    --	skynet.uniqueservice"mysqldb"
    skynet.uniqueservice"room_mgr"
    local watchdog = skynet.newservice("watchdog")
    skynet.call(watchdog, "lua", "start", {
        port = 8899,
        maxclient = max_client,
        nodelay = true
    })
    skynet.error("Watchdog listen on",8899)
    skynet.exit()
end)
