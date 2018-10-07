FROM ubuntu:18.04
MAINTAINER Schlomo Schapiro

RUN apt-get update
RUN apt-get -y -q install curl gnupg
RUN curl --silent --location --remote-name http://apt.ntop.org/18.04/all/apt-ntop.deb && \
    apt-get -y -q install ./apt-ntop.deb && \
    rm -f apt-ntop.deb

RUN apt-get update && \
    apt-get -y -q install ntopng

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

EXPOSE 3000

RUN echo '#!/bin/bash\nredis-server </dev/null &\nexec ntopng "$@"' > /tmp/run.sh && \
    chmod +x /tmp/run.sh

ENTRYPOINT ["/tmp/run.sh"]