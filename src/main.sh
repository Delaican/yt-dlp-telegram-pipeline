#!/bin/bash

# --- Default Configuration ---
DEFAULT_CONFIG_DIR="/app/vpn_config_files"
DEFAULT_CONFIG1=$(find "$DEFAULT_CONFIG_DIR" -name "*.ovpn" | head -1 | xargs basename 2>/dev/null)
DEFAULT_CONFIG2=$(find "$DEFAULT_CONFIG_DIR" -name "*.ovpn" | tail -1 | xargs basename 2>/dev/null)
DEFAULT_URL_FILE="urls.txt"
DEFAULT_DOWNLOAD_DIR="/app/downloads"

# --- Configuration Variables ---
CONFIG_DIR="${CONFIG_DIR:-$DEFAULT_CONFIG_DIR}"
CONFIG1="${CONFIG_DIR}/${DEFAULT_CONFIG1}"
CONFIG2="${CONFIG_DIR}/${DEFAULT_CONFIG2}"
URL_FILE="${URL_FILE:-$DEFAULT_URL_FILE}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-$DEFAULT_DOWNLOAD_DIR}"

# --- Script Setup ---
# Source function libraries
source /app/src/telegram.sh
source /app/src/vpn.sh
source /app/src/downloader.sh

# Load environment variables (API keys, tokens, etc.)
source /app/.env

# --- Default Flag Values ---
USE_VPN=false
DO_DOWNLOAD=false
DO_UPLOAD=false
START_COUNT=1
UPLOAD_FILE_PATH=""

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    -c, --count NUMBER      Starting line number in the URL file (positive integer)
    -v, --vpn               Enable VPN connection and rotation
    -d, --download          Enable video downloading from URL file
    -u, --upload            Enable uploading to Telegram
    -f, --file PATH         Specify a single file to upload
    
    --config-dir PATH       Directory containing VPN config files (default: $DEFAULT_CONFIG_DIR)
    --config1 FILENAME      Primary VPN config filename (default: $DEFAULT_CONFIG1)
    --config2 FILENAME      Secondary VPN config filename (default: $DEFAULT_CONFIG2)
    --url-file PATH         Path to URL file (default: $DEFAULT_URL_FILE)
    --download-dir PATH     Directory to download videos (default: $DEFAULT_DOWNLOAD_DIR)
    
    -h, --help              Show this help message

EXAMPLES:
    $0 --count 1 --vpn --download --upload
    $0 --vpn --download --upload
    $0 -c 5 --file /path/to/video.mp4 --upload
    $0 --config-dir /custom/path --url-file /path/to/urls.txt --download

ENVIRONMENT VARIABLES:
    CONFIG_DIR      Override default config directory
    URL_FILE        Override default URL file path
    DOWNLOAD_DIR    Override default download directory
EOF
    exit 1
}

# --- Flag Parsing ---
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--count)
            if [[ "$2" =~ ^[0-9]+$ ]] && [[ "$2" -gt 0 ]]; then
                START_COUNT="$2"
                shift 2
            else
                echo "Error: --count requires a positive integer" >&2
                exit 1
            fi
            ;;
        -v|--vpn)
            USE_VPN=true
            shift
            ;;
        -d|--download)
            DO_DOWNLOAD=true
            shift
            ;;
        -u|--upload)
            DO_UPLOAD=true
            shift
            ;;
        -f|--file)
            UPLOAD_FILE_PATH="$2"
            shift 2
            ;;
        --config-dir)
            CONFIG_DIR="$2"
            CONFIG1="${CONFIG_DIR}/${DEFAULT_CONFIG1}"
            CONFIG2="${CONFIG_DIR}/${DEFAULT_CONFIG2}"
            shift 2
            ;;
        --config1)
            CONFIG1="${CONFIG_DIR}/$2"
            shift 2
            ;;
        --config2)
            CONFIG2="${CONFIG_DIR}/$2"
            shift 2
            ;;
        --url-file)
            URL_FILE="$2"
            shift 2
            ;;
        --download-dir)
            DOWNLOAD_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

# --- Validation ---
# Check if at least one action flag is provided
if [[ "$DO_DOWNLOAD" == "false" && "$DO_UPLOAD" == "false" ]]; then
    echo "Error: At least one action flag must be provided (-d/--download or -u/--upload)" >&2
    echo "Use -h or --help for usage information."
    exit 1
fi
validate_config() {
    # Check if required source files exist
    for src in "/app/src/telegram.sh" "/app/src/vpn.sh" "/app/src/downloader.sh"; do
        if [[ ! -f "$src" ]]; then
            echo "Error: Required source file not found: $src" >&2
            exit 1
        fi
    done

    # Check if .env file exists
    if [[ ! -f "/app/.env" ]]; then
        echo "Warning: .env file not found. Make sure environment variables are set." >&2
    fi

    # Validate VPN configs if VPN is enabled
    if [[ "$USE_VPN" == "true" ]]; then
        for config in "$CONFIG1" "$CONFIG2"; do
            if [[ ! -f "$config" ]]; then
                echo "Error: VPN config file not found: $config" >&2
                exit 1
            fi
        done
    fi

    # Validate URL file if downloading is enabled
    if [[ "$DO_DOWNLOAD" == "true" && ! -f "$URL_FILE" ]]; then
        echo "Error: URL file not found: $URL_FILE" >&2
        exit 1
    fi

    # Validate upload file if specified
    if [[ -n "$UPLOAD_FILE_PATH" && ! -f "$UPLOAD_FILE_PATH" ]]; then
        echo "Error: Upload file not found: $UPLOAD_FILE_PATH" >&2
        exit 1
    fi

    # Create download directory if it doesn't exist
    if [[ "$DO_DOWNLOAD" == "true" ]]; then
        mkdir -p "$DOWNLOAD_DIR" || {
            echo "Error: Could not create download directory: $DOWNLOAD_DIR" >&2
            exit 1
        }
    fi
}
# --- Display Configuration ---
show_config() {
    echo "=== Configuration ==="
    echo "VPN Enabled: $USE_VPN"
    echo "Download Enabled: $DO_DOWNLOAD"
    echo "Upload Enabled: $DO_UPLOAD"
    echo "Start Count: $START_COUNT"
    [[ -n "$UPLOAD_FILE_PATH" ]] && echo "Upload File: $UPLOAD_FILE_PATH"
    echo "Config Directory: $CONFIG_DIR"
    echo "Primary VPN Config: $CONFIG1"
    echo "Secondary VPN Config: $CONFIG2"
    echo "URL File: $URL_FILE"
    echo "Download Directory: $DOWNLOAD_DIR"
    echo "===================="
}

