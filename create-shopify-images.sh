#!/bin/bash

# Create high-quality JPG images for Shopify uploads
# Converts TIF to JPG with proper CMYK->RGB conversion
# Maintains full resolution for product detail

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SOURCE_DIR="./Beauveste"
OUTPUT_DIR="./Beauveste/shopify"
QUALITY=98  # Very high quality for product images

# Check if ImageMagick is installed
if ! command -v magick &> /dev/null; then
    echo -e "${RED}Error: ImageMagick is not installed${NC}"
    echo "Please install it with: brew install imagemagick"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Count total TIF files
TOTAL_FILES=$(find "$SOURCE_DIR" -maxdepth 1 \( -name "*.tif" -o -name "*.tiff" \) 2>/dev/null | wc -l | xargs)

if [ "$TOTAL_FILES" -eq 0 ]; then
    echo -e "${YELLOW}No TIF files found in $SOURCE_DIR${NC}"
    exit 0
fi

echo "========================================"
echo "Creating Shopify-Ready JPG Images"
echo "========================================"
echo "Source directory: $SOURCE_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "Total files: $TOTAL_FILES"
echo "Quality: $QUALITY% (very high)"
echo "Resolution: Full (no resizing)"
echo "========================================"
echo ""
echo "Note: CMYK->RGB conversion will cause some"
echo "color shift. This is normal for web display."
echo ""

# Ask for confirmation
read -p "Proceed with conversion? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Conversion cancelled"
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
    FILENAME="${BASENAME%.*}"
    OUTPUT_FILE="$OUTPUT_DIR/${FILENAME}.jpg"

    # Skip if already exists
    if [ -f "$OUTPUT_FILE" ]; then
        echo -e "${YELLOW}[$CURRENT/$TOTAL_FILES]${NC} Skipping: $BASENAME (already exists)"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        continue
    fi

    echo -e "${YELLOW}[$CURRENT/$TOTAL_FILES]${NC} Converting: $BASENAME"

    # Convert TIF to JPG with high quality
    # [0]: only use first page/layer (handles multi-layer EPS files)
    # -colorspace sRGB: proper CMYK to RGB conversion
    # -quality: JPG quality setting (98 = very high)
    # -strip: remove metadata to reduce file size
    # -auto-orient: fix rotation based on EXIF
    if magick "$file[0]" -colorspace sRGB -quality "$QUALITY" -strip -auto-orient "$OUTPUT_FILE" 2>/dev/null; then
        if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
            ORIGINAL_SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
            NEW_SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null)
            REDUCTION=$(echo "scale=1; 100 - ($NEW_SIZE * 100 / $ORIGINAL_SIZE)" | bc 2>/dev/null || echo "N/A")

            # Get dimensions
            DIMS=$(identify -format "%wx%h" "$OUTPUT_FILE" 2>/dev/null || echo "unknown")

            # Convert size to MB for readability
            NEW_SIZE_MB=$(echo "scale=1; $NEW_SIZE / 1024 / 1024" | bc 2>/dev/null || echo "?")

            echo -e "${GREEN}✓ Success${NC} - ${DIMS}, ${NEW_SIZE_MB}MB (${REDUCTION}% reduction)"
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
echo "Conversion Complete"
echo "========================================"
echo -e "Successfully created: ${GREEN}$SUCCESS_COUNT${NC}"
echo -e "Skipped (already exist): ${YELLOW}$SKIP_COUNT${NC}"
echo -e "Failed: ${RED}$FAIL_COUNT${NC}"
echo "========================================"
echo ""
echo "Shopify-ready images are in: $OUTPUT_DIR"
echo "Upload these JPG files to Shopify."
