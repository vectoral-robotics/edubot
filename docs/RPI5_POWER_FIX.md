# RPi 5 Power Fix (GPIO 5.15V/8A)

When powering the RPi 5 via GPIO instead of USB-C, it assumes insufficient power and limits USB current.
USB devices may not be detected on boot.

## 1. Suppress Power Warning

```bash
sudo mkdir -p /etc/xdg/pemmican
sudo touch /etc/xdg/pemmican/max_current.inhibit
echo "usb_max_current_enable=1" | sudo tee -a /boot/firmware/config.txt
```

## 2. USB Device Watchdog (auto-reboot if device missing)

Create the script:

```bash
sudo tee /usr/local/bin/ensure-usb-devices.sh << 'EOF'
#!/bin/bash
DEVICES=("0c45:6360" "0bda:c811" "303a:1001")
NAMES=("Camera" "Realtek WiFi" "ESP32")
COUNTER_FILE="/tmp/usb-reboot-count"

sleep 10

for i in "${!DEVICES[@]}"; do
    if ! lsusb -d "${DEVICES[$i]}" > /dev/null 2>&1; then
        count=0
        [ -f "$COUNTER_FILE" ] && count=$(cat "$COUNTER_FILE")

        if [ "$count" -ge 2 ]; then
            echo "$(date): ${NAMES[$i]} still missing after 2 reboots - giving up" >> /var/log/usb-watchdog.log
            exit 1
        fi

        echo $((count + 1)) > "$COUNTER_FILE"
        echo "$(date): ${NAMES[$i]} missing - reboot #$((count + 1))" >> /var/log/usb-watchdog.log
        reboot
    fi
done

rm -f "$COUNTER_FILE"
echo "$(date): All USB devices present" >> /var/log/usb-watchdog.log
EOF

sudo chmod +x /usr/local/bin/ensure-usb-devices.sh
```

Create the systemd service:

```bash
sudo tee /etc/systemd/system/ensure-usb-devices.service << 'EOF'
[Unit]
Description=Ensure USB devices or reboot (max 2 attempts)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ensure-usb-devices.sh

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ensure-usb-devices.service
```

## 3. Verify

```bash
vcgencmd get_throttled
# 0x0 = OK, 0x50000 = undervoltage, 0xe0008 = thermal only

cat /var/log/usb-watchdog.log
```
