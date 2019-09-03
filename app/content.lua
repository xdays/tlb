local common = require "common"
local cjson = require "cjson.safe"

local servers = ngx.shared.servers
local stats = ngx.shared.stats
local data = {}
local stat_keys = {
    "total_time", "ttfb_time",
    "bytes_received"
}
for k,v in ipairs(servers:get_keys()) do
    local r = {}
    local metrics_data = servers:get(v)
    if metrics_data ~= 0 and metrics_data ~= nil then
        local metrics = common.split(metrics_data, ",")
        r["avg_ttfb"] = metrics[1]
        r["avg_speed"] = metrics[2]
    end
    for m,n in ipairs(stat_keys) do
        stat_key = n .. "_sum"
        r[n] = stats:get(stat_key)
    end
    r["count"] = stats:get(v .. "-nb")
    data[v] = r
end
local t = cjson.encode(data)
ngx.say(t)
