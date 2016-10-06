local skynet = require "skynet"
local csv = require "csv"

skynet.start(function()
    local data = assert(csv.fromfile("./test/testdata.csv"))
    for _, r in ipairs(data) do
        for k, v in pairs(r) do print(k, v, type(v)) end
    end
    skynet.exit()
end)