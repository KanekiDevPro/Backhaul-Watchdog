#!/bin/bash

if [[ "$(id -u)" -ne 0 ]]; then
  echo "This script must be run as root." >&2
  exit 1
fi

MONITOR_SCRIPT="/usr/local/bin/backhaul-monitor.sh"
LOG_FILE="/var/log/backhaul-monitor.log"

echo "Select action:"
echo "1) Install backhaul monitor"
echo "2) Remove backhaul monitor"
echo "3) View or edit monitor configuration"
read -rp "Enter choice [1, 2 or 3]: " CHOICE

case "$CHOICE" in
  1)
    read -rp "Enter systemd service name to monitor (e.g. backhaul.service): " SERVICE_NAME
    read -rp "Enter log file path [$LOG_FILE]: " INPUT_LOG
    LOG_PATH="${INPUT_LOG:-$LOG_FILE}"
    read -rp "Enter time window in minutes to check logs [5]: " TIME_WINDOW
    TIME_WINDOW="${TIME_WINDOW:-5}"
    read -rp "Enter error keywords (regex) to detect [error|failed|fatal]: " ERROR_REGEX
    ERROR_REGEX="${ERROR_REGEX:-error|failed|fatal}"

    echo "Writing monitor script to $MONITOR_SCRIPT..."
    cat > "$MONITOR_SCRIPT" <<EOF
#!/bin/bash
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

SERVICE="$SERVICE_NAME"
LOG="$LOG_PATH"
SINCE_MINUTES=$TIME_WINDOW
ERROR_REGEX="$ERROR_REGEX"

if journalctl -u "\$SERVICE" --since "\${SINCE_MINUTES} minutes ago" | grep -Eiq "\$ERROR_REGEX"; then
    echo "[INFO] \$(date '+%Y-%m-%d %H:%M:%S'): Detected ERROR in \$SERVICE. Restarting service..." >> "\$LOG"
    systemctl restart "\$SERVICE"
fi
EOF

    chmod +x "$MONITOR_SCRIPT"
    touch "$LOG_PATH"
    chmod 666 "$LOG_PATH"

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
    if crontab -l 2>/dev/null | grep -Fq "$MONITOR_SCRIPT"; then
      crontab -l 2>/dev/null | grep -Fv "$MONITOR_SCRIPT" | crontab -
      echo "Cron job removed."
    else
      echo "Cron job not found."
    fi

    if [[ -f "$MONITOR_SCRIPT" ]]; then
      rm -f "$MONITOR_SCRIPT"
      echo "Monitor script removed."
    else
      echo "Monitor script not found."
    fi

    echo "Done."
    ;;
  3)
    if [[ ! -f "$MONITOR_SCRIPT" ]]; then
      echo "Monitor script not found. Please install it first." >&2
      exit 1
    fi

    echo "Current monitor configuration:"
    grep -E '^(SERVICE|LOG|SINCE_MINUTES|ERROR_REGEX)=' "$MONITOR_SCRIPT"
    echo

    read -rp "Do you want to edit configuration? [y/N]: " CONFIRM_EDIT
    if [[ "$CONFIRM_EDIT" =~ ^[Yy]$ ]]; then
      read -rp "New service name (leave blank to keep current): " NEW_SERVICE
      [[ -n "$NEW_SERVICE" ]] && sed -i "s|^SERVICE=.*|SERVICE=\"$NEW_SERVICE\"|" "$MONITOR_SCRIPT"

      read -rp "New log file path (leave blank to keep current): " NEW_LOG
      [[ -n "$NEW_LOG" ]] && sed -i "s|^LOG=.*|LOG=\"$NEW_LOG\"|" "$MONITOR_SCRIPT"

      read -rp "New time window in minutes (leave blank to keep current): " NEW_MIN
      [[ -n "$NEW_MIN" ]] && sed -i "s|^SINCE_MINUTES=.*|SINCE_MINUTES=$NEW_MIN|" "$MONITOR_SCRIPT"

      read -rp "New error regex (leave blank to keep current): " NEW_REGEX
      [[ -n "$NEW_REGEX" ]] && sed -i "s|^ERROR_REGEX=.*|ERROR_REGEX=\"$NEW_REGEX\"|" "$MONITOR_SCRIPT"

      echo "Configuration updated."
    fi
    ;;
  *)
    echo "Invalid choice."
    exit 1
    ;;
esac
