FROM alpine:3.7
MAINTAINER eaglering <442958506@qq.com>

ENV NGROKD_DOMAIN="dns.fastapi.com.cn"
ENV NGROKD_HTTP_ADDR=80
ENV NGROKD_HTTPS_ADDR=443
ENV NGROKD_TUNNEL_ADDR=4443

COPY ngrokd /usr/local/bin/

RUN chmod 755 /usr/local/bin/ngrokd

CMD /usr/local/bin/ngrokd -domain=${NGROKD_DOMAIN} -httpAddr=:${NGROKD_HTTP_ADDR} -httpsAddr=:${NGROKD_HTTPS_ADDR} -tunnelAddr=:${NGROKD_TUNNEL_ADDR}
