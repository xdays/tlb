local common = require "common"
local panel = require "panel"
local cjson = require "cjson.safe"
local _M = {}

local stats = ngx.shared.stats
local servers = ngx.shared.servers

function _M.get_rules()
    local rules, err = servers:get_keys()
    if rules == nil then
        ngx.log(ngx.ERR, "rules is nil, " .. err)
    end
    return rules
end

function _M.warm_up(rules)
    ngx.log(ngx.DEBUG, "current upstream list: " .. cjson.encode(rules))
    -- if upstream is not used, just proxy to it to get res time
    for k, v in ipairs(rules) do
        if servers:get(v) == 0 then
            ngx.log(ngx.DEBUG, v .. " has no metric data, so proxy to it")
            return v
        end
    end

    -- if upstream metrics count not great than 10, select one by random
    local need_random = false
    local targets = {}
    for k, v in ipairs(rules) do
        local count = stats:get(v .. "-count")
        if count == nil or count < 10 then
            need_random = true
            targets[#targets+1] = v
        end
    end
    if need_random == true then
        math.randomseed(tostring(os.time()):reverse():sub(1, 6))
        local r_index = math.random(1, #targets)
        ngx.log(ngx.DEBUG, "random number for node selection is " .. r_index)
        local r_target = targets[r_index]
        ngx.log(ngx.DEBUG, "all nodes has too few metrics, select by random to " .. r_target)
        return r_target
    end

    return 
end

function _M.least_ttfb()
    local rules = _M.get_rules()
    local least_res_ttfb = 1000000
    local least_upstream
    local avg_res_ttfb
    local upstream_port 

    local warm_target = _M.warm_up(rules)
    if warm_target ~= nil then
        upstream_port = stats:get(warm_target .. "-port")
        return {warm_target, upstream_port}
    end

    -- select upstream that res time is least
    for k, v in ipairs(rules) do
        local avg_res_ttfb_key = v .. "-ttfb"
        avg_res_ttfb = stats:get(avg_res_ttfb_key)
        ngx.log(ngx.DEBUG, v .. " current res ttfb is " .. avg_res_ttfb)
        if avg_res_ttfb < least_res_ttfb then
            least_res_ttfb = avg_res_ttfb
            least_upstream = v
        end
    end
    ngx.log(ngx.INFO, least_upstream .. " is best upstream now as its res ttfb is " .. avg_res_ttfb)
    upstream_port = stats:get(least_upstream.. "-port")
    return {least_upstream, upstream_port}
end

function _M.max_speed()
    local rules = _M.get_rules()
    local max_res_speed = 0
    local fastest_upstream
    local avg_res_speed
    local upstream_port 

    -- repeat
    --     ngx.log(ngx.DEBUG, "there is no rule, so generate and save rules")
    --     rules = _M.get_rules()
    -- until #rules > 0

    local warm_target = _M.warm_up(rules)
    if warm_target ~= nil then
        upstream_port = stats:get(warm_target .. "-port")
        return {warm_target, upstream_port}
    end

    -- select upstream that is fastest
    for k, v in ipairs(rules) do
        local avg_res_speed_key = v .. "-speed" 
        avg_res_speed = stats:get(avg_res_speed_key)
        ngx.log(ngx.DEBUG, v .. " current speed is " .. avg_res_speed)
        if avg_res_speed > max_res_speed then
            max_res_speed = avg_res_speed
            fastest_upstream = v
        end
    end
    ngx.log(ngx.INFO, fastest_upstream .. " is best upstream now as its speed is " .. avg_res_speed)
    upstream_port = stats:get(fastest_upstream .. "-port")
    return {fastest_upstream, upstream_port}
end

function _M.round_robin()
    return
end

function _M.random()
    return
end

return _M
