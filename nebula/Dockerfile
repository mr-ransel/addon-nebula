ARG BUILD_FROM=ghcr.io/hassio-addons/base:14.3.2

FROM ${BUILD_FROM}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Build Nebula
RUN \
    apk add --no-cache --virtual .build-dependencies \
        build-base=0.5-r3 \
        git=2.40.1-r0 \
    \
    && apk add --no-cache \
        go \
        iptables \
        yq \
        bind-tools \
#        libqrencode=4.1.1-r0 \
#        openresolv=3.12.0-r0 \
#        wireguard-tools=1.0.20210914-r0 \
    \
    && git clone --branch "v1.7.2" --depth=1 \
        "https://github.com/slackhq/nebula.git" /tmp/nebula \
    \
    && cd /tmp/nebula \
    && make bin \
    && mv nebula /usr/bin/nebula \
    && mv nebula-cert /usr/bin/nebula-cert \
#    && chmod +x /usr/bin/nebula \
#    && chmod +x /usr/bin/nebula-cert \
    \
    && rm -f -r /tmp/* \
    && apk del --no-cache --purge \
        .build-dependencies \
        go

COPY rootfs /
