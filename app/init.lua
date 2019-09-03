local panel = require "panel"


local servers = ngx.shared.servers
local delay = 5
local handler
local lock = false

function generate_rules()
    local panel_host = os.getenv("PANEL_HOST")
    local rules = panel.generate_rules(panel_host)
    for k,v in ipairs(rules) do
        local metrics = servers:get(v)
        if  metrics == nil then
            ngx.log(ngx.DEBUG, "add server: " .. v)
            local res, err = servers:set(v, 0)
            if res == false then
                ngx.log(ngx.ERR, err)
            end
        end
    end
end

function handler(premature)
    generate_rules()
    if premature then
        return
    end
    local ok, err = ngx.timer.at(delay, handler)
    if not ok then
        ngx.log(ngx.ERR, "failed to create the timer: ", err)
        return
    end
end

if not lock then
    local ok, err = ngx.timer.at(delay, handler)
    if not ok then
        ngx.log(ngx.ERR, "failed to create the timer: ", err)
        return
    end
    lock = true
end
