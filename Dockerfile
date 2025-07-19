FROM alpine:3.18 AS builder
# Install build dependencies
RUN apk add --no-cache \
    build-base \
    cmake \
    git \
    openssl-dev \
    zlib-dev \
    linux-headers \
    boost-dev \
    gperf \
    readline-dev

# Build Telegram Bot API in a separate stage (This takes a while)
RUN git clone --recursive https://github.com/tdlib/telegram-bot-api.git /tmp/telegram-bot-api && \
    cd /tmp/telegram-bot-api && \
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release .. && \
    make -j$(nproc) && make install

FROM alpine:3.18
# Install runtime dependencies
RUN apk add --no-cache \
    bash \
    python3 \
    py3-pip \
    openvpn \
    curl \
    ca-certificates \
    bind-tools \
    iproute2 \
    ffmpeg

# Copy the built binary from builder stage
COPY --from=builder /usr/local/bin/telegram-bot-api /usr/local/bin/telegram-bot-api

# Create openvpn directory and download the standard update-resolv-conf script
RUN mkdir -p /etc/openvpn && \
    wget -O /etc/openvpn/update-resolv-conf https://git.launchpad.net/ubuntu/+source/openvpn/plain/debian/update-resolv-conf && \
    chmod +x /etc/openvpn/update-resolv-conf

# Install yt-dlp globally
RUN python3 -m pip install --no-cache-dir -U "yt-dlp[default]"

# Set working directory
WORKDIR /app

# Create downloads directory
RUN mkdir -p /app/downloads

# Default command
CMD ["bash"]
