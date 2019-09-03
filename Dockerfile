FROM ubuntu

ENV OPENRESTY_ROOT="/usr/local/openresty"
ENV PATH=$OPENRESTY_ROOT/bin:$OPENRESTY_ROOT/nginx/sbin:$OPENRESTY_ROOT/luajit/bin:$PATH 

RUN apt-get update && apt-get -y install curl software-properties-common && \
    curl -qo - https://openresty.org/package/pubkey.gpg | apt-key add - && \
    add-apt-repository -y "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main" && \
    apt-get -qq update && \
    apt-get install -y openresty && \
    opm get ledgetech/lua-resty-http && \
    rm -rf /var/lib/apt/lists/*

ADD app ${OPENRESTY_ROOT}/nginx/app
ADD nginx.conf $OPENRESTY_ROOT/nginx/conf

WORKDIR $OPENRESTY_ROOT
EXPOSE 80 443

CMD ["nginx"]
