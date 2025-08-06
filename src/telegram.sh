#!/bin/bash

start_telegram_server() {
    local pid_file="/tmp/telegram_bot_api.pid"
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" &>/dev/null; then
        echo "Telegram Bot API server is already running."
        return 0
    fi

    echo "Starting Telegram Bot API server..."
    telegram-bot-api \
        --api-id="$API_ID" \
        --api-hash="$API_HASH" \
        --local \
        --http-port=8081 \
        &>/dev/null &

    local server_pid=$!
    echo "$server_pid" > "$pid_file"
    
    sleep 10 # Wait for the server to fully initialize

    if kill -0 "$server_pid" &>/dev/null; then
        echo "Telegram Bot API server started (PID: $server_pid)."
    else
        echo "Failed to start Telegram Bot API server."
        rm -f "$pid_file"
        return 1
    fi
}

stop_telegram_server() {
    local pid_file="/tmp/telegram_bot_api.pid"
    if [ ! -f "$pid_file" ]; then return; fi

    local pid=$(cat "$pid_file")
    if kill -0 "$pid" &>/dev/null; then
        echo "Stopping Telegram Bot API server (PID: $pid)..."
        kill "$pid"
        sleep 3
        # Force kill if it's still running
        if kill -0 "$pid" &>/dev/null; then
            kill -9 "$pid"
        fi
        echo "Telegram Bot API server stopped."
    fi
    rm -f "$pid_file"
}

restart_telegram_server() {
    echo "Restarting Telegram Bot API server..."
    stop_telegram_server
    start_telegram_server
}

# Generates the expected caption (e.g., "E001") from a filename.
generate_caption() {
    local filename
    filename=$(basename "$1")
    echo "$filename" | sed 's/^\([0-9]\+\)_\(.*\)\.mp4$/E\1/'
}

# Uploads a file, handling all retries and server restarts internally.
upload_to_telegram() {
    local file_path="$1"

    if [ ! -f "$file_path" ]; then
        echo "File to upload not found: $file_path"
        return 1
    fi

    local filename
    filename=$(basename "$file_path")
    local expected_caption
    expected_caption=$(generate_caption "$file_path")

    echo "Uploading '$filename'"

    local curl_exit_code
    curl -s -X POST \
        --max-time 7200 \
        --show-error \
        "$TELEGRAM_API_URL/bot$TELEGRAM_BOT_TOKEN/sendVideo" \
        -F "chat_id=$TELEGRAM_CHAT_ID" \
        -F "video=@$file_path;type=video/mp4" \
        -F "caption=$expected_caption" \
        -F "supports_streaming=true" >/dev/null

    curl_exit_code=$?

    case $curl_exit_code in
        0)
            echo "Upload successful."
            echo "Cooling down for 15 seconds..."
            sleep 15
            return 0 # SUCCESS
            ;;
        52)
            echo "Asynchronous upload detected (Code 52)."
            echo "Waiting 5 minutes for the upload to complete..."
            sleep 300
            echo "Restarting Telegram server..."
            restart_telegram_server
            return 0 # SUCCESS
            ;;
        *)
            echo "Upload failed with code $curl_exit_code. Skipping file."
            return 1 # FAILURE
            ;;
    esac
}
