#!/bin/bash

# Function to download a video from a URL
# Returns the full path of the downloaded file
download_video() {
    local url="$1"
    local output_dir="$2"
    local counter="$3"
    
    local count_string
    count_string=$(printf "%03d" "$counter")
    local output_template="${output_dir}/${count_string}_%(title)s.%(ext)s"
    
    echo "📥 Downloading video #$counter from URL: $url" >&2
    
    # Use --print filename to reliably get the final file path
    local downloaded_file
    downloaded_file=$(yt-dlp \
        -f "best[height<=720]" \
        -o "$output_template" \
        --print filename \
        "$url" 2>&1)
    
    # The actual download happens here, as --print happens after processing
    yt-dlp \
        -f "best[height<=720]" \
        -o "$output_template" \
        "$url" >&2
        
    if [ -f "$downloaded_file" ]; then
        echo "✅ Download complete: $downloaded_file" >&2
        echo "$downloaded_file" # Return the filename
    else
        echo "❌ Download failed for URL: $url" >&2
        return 1
    fi
}
