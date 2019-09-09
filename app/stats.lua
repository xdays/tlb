local common = require "common"
local cjson = require "cjson.safe"
local config = require "config"

local stats = ngx.shared.stats
local servers = ngx.shared.servers

local upstream_addr = common.split(ngx.var.upstream_addr, ":")[1]
local t = {
    bytes_received = ngx.var.upstream_bytes_received,
    ttfb_time = ngx.var.upstream_first_byte_time,
    total_time = ngx.var.upstream_session_time,
}
local r = {}

ngx.log(ngx.DEBUG, string.format("upstream %s metrics: {total:%s, ttfb: %s, size: %s}\n", 
    upstream_addr, t.total_time, t.ttfb_time, t.bytes_received))

if t.ttfb_time == "-" then
    t.ttfb_time = "1000"
end

for k,v in pairs(t) do
    local metric_value = tonumber(v)
    t[k] = metric_value
    local metric_key = upstream_addr .. "-" .. k .. "_sum"
    local sum = stats:get(metric_key) or 0
    sum = sum + metric_value
    r[k] = sum
    stats:set(metric_key, sum)
end

local count_key = upstream_addr .. "-count"
local avg_res_ttfb_key = upstream_addr .. "-ttfb"
local avg_res_speed_key = upstream_addr .. "-speed" 
local expire_time = 0
local avg_res_ttfb
local avg_res_speed
-- fail fast for unavailable upstream 
if t.ttfb_time == 1000 then
    -- retry after some time
    stats:set(upstream_addr .. "-ttfb_time_sum", 10000, config.lb_retry_time - 5)
    stats:set(count_key, 10, config.lb_retry_time - 5)
    avg_res_ttfb = t.ttfb_time
    expire_time = config.lb_retry_time
else
    local newval, err = stats:incr(count_key, 1)
    if not newval and err == "not found" then
        stats:add(count_key, 0)
        stats:incr(count_key, 1)
    end
    avg_res_ttfb = r.ttfb_time/stats:get(count_key)
end
stats:set(avg_res_ttfb_key, avg_res_ttfb)
avg_res_speed = r.bytes_received/r.total_time
stats:set(avg_res_speed_key, avg_res_speed)
ngx.log(ngx.INFO, string.format("upstream %s quality: {avg_res_ttfb: %s, avg_res_speed: %s}\n",
    upstream_addr, avg_res_ttfb, avg_res_speed))
servers:set(upstream_addr, 1)
