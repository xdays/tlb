local common = require "common"
local cjson = require "cjson.safe"

local servers = ngx.shared.servers
local stats = ngx.shared.stats
local data = {}
local stat_keys = {
    "ttfb", "speed", "count"
}
for k,v in ipairs(servers:get_keys()) do
    local r = {}
    for m,n in ipairs(stat_keys) do
        local stat_key = v .. "-" .. n
        r[n] = stats:get(stat_key)
    end
    r["status"] = servers:get(v)
    data[v] = r
end
local t = cjson.encode(data)
ngx.say(t)
