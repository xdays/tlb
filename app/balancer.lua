local schedule = require "schedule"
local balancer = require "ngx.balancer"
local cjson = require "cjson.safe"
local config = require "config"

local target
local port = config.server_port
if config.lb_method == "least_ttfb" then
    target = schedule.least_ttfb()
elseif config.lb_method == "max_speed" then
    target = schedule.max_speed()
end

ngx.log(ngx.INFO, string.format("proxy request to %s\n", target))
local ok, err = balancer.set_current_peer(target, port)
if not ok then
    ngx.log(ngx.ERR, "failed to set the current peer: ", err)
end
