local skynet = require "skynet"
local lsqlite3 = require "lsqlite3"

skynet.start(function()
    skynet.error("sqlite3 version: "..lsqlite3.version())
    skynet.error("lsqlite3 version: "..lsqlite3.lversion())

    print(lsqlite3.OK)
    print(lsqlite3.ERROR)
    print(lsqlite3.DONE)

    local db = lsqlite3.open_memory()
    assert(lsqlite3.OK == db:exec[[CREATE TABLE t_test(
        id int unsigned not null default 0,
        value text default ''
    );]])
    assert(lsqlite3.OK == db:exec[[insert into t_test values(1, 'one');]])
    assert(lsqlite3.OK == db:exec[[insert into t_test values(2, 'two');]])
    assert(lsqlite3.OK == db:exec("select * from t_test;", function(usrdata, ncols, values, names)
        skynet.error(table.unpack(names))
        skynet.error(table.unpack(values))
        return lsqlite3.OK
    end))

    assert(lsqlite3.OK == db:close())
    skynet.exit()
end)