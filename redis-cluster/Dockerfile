FROM redis:4.0.9
MAINTAINER eaglering <442958506@qq.com>

ADD redis.conf /etc/redis.conf
COPY run.sh /usr/local/bin/run.sh
RUN chmod 755 /usr/local/bin/run.sh

CMD [ "/usr/local/bin/run.sh" ]

ENTRYPOINT [ "bash", "-c" ]