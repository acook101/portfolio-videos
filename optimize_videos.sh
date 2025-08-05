#!/bin/bash

# Video optimization script for portfolio videos
# Target specs: 1-3MB, 3-10 seconds, 720p max, WebM + MP4

echo "🎬 Starting video optimization process..."

# Create output directories if they don't exist
mkdir -p optimized/{webm,mp4,posters}

# Function to optimize a single video
optimize_video() {
    local input_file="$1"
    local base_name=$(basename "$input_file" .mp4)
    
    echo "📹 Processing: $input_file"
    
    # Check if input file exists
    if [[ ! -f "$input_file" ]]; then
        echo "❌ Error: $input_file not found"
        return 1
    fi
    
    # Get video duration to ensure it's within 3-10 seconds
    duration=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input_file" 2>/dev/null)
    duration_int=$(echo "$duration" | cut -d. -f1)
    
    echo "   Duration: ${duration_int}s"
    
    # If video is longer than 10 seconds, we'll trim it to 10 seconds
    trim_option=""
    if (( duration_int > 10 )); then
        trim_option="-t 10"
        echo "   ⚠️  Video longer than 10s, trimming to 10s"
    fi
    
    # Create WebM version (VP9 codec for better compression)
    echo "   🔄 Creating WebM version..."
    ffmpeg -y -i "$input_file" $trim_option \
        -vf "scale='min(1280,iw)':'min(720,ih)':force_original_aspect_ratio=decrease" \
        -c:v libvpx-vp9 -b:v 1M -crf 35 \
        -c:a libopus -b:a 128k \
        -pass 1 -f null /dev/null 2>/dev/null
    
    ffmpeg -y -i "$input_file" $trim_option \
        -vf "scale='min(1280,iw)':'min(720,ih)':force_original_aspect_ratio=decrease" \
        -c:v libvpx-vp9 -b:v 1M -crf 35 \
        -c:a libopus -b:a 128k \
        -pass 2 "optimized/webm/${base_name}.webm" 2>/dev/null
    
    # Clean up pass files
    rm -f ffmpeg2pass-*.log
    
    # Create MP4 version (H.264 for compatibility)
    echo "   🔄 Creating MP4 version..."
    ffmpeg -y -i "$input_file" $trim_option \
        -vf "scale='min(1280,iw)':'min(720,ih)':force_original_aspect_ratio=decrease" \
        -vcodec libx264 -crf 28 -preset slow \
        -movflags +faststart \
        "optimized/mp4/${base_name}.mp4" 2>/dev/null
    
    # Create poster image (first frame after 1 second)
    echo "   🔄 Creating poster image..."
    ffmpeg -y -i "$input_file" -ss 00:00:01 -vframes 1 -q:v 2 \
        "optimized/posters/${base_name}-poster.jpg" 2>/dev/null
    
    # Check file sizes
    if [[ -f "optimized/webm/${base_name}.webm" ]]; then
        webm_size=$(du -h "optimized/webm/${base_name}.webm" | cut -f1)
        echo "   ✅ WebM created: ${webm_size}"
    fi
    
    if [[ -f "optimized/mp4/${base_name}.mp4" ]]; then
        mp4_size=$(du -h "optimized/mp4/${base_name}.mp4" | cut -f1)
        echo "   ✅ MP4 created: ${mp4_size}"
    fi
    
    if [[ -f "optimized/posters/${base_name}-poster.jpg" ]]; then
        echo "   ✅ Poster created"
    fi
    
    echo "   ✨ Completed: $base_name"
    echo ""
}

# Find all MP4 files in the videos directory
echo "🔍 Scanning for video files..."
video_files=(videos/*.mp4)

if [[ ${#video_files[@]} -eq 0 ]] || [[ ! -f "${video_files[0]}" ]]; then
    echo "❌ No MP4 files found in videos/ directory"
    exit 1
fi

echo "📊 Found ${#video_files[@]} video files to process"
echo ""

# Process each video
for video in "${video_files[@]}"; do
    optimize_video "$video"
done

echo "🎉 Video optimization complete!"
echo ""
echo "📁 Output structure:"
echo "   📂 optimized/webm/     - WebM versions (better compression)"
echo "   📂 optimized/mp4/      - MP4 versions (broader compatibility)"
echo "   📂 optimized/posters/  - Poster images"
echo ""
echo "💡 Next steps:"
echo "   1. Test the optimized videos in your browser"
echo "   2. Check file sizes are within 1-3MB target"
echo "   3. Verify video quality meets your standards" 