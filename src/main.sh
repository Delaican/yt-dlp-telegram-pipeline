#!/bin/bash

# --- Default Configuration ---
DEFAULT_CONFIG_DIR="/app/vpn_config_files"
DEFAULT_CONFIG1=$(find "$DEFAULT_CONFIG_DIR" -name "*.ovpn" | head -1 | xargs basename 2>/dev/null)
DEFAULT_CONFIG2=$(find "$DEFAULT_CONFIG_DIR" -name "*.ovpn" | tail -1 | xargs basename 2>/dev/null)
DEFAULT_URL_FILE="/app/urls/urls.txt"
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

# Load environment variables
source /app/.env

# --- Default Flag Values ---
USE_VPN=false
DO_DOWNLOAD=false
DO_UPLOAD=false
START_COUNT=1
DOWNLOAD_URL=""
UPLOAD_FILE_PATH=""

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    -c, --count NUMBER      Starting line number in the URL file (positive integer)
    -v, --vpn               Enable VPN connection and rotation
    -d, --download          Enable video downloading from URL file
    -t, --upload            Enable uploading to Telegram
    -f, --file PATH         Specify a single file to upload
    
    --config-dir PATH       Directory containing VPN config files (default: $DEFAULT_CONFIG_DIR)
    --config1 FILENAME      Primary VPN config filename (default: $DEFAULT_CONFIG1)
    --config2 FILENAME      Secondary VPN config filename (default: $DEFAULT_CONFIG2)
    --url URL               URL for single download
    --url-file PATH         Path to URL file (default: $DEFAULT_URL_FILE)
    --download-dir PATH     Directory to download videos (default: $DEFAULT_DOWNLOAD_DIR)
    
    -h, --help              Show this help message

EXAMPLES:
    $0 --vpn --download --upload --url-file
    $0 -c 10 -d
    $0 --file /path/to/video.mp4 -t
    $0 --config-dir /custom/path --download --url https://video-url.com

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
        -t|--upload)
            DO_UPLOAD=true
            shift
            ;;
        -f|--file)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: --file requires a file path" >&2
                exit 1
            fi
            UPLOAD_FILE_PATH="$2"
            shift 2
            ;;
        --config-dir)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: --config-dir requires a directory path" >&2
                exit 1
            fi
            CONFIG_DIR="$2"
            CONFIG1="${CONFIG_DIR}/${DEFAULT_CONFIG1}"
            CONFIG2="${CONFIG_DIR}/${DEFAULT_CONFIG2}"
            shift 2
            ;;
        --config1)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: --config1 requires a filename" >&2
                exit 1
            fi
            CONFIG1="${CONFIG_DIR}/$2"
            shift 2
            ;;
        --config2)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: --config2 requires a filename" >&2
                exit 1
            fi
            CONFIG2="${CONFIG_DIR}/$2"
            shift 2
            ;;
        --url)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: --url requires a value" >&2
                exit 1
            fi
            DOWNLOAD_URL="$2"
            shift 2
            ;;
        --url-file)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: --url-file requires a file path" >&2
                exit 1
            fi
            URL_FILE="$2"
            shift 2
            ;;
        --download-dir)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: --download-dir requires a directory path" >&2
                exit 1
            fi
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
    echo "Error: At least one action flag must be provided (-d/--download or -t/--upload)" >&2
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
    if [[ "$DO_DOWNLOAD" == "true" && ! -f "$URL_FILE" && -z "$DOWNLOAD_URL" ]]; then
        echo 'Error: No URL provided: Provide one with --url or with a "urls.txt" file.' >&2
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
    echo -e "\nCleaning up..."
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

handle_vpn_connection() {
    local auth_file="$1"
    local current_config_val="$2"
    local swap="$3"

    if (( ( (current_config_val == 1) && swap ) || ( (current_config_val == 2) && ! swap ) )); then
        connect_vpn "$CONFIG2" "$AUTH_FILE"
        echo 2 # Return new config number
    else
        connect_vpn "$CONFIG1" "$AUTH_FILE"
        echo 1 # Return new config number
    fi
}

# --- Main Logic ---

# Run validation
validate_config

# Show current configuration
show_config

# Scenario 1: Just upload a single file
if [ "$DO_UPLOAD" = true ] && [ "$DO_DOWNLOAD" = false ] && [ -n "$UPLOAD_FILE_PATH" ]; then
    echo "Mode: Single File Upload"
    start_telegram_server || exit 1
    upload_to_telegram "$UPLOAD_FILE_PATH"
    stop_telegram_server
    exit 0
fi

