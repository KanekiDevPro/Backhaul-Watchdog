# 🔧 Backhaul Service Monitor

A simple and configurable Bash-based monitoring script to automatically restart a `systemd` service when errors are detected in its logs. Ideal for **VPN tunnels**, **proxy services**, or any critical `systemd` service that must stay online with minimal manual intervention.

---

## ⚙️ Features

- ✅ Monitors any `systemd` service for errors
- 🛠 Configurable time window & error patterns (regex-based)
- 🔁 Auto-restarts service upon error detection
- 📝 Logs every restart action
- ⏱ Automatically runs every 5 minutes using `cron`
- 🔄 Easy to install, edit, and remove via interactive script

---

## 🚀 Installation

Run the following script as `root`:

```bash
sudo bash backhaul_monitor_manager.sh
```

Then select:

```
1) Install backhaul monitor
```

You'll be prompted to configure:
- Service name (e.g. `backhaul.service`)
- Log file path (default: `/var/log/backhaul-monitor.log`)
- Log time window (e.g. last 5 minutes)
- Error pattern to search (default: `error|failed|fatal`)

---

## 🛠 Usage

### View or Edit Configuration

Run the script again and choose:

```
3) View or edit monitor configuration
```

You can then change:
- The monitored service name
- Path to the log file
- Time window in minutes
- Regex used to detect errors

### Uninstall

Choose:

```
2) Remove backhaul monitor
```

This will:
- Remove the cron job
- Delete the monitor script
- Optionally keep or remove log file

---

## 📂 File Structure

| File | Description |
|------|-------------|
| `/usr/local/bin/backhaul-monitor.sh` | Main monitoring script |
| `/var/log/backhaul-monitor.log`      | Log of auto-restarts |
| `crontab`                            | Runs monitor script every 5 minutes |
| `backhaul_monitor_manager.sh`        | Manager script to install/remove/edit monitor |

---

## 🧠 How It Works

Every 5 minutes, a cron job runs `backhaul-monitor.sh`, which:
1. Uses `journalctl` to fetch logs for the service in the past _N_ minutes
2. Greps logs for specified error patterns (regex)
3. If any match is found:
   - Logs a restart event with timestamp
   - Calls `systemctl restart <service>`

---

## 🛡️ Example Use Case

Monitoring a VPN tunnel that crashes silently:

```bash
SERVICE="xray.service"
SINCE_MINUTES=3
ERROR_REGEX="panic|unexpected EOF|failed"
```

If log entries contain any of the above, the service will be restarted automatically.

---

## 📌 Requirements

- Linux with `bash`
- `systemd` (for service management)
- `cron` (for scheduling)
- Root privileges

---

## 📣 Notes

- This script does **not** monitor CPU/memory/network — only journal logs.
- Multiple services can be monitored by duplicating the script and cron entries.
- Use with caution on high-availability services — consider `Restart=on-failure` in systemd first.

---

## 📜 License

MIT — free to use, modify, and share.

---

## ✉️ Contact

Developed by [YourNameHere]  
If you find it useful, ⭐ the repo or contribute!
