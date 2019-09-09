# TLB

TCP load balancer with least response time load balancing strategy

# Goal

This project can work with v2ray and ssr to select best node with least response time or network speed.

# Features

* get upstream servers from subscription
* filter out failure upstream server
* select best backend server with least time for first byte
* select best backend server with highest speed

# Setup

```
docker build -t tlb .
cat > .env <<EOF
PANEL_HOST=example.com # subscription url
PANEL_TYPE=v2ray # use ss for ss
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
}

return _M
```

Enjoy!
