#!/bin/bash

if [[ "$(id -u)" -ne 0 ]]; then
  echo "This script must be run as root." >&2
  exit 1
fi

echo "Select action:"
echo "1) Install backhaul monitor"
echo "2) Remove backhaul monitor"
read -rp "Enter choice [1 or 2]: " CHOICE

MONITOR_SCRIPT="/usr/local/bin/backhaul-monitor.sh"
LOG_FILE="/var/log/backhaul-monitor.log"

case "$CHOICE" in
  1)
    read -rp "Enter the full systemd service name (e.g. backhaul.service): " SERVICE_NAME
    if [[ -z "$SERVICE_NAME" ]]; then
      echo "Service name cannot be empty." >&2
      exit 1
    fi

    echo "Writing monitor script to $MONITOR_SCRIPT..."
    cat > "$MONITOR_SCRIPT" <<EOF
#!/bin/bash
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

SERVICE="$SERVICE_NAME"
LOG="$LOG_FILE"

if journalctl -u "\$SERVICE" --since '5 minutes ago' | grep -Eiq 'error|failed|fatal'; then
    echo "[INFO] \$(date '+%Y-%m-%d %H:%M:%S'): Detected ERROR in \$SERVICE. Restarting service..." >> "\$LOG"
    systemctl restart "\$SERVICE"
fi
EOF

    chmod +x "$MONITOR_SCRIPT"

    echo "Creating log file at $LOG_FILE..."
    touch "$LOG_FILE"
    chmod 666 "$LOG_FILE"

    CRON_CMD="*/5 * * * * $MONITOR_SCRIPT"
    if crontab -l 2>/dev/null | grep -Fq "$MONITOR_SCRIPT"; then
      echo "Cron job already exists."
    else
      (crontab -l 2>/dev/null; echo "SHELL=/bin/bash"; echo "PATH=/usr/bin:/bin:/usr/sbin:/sbin"; echo "$CRON_CMD") | crontab -
      echo "Cron job installed to run every 5 minutes."
    fi
    echo "Installation complete."
    ;;
  2)
    echo "Removing backhaul monitor..."

    # Remove cron job
    if crontab -l 2>/dev/null | grep -Fq "$MONITOR_SCRIPT"; then
      crontab -l 2>/dev/null | grep -Fv "$MONITOR_SCRIPT" | crontab -
      echo "Cron job removed."
    else
      echo "Cron job not found."
    fi

    # Remove monitor script
    if [[ -f "$MONITOR_SCRIPT" ]]; then
      rm -f "$MONITOR_SCRIPT"
      echo "Monitor script removed."
    else
      echo "Monitor script not found."
    fi

    # Optional: Remove log file or leave it
    # rm -f "$LOG_FILE"
    echo "Done."
    ;;
  *)
    echo "Invalid choice."
    exit 1
    ;;
esac
