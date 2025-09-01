#!/bin/bash

# Cloudinary Cleanup Cron Jobs Setup Script
# This script sets up automated tasks for managing Cloudinary storage and bandwidth

set -e

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$PROJECT_ROOT/scripts/cloudinary_cleanup.php"
LOG_DIR="$PROJECT_ROOT/logs"
PHP_BIN="/usr/bin/php"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up Cloudinary cleanup cron jobs...${NC}"

# Check if PHP exists
if ! command -v php &> /dev/null; then
    echo -e "${RED}Error: PHP not found. Please install PHP first.${NC}"
    exit 1
fi

# Find correct PHP binary path
PHP_BIN=$(which php)
echo "Using PHP binary: $PHP_BIN"

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Make cleanup script executable
chmod +x "$SCRIPT_PATH"

# Create temporary crontab file
TEMP_CRON=$(mktemp)

# Backup existing crontab
echo "Backing up existing crontab..."
crontab -l > "$TEMP_CRON" 2>/dev/null || echo "# Empty crontab" > "$TEMP_CRON"

# Add Cloudinary cron jobs to the temp file
echo "" >> "$TEMP_CRON"
echo "# ===============================================" >> "$TEMP_CRON"
echo "# KiloShare Cloudinary Cleanup Cron Jobs" >> "$TEMP_CRON"
echo "# Generated on $(date)" >> "$TEMP_CRON"
echo "# ===============================================" >> "$TEMP_CRON"
echo "" >> "$TEMP_CRON"

echo "# Automatic cleanup check - every 6 hours" >> "$TEMP_CRON"
echo "0 */6 * * * $PHP_BIN $SCRIPT_PATH auto >> $LOG_DIR/cloudinary_auto_cleanup.log 2>&1" >> "$TEMP_CRON"

echo "# Daily quota check and alert - every day at 9:00 AM" >> "$TEMP_CRON"
echo "0 9 * * * $PHP_BIN $SCRIPT_PATH check-quota >> $LOG_DIR/cloudinary_quota_check.log 2>&1" >> "$TEMP_CRON"

echo "# Weekly usage statistics - every Monday at 8:00 AM" >> "$TEMP_CRON"
echo "0 8 * * 1 $PHP_BIN $SCRIPT_PATH stats >> $LOG_DIR/cloudinary_weekly_stats.log 2>&1" >> "$TEMP_CRON"

echo "# Monthly usage report - first day of month at 7:00 AM" >> "$TEMP_CRON"
echo "0 7 1 * * $PHP_BIN $SCRIPT_PATH report >> $LOG_DIR/cloudinary_monthly_report.log 2>&1" >> "$TEMP_CRON"

echo "" >> "$TEMP_CRON"

# Show what will be added
echo -e "${YELLOW}The following cron jobs will be added:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
grep -A 10 "KiloShare Cloudinary" "$TEMP_CRON"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Ask for confirmation
read -p "Do you want to install these cron jobs? (y/N): " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installation cancelled.${NC}"
    rm "$TEMP_CRON"
    exit 0
fi

# Install the new crontab
echo "Installing cron jobs..."
crontab "$TEMP_CRON"

# Clean up
rm "$TEMP_CRON"

echo -e "${GREEN}✅ Cloudinary cleanup cron jobs installed successfully!${NC}"
echo ""
echo -e "${YELLOW}Cron Jobs Schedule:${NC}"
echo "• Auto cleanup: Every 6 hours (when quota > 75%)"
echo "• Quota check: Daily at 9:00 AM"
echo "• Weekly stats: Every Monday at 8:00 AM"
echo "• Monthly report: 1st of each month at 7:00 AM"
echo ""
echo -e "${YELLOW}Log Files:${NC}"
echo "• Auto cleanup: $LOG_DIR/cloudinary_auto_cleanup.log"
echo "• Quota checks: $LOG_DIR/cloudinary_quota_check.log"
echo "• Weekly stats: $LOG_DIR/cloudinary_weekly_stats.log"
echo "• Monthly reports: $LOG_DIR/cloudinary_monthly_report.log"
echo ""
echo -e "${YELLOW}Management Commands:${NC}"
echo "• View cron jobs: crontab -l"
echo "• Edit cron jobs: crontab -e"
echo "• Test cleanup: $PHP_BIN $SCRIPT_PATH auto --dry-run --verbose"
echo ""
echo -e "${GREEN}Setup complete!${NC}"