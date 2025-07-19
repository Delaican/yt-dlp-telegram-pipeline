#!/bin/bash

# Function to start the local Telegram Bot API server
start_telegram_server() {
    local pid_file="/tmp/telegram_bot_api.pid"
    
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        echo "✅ Telegram Bot API server is already running."
        return 0
    fi

    TELEGRAM_TEMP_DIR=$(mktemp -d)

    echo "🚀 Starting Telegram Bot API server..."
    telegram-bot-api \
        --api-id="$API_ID" \
        --api-hash="$API_HASH" \
        --local \
        --http-port=8081 \
        --dir="$TELEGRAM_TEMP_DIR" \
        >/dev/null 2>&1 &
    
    local server_pid=$!
    echo $server_pid > "$pid_file"
    sleep 5 # Wait for server to initialize
    
    if kill -0 $server_pid 2>/dev/null; then
        echo "✅ Telegram Bot API server started (PID: $server_pid)."
        return 0
    else
        echo "❌ Failed to start Telegram Bot API server."
        rm -f "$pid_file"
        return 1
    fi
}

# Function to stop the local Telegram Bot API server
stop_telegram_server() {
    local pid_file="/tmp/telegram_bot_api.pid"
    
    if [ -f "$pid_file" ]; then
        local pid
        pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo "🛑 Stopping Telegram Bot API server..."
            kill "$pid"
            rm -f "$pid_file"
            echo "✅ Telegram Bot API server stopped."
        else
            # Clean up stale PID file
            rm -f "$pid_file"
        fi
    fi
}

# Function to check if the Telegram API server is accessible
check_telegram_api() {
    if ! curl -s "$TELEGRAM_API_URL/bot$TELEGRAM_BOT_TOKEN/getMe" > /dev/null; then
        echo "❌ Telegram Bot API server not accessible at $TELEGRAM_API_URL."
        echo "Please ensure it's running and configured correctly."
        return 1
    else
        echo "✅ Telegram Bot API server is accessible."
        return 0
    fi
}

wait_for_telegram_api() {
    local max_attempts=30
    local wait_seconds=10
    local attempt=0

    echo "⏳ Waiting for pending uploads to complete..."
    while [ $attempt -lt $max_attempts ]; do
        if curl -s "$TELEGRAM_API_URL/bot$TELEGRAM_BOT_TOKEN/getUpdates" > /dev/null; then
            echo "✅ Telegram API is responsive again"
            return 0
        fi
        echo "⏳ Attempt $((attempt+1))/$max_attempts: API not ready yet..."
        sleep $wait_seconds
        attempt=$((attempt+1))
    done

    echo "❌ Telegram API did not respond after $((max_attempts * wait_seconds)) seconds"
    return 1
}

# Function to upload a video file to Telegram
upload_to_telegram() {
    local file_path="$1"
    
    if [ ! -f "$file_path" ]; then
        echo "❌ File to upload not found: $file_path"
        return 1
    fi

    local filename
    filename=$(basename "$file_path")

    # Format caption: "001_Title-Goes-Here.mp4" -> "E001"
    local formatted_caption
    formatted_caption=$(echo "$filename" | sed 's/^\([0-9]\+\)_\(.*\)\.mp4$/E\1/')
    
    echo "📤 Uploading $filename to Telegram..."

    local file_size
    file_size=$(du -h "$file_path" | cut -f1)
    echo "File size: $file_size"

    # Log upload attempt with timestamp
    echo "🕐 Upload started at: $(date)"
    
    local response
    local curl_exit_code
    
    # Use a temporary file to capture curl's stderr
    local curl_stderr_file
    curl_stderr_file=$(mktemp)
    
    response=$(curl -s -X POST \
        --max-time 3600 \
        --connect-timeout 60 \
        --show-error \
        --fail-with-body \
        "$TELEGRAM_API_URL/bot$TELEGRAM_BOT_TOKEN/sendVideo" \
        -F "chat_id=$TELEGRAM_CHAT_ID" \
        -F "video=@$file_path;type=video/mp4" \
        -F "caption=$formatted_caption" \
        -F "supports_streaming=true" \
        2>"$curl_stderr_file")
    
    curl_exit_code=$?
    
    echo "🕐 Upload finished at: $(date)"
    echo "curl exit code: $curl_exit_code"
    
    # Show curl stderr if there were errors
    if [ $curl_exit_code -ne 0 ]; then
        echo "curl stderr:"
        cat "$curl_stderr_file"
    fi
    
    # Clean up temp file
    rm -f "$curl_stderr_file"

    if [ $curl_exit_code -eq 0 ] || [ $curl_exit_code -eq 52 ]; then
        echo "⚠️ Got empty response but upload might succeed in background"
        return 0
    elif [ -z "$response" ]; then
        echo "⚠️ No response from Telegram API"
        return 1
    fi
    
    # Check for specific error patterns
    if echo "$response" | grep -q '"ok":true'; then
        echo "✅ Successfully uploaded $filename."
        return 0
    else
        echo "❌ Failed to upload $filename."
        echo "Full Response: $response"
        return 1
    fi
}
