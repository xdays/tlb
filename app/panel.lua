local http = require "resty.http"
local cjson = require "cjson.safe"
local common = require "common"
local yaml = require "yaml"
local _M = {}

local stats = ngx.shared.stats
local servers = ngx.shared.servers

function _M.is_ip(str)
    local regex = [[\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b]]
    local m = ngx.re.match(str, regex)
    if m then
        return true
    else
        return false
    end
end

function _M.reslove(host)
    local resolver = require "resty.dns.resolver"
    local ip
    local r, err =
        resolver:new {
        nameservers = {"8.8.8.8", {"8.8.4.4", 53}},
        retrans = 5, -- 5 retransmissions on receive timeout
        timeout = 2000 -- 2 sec
    }

    if not r then
        ngx.say("failed to instantiate the resolver: ", err)
        return
    end

    local answers, err, tries = r:query(host, nil, {})
    if not answers then
        ngx.log(ngx.ERR, "failed to query the DNS server: " .. err)
        ngx.log(ngx.ERR, "retry historie: ", table.concat(tries, "\n  "))
        return
    end

    if answers.errcode then
        ngx.log(ngx.ERR, "server returned error code: ", answers.errcode, ": ", answers.errstr)
    end

    for i, ans in ipairs(answers) do
        if ans.address ~= nil then
            ip = ans.address
            ngx.log(ngx.DEBUG, "dns reslult for " .. host .. " is: " .. ip)
        end
    end
    return ip
end

function _M.send_request(url)
    local httpc = http.new()
    httpc:set_timeout(3000)
    ngx.log(ngx.DEBUG, "get nodes from api: " .. url)
    local r, err = httpc:request_uri(url, {ssl_verify = false})
    if (not r) or r.status ~= 200 then
        ngx.log(ngx.ERR, "failed to get data from panel: " .. (err or "unknown"))
        return nil
    end
    ngx.log(ngx.DEBUG, "panel result is:\n" .. r.body)
    return r.body
end

function _M.get_v2ray_panel_servers(url)
    local servers = {}
    local r = _M.send_request(url)
    if r == nil then
        return servers
    end
    for k, v in ipairs(cjson.decode(r)["data"]) do
        local ip = v["add"]
        local port = v["port"]
        if not _M.is_ip(ip) then
            ngx.log(ngx.DEBUG, "try to reslove " .. ip .. " to ip")
            ip = _M.reslove(ip)
        end
        servers[ip] = port
    end
    ngx.log(ngx.DEBUG, "servers got from v2ray panel: " .. cjson.encode(servers))
    return servers
end

function _M.get_ss_panel_servers(url)
    local servers = {}
    local t = {}
    local r = _M.send_request(url)
    if r ~= nil then
        ngx.log(ngx.DEBUG, "panel response is: " .. r)
        local data = ngx.decode_base64(r)
        t = common.split(data, "\n")
    else
        ngx.log(ngx.ERR, "panel response is nil")
    end
    for k, v in ipairs(t) do
        v = v:gsub("ssr://", "")
        v = v:gsub("_", "/")
        local n_str = ngx.decode_base64(v)
        local n = common.split(n_str, ":")
        local ip = n[1]
        local port = n[2]
        if not _M.is_ip(ip) then
            ngx.log(ngx.DEBUG, "try to reslove " .. ip .. " to ip")
            ip = _M.reslove(ip)
        end
        servers[ip] = port
    end
    ngx.log(ngx.DEBUG, "servers got from ss panel: " .. cjson.encode(servers))
    return servers
end

function _M.get_clash_panel_servers(url)
    local servers = {}
    local r = _M.send_request(url)
    if r == nil then
        return servers
    end
    for k, v in ipairs(yaml.eval(r)["Proxy"]) do
        local name = v["name"]
        local ip = v["server"]
        local port = v["port"]
        if not _M.is_ip(ip) then
            ngx.log(ngx.DEBUG, "try to reslove " .. ip .. " to ip")
            ip = _M.reslove(ip)
        end
        if ip ~= nil then
            servers[ip] = port
        end
    end
    ngx.log(ngx.DEBUG, "servers got from v2ray panel: " .. cjson.encode(servers))
    return servers
end

function _M.get_rules()
    local rules
    local panel_host = os.getenv("PANEL_HOST")
    local panel_type = os.getenv("PANEL_TYPE")
    if panel_type == "v2ray" then
        rules = _M.get_v2ray_panel_servers(panel_host)
    elseif panel_type == "ss" then
        rules = _M.get_ss_panel_servers(panel_host)
    elseif panel_type == "clash" then
        rules = _M.get_clash_panel_servers(panel_host)
    else
        ngx.log(ngx.ERR, "unknown panel type")
    end
    return rules
end

function _M.delete_stats_keys(prefix)
    local all_stats_keys = stats:get_keys()
    for m, n in ipairs(all_stats_keys) do
        if common.startswith(m, prefix) then
            stats:delete(m)
        end
    end
end

function _M.cleanup_rules(rules)
    local saved_servers = servers:get_keys()
    for k, v in pairs(saved_servers) do
        if not common.member(rules, v) then
            ngx.log(ngx.INFO, "delete server that not exist in subscripiton: " .. v)
            servers:delete(v)
            _M.delete_stats_keys(v)
        end
    end
end

function _M.save_rules()
    local rules = _M.get_rules()
    _M.cleanup_rules(rules)
    for k, v in pairs(rules) do
        local status = servers:get(k)
        if status == nil then
            ngx.log(ngx.DEBUG, "add server: " .. k)
            local res, err = servers:set(k, 0)
            if res == false then
                ngx.log(ngx.ERR, err)
            end
            local res, err = stats:set(k .. "-port", v)
            if res == false then
                ngx.log(ngx.ERR, err)
            end
        end
    end
end

return _M
