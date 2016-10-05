package.cpath = "../luaclib/?.so"

local lsqlite3 = require "lsqlite3"

local db = lsqlite3.open_memory()

db:exec[[ CREATE DATABASE 'testdb'; ]]
