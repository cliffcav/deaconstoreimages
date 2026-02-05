#!/bin/bash

# Create JPG preview images alongside TIF files
# Previews will be smaller and web-friendly for GitHub browsing
# Original TIFs remain unchanged for Shopify uploads

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SOURCE_DIR="./Beauveste"
QUALITY=85  # JPG quality (85 is good balance)
MAX_WIDTH=1200  # Max width for preview (keeps aspect ratio)

# Check if ImageMagick is installed
if ! command -v magick &> /dev/null; then
    echo -e "${RED}Error: ImageMagick is not installed${NC}"
    echo "Please install it with: brew install imagemagick"
    exit 1
fi

# Count total TIF files
TOTAL_FILES=$(find "$SOURCE_DIR" -maxdepth 1 \( -name "*.tif" -o -name "*.tiff" \) 2>/dev/null | wc -l | xargs)

if [ "$TOTAL_FILES" -eq 0 ]; then
    echo -e "${YELLOW}No TIF files found in $SOURCE_DIR${NC}"
    exit 0
fi

echo "========================================"
echo "Creating JPG Preview Images"
echo "========================================"
echo "Source directory: $SOURCE_DIR"
echo "Total files: $TOTAL_FILES"
echo "Quality: $QUALITY"
echo "Max width: ${MAX_WIDTH}px"
echo "========================================"
echo ""

# Ask for confirmation
read -p "Proceed with preview creation? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Preview creation cancelled"
    exit 0
fi

# Counters
SUCCESS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
CURRENT=0

while IFS= read -r file; do
    CURRENT=$((CURRENT + 1))
    BASENAME=$(basename "$file")
    # Remove extension and add .jpg
    OUTPUT_FILE="${file%.*}.jpg"

    # Skip if preview already exists
    if [ -f "$OUTPUT_FILE" ]; then
        echo -e "${YELLOW}[$CURRENT/$TOTAL_FILES]${NC} Skipping: $BASENAME (preview exists)"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        continue
    fi

    echo -e "${YELLOW}[$CURRENT/$TOTAL_FILES]${NC} Creating preview: $BASENAME"

    # Create JPG preview with ImageMagick
    # [0]: only use first page/layer (handles multi-layer EPS files)
    # -resize: constrains to max width, maintains aspect ratio
    # -quality: JPG quality setting
    # -strip: remove metadata to reduce file size
    # -auto-orient: fix rotation based on EXIF
    if magick "$file[0]" -resize "${MAX_WIDTH}x>" -quality "$QUALITY" -strip -auto-orient "$OUTPUT_FILE" 2>/dev/null; then
        if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
            ORIGINAL_SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
            NEW_SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null)
            REDUCTION=$(echo "scale=1; 100 - ($NEW_SIZE * 100 / $ORIGINAL_SIZE)" | bc 2>/dev/null || echo "N/A")

            # Get dimensions
            DIMS=$(identify -format "%wx%h" "$OUTPUT_FILE" 2>/dev/null || echo "unknown")

            echo -e "${GREEN}✓ Success${NC} - ${DIMS}, Size reduction: ${REDUCTION}%"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            echo -e "${RED}✗ Failed${NC} - Output file is empty or missing"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            rm -f "$OUTPUT_FILE"
        fi
    else
        echo -e "${RED}✗ Failed${NC} - Conversion error"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi

    echo ""
done < <(find "$SOURCE_DIR" -maxdepth 1 \( -name "*.tif" -o -name "*.tiff" \) 2>/dev/null | sort)

# Summary
echo "========================================"
echo "Preview Creation Complete"
echo "========================================"
echo -e "Successfully created: ${GREEN}$SUCCESS_COUNT${NC}"
echo -e "Skipped (already exist): ${YELLOW}$SKIP_COUNT${NC}"
echo -e "Failed: ${RED}$FAIL_COUNT${NC}"
echo "========================================"
echo ""
echo "Note: Original TIF files are unchanged and ready for Shopify upload"
