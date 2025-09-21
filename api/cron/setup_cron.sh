#!/bin/bash

# KiloShare Notification System Cron Jobs Setup
# Run this script to install cron jobs for the notification system

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHP_PATH="/usr/bin/php"

# Check if PHP is available
if ! command -v php &> /dev/null; then
    echo "PHP is not installed or not in PATH"
    exit 1
fi

# Get the actual PHP path
PHP_PATH=$(which php)
echo "Using PHP: $PHP_PATH"

# Create temporary cron file
TEMP_CRON_FILE="/tmp/kiloshare_cron_jobs"

# Write cron jobs to temporary file
cat > "$TEMP_CRON_FILE" << EOF
# KiloShare Notification System Cron Jobs

# Process notification queue every 2 minutes
*/2 * * * * $PHP_PATH $SCRIPT_DIR/notification_processor.php >> $SCRIPT_DIR/../logs/notification_processor.log 2>&1

# Send trip reminders every 15 minutes
*/15 * * * * $PHP_PATH $SCRIPT_DIR/trip_reminders.php >> $SCRIPT_DIR/../logs/trip_reminders.log 2>&1

# Clean up notification logs daily at 2 AM
0 2 * * * $PHP_PATH $SCRIPT_DIR/cleanup_logs.php >> $SCRIPT_DIR/../logs/cleanup.log 2>&1

EOF

# Install cron jobs
echo "Installing KiloShare notification cron jobs..."

# Get current crontab, filter out existing KiloShare jobs, and add new ones
(crontab -l 2>/dev/null | grep -v "KiloShare Notification System" | grep -v "notification_processor.php" | grep -v "trip_reminders.php" | grep -v "cleanup_logs.php"; cat "$TEMP_CRON_FILE") | crontab -

# Clean up temporary file
rm "$TEMP_CRON_FILE"

# Create logs directory if it doesn't exist
mkdir -p "$SCRIPT_DIR/../logs"

echo "Cron jobs installed successfully!"
echo ""
echo "Installed jobs:"
echo "- Notification processor: every 2 minutes"
echo "- Trip reminders: every 15 minutes"  
echo "- Log cleanup: daily at 2 AM"
echo ""
echo "Logs will be stored in: $SCRIPT_DIR/../logs/"
echo ""
echo "To view current cron jobs: crontab -l"
echo "To remove cron jobs: crontab -e (then delete the KiloShare lines)"