# Scenario 2: Single Download
if [[ $DO_DOWNLOAD = true && -n $DOWNLOAD_URL ]]; then
    echo "Mode: Single Download"

    if [ "$USE_VPN" = true ]; then
        AUTH_FILE=$(mktemp)
        trap 'rm -f "$AUTH_FILE"; exit' EXIT
        echo "$VPN_USERNAME" > "$AUTH_FILE"
        echo "$VPN_PASSWORD" >> "$AUTH_FILE"
        connect_vpn "$CONFIG1" "$AUTH_FILE"
    fi

    download_video "$DOWNLOAD_URL" "$DOWNLOAD_DIR" 0

    cleanup
fi

# --- Scenarios 3: Multiple Processing Loop ---
if { [ "$DO_DOWNLOAD" = true ] || [ "$DO_UPLOAD" = true ]; } && [ -z "$UPLOAD_FILE_PATH" ]; then
    echo "Mode: Multiple Processing (Download/Upload)"

    # --- Setup Phase ---
    if [ "$USE_VPN" = true ]; then
        AUTH_FILE=$(mktemp)
        trap 'rm -f "$AUTH_FILE"; exit' EXIT
        echo "$VPN_USERNAME" > "$AUTH_FILE"
        echo "$VPN_PASSWORD" >> "$AUTH_FILE"
        connect_vpn "$CONFIG1" "$AUTH_FILE"
    fi

    # For download mode, open the URL file on a specific file descriptor for efficient line-by-line reading.
    if [ "$DO_DOWNLOAD" = true ]; then
        exec 3< <(tail -n "+$START_COUNT" "$URL_FILE")
    fi

    if [ "$DO_UPLOAD" ] && [ "$USE_VPN" == "false" ]; then
        start_telegram_server
    fi

    # --- Multiple Processing Loop ---
    current_config=1
    count=$START_COUNT
    iteration=1

    while true; do
        # --- Step 1: Get the next item dynamically based on the mode ---
        item=""
        if [ "$DO_DOWNLOAD" = true ]; then
            # Read the next line from the URL file via the file descriptor.
            # If read fails (end of file), break the loop.
            if ! read -r item <&3; then
                echo "End of URL file reached."
                break
            fi
        else
            # For upload-only mode, find the Nth file on each iteration.
            # This preserves the dynamic discovery of the original script.
            item=$(find "$DOWNLOAD_DIR" -type f -name "*.mp4" -not -name "*.*.*" | sort | sed -n "${count}p")
            # If find returns nothing for the current line number, we're done.
            if [ -z "$item" ]; then
                echo "No more files to process."
                break
            fi
        fi

        echo "--- Processing item #$count (Iteration #$iteration) ---"

        # --- Step 2: Swap VPN to avoid load balancing (every 3 iterations) ---
        if (( iteration > 1 && iteration % 3 == 0 )) && [ "$USE_VPN" = true ]; then
            echo "Swapping VPN..."
            current_config=$(handle_vpn_connection "$AUTH_FILE" "$current_config" 1)
        fi

        # --- Step 3: Core Action ---
        file_to_process=""
        if [ "$DO_DOWNLOAD" = true ]; then
            file_to_process=$(download_video "$item" "$DOWNLOAD_DIR" "$count")
        else
            file_to_process="$item"
        fi

        # --- Step 4: Upload if enabled ---
        if [ "$DO_UPLOAD" = true ]; then
            if [ "$USE_VPN" = true ]; then
                disconnect_vpn
                start_telegram_server || exit 1
            fi
            if [ -n "$file_to_process" ] && [ -f "$file_to_process" ]; then
                if ! upload_to_telegram "$file_to_process"; then
                    echo "CRITICAL: Failed to upload '$file_to_process'."
                    exit 1
                fi
                echo "Successfully uploaded."
            else
                echo "Skipping upload: File not found or download failed."
            fi
            if [ "$USE_VPN" = true ]; then
                stop_telegram_server
                # VPN rotation will happen on next iteration, so there's no need to connect now
                if (( iteration > 1 && iteration % 2 != 0 )); then
                    current_config=$(handle_vpn_connection "$AUTH_FILE" "$current_config" 0)
                fi
            fi
        fi

        count=$((count + 1))
        iteration=$((iteration + 1))
    done

    # Close the file descriptor if it was opened.
    if [ "$DO_DOWNLOAD" = true ]; then
        exec 3<&-
    fi

    echo "Multiple processing loop finished."
    cleanup
    exit 0
fi

# If no valid combination of flags was given
echo "No action specified. Please use flags to define what to do."
usage
