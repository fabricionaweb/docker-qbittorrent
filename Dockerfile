# syntax=docker/dockerfile:1-labs
FROM public.ecr.aws/docker/library/alpine:3.19 AS base
ENV TZ=UTC
WORKDIR /src

# source stage =================================================================
FROM base AS source

# get and extract source from git
ARG VERSION
ADD https://github.com/qbittorrent/qBittorrent.git#release-$VERSION ./

# apply available patches
# RUN apk add --no-cache patch
# COPY patches ./
# RUN find ./ -name "*.patch" -print0 | sort -z | xargs -t -0 -n1 patch -p1 -i

# build libtorrent =============================================================
FROM base AS build-libtorrent

# build dependencies
RUN apk add --no-cache build-base cmake samurai boost-dev openssl-dev \
    python3-dev py3-setuptools

# get and extract source from git
ARG LIBTORRENT_VERSION=1.2.19
ADD https://github.com/arvidn/libtorrent.git#v$LIBTORRENT_VERSION ./

# build libtorrent
RUN cmake -B /build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_CXX_STANDARD=17 && \
    cmake --build /build && \
    DESTDIR=/build/rootfs cmake --install /build

# build stage ==================================================================
FROM base AS build

# build dependencies
RUN apk add --no-cache build-base cmake samurai boost-dev openssl-dev \
    qt6-qtbase-dev qt6-qtsvg-dev qt6-qttools-dev

# build app
COPY --from=build-libtorrent /build/rootfs/. /
COPY --from=source /src/cmake ./cmake
COPY --from=source /src/dist ./dist
COPY --from=source /src/src ./src
COPY --from=source /src/CMakeLists.txt ./
RUN cmake -B /build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DSTACKTRACE=OFF \
        -DGUI=OFF \
        -DQT6=ON && \
    cmake --build /build && \
    strip /build/qbittorrent-nox

# runtime stage ================================================================
FROM base

ENV S6_VERBOSITY=0 S6_BEHAVIOUR_IF_STAGE2_FAILS=2 PUID=65534 PGID=65534
ENV ENV="/root/.profile"
WORKDIR /config
VOLUME /config
EXPOSE 8080

# copy files
COPY --from=build-libtorrent /build/rootfs/usr/lib/. /usr/lib/
COPY --from=build /build/qbittorrent-nox /app/
COPY ./rootfs/. /

# runtime dependencies
RUN apk add --no-cache tzdata s6-overlay iptables wireguard-tools curl \
        qt6-qtbase-sqlite

# run using s6-overlay
ENTRYPOINT ["/init"]
