# TLB

TCP load balancer with least response time load balancing strategy

# Goal

This project can work with transparent v2ray to select best node with least response time.

# Features

* get upstream servers from subscription
* filter out failure upstream server(will never be used)
* select best backend server with least time for first byte
* select best backend server with highest speed

# Setup

```
docker build -t tlb .
cat > .env <<EOF
PANEL_HOST=example.com
EOF
docker-compose up -d
```

# Config

`app/config.app`

```
local _M = {
    -- load balancing strategy
    lb_method = "max_speed",
    -- time for retry failed server
    lb_retry_time = 300,
    -- backend server port
    server_port = 443,
}

return _M
```

Enjoy!
