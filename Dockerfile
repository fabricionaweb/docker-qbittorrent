# syntax=docker/dockerfile:1-labs
FROM public.ecr.aws/docker/library/alpine:3.18 AS base

# source stage =================================================================
FROM base AS source

WORKDIR /src
ARG VERSION

# mandatory build-arg
RUN test -n "$VERSION"

# get and extract source from git
ADD https://github.com/qbittorrent/qBittorrent.git#release-$VERSION ./

# dependencies
RUN apk add --no-cache patch

# apply available patches
COPY patches ./
RUN find . -name "*.patch" -print0 | sort -z | xargs -t -0 -n1 patch -p1 -i

# build stage ==================================================================
FROM source AS build

# build dependencies
RUN apk add --no-cache boost-dev build-base cmake libtorrent-rasterbar-dev \
        samurai qt6-qtbase-dev qt6-qtsvg-dev qt6-qttools-dev

# build
RUN cmake -B /build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DSTACKTRACE=OFF \
        -DGUI=OFF \
        -DQT6=ON && \
    cmake --build /build

# runtime stage ================================================================
FROM base

ENV S6_VERBOSITY=0 S6_BEHAVIOUR_IF_STAGE2_FAILS=2 PUID=65534 PGID=65534
WORKDIR /config
VOLUME /config
EXPOSE 8080

# copy files
COPY --from=build /build/qbittorrent-nox /app/qbittorrent-nox
COPY ./rootfs /

# runtime dependencies
RUN apk add --no-cache tzdata s6-overlay libtorrent-rasterbar \
        qt6-qtbase-sqlite wireguard-tools curl

# run using s6-overlay
ENTRYPOINT ["/init"]