# --- Cleanup Handler ---
cleanup() {
    echo -e "\n🧹 Cleaning up..."
    [ -n "$TELEGRAM_TEMP_DIR" ] && rm -rf "$TELEGRAM_TEMP_DIR"
    if [ "$USE_VPN" = true ]; then
        disconnect_vpn
    fi
    if [ "$DO_UPLOAD" = true ]; then
        stop_telegram_server
    fi
    if [ -n "$AUTH_FILE" ]; then
        rm -f "$AUTH_FILE"
    fi
    echo "Script terminated."
    exit 0
}
trap cleanup SIGINT SIGTERM

# --- Main Logic ---

# Run validation
validate_config

# Show current configuration
show_config

# Scenario 1: Just upload a single file
if [ "$DO_UPLOAD" = true ] && [ "$DO_DOWNLOAD" = false ] && [ -n "$UPLOAD_FILE_PATH" ]; then
    echo "Mode: Single File Upload"
    start_telegram_server || exit 1
    check_telegram_api || exit 1
    upload_to_telegram "$UPLOAD_FILE_PATH"
    wait_for_telegram_api
    stop_telegram_server
    exit 0
fi

# Scenario 1.5: Only upload multiple files
if [ "$DO_UPLOAD" = true ] && [ "$DO_DOWNLOAD" = false ] && [ -n "$START_COUNT" ] && [ -z "$UPLOAD_FILE_PATH" ]; then
    echo "Mode: Multiple File Upload"
    start_telegram_server || exit 1
    check_telegram_api || exit 1
    # get a list of mp4 files from $START_COUNT
    UPLOAD_FILE_PATH=$(find "$DOWNLOAD_DIR" -type f | sort | sed -n "${START_COUNT},\$ { /.*\.mp4$/p }")
    # loop through each file and upload
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            echo "Uploading file: $file"
            upload_to_telegram "$file"
            wait_for_telegram_api
        else
            echo "File not found: $file"
        fi
        # Update list of files to upload
        UPLOAD_FILE_PATH=$(find "$DOWNLOAD_DIR" -type f | sort | sed -n "${START_COUNT},\$ { /.*\.mp4$/p }")
    done <<< "$UPLOAD_FILE_PATH"
    stop_telegram_server
    exit 0
fi

# Scenario 2: Main processing loop (downloading and/or uploading)
if [ "$DO_DOWNLOAD" = true ]; then
    echo "Mode: Processing from URL file"
    
    # TODO: Probe both vpns to start with the best one

    # Setup for VPN if enabled
    if [ "$USE_VPN" = true ]; then
        AUTH_FILE=$(mktemp)
        trap "rm -f $AUTH_FILE; exit" EXIT # Ensure auth file is cleaned up
        echo "$VPN_USERNAME" > "$AUTH_FILE"
        echo "$VPN_PASSWORD" >> "$AUTH_FILE"
        connect_vpn "$CONFIG1" "$AUTH_FILE"
    fi

    # Setup for Telegram if uploading is enabled
    if [ "$DO_UPLOAD" = true ]; then
        start_telegram_server || exit 1
        check_telegram_api || exit 1
    fi

    current_config=1
    count=$START_COUNT
    iteration=1
    total_lines=$(wc -l < "$URL_FILE")
    remaining_lines=$((total_lines - START_COUNT + 1))

    echo "Processing $remaining_lines URLs starting from line $START_COUNT..."

    while IFS= read -r line; do
        echo "--- Iteration #$iteration (URL line #$count/$total_lines) ---"
        
        # Rotate VPN every 2 iterations if enabled
        if [ "$USE_VPN" = true ] && (( iteration > 1 && (iteration - 1) % 2 == 0 )); then
            if [ $current_config -eq 1 ]; then
                connect_vpn "$CONFIG2" "$AUTH_FILE"
                current_config=2
            else
                connect_vpn "$CONFIG1" "$AUTH_FILE"
                current_config=1
            fi
        fi

        # Download the video
        downloaded_file=$(download_video "$line" "$DOWNLOAD_DIR" "$count")
        
        # Upload if enabled and download was successful
        if [ "$DO_UPLOAD" = true ] && [ -n "$downloaded_file" ] && [ -f "$downloaded_file" ]; then
            upload_to_telegram "$downloaded_file"
        elif [ "$DO_UPLOAD" = true ]; then
            echo "Skipping upload because download failed."
        fi
        
        count=$((count + 1))
        iteration=$((iteration + 1))
    done < <(tail -n +$START_COUNT "$URL_FILE")

    echo "✅ Main processing loop finished."
    cleanup # Run normal cleanup
    exit 0
fi

# If no valid combination of flags was given
echo "No action specified. Please use flags to define what to do."
usage
