# Video Downloader & Telegram Uploader

A containerized solution that automates video downloading from URL lists and uploads them to Telegram channels. Features VPN rotation for bypassing geo-restrictions and uses a local Telegram Bot API server to handle large file uploads.

## Key Features

**Video Processing**
- Batch download videos from URL lists using yt-dlp
- Automatic upload to Telegram channels and groups
- Support for large file uploads via local Telegram Bot API server

**VPN & Security**
- Built-in VPN support for bypassing geo-restrictions
- Automatic VPN rotation to distribute load across servers
- Clean connection handling and resource cleanup

**Deployment & Configuration**
- Fully containerized with Docker (Alpine Linux base)
- Multi-stage build process for efficient container creation
- Development setup with mounted source directories
- Flexible configuration via environment variables and CLI flags

## Quick Start

### Prerequisites
- Docker and Docker Compose
- VPN configuration files (.ovpn format)
- Telegram bot token and API credentials

### Setup

1. **Configure VPN files**
   ```bash
   # Place your .ovpn files in the VPN config directory
   cp your-vpn-configs/*.ovpn vpn_config_files/
   ```

2. **Prepare video URLs**
   ```bash
   # Add URLs to download (one per line)
   echo "https://example.com/video1" >> urls.txt
   echo "https://example.com/video2" >> urls.txt
   ```

3. **Configure environment**
   ```bash
   # Copy and fill out the environment template
   cp .env.example .env
   # Edit .env with your credentials (see Configuration section)
   ```

4. **Build and run**
   ```bash
   # Start the application
   docker compose up
   
   # Begin processing
   ./run.sh -c 1 -d
   ```

> **First Build Notice:** Initial container build takes several minutes due to the Telegram Bot API server compilation. Subsequent builds are much faster thanks to multi-stage caching.

## Configuration

### Environment Variables (.env)

Create a `.env` file with the following required variables:

```env
# Telegram Bot Configuration
TELEGRAM_BOT_TOKEN=your_bot_token_here
TELEGRAM_CHAT_ID=@your_channel_or_chat_id
TELEGRAM_API_URL=http://localhost:8081

# Telegram API Credentials (from https://my.telegram.org)
API_ID=your_api_id
API_HASH=your_api_hash

# VPN Credentials
VPN_USERNAME=your_vpn_username
VPN_PASSWORD=your_vpn_password
```

### Command Line Options

The `run.sh` script supports various flags for customizing behavior:

**Basic Operations**
- `-d, --download` - Enable video downloading
- `-u, --upload` - Enable video uploading to Telegram
- `-v, --vpn` - Enable VPN rotation

**File Management**
- `-c, --count NUMBER` - Start processing from line NUMBER in URLs file
- `-f, --file PATH` - Upload a single specific file
- `--url-file PATH` - Use custom URLs file (default: urls.txt)
- `--download-dir PATH` - Set custom download directory
- `--config-dir PATH` - Set custom VPN config directory

**Usage Examples**

```bash
# Download and upload starting from line 5 with VPN rotation
./run.sh -c 5 -v -d -u

# Upload a single file without downloading
./run.sh -u -f /path/to/video.mp4

# Download only, no upload, starting from line 10
./run.sh -c 10 -d
```

## Docker Architecture

**Container Features**
- Alpine Linux base for minimal footprint
- Multi-stage build separating Telegram API server compilation
- Mounted volumes for persistent data and configuration
- Network privileges for VPN functionality

**Volume Mounts**
- Downloads: `$HOME/Videos` (configurable)
- VPN configs: `./vpn_config_files` 
- URL list: `./urls.txt`   
- Environment: `./.env` 
- Source code: `./src` 

**Network Requirements**
- `NET_ADMIN` capability for VPN operations
- `/dev/net/tun` device access for tunnel creation

## Dependencies

**Core Technologies**
- [Docker](https://docker.com) - Containerization platform
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) - Video download engine
- [Telegram Bot API](https://github.com/tdlib/telegram-bot-api) - Local API server for large uploads

**System Requirements**
- OpenVPN - VPN client functionality
- Linux/macOS with Docker support
