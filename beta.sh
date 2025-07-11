#!/bin/bash

if [[ "$(id -u)" -ne 0 ]]; then
  echo "This script must be run as root." >&2
  exit 1
fi

CONF_DIR="/etc/backhaul-monitor"
CONF_FILE="$CONF_DIR/config.conf"
MONITOR_SCRIPT="/usr/local/bin/backhaul-monitor.sh"
LOG_FILE="/var/log/backhaul-monitor.log"

mkdir -p "$CONF_DIR"

echo "Backhaul Monitor Manager"
echo "1) Install Monitor"
echo "2) Remove Monitor"
echo "3) View/Edit Configuration"
read -rp "Enter choice [1/2/3]: " CHOICE

case "$CHOICE" in
  1)
    echo "Enter systemd service names to monitor (comma separated):"
    read -rp "Example: nginx.service,apache2.service: " SERVICE_LIST

    read -rp "Log file path [$LOG_FILE]: " INPUT_LOG
    LOG_PATH="${INPUT_LOG:-$LOG_FILE}"

    read -rp "Time window to check (minutes) [5]: " TIME_WINDOW
    TIME_WINDOW="${TIME_WINDOW:-5}"

    read -rp "Error keywords (regex) [error|failed|fatal]: " ERROR_REGEX
    ERROR_REGEX="${ERROR_REGEX:-error|failed|fatal}"

    read -rp "Max restarts allowed in $TIME_WINDOW min [3]: " MAX_RESTARTS
    MAX_RESTARTS="${MAX_RESTARTS:-3}"

    echo "Saving configuration..."
    cat > "$CONF_FILE" <<EOF
SERVICES="$SERVICE_LIST"
LOG="$LOG_PATH"
WINDOW=$TIME_WINDOW
REGEX="$ERROR_REGEX"
MAX=$MAX_RESTARTS
EOF

    echo "Writing monitor script to $MONITOR_SCRIPT..."
    cat > "$MONITOR_SCRIPT" <<'EOF'
#!/bin/bash
source /etc/backhaul-monitor/config.conf
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

for SERVICE in $(echo "$SERVICES" | tr ',' ' '); do
  STATUS=$(systemctl is-active "$SERVICE")
  echo "[STATUS] $SERVICE is $STATUS" >> "$LOG"

  ERROR_COUNT=$(journalctl -u "$SERVICE" --since "$WINDOW minutes ago" | grep -Eic "$REGEX")
  RESTART_LOG_COUNT=$(journalctl -u "$SERVICE" --since "$WINDOW minutes ago" | grep -ic "Restarting service")

  if [[ "$ERROR_COUNT" -gt 0 && "$RESTART_LOG_COUNT" -lt "$MAX" ]]; then
    echo "[INFO] $(date '+%F %T'): ERROR detected in $SERVICE. Restarting..." >> "$LOG"
    systemctl restart "$SERVICE"
  elif [[ "$ERROR_COUNT" -gt 0 ]]; then
    echo "[WARN] $(date '+%F %T'): Too many restarts for $SERVICE. Skipping restart." >> "$LOG"
  fi
done
EOF

    chmod +x "$MONITOR_SCRIPT"
    touch "$LOG_PATH"
    chmod 666 "$LOG_PATH"

    if crontab -l 2>/dev/null | grep -Fq "$MONITOR_SCRIPT"; then
      echo "Cron job already exists."
    else
      (crontab -l 2>/dev/null; echo "SHELL=/bin/bash"; echo "PATH=/usr/bin:/bin:/usr/sbin:/sbin"; echo "*/5 * * * * $MONITOR_SCRIPT") | crontab -
      echo "Cron job added: runs every 5 min."
    fi

    echo "Monitor installed!"
    ;;

  2)
    echo "Removing monitor..."
    crontab -l 2>/dev/null | grep -Fv "$MONITOR_SCRIPT" | crontab -
    rm -f "$MONITOR_SCRIPT" "$CONF_FILE"
    echo "Monitor removed."
    ;;

  3)
    if [[ ! -f "$CONF_FILE" ]]; then
      echo "Configuration not found. Install monitor first." >&2
      exit 1
    fi

    echo "Current Configuration:"
    cat "$CONF_FILE"
    echo

    read -rp "Edit config? [y/N]: " CONFIRM
    [[ ! "$CONFIRM" =~ ^[Yy]$ ]] && exit 0

    read -rp "New service list (comma separated): " NEW_SERVICES
    [[ -n "$NEW_SERVICES" ]] && sed -i "s|^SERVICES=.*|SERVICES=\"$NEW_SERVICES\"|" "$CONF_FILE"

    read -rp "New log file path: " NEW_LOG
    [[ -n "$NEW_LOG" ]] && sed -i "s|^LOG=.*|LOG=\"$NEW_LOG\"|" "$CONF_FILE"

    read -rp "New time window (minutes): " NEW_WIN
    [[ -n "$NEW_WIN" ]] && sed -i "s|^WINDOW=.*|WINDOW=$NEW_WIN|" "$CONF_FILE"

    read -rp "New error keywords regex: " NEW_REGEX
    [[ -n "$NEW_REGEX" ]] && sed -i "s|^REGEX=.*|REGEX=\"$NEW_REGEX\"|" "$CONF_FILE"

    read -rp "New max restart attempts: " NEW_MAX
    [[ -n "$NEW_MAX" ]] && sed -i "s|^MAX=.*|MAX=$NEW_MAX|" "$CONF_FILE"

    echo "Configuration updated."
    ;;

  *)
    echo "Invalid choice."
    exit 1
    ;;
esac
