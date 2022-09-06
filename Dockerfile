FROM debian
COPY . /app
RUN set -x \
 && apt-get update \
 && apt-get --yes install --no-install-recommends apt-utils \
 && apt-get --yes install --no-install-recommends \
# Perl requirements
    perl \

 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
