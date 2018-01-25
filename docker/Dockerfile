FROM nginx:1.13.6-alpine 

LABEL maintainer="Barry New <niuchp@126.com>"

ARG TZ='Asia/Shanghai'

ENV TZ ${TZ}

RUN apk upgrade --update \
    && apk add bash git \
    && rm -rf /usr/share/nginx/html \
    && git clone https://github.com/niuchp/kago.site.git /usr/share/nginx/html \
    && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone \
    && rm -rf /var/cache/apk/*

ADD entrypoint.sh /entrypoint.sh
COPY default.conf /etc/nginx/conf.d/

WORKDIR /usr/share/nginx/html

CMD ["/entrypoint.sh"]