ARG BASE_IMAGE=alpine:3.24.2

FROM $BASE_IMAGE

# Reproducibility: the installed OpenDKIM version is pinned.
# The "~=" component-wise match accepts Alpine package rebuilds of the same
# upstream version (2.11.0-rX) but rejects 2.11.1 / 2.11.01 / 2.1.x, so a
# later rebuild is guaranteed to install the planned OpenDKIM version or fail
# loudly. Both packages are pinned (opendkim and opendkim-utils) because they
# are built from the same upstream release and must match.
ARG OPENDKIM_VERSION=2.11.0

RUN apk update && \
    apk add \
    "opendkim~=${OPENDKIM_VERSION}" \
    "opendkim-utils~=${OPENDKIM_VERSION}" \
    supervisor \
    rsyslog \
    && rm -rf /var/cache/apk/* \
    &&  mkdir -p /run/opendkim/ /data/log/ /var/spool/rsyslog/

COPY rootfs/ /


# Safety net: the build fails loudly if the planned OpenDKIM version was not
# installed (e.g. when the version pins are changed later by mistake)
RUN test "$(opendkim -V 2>&1 | head -n 1 | sed 's/.*v//')" = "${OPENDKIM_VERSION}" \
    || { echo "ERROR: expected OpenDKIM ${OPENDKIM_VERSION}, got: $(opendkim -V 2>&1 | head -n 1)"; exit 1; }


ARG URL
ARG SOURCE
ARG BUILD_DATE
ARG AUTHORS
ARG VENDOR
ARG REVISION
ARG OS_VERSION
ARG BASE_IMAGE
#ARG BASE_DIGEST

# https://github.com/opencontainers/image-spec/blob/master/annotations.md
LABEL "org.opencontainers.image.title"="OpenDKIM"
LABEL "org.opencontainers.image.description"="OpenDKIM milter on $OS_VERSION"
LABEL "org.opencontainers.image.url"="$URL"
LABEL "org.opencontainers.image.source"="$SOURCE"
LABEL "org.opencontainers.image.version"="$OPENDKIM_VERSION"
LABEL "org.opencontainers.image.revision"="$REVISION"
LABEL "org.opencontainers.image.licenses"="MIT"
LABEL "org.opencontainers.image.created"="$BUILD_DATE"
LABEL "org.opencontainers.image.authors"="$AUTHORS"
LABEL "org.opencontainers.image.vendor"="$VENDOR"
LABEL "org.opencontainers.image.base.name"="$BASE_IMAGE"
#LABEL "org.opencontainers.image.base.digest"="$BASE_DIGEST"

VOLUME ["/data"]
EXPOSE 8891

CMD ["/usr/bin/supervisord", "--nodaemon", "--configuration", "/etc/supervisord.conf"]