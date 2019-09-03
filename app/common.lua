local http = require "resty.http"
local cjson = require "cjson.safe"
local _M = {}


function _M.split(str, pat)
    local t = {}  -- NOTE: use {n = 0} in Lua-5.0
    local fpat = "(.-)" .. pat
    local last_end = 1
    local s, e, cap = str:find(fpat, 1)
    while s do
        if s ~= 1 or cap ~= "" then
            table.insert(t,cap)
        end
        last_end = e+1
        s, e, cap = str:find(fpat, last_end)
    end
    if last_end <= #str then
        cap = str:sub(last_end)
        table.insert(t, cap)
    end
    return t
end

function _M.startswith(String, Start)
   return string.sub(String,1,string.len(Start))==Start
end

function _M.endswith(String, End)
   return End=='' or string.sub(String,-string.len(End))==End
end

function _M.member(tbl, item)
    for key, value in pairs(tbl) do
        if key == item then
            return true
        end
    end
    return false
end

function _M.get_or_default(tbl, key, default)
    for k,v in pairs(tbl) do
        if key == k then
            return v
        end
    end
    return default
end

function _M.get_file_content(file_name)
    local r = ""
    local file, err = io.open(file_name, "r")
    if not file then
        ngx.log(ngx.ERR, "failed to open file: ", err)
    end
    for line in file:lines() do
        line = line .. '\n'
        r = r .. line
    end
    return r
end

return _M
