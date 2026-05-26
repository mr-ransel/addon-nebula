ARG BUILD_FROM=ghcr.io/hassio-addons/base/amd64:20.1.1

FROM ${BUILD_FROM}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Docker buildx sets these automatically based on the target --platform.
# The HA build system passes BUILD_FROM per arch; TARGETARCH/TARGETVARIANT
# are used here to select the matching pre-built Nebula binary.
ARG TARGETARCH
ARG TARGETVARIANT

# Install Nebula from pre-built official release binaries.
# Checksums from:
# https://github.com/slackhq/nebula/releases/download/v1.10.3/SHASUM256.txt
RUN \
    case "${TARGETARCH}${TARGETVARIANT}" in \
        "amd64")  NEBULA_ARCH="amd64";  NEBULA_SHA256="99ac335caeb69d02a6b6b00a3d4b5d0a36ec3971df480a1cc50e6db378342955" ;; \
        "arm64")  NEBULA_ARCH="arm64";  NEBULA_SHA256="69b2764b0c27b04e4f3fb47764cf330555beb5a49e62e045ed5f208a14341343" ;; \
        "armv7")  NEBULA_ARCH="arm-7";  NEBULA_SHA256="b4d557a396fd5d62848a5358008f5410f6eb66ea12f7bf8d98193a82b010393f" ;; \
        "armv6")  NEBULA_ARCH="arm-6";  NEBULA_SHA256="3a451e9e8a0ca08811dbaab897f98574e0e79a2a6d017a1cb5640ea35022c1ea" ;; \
        "386")    NEBULA_ARCH="386";    NEBULA_SHA256="5e586f5bc7e6c28abe813ebd765f39405c4a75cb9ea765a49e09bee4366c0d89" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}${TARGETVARIANT}" >&2; exit 1 ;; \
    esac \
    \
    && apk add --no-cache \
        iptables \
        yq \
        bind-tools \
    \
    && wget -qO /tmp/nebula.tar.gz \
        "https://github.com/slackhq/nebula/releases/download/v1.10.3/nebula-linux-${NEBULA_ARCH}.tar.gz" \
    && echo "${NEBULA_SHA256}  /tmp/nebula.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/nebula.tar.gz -C /tmp \
    && mv /tmp/nebula /usr/bin/nebula \
    && mv /tmp/nebula-cert /usr/bin/nebula-cert \
    && rm /tmp/nebula.tar.gz

COPY rootfs /
