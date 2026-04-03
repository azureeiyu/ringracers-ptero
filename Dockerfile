# ============================================================
# Dr. Robotnik's Ring Racers - Pterodactyl Compatible Docker Image
# Build: docker build -t trishjoushi/ringracers-ptero:latest .
# Push:  docker push trishjoushi/ringracers-ptero:latest
# ============================================================

FROM debian:bookworm-slim

ARG RINGRACERS_VERSION=2.4

# Create the container user that Pterodactyl expects (UID 1000)
RUN useradd -m -d /home/container -s /bin/bash --uid 1000 container

# Install build dependencies and nginx
RUN apt-get update -y && apt-get install -y \
    git \
    cmake \
    ninja-build \
    build-essential \
    g++ \
    pkg-config \
    libcurl4-openssl-dev \
    zlib1g-dev \
    libpng-dev \
    libogg-dev \
    libvorbis-dev \
    libvpx-dev \
    libopus-dev \
    libsdl2-dev \
    nginx \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# libyuv is not in Debian apt, build it from source
RUN git clone --depth=1 https://chromium.googlesource.com/libyuv/libyuv /tmp/libyuv \
    && mkdir /tmp/libyuv/build \
    && cd /tmp/libyuv/build \
    && cmake .. -DCMAKE_BUILD_TYPE=Release \
    && make -j$(nproc) \
    && make install \
    && rm -rf /tmp/libyuv

# Download and extract game assets to a permanent location
# NOTE: /home/container is wiped by Wings at runtime, so assets go elsewhere
RUN wget -O /tmp/assets.zip \
    "https://github.com/KartKrewDev/RingRacers/releases/download/v${RINGRACERS_VERSION}/Dr.Robotnik.s-Ring-Racers-v${RINGRACERS_VERSION}-Assets.zip" \
    && mkdir -p /usr/share/games/RingRacers \
    && unzip -o /tmp/assets.zip -d /usr/share/games/RingRacers \
    && rm /tmp/assets.zip

# Clone and compile Ring Racers from source
RUN git clone --depth=1 -b v${RINGRACERS_VERSION} \
    https://github.com/KartKrewDev/RingRacers.git /tmp/ringracers \
    && mkdir -p /tmp/ringracers/build \
    && cd /tmp/ringracers/build \
    && cmake .. -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DSRB2_CONFIG_ENABLE_DISCORDRPC=OFF \
    && ninja -j$(nproc) \
    && cp /tmp/ringracers/build/bin/ringracers_v${RINGRACERS_VERSION} /usr/local/bin/ringracers \
    && chmod +x /usr/local/bin/ringracers \
    && rm -rf /tmp/ringracers

# Remove build deps, keep only runtime libraries
RUN apt-get update -y \
    && apt-get purge -y \
        git \
        cmake \
        ninja-build \
        build-essential \
        g++ \
        pkg-config \
        libcurl4-openssl-dev \
        zlib1g-dev \
        libpng-dev \
        libogg-dev \
        libvorbis-dev \
        libvpx-dev \
        libopus-dev \
        libsdl2-dev \
    && apt-get install -y \
        libcurl4 \
        zlib1g \
        libpng16-16 \
        libogg0 \
        libvorbis0a \
        libvpx7 \
        libopus0 \
        libsdl2-2.0-0 \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Replace /var/log/nginx with a symlink to /tmp so nginx can write logs
# without root permissions at runtime
RUN rm -rf /var/log/nginx \
    && ln -s /tmp /var/log/nginx

# Write a clean nginx.conf with all paths pointing to /tmp
RUN printf 'pid /tmp/nginx.pid;\n\nevents {\n    worker_connections 1024;\n}\n\nhttp {\n    access_log /tmp/nginx-access.log;\n    error_log /tmp/nginx-error.log;\n    client_body_temp_path /tmp/nginx-client-body;\n    proxy_temp_path /tmp/nginx-proxy;\n    fastcgi_temp_path /tmp/nginx-fastcgi;\n    uwsgi_temp_path /tmp/nginx-uwsgi;\n    scgi_temp_path /tmp/nginx-scgi;\n    include /tmp/nginx-*.conf;\n}\n' > /etc/nginx/nginx.conf \
    && rm -f /etc/nginx/sites-enabled/default

# Write the nginx server block template
RUN printf 'server {\n    listen HTTP_PORT_PLACEHOLDER;\n    server_name _;\n\n    location /repo/ {\n        alias /home/container/addons/;\n        autoindex on;\n        disable_symlinks off;\n    }\n}\n' > /etc/nginx/nginx-ringracers.conf.template

# Create the entrypoint script
RUN printf '#!/bin/bash\n\
cd /home/container || exit 1\n\
\n\
# Write http_source to ringserv.cfg if HTTP_SOURCE is set\n\
if [ -n "${HTTP_SOURCE}" ] && [ -f /home/container/ringserv.cfg ]; then\n\
    sed -i "/^http_source/d" /home/container/ringserv.cfg\n\
    echo "http_source \\"${HTTP_SOURCE}\\"" >> /home/container/ringserv.cfg\n\
fi\n\
\n\
# Start nginx on HTTP_PORT\n\
if [ -n "${HTTP_PORT}" ]; then\n\
    mkdir -p /tmp/nginx-client-body /tmp/nginx-proxy /tmp/nginx-fastcgi /tmp/nginx-uwsgi /tmp/nginx-scgi\n\
    sed "s/HTTP_PORT_PLACEHOLDER/${HTTP_PORT}/" /etc/nginx/nginx-ringracers.conf.template > /tmp/nginx-ringracers.conf\n\
    nginx -g "daemon off;" &\n\
    echo "Mod file server started on port ${HTTP_PORT}"\n\
fi\n\
\n\
# Build mod file list from addon subdirectories in load order\n\
MODS=""\n\
for f in /home/container/addons/loadfirst/*.* \\n\
          /home/container/addons/chars/*.* \\n\
          /home/container/addons/tracks/*.* \\n\
          /home/container/addons/loadlast/*.*; do\n\
    [ -f "$f" ] && MODS="$MODS $f"\n\
done\n\
\n\
# Parse the Pterodactyl startup command\n\
PARSED=$(echo "${STARTUP}" | sed -e "s/{{/\${/g" -e "s/}}/}/g" | eval echo "$(cat -)")\n\
\n\
# Append mod list if any mods were found\n\
[ -n "$MODS" ] && PARSED="$PARSED -file $MODS"\n\
\n\
printf "\\033[1m\\033[33mcontainer@pterodactyl~ \\033[0m%s\\n" "$PARSED"\n\
\n\
# Run with assets directory pointed at baked-in game data\n\
exec env RINGRACERSDIR=/usr/share/games/RingRacers ${PARSED}\n' > /entrypoint.sh \
    && chmod +x /entrypoint.sh

USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

CMD ["/bin/bash", "/entrypoint.sh"]
