#!/bin/bash

# Cloudinary Cleanup Cron Jobs Removal Script
# This script removes the automated Cloudinary cleanup cron jobs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Removing Cloudinary cleanup cron jobs...${NC}"

# Create temporary crontab file
TEMP_CRON=$(mktemp)

# Backup existing crontab
echo "Backing up existing crontab..."
crontab -l > "$TEMP_CRON" 2>/dev/null || echo "# Empty crontab" > "$TEMP_CRON"

# Check if our cron jobs exist
if ! grep -q "KiloShare Cloudinary" "$TEMP_CRON"; then
    echo -e "${YELLOW}No KiloShare Cloudinary cron jobs found.${NC}"
    rm "$TEMP_CRON"
    exit 0
fi

# Show current cron jobs that will be removed
echo -e "${YELLOW}The following cron jobs will be REMOVED:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
grep -A 10 "KiloShare Cloudinary" "$TEMP_CRON" || true
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Ask for confirmation
read -p "Are you sure you want to remove these cron jobs? (y/N): " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Removal cancelled.${NC}"
    rm "$TEMP_CRON"
    exit 0
fi

# Create new crontab without our entries
TEMP_CRON_NEW=$(mktemp)

# Copy everything except our cron jobs section
awk '
    /KiloShare Cloudinary/ { in_section=1; next }
    in_section && /^$/ && getline && /^$/ { in_section=0; next }
    in_section && /^[^#]/ { next }
    in_section && /^#/ { next }
    !in_section { print }
' "$TEMP_CRON" > "$TEMP_CRON_NEW"

# Install the cleaned crontab
echo "Removing cron jobs..."
crontab "$TEMP_CRON_NEW"

# Clean up
rm "$TEMP_CRON" "$TEMP_CRON_NEW"

echo -e "${GREEN}✅ Cloudinary cleanup cron jobs removed successfully!${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} Log files have been preserved and can be manually deleted if needed:"
echo "• logs/cloudinary_auto_cleanup.log"
echo "• logs/cloudinary_quota_check.log"  
echo "• logs/cloudinary_weekly_stats.log"
echo "• logs/cloudinary_monthly_report.log"
echo ""
echo -e "${GREEN}Removal complete!${NC}"