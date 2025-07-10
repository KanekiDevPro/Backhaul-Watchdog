#!/bin/bash

# This installer script sets up a backhaul-monitor for a given systemd service
# It will:
# 1. Prompt for the service name
# 2. Create /usr/local/bin/backhaul-monitor.sh with the appropriate configuration
# 3. Make it executable, create the log file, and set permissions
# 4. Add a cron entry under root to run the monitor every 5 minutes

# Ensure script runs as root
test "$(id -u)" -eq 0 || { echo "This script must be run as root." >&2; exit 1; }

read -p "Enter the full systemd service name (e.g. backhaul.service): " SERVICE_NAME
if [[ -z "$SERVICE_NAME" ]]; then
  echo "Service name cannot be empty." >&2
  exit 1
fi

# Paths and variables
MONITOR_SCRIPT="/usr/local/bin/backhaul-monitor.sh"
LOG_FILE="/var/log/backhaul-monitor.log"

# Write the monitor script
echo "Writing monitor script to $MONITOR_SCRIPT..."
cat > "$MONITOR_SCRIPT" <<EOF
#!/bin/bash
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

SERVICE="$SERVICE_NAME"
LOG="$LOG_FILE"

# Check for errors in the last 5 minutes
if journalctl -u "\$SERVICE" --since '5 minutes ago' | grep -Eiq 'error|failed|fatal'; then
    echo "[INFO] \$(date '+%Y-%m-%d %H:%M:%S'): Detected ERROR in \$SERVICE. Restarting service..." >> "\$LOG"
    systemctl restart "\$SERVICE"
fi
EOF

# Set permissions
chmod +x "$MONITOR_SCRIPT"

echo "Creating log file at $LOG_FILE..."
touch "$LOG_FILE"
chmod 666 "$LOG_FILE"

# Install cron job for root
CRON_CMD="*/5 * * * * $MONITOR_SCRIPT"
# Preserve existing root crontab and append if not present
crontab -l 2>/dev/null | grep -F "$MONITOR_SCRIPT" >/dev/null || (
    (crontab -l 2>/dev/null; echo "SHELL=/bin/bash"; echo "PATH=/usr/bin:/bin:/usr/sbin:/sbin"; echo "$CRON_CMD") | crontab -
)

echo "Setup complete!"
echo "Monitor \"$SERVICE_NAME\" will run every 5 minutes. Check \"$LOG_FILE\" for entries."
