local skynet = require "skynet"
local csv = require "csv"

local function readfile(filename)
    local f = csv.open(filename)
    for fields in f:lines() do
        for i, v in ipairs(fields) do print(i, v) end
    end
end

skynet.start(function()
    readfile("./test/testdata.csv")
    skynet.exit()
end)