# syntax=docker/dockerfile:1-labs
FROM public.ecr.aws/docker/library/alpine:3.18 AS base
ENV TZ=UTC

# source stage =================================================================
FROM base AS source
WORKDIR /src

# get and extract source from git
ARG VERSION
ADD https://github.com/qbittorrent/qBittorrent.git#release-$VERSION ./

# apply available patches
RUN apk add --no-cache patch
COPY patches ./
RUN find . -name "*.patch" -print0 | sort -z | xargs -t -0 -n1 patch -p1 -i

# build stage ==================================================================
FROM base AS build
WORKDIR /src

# build dependencies
RUN apk add --no-cache build-base cmake libtorrent-rasterbar-dev \
        samurai qt6-qtbase-dev qt6-qtsvg-dev qt6-qttools-dev

# source and build
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

# runtime dependencies
RUN apk add --no-cache tzdata s6-overlay libtorrent-rasterbar \
        qt6-qtbase-sqlite wireguard-tools curl

# copy files
COPY --from=build /build/qbittorrent-nox /app/
COPY ./rootfs /

# run using s6-overlay
ENTRYPOINT ["/init"]
