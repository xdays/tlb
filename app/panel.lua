local http = require "resty.http"
local cjson = require "cjson.safe"
local _M = {}


function _M.panel_client(host, object)
    local httpc = http.new()
    httpc:set_timeout(3000)
    local url = string.format("https://%s/%s", host, object)
    ngx.log(ngx.DEBUG, "get nodes from api: " .. url)
    local r, err = httpc:request_uri(url, { ssl_verify = false, })
    if not r then
        ngx.log(ngx.ERR, "faild to get data from panel: " .. (err or "unknown"))
        return '{"data": []}'
    end
    ngx.log(ngx.DEBUG, "panel result is: " .. r.body)
    return r.body
end

function _M.get_nodes(host)
    return _M.panel_client(host, "nodes")
end 

function _M.generate_rules(host)
    local nodes_data = _M.get_nodes(host)
    local nodes = {}
    for k,v in ipairs(cjson.decode(nodes_data)["data"]) do
        nodes[#nodes+1] = v["add"]
    end
    ngx.log(ngx.DEBUG, "nodes got from panel: " .. cjson.encode(nodes))
    return nodes
end

return _M
